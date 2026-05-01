import {
  BadRequestException,
  Body,
  Controller,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsNotEmpty,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import { z } from 'zod';
import { AgentContextInput } from './ai-health-agent.service';
import { AuthGuard } from '../common/auth.guard';
import { CurrentUser, CurrentUserPayload } from '../common/current-user.decorator';
import { AiHealthAgentService } from './ai-health-agent.service';

class TriageDto {
  @IsOptional()
  @IsString()
  symptoms?: string;

  /** @deprecated use symptoms */
  @IsOptional()
  @IsString()
  symptomText?: string;

  @IsOptional()
  @IsString()
  age?: string;

  @IsOptional()
  @IsString()
  gender?: string;

  @IsOptional()
  @IsString()
  duration?: string;

  @IsOptional()
  @IsString()
  severity?: string;
}

class AgentImageDto {
  @IsOptional()
  @IsString()
  url?: string;

  @IsOptional()
  @IsString()
  base64?: string;

  @IsOptional()
  @IsString()
  mime?: string;
}

class AgentHistoryItemDto {
  @IsString()
  role!: string;

  @IsString()
  @IsNotEmpty()
  content!: string;
}

class AgentContextDto {
  @IsOptional()
  @IsString()
  userId?: string;

  @IsOptional()
  @IsString()
  language?: string;

  @IsOptional()
  @IsString()
  currentScreen?: string;

  @IsOptional()
  @IsString()
  conversationId?: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => AgentHistoryItemDto)
  history?: AgentHistoryItemDto[];
}

class AgentRequestDto {
  @IsOptional()
  @IsString()
  message?: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => AgentImageDto)
  images?: AgentImageDto[];

  @IsOptional()
  @IsString()
  userId?: string;

  @IsOptional()
  @IsString()
  conversationId?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => AgentContextDto)
  context?: AgentContextDto;
}

const imageBodySchema = z
  .object({
    url: z.string().url().trim().max(2048).optional(),
    base64: z.string().max(12000000).optional(),
    mime: z.string().trim().max(128).optional(),
  })
  .superRefine((val, ctx) => {
    const hasUrl = val.url != null && val.url.trim().length > 0;
    const hasB64 =
      val.base64 != null &&
      typeof val.base64 === 'string' &&
      val.base64.trim().length > 0;
    if (!hasUrl && !hasB64) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Each image requires url or base64',
      });
    }
  });

const ChatRequestSchema = z
  .object({
    message: z.string().max(6000).default(''),
    images: z.array(imageBodySchema).max(16).optional(),
    userId: z.string().trim().min(1).max(128).optional(),
    conversationId: z.string().trim().min(1).max(128).optional(),
    context: z
      .object({
        userId: z.string().trim().min(1).max(128).optional(),
        language: z.string().trim().min(2).max(8).optional(),
        currentScreen: z.string().trim().min(1).max(64).optional(),
        conversationId: z.string().trim().min(1).max(128).optional(),
        history: z
          .array(
            z.object({
              role: z.string().trim().min(1).max(32),
              content: z.string().trim().min(1).max(6000),
            }),
          )
          .max(20)
          .optional(),
      })
      .optional(),
  })
  .transform((d) => ({
    ...d,
    message:
      typeof d.message === 'string' ? d.message.trim() : '',
  }))
  .refine(
    (d) =>
      d.message.length > 0 ||
      (Array.isArray(d.images) && d.images.length > 0),
    { message: 'message or images required', path: ['message'] },
  );

type ParsedChatBody = z.infer<typeof ChatRequestSchema>;

function mapIncomingImages(
  images?: ParsedChatBody['images'],
): AgentContextInput['images'] {
  if (!images?.length) {
    return undefined;
  }
  return images.map((i) => ({
    ...(i.url != null && i.url.trim() ? { url: i.url.trim() } : {}),
    ...(i.base64 != null &&
    typeof i.base64 === 'string' &&
    i.base64.trim().length > 0
      ? { base64: i.base64.trim() }
      : {}),
    ...(i.mime?.trim() ? { mime: i.mime.trim() } : {}),
  }));
}

/** Merge body-level ids, nested context fields, optional vision payloads. */
function buildAgentCtxFromBody(
  body: ParsedChatBody,
): AgentContextInput | undefined {
  const images = mapIncomingImages(body.images);
  const hasContext = body.context != null;
  const hasIds = !!(body.conversationId || body.userId);
  const hasImages = !!(images?.length);

  if (!hasContext && !hasIds && !hasImages) {
    return undefined;
  }

  return {
    userId: body.context?.userId,
    language: body.context?.language,
    currentScreen: body.context?.currentScreen,
    conversationId: body.conversationId ?? body.context?.conversationId,
    history: body.context?.history?.map((h) => ({
      role: h.role,
      content: h.content,
    })),
    images,
  };
}

@Controller(['api/ai', 'ai-agent'])
export class AiAgentController {
  constructor(private readonly healthAgentService: AiHealthAgentService) {}

  @Post('chat')
  @Throttle({ default: { limit: 25, ttl: 60000 } })
  chat(@Body() dto: AgentRequestDto) {
    const parsed = ChatRequestSchema.safeParse(dto);
    if (!parsed.success) {
      throw new BadRequestException('Invalid AI chat request payload');
    }
    const body = parsed.data;
    const ctx = buildAgentCtxFromBody(body);
    return this.healthAgentService.runChat(body.message, {
      ...ctx,
      userId: body.userId ?? ctx?.userId,
      conversationId: body.conversationId ?? ctx?.conversationId,
    });
  }

  @Post('recommend')
  @UseGuards(AuthGuard)
  recommend(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: AgentRequestDto,
  ) {
    const parsed = ChatRequestSchema.safeParse(dto);
    if (!parsed.success) {
      throw new BadRequestException('Invalid AI chat request payload');
    }
    const body = parsed.data;
    const ctx = buildAgentCtxFromBody(body);
    return this.healthAgentService.runRecommend(body.message, ctx, {
      userId: user.sub,
      role: user.role,
    });
  }

  @Post('actions')
  @UseGuards(AuthGuard)
  actions(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: AgentRequestDto,
  ) {
    const parsed = ChatRequestSchema.safeParse(dto);
    if (!parsed.success) {
      throw new BadRequestException('Invalid AI chat request payload');
    }
    const body = parsed.data;
    const ctx = buildAgentCtxFromBody(body);
    return this.healthAgentService.runActions(body.message, ctx, {
      userId: user.sub,
      role: user.role,
    });
  }

  @Post('agent')
  agent(@Body() dto: AgentRequestDto) {
    const parsed = ChatRequestSchema.safeParse(dto);
    if (!parsed.success) {
      throw new BadRequestException('Invalid AI chat request payload');
    }
    const body = parsed.data;
    const ctx = buildAgentCtxFromBody(body);
    return this.healthAgentService.runChat(body.message, ctx);
  }

  @Post('triage')
  triage(@Body() dto: TriageDto) {
    const symptoms = (dto.symptoms ?? dto.symptomText ?? '').trim();
    if (!symptoms) {
      throw new BadRequestException(
        'symptoms (or legacy symptomText) is required',
      );
    }
    return this.healthAgentService.runTriage({
      symptoms,
      age: dto.age,
      gender: dto.gender,
      duration: dto.duration,
      severity: dto.severity,
    });
  }
}
