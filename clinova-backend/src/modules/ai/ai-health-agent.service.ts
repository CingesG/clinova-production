import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Role } from '@prisma/client';
import OpenAI from 'openai';

import { AppointmentService } from '../appointment/appointment.service';
import { PrismaService } from '../common/prisma.service';

export type RiskLevel = 'low' | 'medium' | 'high' | 'emergency';

export interface AgentImageInput {
  /** Public HTTPS-only URL readable by OpenAI servers (e.g. already-uploaded file). */
  url?: string;
  /** Raw base64 (no data: prefix). Prefer JPEG/PNG/WebP via [mime]. */
  base64?: string;
  /** e.g. image/jpeg, image/png */
  mime?: string;
}

export interface AgentContextInput {
  userId?: string;
  language?: string;
  currentScreen?: string;
  conversationId?: string;
  history?: Array<{ role: string; content: string }>;
  /** Up to ~4 vision inputs for multimodal model. */
  images?: AgentImageInput[];
}

export interface ClinovaAgentAction {
  type: string;
  label: string;
  route?: string;
  params?: Record<string, unknown>;
  payload: Record<string, unknown>;
}

export type ClinovaAgentIntent =
  | 'symptom_check'
  | 'image_analysis'
  | 'appointment_help'
  | 'doctor_recommendation'
  | 'service_info'
  | 'emergency'
  | 'app_help'
  | 'general';

export interface ClinovaAgentResponse {
  /** Primary user-facing text (same as reply; API / grading-friendly name). */
  answerText: string;
  reply: string;
  suggestions: string[];
  recommendedServices: Array<Record<string, unknown>>;
  recommendedDoctors: Array<Record<string, unknown>>;
  availableSlots: Array<Record<string, unknown>>;
  riskLevel: RiskLevel;
  conversationId?: string;
  actions: ClinovaAgentAction[];
  /** Alias of actions for structured JSON contract. */
  suggestedActions: ClinovaAgentAction[];
  safetyDisclaimer: string;
  metadata: Record<string, unknown>;
  answer: string;
  followUpQuestions: string[];
  urgency: 'LOW' | 'MEDIUM' | 'HIGH' | 'EMERGENCY' | 'NONE';
  type: 'GENERAL' | 'TRIAGE' | 'EMERGENCY' | 'BOOKING_HELP';
  /** Structured intent for clients (UI chips, analytics). */
  intent: ClinovaAgentIntent;
  recommendedDepartment: string | null;
  /** e.g. "стоматолог", "дотоодын эмч" — when DB has no named doctor. */
  recommendedDoctorType: string | null;
  /** When true, client should show image preliminary disclaimer (Mn). */
  imageAnalysisDisclaimer: boolean;
}

/** Богино мэндчилгээ, байгаа эсэх, «юугаар туслах вэ» гэх мэт — LLM дамжуулаад зайлшгүй дуудагдахгүй. */
type SmalltalkKind = 'GREETING' | 'HELP_MENU' | 'THANKS';

const EMERGENCY_PATTERNS: RegExp[] = [
  /chest\s*pain|цээж.*өвд|tseej.*(ovd|uwd)|давсагтай\s*цээж/i,
  /shortness\s*of\s*breath|can't\s*breathe|амьсгал.*давч|амьсгал.*хүнд/i,
  /severe\s*bleed|hemorrhage|хүчтэй.*цус|цус\s*алда|tsus.*(ih|ald)/i,
  /stroke|face.*droop|slurred\s*speech|инсульт|судас.*хаагд|хэл.*бүхий/i,
  /loss\s*of\s*consciousness|unresponsive|faint(ing)?|ухаан.*алда|балар|uhaan.*alda/i,
  /anaphylaxis|throat.*swelling|харшил.*амь|хоолой.*хөндүүр/i,
  /pregnancy.*bleed|eclampsia|жирэмсэн.*цус|жирэмсэн.*хорхой|хөөрөлт|товлолт/i,
  /seizure|convulsion|чичиргээ|таталт|гүйцэд\s*гэмтэл/i,
  /suicid|self[\s-]*harm|амь\s*хорлох|өөрийгөө\s*хорлох|ахин\s*алах\s*санагд/i,
  /infant|newborn|нярай|жоотой\s*хүүхэд|5\s*сартай|1\s*настай.*(халуур|амьсгал)/i,
  /baby.*(fever|breath)|(хүүхэд|нярай).*(халуур|хүнд).*(амьсгал|амьсгаа)/i,
];

@Injectable()
export class AiHealthAgentService {
  private readonly logger = new Logger(AiHealthAgentService.name);
  private readonly client?: OpenAI;
  private readonly safetyDisclaimer =
    'Clinova AI нь зөвхөн мэдээллийн чиглүүлэг өгнө. Эцсийн онош, эмчилгээ, эмийн тунг зөвхөн эмч шийднэ.';

  private resolveOpenAiModel(forVision: boolean): string {
    const visionModel = this.config.get<string>('OPENAI_VISION_MODEL')?.trim();
    const primary = this.config.get<string>('OPENAI_MODEL')?.trim();
    if (forVision) {
      if (visionModel) return visionModel;
      if (primary) return primary;
      return 'gpt-4o-mini';
    }
    if (primary) return primary;
    return 'gpt-4o-mini';
  }

  /** Add Mongolian + clinical hints so Prisma search finds dental / gastro / OB-GYN rows. */
  private expandSymptomSearchForClinova(symptoms: string): string {
    const t = `${symptoms} ${this.toSearchableText(symptoms)}`.toLowerCase();
    const bits: string[] = [symptoms];
    if (/шүд|шүдэн|cuspid|dental|стоматолог/i.test(t)) bits.push('шүд стоматолог dental');
    if (/гэдэс|хэвлий|stomach|gastro|gist|ойгуулал|acid|reflux/i.test(t))
      bits.push('гэдэс дотоод эмч gastro');
    if (/жирэмсэн|төрөх|хүүхэд\s*төрүүлэх|эмэгтэйчүүд|obgyn|хагас\s*эх/i.test(t))
      bits.push('жирэмсэн эмэгтэйчүүд төрөх');
    if (/хүүхэд|child|pediat|педиатр/i.test(t)) bits.push('хүүхэд педиатр');
    if (/цээж|зүрх|cardio|давхар судас/i.test(t)) bits.push('зүрх судас');
    if (/амьсгал|уртавч|pulmo|үндсэн/i.test(t)) bits.push('амьсгалын эмч');
    return [...new Set(bits)].join(' ');
  }

  private inferRecommendedDoctorTypeFromUserText(text: string): string | null {
    const t = this.toSearchableText(text);
    if (/шүд|dental|стоматолог/i.test(t)) return 'Стоматолог (шүдний эмч)';
    if (/гэдэс|gastro|хэвлий|stomach/i.test(t)) return 'Дотоодын эмч / гастроэнтеролог';
    if (/жирэмсэн|төрөх|obgyn|эмэгтэйчүүд/i.test(t)) return 'Эмэгтэйчүүдийн эмч / акушер-гинеколог';
    if (/хүүхэд|pediat/i.test(t)) return 'Хүүхдийн эмч';
    return null;
  }

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly appointments: AppointmentService,
  ) {
    const apiKey = this.config.get<string>('OPENAI_API_KEY');
    if (apiKey) this.client = new OpenAI({ apiKey });
  }

  async runChat(
    message: string,
    ctx?: AgentContextInput,
    currentUser?: { userId: string; role: Role },
  ): Promise<ClinovaAgentResponse> {
    const visionImages = this.sanitizeIncomingImages(ctx?.images);
    const hasVision = visionImages.length > 0;
    const textTrimmed = message.trim();
    const textForAi =
      textTrimmed ||
      (hasVision
        ? 'Хавсаргасан зургийг ажиглаад: юу анхаарууштай харагдаж байна, ямар эрүүл мэндийн чиг хандлага санагдуулж байна, Clinova апп дээр дараагийн алхмыг онцлон тайлбарлаарай. Зургийн чанарыг үл хүндэтгээд онош бус зөвлөмж байна.'
        : '');
    if (!textForAi || (!textTrimmed && !hasVision)) {
      return this.fallback('Асуулт бичээд үлдээх эсвэл зураг сонгоно уу.');
    }

    const persistedLine = [
      ...(hasVision ? [`[зураг:${visionImages.length}]`] : []),
      textTrimmed || (hasVision ? 'зураг' : ''),
    ]
      .filter((x) => x.length > 0)
      .join(' ');

    const userId = currentUser?.userId ?? ctx?.userId;
    const role = currentUser?.role ?? (await this.resolveRole(userId));
    const conversationId = userId
      ? await this.ensureConversationAndSaveUserMessage(userId, role, persistedLine, ctx?.conversationId)
      : ctx?.conversationId;

    if (EMERGENCY_PATTERNS.some((re) => re.test(this.toSearchableText(textForAi)))) {
      const out = this.emergency(conversationId);
      await this.persistAi(conversationId, out);
      return out;
    }

    if (!hasVision) {
      const small = this.detectSmalltalk(textTrimmed);
      if (small !== null) {
        const out = this.smalltalkResponse(small, conversationId);
        await this.persistAi(conversationId, out);
        return out;
      }
    }

    let out: ClinovaAgentResponse;
    if (!this.client) {
      out = this.fallback(
        'AI түр хугацаанд хязгаарлагдмал байна. Шинж тэмдгээ дэлгэрэнгүй бичвэл үйлчилгээ, эмч, боломжтой цаг санал болгоно.',
        conversationId,
        userId,
      );
    } else {
      const history = await this.loadRecentHistory(conversationId, ctx?.history);
      out = await this.askOpenAi(
        textForAi,
        history,
        userId,
        ctx?.language ?? 'mn',
        conversationId,
        hasVision ? visionImages : undefined,
      );
    }

    await this.persistAi(conversationId, out);
    return out;
  }

  async runRecommend(
    message: string,
    ctx?: AgentContextInput,
    currentUser?: { userId: string; role: Role },
  ) {
    const base = await this.runChat(message, ctx, currentUser);
    return {
      riskLevel: base.riskLevel,
      suggestions: base.suggestions,
      recommendedServices: base.recommendedServices,
      recommendedDoctors: base.recommendedDoctors,
      availableSlots: base.availableSlots,
      actions: base.actions,
      conversationId: base.conversationId,
    };
  }

  async runActions(
    message: string,
    ctx?: AgentContextInput,
    currentUser?: { userId: string; role: Role },
  ) {
    const base = await this.runChat(message, ctx, currentUser);
    return {
      riskLevel: base.riskLevel,
      actions: base.actions,
      conversationId: base.conversationId,
    };
  }

  async runTriage(input: {
    symptoms: string;
    age?: string;
    gender?: string;
    duration?: string;
    severity?: string;
  }) {
    const merged = [input.symptoms, input.age, input.gender, input.duration, input.severity]
      .filter((x) => x != null && String(x).trim().length > 0)
      .join(' | ');
    const base = await this.runChat(merged, { language: 'mn', currentScreen: 'triage' });
    return {
      urgency: base.urgency,
      summary: base.reply,
      answerText: base.answerText,
      intent: base.intent,
      nextSteps: base.suggestions,
      recommendedDepartment: base.recommendedDepartment,
      recommendedDoctorType: base.recommendedDoctorType,
      suggestedDoctors: base.recommendedDoctors,
      availableSlots: base.availableSlots,
      actions: base.actions,
      suggestedActions: base.suggestedActions,
    };
  }

  private async askOpenAi(
    text: string,
    history: Array<{ role: string; content: string }>,
    userId: string | undefined,
    languageHint: string,
    conversationId?: string,
    visionImages?: AgentImageInput[],
  ): Promise<ClinovaAgentResponse> {
    const hasVision = Boolean(visionImages?.length);
    const model = this.resolveOpenAiModel(hasVision);
    const historyText = history
      .slice(-20)
      .map((h) => `${h.role}: ${h.content}`)
      .join('\n');

    const userContent = this.buildUserMultimodalContent(historyText, text, visionImages);

    try {
      const inferenceOpts = this.openAiInferenceOptions();
      let r: any = await this.client!.responses.create({
        ...inferenceOpts,
        model,
        input: [
          { role: 'system', content: this.systemPrompt(languageHint, Boolean(visionImages?.length)) },
          typeof userContent === 'string'
            ? { role: 'user', content: userContent }
            : { role: 'user', content: userContent as any },
        ],
        tools: this.openAiTools() as any,
      });

      for (let i = 0; i < 6; i++) {
        const calls = this.extractFunctionCalls(r);
        if (calls.length === 0) break;
        const outputs: Array<Record<string, unknown>> = [];
        for (const c of calls) {
          const result = await this.executeTool(c.name, this.safeJson(c.arguments), userId);
          outputs.push({
            type: 'function_call_output',
            call_id: c.call_id,
            output: JSON.stringify(result),
          });
        }
        r = await this.client!.responses.create({
          ...inferenceOpts,
          model,
          previous_response_id: r.id,
          input: outputs as any,
        });
      }

      return this.normalize(this.parseAgentJsonPayload(this.extractText(r)), conversationId, {
        hadVision: hasVision,
        userId,
        model,
        userMessage: text,
      });
    } catch (e) {
      this.logger.warn(`Responses API failed (model=${model}): ${this.extractShortError(e)}`);
      return this.localFallbackFromTools(text, userId, conversationId, e, hasVision);
    }
  }

  /** Text-only or multimodal (OpenAI Responses `input_*` blocks). */
  private buildUserMultimodalContent(
    historyText: string,
    text: string,
    images?: AgentImageInput[],
  ): string | Array<Record<string, unknown>> {
    const header = `conversation_history:\n${historyText}\n\nuser_message:\n${text}`;
    const list = images?.filter(Boolean) ?? [];
    if (!list.length) return header;

    const parts: Array<Record<string, unknown>> = [
      {
        type: 'input_text',
        text: `${header}\n\n(Attached: ${list.length} image(s). Describe relevant visible detail, keep medical caveats, then use tools if booking data is needed.)`,
      },
    ];
    for (const im of list) {
      const imageUrl =
        typeof im.url === 'string' && im.url.trim().length > 0
          ? im.url.trim()
          : typeof im.base64 === 'string' && im.base64.trim().length > 0
            ? (() => {
                const mimeRaw = (im.mime ?? 'image/jpeg').split(';')[0].trim().toLowerCase();
                const mime = /^image\/(jpeg|png|webp|gif)$/.test(mimeRaw)
                  ? mimeRaw
                  : 'image/jpeg';
                return `data:${mime};base64,${im.base64!.trim()}`;
              })()
            : null;

      if (!imageUrl) continue;
      parts.push({
        type: 'input_image',
        detail: 'high',
        image_url: imageUrl,
      });
    }
    return parts.length > 1 ? parts : header;
  }

  /** Max count, HTTPS-only URLs, bounded base64. */
  private sanitizeIncomingImages(raw?: AgentImageInput[]): AgentImageInput[] {
    if (!raw?.length) return [];

    const maxN = Number(this.config.get('AI_AGENT_MAX_IMAGES') ?? '4');
    const clampedN =
      Number.isFinite(maxN) && maxN >= 1 && maxN <= 8 ? Math.floor(maxN) : 4;
    const mb = Number(this.config.get('AI_AGENT_MAX_IMAGE_MB') ?? '8');
    const clampedMb =
      Number.isFinite(mb) && mb >= 0.25 && mb <= 20 ? mb : 8;
    const maxBytes = clampedMb * 1024 * 1024;

    const allowedMime = /^image\/(jpeg|jpg|png|webp|gif)$/i;

    const out: AgentImageInput[] = [];
    for (const item of raw) {
      if (out.length >= clampedN) break;
      const url = typeof item.url === 'string' ? item.url.trim() : '';
      const base64Raw = typeof item.base64 === 'string' ? item.base64.trim() : '';
      if (!url && !base64Raw) continue;

      if (url.length > 0) {
        if (!/^https:\/\//i.test(url)) continue;
        try {
          const hostname = new URL(url).hostname;
          const blocked =
            hostname === 'localhost' ||
            /^127\.|^169\.|^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\./i.test(hostname) ||
            hostname.endsWith('.local');
          if (blocked) continue;
        } catch {
          continue;
        }
        out.push({ url });
        continue;
      }

      let decoded: Buffer;
      try {
        decoded = Buffer.from(base64Raw, 'base64');
      } catch {
        continue;
      }
      if (decoded.length > maxBytes || decoded.length < 32) continue;

      const mimeGuess = typeof item.mime === 'string' ? item.mime.split(';')[0].trim().toLowerCase() : 'image/jpeg';
      const mime = allowedMime.test(mimeGuess)
        ? mimeGuess.replace(/^image\/jpg$/i, 'image/jpeg')
        : 'image/jpeg';
      out.push({ base64: base64Raw, mime });
    }
    return out;
  }

  /** Sampling, output cap, optional reasoning effort — env-driven. */
  private openAiInferenceOptions(): Record<string, unknown> {
    const rawT = this.config.get<string>('OPENAI_CHAT_TEMPERATURE');
    const rawMax = this.config.get<string>('OPENAI_MAX_OUTPUT_TOKENS');
    const rawEff = this.config.get<string>('OPENAI_REASONING_EFFORT')?.trim();

    const out: Record<string, unknown> = {};

    const t = parseFloat(rawT ?? '');
    out.temperature = Number.isFinite(t) && t >= 0 && t <= 2 ? t : 0.78;

    const maxTok = parseInt(rawMax ?? '3072', 10);
    if (Number.isFinite(maxTok) && maxTok >= 256 && maxTok <= 32000) {
      out.max_output_tokens = maxTok;
    }

    const allowed = new Set(['none', 'minimal', 'low', 'medium', 'high', 'xhigh']);
    if (rawEff && allowed.has(rawEff)) {
      out.reasoning = { effort: rawEff };
    }

    return out;
  }

  private async localFallbackFromTools(
    text: string,
    userId?: string,
    conversationId?: string,
    error?: unknown,
    hadVision?: boolean,
  ): Promise<ClinovaAgentResponse> {
    const widerText = hadVision ? `${text} зураг хавсаргасан` : text;
    const serviceResult = await this.searchServicesBySymptoms(widerText);
    const services = this.toObjects(serviceResult?.items);
    const firstServiceId = services[0]?.['id']?.toString();

    const doctorResult = firstServiceId
      ? await this.searchDoctorsByService(firstServiceId)
      : ({ items: [] } as Record<string, unknown>);
    const doctors = this.toObjects(doctorResult?.items);
    const firstDoctorId = doctors[0]?.['id']?.toString();

    const slotResult =
      firstServiceId != null
        ? await this.findAvailableSlots({
            serviceId: firstServiceId,
            doctorId: firstDoctorId,
          })
        : ({ items: [] } as Record<string, unknown>);
    const slots = this.toObjects(slotResult?.items);

    const riskLevel = this.estimateRisk(text);
    const suggestions = [
      'Цаг авах',
      doctors.length > 0 ? 'Санал болгосон эмчтэй чатлах' : 'Эмчтэй чатлах',
      slots.length > 0 ? 'Өнөөдрийн боломжтой цаг харах' : 'Боломжтой цаг шалгах',
    ];
    const reply =
      (hadVision ? 'Зургийг автоматаар дэлгэрэнгүй шинжлэх боломжгүй байна. ' : '') +
      this.buildLocalReply(services, doctors, slots, riskLevel) +
      (hadVision
        ? ' Илүү тод зураг (гэрэл сайн, ойрын) эсвэл шинж тэмдгийг бичвел илүү нарийвчилна.'
        : '');

    const docType =
      (services[0]?.['departmentName']?.toString() ?? null) ||
      this.inferRecommendedDoctorTypeFromUserText(text);
    const acts = this.actions(riskLevel, services, doctors, userId);

    return {
      answerText: reply,
      reply,
      suggestions,
      recommendedServices: services,
      recommendedDoctors: doctors,
      availableSlots: slots,
      riskLevel,
      conversationId,
      actions: acts,
      suggestedActions: acts,
      safetyDisclaimer: this.safetyDisclaimer,
      metadata: {
        source: 'local-fallback',
        reason: this.extractShortError(error),
        openAiModel: this.config.get<string>('OPENAI_MODEL') ?? 'gpt-4o-mini',
        hasUserId: Boolean(userId),
        hadVision: Boolean(hadVision),
      },
      answer: reply,
      followUpQuestions: suggestions,
      urgency:
        riskLevel === 'low'
          ? 'LOW'
          : riskLevel === 'high'
            ? 'HIGH'
            : riskLevel === 'emergency'
              ? 'EMERGENCY'
              : 'MEDIUM',
      type: services.length > 0 ? 'TRIAGE' : 'GENERAL',
      intent:
        riskLevel === 'emergency'
          ? 'emergency'
          : doctors.length > 0
            ? 'doctor_recommendation'
            : services.length > 0
              ? 'service_info'
              : hadVision
                ? 'image_analysis'
                : 'symptom_check',
      recommendedDepartment: services[0]?.['departmentName']?.toString() ?? null,
      recommendedDoctorType: doctors.length > 0 ? null : docType,
      imageAnalysisDisclaimer: Boolean(hadVision) && riskLevel !== 'emergency',
    };
  }

  private openAiTools() {
    const f = (name: string, description: string, parameters: Record<string, unknown>) => ({
      type: 'function',
      name,
      strict: false,
      description,
      parameters,
    });
    return [
      f(
        'searchServicesBySymptoms',
        'Clinova үйлчилгээ/тасгаар шинж тэмдэг, зорилгоор хайлт. Хэрэглэгчийн биеийн тухай бичвэрээр дууд. ID зохиохгүй.',
        {
          type: 'object',
          properties: { symptoms: { type: 'string' }, branchId: { type: 'string' } },
          required: ['symptoms'],
          additionalProperties: false,
        },
      ),
      f(
        'searchDoctorsByService',
        'serviceId-аар (өмнө хайлтын үр дүн эсвэл үлдсэн контекстээс) тохирох эмчийн жагсаалт. serviceId тодорхой биш бол өмнө хайлт хий.',
        {
          type: 'object',
          properties: { serviceId: { type: 'string' }, branchId: { type: 'string' } },
          required: ['serviceId'],
          additionalProperties: false,
        },
      ),
      f(
        'findAvailableSlots',
        'Боломжтой цаг авах — serviceId (шаардлагатай), doctorId/огноо/салбар нэмэлт. Цаг харах, захиалах хүсэлтэд.',
        {
          type: 'object',
          properties: {
            doctorId: { type: 'string' },
            serviceId: { type: 'string' },
            date: { type: 'string' },
            branchId: { type: 'string' },
            departmentId: { type: 'string' },
          },
          additionalProperties: false,
        },
      ),
      f(
        'getBranches',
        'Идэвхтэй салбаруудын жагсаалт — хаана байрлаж буй, харьцуулах, салбараар шүүхэд.',
        {
          type: 'object',
          properties: {},
          additionalProperties: false,
        },
      ),
      f(
        'createAppointment',
        'Сонгосон slotId-аар цаг баталгаажуулах (userId, doctorId, serviceId бүгд шаардлагатай).',
        {
          type: 'object',
          properties: {
            userId: { type: 'string' },
            doctorId: { type: 'string' },
            serviceId: { type: 'string' },
            slotId: { type: 'string' },
          },
          required: ['userId', 'doctorId', 'serviceId', 'slotId'],
          additionalProperties: false,
        },
      ),
      f(
        'getUserAppointments',
        'Хэрэглэгчийн цаг захиалгын түүх/ойрын цаг — "миний цаг" асуухад.',
        {
          type: 'object',
          properties: { userId: { type: 'string' } },
          required: ['userId'],
          additionalProperties: false,
        },
      ),
      f(
        'emergencyTriage',
        'Яаралтай эрсдэл боломжит үед нэмэлт үнэлгээ — эмчийн оронд халаасны эмч биш.',
        {
          type: 'object',
          properties: { symptoms: { type: 'string' } },
          required: ['symptoms'],
          additionalProperties: false,
        },
      ),
    ];
  }

  private async executeTool(
    name: string,
    args: Record<string, unknown>,
    currentUserId?: string,
  ): Promise<Record<string, unknown>> {
    switch (name) {
      case 'searchServicesBySymptoms':
        return this.searchServicesBySymptoms(String(args.symptoms ?? ''), args.branchId?.toString());
      case 'searchDoctorsByService':
        return this.searchDoctorsByService(String(args.serviceId ?? ''), args.branchId?.toString());
      case 'findAvailableSlots':
        return this.findAvailableSlots({
          doctorId: args.doctorId?.toString(),
          serviceId: args.serviceId?.toString(),
          date: args.date?.toString(),
          branchId: args.branchId?.toString(),
          departmentId: args.departmentId?.toString(),
        });
      case 'getBranches':
        return this.getBranches();
      case 'createAppointment':
        return this.createAppointment({
          userId: String(args.userId ?? currentUserId ?? ''),
          doctorId: String(args.doctorId ?? ''),
          serviceId: String(args.serviceId ?? ''),
          slotId: String(args.slotId ?? ''),
        });
      case 'getUserAppointments':
        return this.getUserAppointments(String(args.userId ?? currentUserId ?? ''));
      case 'emergencyTriage':
        return this.emergencyTriage(String(args.symptoms ?? ''));
      default:
        return { error: `Unknown tool ${name}` };
    }
  }

  private async searchServicesBySymptoms(symptoms: string, branchId?: string) {
    const expanded = this.expandSymptomSearchForClinova(symptoms);
    const keys = this.toSearchableText(expanded).split(/\s+/).filter((x) => x.length >= 2).slice(0, 12);
    let items = await this.prisma.service.findMany({
      where: {
        status: 'ACTIVE',
        branchId,
        OR: keys.length
          ? [
              ...keys.map((k) => ({ name: { contains: k, mode: 'insensitive' as const } })),
              ...keys.map((k) => ({ description: { contains: k, mode: 'insensitive' as const } })),
              ...keys.map((k) => ({ department: { name: { contains: k, mode: 'insensitive' as const } } })),
            ]
          : undefined,
      },
      include: { branch: { select: { id: true, name: true } }, department: { select: { id: true, name: true } } },
      take: 6,
    });
    if (items.length === 0) {
      items = await this.prisma.service.findMany({
        where: {
          status: 'ACTIVE',
          branchId,
        },
        include: {
          branch: { select: { id: true, name: true } },
          department: { select: { id: true, name: true } },
        },
        orderBy: { name: 'asc' },
        take: 6,
      });
    }
    return {
      items: items.map((s) => ({
        id: s.id,
        name: s.name,
        description: s.description ?? '',
        price: s.price,
        durationMinutes: s.durationMinutes,
        branchId: s.branchId,
        branchName: s.branch.name,
        departmentId: s.departmentId,
        departmentName: s.department.name,
      })),
    };
  }

  private async searchDoctorsByService(serviceId: string, branchId?: string) {
    const service = await this.prisma.service.findUnique({
      where: { id: serviceId },
      select: { id: true, departmentId: true, branchId: true },
    });
    if (!service) return { items: [], error: 'Service not found' };
    const items = await this.prisma.doctorProfile.findMany({
      where: {
        active: true,
        branchId: branchId ?? service.branchId,
        departmentId: service.departmentId,
        services: { some: { serviceId } },
      },
      include: {
        user: { select: { firstName: true, lastName: true } },
        branch: { select: { name: true } },
        department: { select: { name: true } },
      },
      take: 8,
      orderBy: { experienceYears: 'desc' },
    });
    return {
      items: items.map((d) => ({
        id: d.id,
        name: `${d.user.firstName ?? ''} ${d.user.lastName ?? ''}`.trim(),
        specialty: d.department.name,
        branch: d.branch.name,
        serviceId,
      })),
    };
  }

  private async findAvailableSlots(input: {
    doctorId?: string;
    serviceId?: string;
    date?: string;
    branchId?: string;
    departmentId?: string;
  }) {
    const date = input.date ?? this.nextDateIso();
    let serviceId = input.serviceId;
    if (!serviceId && input.doctorId) {
      const link = await this.prisma.doctorService.findFirst({
        where: { doctorId: input.doctorId },
        select: { serviceId: true },
      });
      serviceId = link?.serviceId;
    }
    if (!serviceId) return { items: [], error: 'serviceId is required' };
    const items = await this.appointments.getAvailableSlots({
      date,
      doctorId: input.doctorId,
      serviceId,
      branchId: input.branchId,
      departmentId: input.departmentId,
    });
    return {
      items: items.slice(0, 12).map((s) => ({
        slotId: s['startsAt'],
        startsAt: s['startsAt'],
        endsAt: s['endsAt'],
        doctorId: s['doctorId'],
        doctorName: s['doctorName'],
        branchId: s['branchId'],
        branchName: s['branchName'],
        serviceId,
      })),
    };
  }

  private async getBranches() {
    const items = await this.prisma.branch.findMany({
      where: { status: 'ACTIVE' },
      select: { id: true, name: true, city: true, address: true, contactPhone: true },
      orderBy: { name: 'asc' },
      take: 20,
    });
    return { items };
  }

  private async createAppointment(input: {
    userId: string;
    doctorId: string;
    serviceId: string;
    slotId: string;
  }) {
    try {
      const appt = await this.appointments.createAppointment(
        { userId: input.userId, role: Role.PATIENT },
        { doctorId: input.doctorId, serviceId: input.serviceId, startsAt: input.slotId, withPaymentIntent: false },
      );
      return { ok: true, appointment: { id: appt.id, startsAt: appt.startsAt, status: appt.status } };
    } catch (e) {
      return { ok: false, error: String(e) };
    }
  }

  private async getUserAppointments(userId: string) {
    try {
      const list = await this.appointments.listAppointments(
        { userId, role: Role.PATIENT },
        { page: 1, pageSize: 10 },
      );
      return {
        items: list.items.map((a) => ({
          id: a.id,
          startsAt: a.startsAt,
          status: a.status,
          doctor: `${a.doctor.user.firstName ?? ''} ${a.doctor.user.lastName ?? ''}`.trim(),
          service: a.service.name,
        })),
      };
    } catch (e) {
      return { items: [], error: String(e) };
    }
  }

  private emergencyTriage(symptoms: string) {
    const emergency = EMERGENCY_PATTERNS.some((re) => re.test(this.toSearchableText(symptoms)));
    return {
      riskLevel: emergency ? 'emergency' : 'medium',
      advice: emergency
        ? 'Call emergency now or go to nearest hospital immediately.'
        : 'Non-emergency pattern; still advise doctor consultation.',
    };
  }

  private normalizeAgentIntent(
    raw: unknown,
    risk: RiskLevel,
    svcCount: number,
    docCount: number,
    hadVision?: boolean,
  ): ClinovaAgentIntent {
    const allowed: ClinovaAgentIntent[] = [
      'symptom_check',
      'image_analysis',
      'appointment_help',
      'doctor_recommendation',
      'service_info',
      'emergency',
      'app_help',
      'general',
    ];
    const s = String(raw ?? '')
      .trim()
      .toLowerCase()
      .replace(/-/g, '_');
    if (allowed.includes(s as ClinovaAgentIntent)) return s as ClinovaAgentIntent;
    if (risk === 'emergency') return 'emergency';
    if (hadVision && (s === '' || s === 'general')) return 'image_analysis';
    if (docCount > 0) return 'doctor_recommendation';
    if (svcCount > 0) return 'service_info';
    return 'general';
  }

  private normalizeLlmActionRoute(type: string, route: string): string | null {
    const t = type.trim().toUpperCase();
    let r = route.trim();
    if (r === '/doctors' || r.toLowerCase() === 'doctors' || r.toLowerCase() === '/doctors') {
      r = '/branches';
    }
    if (r.startsWith('emergency:')) return r;
    if (r.startsWith('/')) return r;
    if (t === 'BOOK_APPOINTMENT' || t === 'BOOKING') return '/appointments/book';
    if (t === 'APPOINTMENT_LANDING' || t === 'SHOW_AVAILABLE_TIMES') return '/appointments-landing';
    if (
      t === 'SHOW_DOCTORS' ||
      t === 'VIEW_BRANCHES' ||
      t === 'VIEW_DOCTORS' ||
      r.toLowerCase() === 'branches'
    ) {
      return '/branches';
    }
    if (t === 'OPEN_CHAT' || t === 'OPEN_PATIENT_CHAT' || r.toLowerCase() === 'chat') return '/chat-landing';
    if (t === 'OPEN_EMERGENCY_PAGE' || r.toLowerCase() === 'emergency') return '/emergency';
    if (t === 'VIEW_MY_APPOINTMENTS' || t === 'MY_APPOINTMENTS') return '/appointments';
    if (r.length > 0 && r.startsWith('appointments')) return `/${r.replace(/^\/+/, '')}`;
    return null;
  }

  private normalizeSuggestedActionsFromLlm(items: Array<Record<string, unknown>>): ClinovaAgentAction[] {
    const out: ClinovaAgentAction[] = [];
    for (const it of items.slice(0, 5)) {
      const label = String(it.label ?? '').trim();
      if (!label) continue;
      const type = String(it.type ?? 'CUSTOM').trim() || 'CUSTOM';
      const rawRoute = String(it.route ?? '').trim();
      const route = this.normalizeLlmActionRoute(type, rawRoute);
      if (!route) continue;
      const params =
        it.params != null && typeof it.params === 'object' && !Array.isArray(it.params)
          ? (it.params as Record<string, unknown>)
          : {};
      out.push({
        type,
        label,
        route,
        params,
        payload: { route, params },
      });
    }
    return out;
  }

  private mergeAgentActions(first: ClinovaAgentAction[], second: ClinovaAgentAction[]): ClinovaAgentAction[] {
    const seen = new Set<string>();
    const merged: ClinovaAgentAction[] = [];
    for (const x of [...first, ...second]) {
      const k = `${x.label}::${x.route ?? ''}`;
      if (seen.has(k)) continue;
      seen.add(k);
      merged.push(x);
      if (merged.length >= 8) break;
    }
    return merged;
  }

  private normalize(
    raw: Record<string, unknown>,
    conversationId?: string,
    opts?: { hadVision?: boolean; userId?: string; model?: string; userMessage?: string },
  ): ClinovaAgentResponse {
    const risk = this.normalizeRisk(raw.urgency ?? raw.riskLevel);
    const reply =
      String(raw.answerText ?? raw.reply ?? raw.answer ?? '').trim() ||
      'Би Clinova AI — шинж тэмдэг, зурагийн урьдчилсан үнэлгээ, цаг захиалга, эмч, аппын талаар тусална. Юу асуух вэ?';
    const followUpQuestions = this.toStrings(raw.followUpQuestions).slice(0, 3);
    const sugOnly = this.toStrings(raw.suggestions).slice(0, 5);
    const suggestions = [...new Set([...followUpQuestions, ...sugOnly])].slice(0, 6);
    const recommendedServices = this.toObjects(raw.recommendedServices);
    const recommendedDoctors = this.toObjects(raw.recommendedDoctors);
    const availableSlots = this.toObjects(raw.availableSlots);
    const deptRaw = raw.recommendedDepartment != null ? String(raw.recommendedDepartment).trim() : '';
    const recommendedDepartment =
      deptRaw.length > 0 && deptRaw !== 'null' && deptRaw !== '—'
        ? deptRaw
        : (recommendedServices[0]?.['departmentName']?.toString() ?? null);
    const docTypeRaw = raw.recommendedDoctorType != null ? String(raw.recommendedDoctorType).trim() : '';
    const recommendedDoctorTypeFromRaw =
      docTypeRaw.length > 0 && docTypeRaw !== 'null' && docTypeRaw !== '—' ? docTypeRaw : null;
    const recommendedDoctorType =
      recommendedDoctorTypeFromRaw ??
      (recommendedDoctors.length > 0
        ? null
        : this.inferRecommendedDoctorTypeFromUserText(String(opts?.userMessage ?? '')));

    const intent = this.normalizeAgentIntent(
      raw.intent,
      risk,
      recommendedServices.length,
      recommendedDoctors.length,
      opts?.hadVision,
    );

    const fromLlm = this.normalizeSuggestedActionsFromLlm(this.toObjects(raw.suggestedActions));
    const serverActs = this.actions(risk, recommendedServices, recommendedDoctors, opts?.userId);
    const actions = this.mergeAgentActions(fromLlm, serverActs);

    const imageAnalysisDisclaimer =
      (intent === 'image_analysis' || Boolean(opts?.hadVision)) && intent !== 'emergency';

    const modelTag = opts?.model ?? this.config.get<string>('OPENAI_MODEL') ?? 'gpt-4o-mini';

    return {
      answerText: reply,
      reply,
      suggestions,
      recommendedServices,
      recommendedDoctors,
      availableSlots,
      riskLevel: risk,
      conversationId,
      actions,
      suggestedActions: actions,
      safetyDisclaimer: this.safetyDisclaimer,
      metadata: { model: modelTag, source: 'responses-api' },
      answer: reply,
      followUpQuestions: followUpQuestions.length > 0 ? followUpQuestions : suggestions.slice(0, 3),
      urgency:
        risk === 'low'
          ? 'LOW'
          : risk === 'high'
            ? 'HIGH'
            : risk === 'emergency'
              ? 'EMERGENCY'
              : 'MEDIUM',
      type: risk === 'emergency' ? 'EMERGENCY' : recommendedServices.length > 0 ? 'TRIAGE' : 'GENERAL',
      intent,
      recommendedDepartment,
      recommendedDoctorType,
      imageAnalysisDisclaimer,
    };
  }

  private actions(
    risk: RiskLevel,
    services: Array<Record<string, unknown>>,
    doctors: Array<Record<string, unknown>>,
    userId?: string,
  ): ClinovaAgentAction[] {
    if (risk === 'emergency') {
      return [
        {
          type: 'OPEN_EMERGENCY_PAGE',
          label: 'Яаралтай тусламж — заавар',
          route: '/emergency',
          params: {},
          payload: { route: '/emergency', params: {} },
        },
        {
          type: 'OPEN_EMERGENCY',
          label: '103 руу залгах',
          route: 'emergency:tel',
          params: { number: '103' },
          payload: { route: 'emergency:tel', params: { number: '103' } },
        },
      ];
    }
    const params: Record<string, unknown> = {};
    const svc = services[0];
    const doc = doctors[0];
    if (svc != null) {
      this.merge(params, { branchId: svc['branchId'], departmentId: svc['departmentId'], serviceId: svc['id'] });
    }
    if (doc != null) this.merge(params, { doctorId: doc['id'] });
    return [
      {
        type: 'BOOK_APPOINTMENT',
        label: 'Цаг захиалах',
        route: '/appointments/book',
        params,
        payload: { route: '/appointments/book', params },
      },
      {
        type: 'SHOW_DOCTORS',
        label: 'Эмч харах',
        route: '/branches',
        params: {},
        payload: { route: '/branches', params: {} },
      },
      {
        type: 'OPEN_PATIENT_CHAT',
        label: 'Эмчтэй чатлах',
        route: '/chat-landing',
        params: {},
        payload: { route: '/chat-landing', params: {} },
      },
      ...(userId
        ? [
            {
              type: 'VIEW_MY_APPOINTMENTS',
              label: 'Миний цагууд',
              route: '/appointments',
              params: {},
              payload: { route: '/appointments', params: {} },
            } as ClinovaAgentAction,
          ]
        : []),
      {
        type: 'SHOW_AVAILABLE_TIMES',
        label: 'Цагийн заавар',
        route: '/appointments-landing',
        params: {},
        payload: { route: '/appointments-landing', params: {} },
      },
      {
        type: 'OPEN_EMERGENCY_PAGE',
        label: 'Яаралтай тусламж',
        route: '/emergency',
        params: {},
        payload: { route: '/emergency', params: {} },
      },
    ];
  }

  /** Мэндчилгээ, «байнаuu», romanized Mongolian асуултыг үл зөв оношихгүйүйн тул ганц мөр ба товч дээр огноочилно. */
  private detectSmalltalk(message: string): SmalltalkKind | null {
    const raw = message.trim();
    if (raw.length === 0 || raw.length > 140) return null;
    const t = this.toSearchableText(message);
    const wordCount = raw.split(/\s+/).filter((w) => w.length > 0).length;
    const shortish = raw.length <= 72 && wordCount <= 10;

    if (/^(thank|thanks|thank you)|^баярлала|^bayarlal|^баярал/i.test(raw)) {
      return 'THANKS';
    }

    const helpSignals =
      /юугаар\s+(тусл|турах)|тан(д|аас)?\s+.*?\b(тусл|турах)\b|^танд .*тусл/i.test(raw) ||
      /yuugaar\s+tuslah|jugaa?r\s+tuslah|^t(us)?lah\s+(ve|vu|vee|weh)\b|^t(us)?lah\??$/i.test(t) ||
      /what\s*can\s*you\b.*\??$/i.test(t) ||
      /можешь\s+помо/i.test(raw) ||
      (/\bt(us)?lah\b/i.test(raw) &&
        /\b(tan(id|daa|nand)|tand|[jy](u|uu)gaar|[jy]ug(?:aa|r))\b/i.test(t));
    const helpAnchored =
      /^\s*((намайг|чиний|чинийг|тад)\s+)?([^.\n]*)?(юу|юун|юуг|хаанаас|хаана).*?(тусл|tur|assist|help[^a-z])/iu.test(raw) ||
      /^\s*юу\b.*?\bтүсл\b/iu.test(raw);
    if (shortish && (helpSignals || helpAnchored)) {
      return 'HELP_MENU';
    }

    const oneLinePresence =
      /^(байна\s*uu|байнаuu|байнуу|байнагуу|эзэ|эмнээ|сайнуу|эмнээ|сай\s*бу|эмнээ|hi|hey|hallo|ciao)$/i.test(
        raw.replace(/\s+/g, ' ').trim(),
      ) ||
      /^baina\s*u{2,}\s*[!.?]*$/i.test(raw.replace(/\s+/g, ' ').trim()) ||
      /^(bai\s*uu|sain\b|morning)$/i.test(t.replace(/\s+/g, ' ').trim());

    const greetFlexible =
      /^(са[йийн]*\s*)?байнуу|^са[йийн]*$/i.test(raw.trim()) ||
      /^sain\b/i.test(t) ||
      /^(байна\s+u{1,6}|байна[uу]{3,})\s*[!.!?]*$/i.test(raw.replace(/\s+/g, ' '));

    const fewWordsFewChars = raw.length <= 36 && wordCount <= 4;

    if (fewWordsFewChars && (oneLinePresence || greetFlexible)) {
      return 'GREETING';
    }

    if (shortish && (oneLinePresence || greetFlexible)) return 'GREETING';

    return null;
  }

  private smalltalkResponse(kind: SmalltalkKind, conversationId?: string): ClinovaAgentResponse {
    const replyByKind: Record<SmalltalkKind, string> = {
      THANKS:
        'Баярлалаа 😊 Өөр асуух зүйл байвал дахин бичнэ үү. Би энд байна.',
      GREETING:
        'Сайн байна уу 🙂 Би Clinova AI — байна шүү. Цаг захиалах, салбар/эмч сонгох, эмчтэй чатлах, шинж тэмдгийн ерөнхий зөвлөгөө өгнө. Юугаар эхлүүлэх вэ?',
      HELP_MENU: [
        'Танд би дараах зүйлсэнд тусална:',
        '',
        '• цаг захиалах, салбар/үйлчилгээ, эмчийг олох;',
        '• боломжтой цаг шалгах;',
        '• эмчтэй текст/дуут чат;',
        '• эрүүл мэндийн ерөнхий мэдээлэл (эмчийн онош биш).',
      ].join('\n'),
    };

    const reply = replyByKind[kind];
    const suggestionsChips =
      kind === 'THANKS'
        ? ['Цаг авах', 'Эмчтэй чатлах']
        : [...new Set(['Цаг яаж авах вэ?', 'Цаг авах', 'Эмчтэй чатлах', 'Боломжтой цаг'])];

    const acts = this.actions('low', [], [], undefined);
    return {
      answerText: reply,
      reply,
      suggestions: suggestionsChips,
      recommendedServices: [],
      recommendedDoctors: [],
      availableSlots: [],
      riskLevel: 'low',
      conversationId,
      actions: acts,
      suggestedActions: acts,
      safetyDisclaimer: this.safetyDisclaimer,
      metadata: { source: 'smalltalk', kind },
      answer: reply,
      followUpQuestions: suggestionsChips.slice(0, 4),
      urgency: 'LOW',
      type: 'GENERAL',
      intent: kind === 'HELP_MENU' ? 'appointment_help' : 'general',
      recommendedDepartment: null,
      recommendedDoctorType: null,
      imageAnalysisDisclaimer: false,
    };
  }

  private fallback(reply: string, conversationId?: string, userId?: string): ClinovaAgentResponse {
    const suggestions = ['Цаг авах', 'Эмчтэй чатлах', 'Боломжтой цаг'];
    const acts = this.actions('medium', [], [], userId);
    return {
      answerText: reply,
      reply,
      suggestions,
      recommendedServices: [],
      recommendedDoctors: [],
      availableSlots: [],
      riskLevel: 'medium',
      conversationId,
      actions: acts,
      suggestedActions: acts,
      safetyDisclaimer: this.safetyDisclaimer,
      metadata: { source: 'fallback', hasOpenAiKey: Boolean(this.client) },
      answer: reply,
      followUpQuestions: suggestions,
      urgency: 'MEDIUM',
      type: 'GENERAL',
      intent: 'general',
      recommendedDepartment: null,
      recommendedDoctorType: null,
      imageAnalysisDisclaimer: false,
    };
  }

  private emergency(conversationId?: string): ClinovaAgentResponse {
    const reply =
      'Таны шинж тэмдэг яаралтай тусламж шаардлагатай байж болзошгүй. Шууд 103 руу залгах эсвэл хамгийн ойрын эмнэлэгт яаралтай очно уу.';
    const acts = this.actions('emergency', [], [], undefined);
    return {
      answerText: reply,
      reply,
      suggestions: [],
      recommendedServices: [],
      recommendedDoctors: [],
      availableSlots: [],
      riskLevel: 'emergency',
      conversationId,
      actions: acts,
      suggestedActions: acts,
      safetyDisclaimer: this.safetyDisclaimer,
      metadata: { source: 'emergency-rule' },
      answer: reply,
      followUpQuestions: [],
      urgency: 'EMERGENCY',
      type: 'EMERGENCY',
      intent: 'emergency',
      recommendedDepartment: 'Яаралтай тусламж',
      recommendedDoctorType: null,
      imageAnalysisDisclaimer: false,
    };
  }

  private async loadRecentHistory(
    conversationId?: string,
    inputHistory?: Array<{ role: string; content: string }>,
  ) {
    const history = (inputHistory ?? []).slice(-20);
    if (!conversationId) return history;
    const rows = await this.prisma.aiMessage.findMany({
      where: { conversationId },
      orderBy: { createdAt: 'desc' },
      take: 20,
      select: { sender: true, content: true },
    });
    const db = rows.reverse().map((r) => ({
      role: r.sender === 'USER' ? 'user' : 'assistant',
      content: r.content,
    }));
    return [...db, ...history].slice(-20);
  }

  private async resolveRole(userId?: string): Promise<Role> {
    if (!userId) return Role.PATIENT;
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { role: true } });
    return user?.role ?? Role.PATIENT;
  }

  private async ensureConversationAndSaveUserMessage(
    userId: string,
    role: Role,
    message: string,
    preferredConversationId?: string,
  ) {
    const conversation =
      (preferredConversationId
        ? await this.prisma.aiConversation.findFirst({ where: { id: preferredConversationId, userId } })
        : null) ??
      (await this.prisma.aiConversation.create({
        data: { userId, role: role.toString(), title: message.slice(0, 90) },
      }));
    await this.prisma.aiMessage.create({
      data: { conversationId: conversation.id, sender: 'USER', content: message },
    });
    return conversation.id;
  }

  private async persistAi(conversationId: string | undefined, response: ClinovaAgentResponse) {
    if (!conversationId) return;
    await this.prisma.aiMessage.create({
      data: {
        conversationId,
        sender: 'AI',
        content: response.reply,
        intent: response.intent,
        riskLevel: response.riskLevel,
        metadata: {
          suggestions: response.suggestions,
          recommendedServices: response.recommendedServices,
          recommendedDoctors: response.recommendedDoctors,
          availableSlots: response.availableSlots,
          actions: response.actions,
          suggestedActions: response.suggestedActions,
          answerText: response.answerText,
          recommendedDoctorType: response.recommendedDoctorType,
          imageAnalysisDisclaimer: response.imageAnalysisDisclaimer,
        } as object,
      },
    });
  }

  private systemPrompt(languageHint: string, hasUploadedImages?: boolean) {
    const visionBlock = hasUploadedImages
      ? `

MULTIMODAL (зураг):
- Дэмжигдсэн төрөл: арьсны тууралт, гэмтэл/вунд, хавдал, эмийн шошго, шинжилгээний дэлгэц, баримт, цагийн screenshot гэх мэт.
- Эхлээд зургийг объектив тодорхойл (өнгө, хэмжээ, байрлал, гэрэл/хумсалт), дараа нь **УРЬДЧИЛСАН** ажиглалт — ямар нэг зүйлийг эцсийн онош мэт баталгаатай хэлэхгүй. "Энэ нь хэд хэдэн нөхцөлд тохирох байж болно, эмчийн үзлэг шаардлагатай" гэж тайлбарла.
- Эмийн шошго: ерөнхий анги, заавал эмч/эмийн сан руу дахин баталгаажуулах. **Тун, хэрхэн уухыг бүү өг.**
- Шинжилгээ/баримт: тоо хэмжээ танихаас зайлсхий, зөвхөн "энэ төрлийн шинжилгээнд эмчийн тайлбар хэрэгтэй" гэж зааж өг.
- Зураг тод биш бол: гэрэл сайжруулах, ойрдуулах, илүү тод зураг, юу өвдөж байгааг бичихийг 1–2 асуултаар хүс.
- Зориулалт: intent = "image_analysis", urgency тохируул. Зуртай үед followUpQuestions нь 1–3 байна.
`
      : '';

    const lang =
      languageHint === 'en'
        ? 'Default to clear English unless the user writes Mongolian — then mirror Mongolian for natural phrasing.'
        : 'Хэрэглэгч Монголоор бичсэн бол хариултыг **байгалийн**, богино, ойлгомжтой монголоор бич (кирилл эсвэл латин). English асуултад товч, тодорхой англиар хариулж болно.';

    return `You are **Clinova AI** — a smart healthcare assistant inside the **Clinova** hospital/clinic platform.
You help patients understand symptoms (including general health education), analyze uploaded images **preliminarily**, choose departments, find doctors, prepare for visits, book appointments, and use the app. You **do not replace** a licensed clinician.

${lang}

VOICE & STRUCTURE:
- Товч, итгэлтэй, дулаан хэлбэр — "роботоор" бичихгүй. Эхний мөрөнд гол санаа.
- Шинж асуухдаа нэг удаад **1–3** нарийн асуулт (хугацаа, хүчтэй байдал, байрлал, өвдөлтийн онцлог).
- Ямар тасаг/чиглэл санал болгож буйгаа **нэг өгүүлбэрээр тайлбарла** (жишээ: шүдний шинж → стоматологийн чиглэл).
- Хариултын төгсгөлд дараагийн **нэг шилдэг алхам** (үзлэг, цаг авах, яаралтай тусламж гэх мэт) тодорхой заана.

Clinova аппын тусламж (appointment хэрхэн авах, цэс, чат, салбар):
- intent = "app_help". Товч алхмууд, шаардлагатай бол "Цаг захиалах", "Эмч харах" гэх маршрутыг санал болго.

OFF-TOPIC:
- Нэг богино мөрөөр хариулаад Clinova/эрүүл мэнд рүү зөөлөн буцаана.

SAFETY:
- Эцсийн онош, "тад энэ өвчтэй" гэх баталгаа хоригтой — зөвхөн "байж болзошгүй", "эмчид үзүүлэх зөвлөгөө".
- Эмийн **нэршил, тун, хэрхэн хэрэглэх** — битгий зааж өг; эмч/эмийн сан руу чиглүүл.
- Зургийн дүгнэлт болон шинжийн үнэлгээ нь **урьдчилсан** — эмчийн үзлэгийг орлодоггүй гэдгийг хариултад тусгах (1 мөрөөр болно).
- Emergency (цээж өвдөх, амьсгал даврах, инсультын шинж, их цус алдалт, ухаан алдах, хүнд харшил, жирэмсний яаралтай нөхцөл, хүүхдийн хүнд халуурал/амьсгал, өөрийгөө хорлох санаа): urgency = "emergency", товч яаралтай заавар, **103**. Энгийн чатыг үргэлжлүүлэхгүй.

TOOLS (жинхэнэ өгөгдөл):
- Хэрэглэгчийн зорилгоор **searchServicesBySymptoms**, **searchDoctorsByService**, **findAvailableSlots**, **getBranches**, шаардлагатай **getUserAppointments** дууд. ID болон цагийг зохиохгүй — зөвхөн хариултаас.
- "Шүд", "гэдэс", "жирэмсэн" гэх мэтээр тасаг тааруулж хайлтын текстэд багтаагаарай.

Output **STRICT JSON ONLY** (no markdown). Schema:
{
  "intent": "symptom_check" | "image_analysis" | "appointment_help" | "doctor_recommendation" | "service_info" | "emergency" | "app_help" | "general",
  "answerText": string (олон жижиг абзац; \\\\n ашиглаж болно),
  "reply": string (answerText-тэй ижил утга байж болно — хуучин клиентүүдэд),
  "recommendedDepartment": string | null,
  "recommendedDoctorType": string | null (жишээ: "Стоматолог" — эмчийн мэдээлэл байхгүй бол),
  "urgency": "low" | "medium" | "high" | "emergency",
  "followUpQuestions": string[] (хамгийн ихдээ 3, богино),
  "suggestions": string[] (chip — followUpQuestions-тай давхцахгүй бол ялгаатай байж болно),
  "suggestedActions": [
    { "label": string, "type": string, "route": string, "params": object? }
  ],
  "recommendedServices": object[],
  "recommendedDoctors": object[],
  "availableSlots": object[]
}
riskLevel = urgency (lowercase) утгаар ижил байлгана.
Маршрутын жишээ: "/appointments/book", "/branches", "/emergency", "/appointments" (миний цаг), "/chat-landing", "/appointments-landing".
${visionBlock}
languageHint: ${languageHint}.`;
  }

  private extractFunctionCalls(response: any) {
    const output = Array.isArray(response?.output) ? response.output : [];
    return output
      .filter((x: any) => x?.type === 'function_call' && x?.name && x?.call_id)
      .map((x: any) => ({
        name: String(x.name),
        call_id: String(x.call_id),
        arguments: String(x.arguments ?? '{}'),
      }));
  }

  private extractText(response: any): string {
    if (typeof response?.output_text === 'string' && response.output_text.trim().length > 0) {
      return response.output_text.trim();
    }
    const output = Array.isArray(response?.output) ? response.output : [];
    for (const item of output) {
      if (item?.type !== 'message' || !Array.isArray(item.content)) continue;
      for (const part of item.content) {
        if (part?.type === 'output_text' && typeof part.text === 'string') {
          return part.text.trim();
        }
      }
    }
    return '';
  }

  private tryJsonObject(raw: string): Record<string, unknown> {
    try {
      const v = JSON.parse(raw) as unknown;
      return v != null && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : {};
    } catch {
      return {};
    }
  }

  /** Robust parse for model output (strict JSON, fenced blocks, or trailing prose). */
  private parseAgentJsonPayload(text: string): Record<string, unknown> {
    const stripped = String(text ?? '').trim();
    if (!stripped) return {};
    let obj = this.tryJsonObject(stripped);
    if (Object.keys(obj).length > 0) return obj;
    const fence = stripped.match(/```(?:json)?\s*([\s\S]*?)```/i);
    if (fence?.[1]) {
      obj = this.tryJsonObject(fence[1].trim());
      if (Object.keys(obj).length > 0) return obj;
    }
    const start = stripped.indexOf('{');
    const end = stripped.lastIndexOf('}');
    if (start >= 0 && end > start) {
      obj = this.tryJsonObject(stripped.slice(start, end + 1));
      if (Object.keys(obj).length > 0) return obj;
    }
    return { reply: stripped };
  }

  private safeJson(input: unknown): Record<string, unknown> {
    if (typeof input !== 'string') return {};
    return this.tryJsonObject(input.trim());
  }

  private normalizeRisk(input: unknown): RiskLevel {
    const v = String(input ?? '').toLowerCase();
    if (v === 'low' || v === 'medium' || v === 'high' || v === 'emergency') return v;
    return 'medium';
  }

  private estimateRisk(text: string): RiskLevel {
    const t = this.toSearchableText(text);
    if (EMERGENCY_PATTERNS.some((re) => re.test(t))) return 'emergency';
    if (/high\s*fever|severe|intense|маш\s*их|хүчтэй|хатгаж/i.test(t)) return 'high';
    if (/pain|өвд|халуур|dizziness|толгой|хоолой|ханиал/i.test(t)) return 'medium';
    return 'low';
  }

  private buildLocalReply(
    services: Array<Record<string, unknown>>,
    doctors: Array<Record<string, unknown>>,
    slots: Array<Record<string, unknown>>,
    riskLevel: RiskLevel,
  ): string {
    if (riskLevel === 'high') {
      return 'Таны шинж тэмдэг ноцтой байж болзошгүй тул ойрын хугацаанд эмчид үзүүлэхийг зөвлөж байна. Доорх үйлчилгээ, эмч, боломжтой цагийг санал болголоо.';
    }
    if (services.length === 0) {
      return 'Таны асуултад тохирох шууд үйлчилгээ олдсонгүй. Шинж тэмдгээ арай дэлгэрэнгүй (хаана, хэдэн хоног, хэр хүчтэй) бичвэл илүү оновчтой санал болгоно.';
    }
    const serviceName = services[0]?.['name']?.toString() ?? 'үйлчилгээ';
    const doctorName = doctors[0]?.['name']?.toString();
    const slotTime = slots[0]?.['startsAt']?.toString();
    const doctorPart = doctorName ? ` Санал болгож буй эмч: ${doctorName}.` : '';
    const slotPart = slotTime ? ` Хамгийн ойрын боломжтой цаг: ${slotTime}.` : '';
    return `${serviceName} үйлчилгээ танд тохирох магадлалтай.${doctorPart}${slotPart} Цааш үргэлжлүүлэх бол "Цаг авах" дээр дарна уу.`;
  }

  private extractShortError(error: unknown): string {
    const msg = String(error ?? '').trim();
    if (!msg) return 'unknown_error';
    return msg.slice(0, 180);
  }

  private toStrings(input: unknown) {
    if (!Array.isArray(input)) return [];
    return input.map((x) => String(x)).filter((x) => x.trim().length > 0).slice(0, 8);
  }

  private toObjects(input: unknown) {
    if (!Array.isArray(input)) return [] as Array<Record<string, unknown>>;
    return input
      .filter((x) => x != null && typeof x === 'object')
      .map((x) => x as Record<string, unknown>)
      .slice(0, 12);
  }

  private toSearchableText(input: string) {
    return input
      .toLowerCase()
      .replace(/[^\p{L}\p{N}\s]/gu, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private nextDateIso() {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    return d.toISOString().slice(0, 10);
  }

  private merge(target: Record<string, unknown>, src: Record<string, unknown>) {
    for (const [k, v] of Object.entries(src)) {
      if (v != null && String(v) !== '' && String(v) !== 'null') target[k] = v;
    }
  }
}
