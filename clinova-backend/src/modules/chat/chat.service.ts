import { Injectable } from '@nestjs/common';
import { MessageType } from '@prisma/client';
import { PrismaService } from '../common/prisma.service';

export type ChatMessageInput = {
  roomId: string;
  senderId: string;
  receiverId?: string;
  text: string;
  messageType?: MessageType;
  attachmentUrl?: string;
  attachmentName?: string;
  attachmentMime?: string;
  attachmentSize?: number;
  metadata?: Record<string, unknown>;
};

@Injectable()
export class ChatService {
  constructor(private readonly prisma: PrismaService) {}

  async saveMessage(input: ChatMessageInput) {
    try {
      return await this.prisma.message.create({
        data: {
          roomId: input.roomId,
          senderId: input.senderId,
          receiverId: input.receiverId,
          text: input.text,
          messageType: input.messageType ?? MessageType.TEXT,
          attachmentUrl: input.attachmentUrl,
          attachmentName: input.attachmentName,
          attachmentMime: input.attachmentMime,
          attachmentSize: input.attachmentSize,
          metadata: input.metadata as object | undefined,
        },
      });
    } catch {
      return {
        id: `msg-${Date.now()}`,
        roomId: input.roomId,
        senderId: input.senderId,
        receiverId: input.receiverId,
        text: input.text,
        messageType: input.messageType ?? MessageType.TEXT,
        attachmentUrl: input.attachmentUrl ?? null,
        attachmentName: input.attachmentName ?? null,
        attachmentMime: input.attachmentMime ?? null,
        attachmentSize: input.attachmentSize ?? null,
        metadata: input.metadata ?? {},
        createdAt: new Date(),
      };
    }
  }

  async getRoomMessages(roomId: string) {
    try {
      return await this.prisma.message.findMany({
        where: { roomId },
        orderBy: { createdAt: 'asc' },
        take: 100,
      });
    } catch {
      return [];
    }
  }
}
