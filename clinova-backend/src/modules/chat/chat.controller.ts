import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  Post,
  Req,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { MessageType } from '@prisma/client';
import { UseGuards } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { mkdirSync } from 'fs';
import { ChatService } from './chat.service';
import { AuthGuard } from '../common/auth.guard';
import { CurrentUser, CurrentUserPayload } from '../common/current-user.decorator';

type CreateChatMessageDto = {
  roomId: string;
  senderId: string;
  receiverId?: string;
  text?: string;
  messageType?: MessageType;
  attachmentUrl?: string;
  attachmentName?: string;
  attachmentMime?: string;
  attachmentSize?: number;
  metadata?: Record<string, unknown>;
};

@Controller('chat')
@UseGuards(AuthGuard)
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get(':roomId/messages')
  getMessages(
    @CurrentUser() user: CurrentUserPayload,
    @Param('roomId') roomId: string,
  ) {
    if (!roomId.startsWith('room-') || user.sub.trim().length === 0) {
      return [];
    }
    return this.chatService.getRoomMessages(roomId);
  }

  @Post('messages')
  sendMessage(
    @CurrentUser() user: CurrentUserPayload,
    @Body() body: CreateChatMessageDto,
  ) {
    if (body.senderId !== user.sub) {
      throw new ForbiddenException('Sender mismatch');
    }
    return this.chatService.saveMessage({
      roomId: body.roomId,
      senderId: body.senderId,
      receiverId: body.receiverId,
      text: body.text?.trim() || '',
      messageType: body.messageType ?? MessageType.TEXT,
      attachmentUrl: body.attachmentUrl,
      attachmentName: body.attachmentName,
      attachmentMime: body.attachmentMime,
      attachmentSize: body.attachmentSize,
      metadata: body.metadata,
    });
  }

  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (_req, _file, cb) => {
          const dir = `${process.cwd()}/uploads/chat`;
          mkdirSync(dir, { recursive: true });
          cb(null, dir);
        },
        filename: (_req, file, cb) => {
          const random = Math.random().toString(36).slice(2, 8);
          const timestamp = Date.now();
          const ext = extname(file.originalname || '').toLowerCase();
          cb(null, `${timestamp}-${random}${ext}`);
        },
      }),
      limits: { fileSize: 20 * 1024 * 1024 },
    }),
  )
  uploadAttachment(
    @CurrentUser() _user: CurrentUserPayload,
    @UploadedFile() file: any,
    @Req() req: any,
  ) {
    if (!file) {
      throw new BadRequestException('File is required.');
    }
    const protocol = req?.protocol ?? 'http';
    const host = req?.get?.('host') ?? '';
    const relativeUrl = `/uploads/chat/${file.filename}`;
    const url = host ? `${protocol}://${host}${relativeUrl}` : relativeUrl;
    return {
      url,
      relativeUrl,
      name: file.originalname,
      mime: file.mimetype,
      size: file.size,
    };
  }
}
