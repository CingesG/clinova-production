import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { MessageType } from '@prisma/client';
import { Server, Socket } from 'socket.io';
import { ChatService } from '../chat/chat.service';
import { socketIoBrowserCorsOptions } from '../../common/cors-origins';

@WebSocketGateway({
  cors: socketIoBrowserCorsOptions(),
  namespace: 'realtime',
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly onlineUsers = new Map<string, string>();

  constructor(private readonly chatService: ChatService) {}

  @WebSocketServer()
  server!: Server;

  handleConnection(client: Socket) {
    const userId = this.getUserId(client);
    if (userId) {
      this.onlineUsers.set(client.id, userId);
      void client.join(this.userRoomName(userId));
      this.server.emit('presence:changed', { userId, status: 'online' });
    }
    client.emit('system:connected', { message: 'Connected to Clinova realtime' });
  }

  handleDisconnect(client: Socket) {
    const userId = this.onlineUsers.get(client.id);
    if (userId) {
      this.server.emit('presence:changed', { userId, status: 'offline' });
      this.onlineUsers.delete(client.id);
    }
  }

  private userRoomName(userId: string) {
    return `user:${userId.trim()}`;
  }

  @SubscribeMessage('chat:join')
  joinRoom(@ConnectedSocket() client: Socket, @MessageBody() data: { roomId: string }) {
    if (!data?.roomId || !data.roomId.startsWith('room-')) {
      throw new BadRequestException('Invalid room id');
    }
    const userId = this.getUserId(client);
    if (!userId) {
      throw new ForbiddenException('Unauthorized socket user');
    }
    client.join(data.roomId);
    return { ok: true, roomId: data.roomId };
  }

  @SubscribeMessage('chat:message')
  async onChatMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: {
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
    },
  ) {
    if (!data?.roomId || !data.roomId.startsWith('room-')) {
      throw new BadRequestException('Invalid room id');
    }
    const userId = this.getUserId(client);
    if (!userId || userId !== data.senderId) {
      throw new ForbiddenException('Sender mismatch');
    }
    const messageType = data.messageType ?? MessageType.TEXT;
    const text = data.text?.trim() ?? '';
    if (messageType === MessageType.TEXT && text.length === 0) {
      throw new BadRequestException('Text is required');
    }
    if (messageType !== MessageType.TEXT && !(data.attachmentUrl || text)) {
      throw new BadRequestException('Attachment payload is required');
    }
    const saved = await this.chatService.saveMessage({
      roomId: data.roomId,
      senderId: data.senderId,
      receiverId: data.receiverId,
      text,
      messageType,
      attachmentUrl: data.attachmentUrl,
      attachmentName: data.attachmentName,
      attachmentMime: data.attachmentMime,
      attachmentSize: data.attachmentSize,
      metadata: data.metadata,
    });
    const payload = {
      id: saved.id,
      roomId: saved.roomId,
      senderId: saved.senderId,
      receiverId: saved.receiverId,
      text: saved.text,
      messageType: saved.messageType,
      attachmentUrl: saved.attachmentUrl ?? null,
      attachmentName: saved.attachmentName ?? null,
      attachmentMime: saved.attachmentMime ?? null,
      attachmentSize: saved.attachmentSize ?? null,
      metadata: saved.metadata ?? {},
      sentAt: saved.createdAt,
    };
    client.to(data.roomId).emit('chat:message', payload);
    client.emit('chat:message', payload);
    const receiverId = data.receiverId?.trim();
    if (receiverId) {
      this.server.to(this.userRoomName(receiverId)).emit('chat:message', payload);
    }
    return { ok: true };
  }

  @SubscribeMessage('chat:typing')
  onTyping(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { roomId: string; userId: string; isTyping: boolean },
  ) {
    client.to(data.roomId).emit('chat:typing', data);
    return { ok: true };
  }

  @SubscribeMessage('call:join')
  joinCallRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { roomId: string; userId: string; callType: 'video' | 'voice' },
  ) {
    client.join(data.roomId);
    client.to(data.roomId).emit('call:participant-joined', data);
    return { ok: true };
  }

  @SubscribeMessage('call:offer')
  onCallOffer(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { roomId: string; fromUserId: string; toUserId: string; sdp: unknown },
  ) {
    const toUserId = data?.toUserId?.trim();
    if (toUserId) {
      this.server.to(this.userRoomName(toUserId)).emit('call:offer', data);
      return { ok: true };
    }
    client.to(data.roomId).emit('call:offer', data);
    return { ok: true };
  }

  @SubscribeMessage('call:answer')
  onCallAnswer(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { roomId: string; fromUserId: string; toUserId: string; sdp: unknown },
  ) {
    const toUserId = data?.toUserId?.trim();
    if (toUserId) {
      this.server.to(this.userRoomName(toUserId)).emit('call:answer', data);
      return { ok: true };
    }
    client.to(data.roomId).emit('call:answer', data);
    return { ok: true };
  }

  @SubscribeMessage('call:ice')
  onCallIce(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: { roomId: string; fromUserId: string; candidate: unknown; toUserId?: string },
  ) {
    const toUserId = data?.toUserId?.trim();
    if (toUserId) {
      this.server.to(this.userRoomName(toUserId)).emit('call:ice', data);
      return { ok: true };
    }
    client.to(data.roomId).emit('call:ice', data);
    return { ok: true };
  }

  @SubscribeMessage('call:end')
  onCallEnd(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { roomId: string; userId: string; reason?: string; peerUserId?: string },
  ) {
    const peerUserId = data?.peerUserId?.trim();
    if (peerUserId) {
      this.server.to(this.userRoomName(peerUserId)).emit('call:end', data);
      return { ok: true };
    }
    client.to(data.roomId).emit('call:end', data);
    return { ok: true };
  }

  emitAppointmentBooked(appointment: unknown) {
    this.server.emit('appointments:booked', appointment);
    const a = appointment as {
      patient?: { user?: { id?: string } };
      doctor?: { user?: { id?: string } };
    };
    const pid = a.patient?.user?.id?.trim();
    const did = a.doctor?.user?.id?.trim();
    if (pid) {
      this.server.to(this.userRoomName(pid)).emit('appointments:booked', appointment);
    }
    if (did) {
      this.server.to(this.userRoomName(did)).emit('appointments:booked', appointment);
    }
  }

  emitAppointmentUpdated(appointment: unknown) {
    this.server.emit('appointments:updated', appointment);
    const a = appointment as {
      patient?: { user?: { id?: string } };
      doctor?: { user?: { id?: string } };
    };
    const pid = a.patient?.user?.id?.trim();
    const did = a.doctor?.user?.id?.trim();
    if (pid) {
      this.server.to(this.userRoomName(pid)).emit('appointments:updated', appointment);
    }
    if (did) {
      this.server.to(this.userRoomName(did)).emit('appointments:updated', appointment);
    }
  }

  private getUserId(client: Socket) {
    const direct = client.handshake.auth?.userId;
    if (typeof direct === 'string' && direct.trim().length > 0) {
      return direct.trim();
    }
    const query = client.handshake.query.userId;
    if (typeof query === 'string' && query.trim().length > 0) {
      return query.trim();
    }
    return null;
  }
}
