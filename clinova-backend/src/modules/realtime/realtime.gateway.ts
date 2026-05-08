import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { BadRequestException, ForbiddenException, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { MessageType } from '@prisma/client';
import { Server, Socket } from 'socket.io';
import { ChatService } from '../chat/chat.service';
import { ChatPermissionService } from '../chat/chat-permission.service';
import { socketIoBrowserCorsOptions } from '../../common/cors-origins';

@WebSocketGateway({
  cors: socketIoBrowserCorsOptions(),
  namespace: 'realtime',
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly onlineUsers = new Map<string, string>();
  private readonly logger = new Logger(RealtimeGateway.name);

  constructor(
    private readonly chatService: ChatService,
    private readonly chatPermission: ChatPermissionService,
    private readonly jwtService: JwtService,
  ) {}

  @WebSocketServer()
  server!: Server;

  handleConnection(client: Socket) {
    const userId = this.getUserId(client);
    if (!userId) {
      this.logger.warn(`Socket auth failure: client=${client.id}`);
      client.emit('system:error', { message: 'Unauthorized socket user' });
      client.disconnect(true);
      return;
    }
    this.onlineUsers.set(client.id, userId);
    void client.join(this.userRoomName(userId));
    this.server.emit('presence:changed', { userId, status: 'online' });
    this.logger.log(`Socket connected: client=${client.id} user=${userId}`);
    client.emit('system:connected', { message: 'Connected to Clinova realtime' });
  }

  handleDisconnect(client: Socket) {
    const userId = this.onlineUsers.get(client.id);
    this.logger.log(
      `Socket disconnected: client=${client.id} user=${userId ?? 'unknown'}`,
    );
    if (userId) {
      this.server.emit('presence:changed', { userId, status: 'offline' });
      this.onlineUsers.delete(client.id);
    }
  }

  private userRoomName(userId: string) {
    return `user:${userId.trim()}`;
  }

  @SubscribeMessage('chat:join')
  async joinRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { roomId: string },
  ) {
    if (!data?.roomId || !data.roomId.startsWith('room-')) {
      throw new BadRequestException('Invalid room id');
    }
    const userId = this.getUserId(client);
    if (!userId) {
      throw new ForbiddenException('Unauthorized socket user');
    }
    await this.chatPermission.assertMayAccessDoctorDmRoomForUserId(
      userId,
      data.roomId,
    );
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
    await this.chatPermission.assertMayAccessDoctorDmRoomForUserId(
      userId,
      data.roomId,
    );
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

  emitChatRequestToDoctor(doctorUserId: string, payload: Record<string, unknown>) {
    const id = doctorUserId.trim();
    if (!id) return;
    this.server.to(this.userRoomName(id)).emit('chat:request', payload);
  }

  emitChatRequestResolved(
    patientUserId: string,
    payload: Record<string, unknown>,
  ) {
    const id = patientUserId.trim();
    if (!id) return;
    this.server.to(this.userRoomName(id)).emit('chat:request:resolved', payload);
  }

  private getUserId(client: Socket) {
    const rawToken = client.handshake.auth?.token;
    if (typeof rawToken === 'string' && rawToken.trim().length > 0) {
      try {
        const payload = this.jwtService.verify<{ sub?: string; userId?: string }>(
          rawToken.trim(),
        );
        const tokenUserId = payload.sub?.trim() || payload.userId?.trim();
        if (tokenUserId) {
          return tokenUserId;
        }
      } catch (error) {
        this.logger.warn(
          `Socket token verify failed: client=${client.id} error=${error instanceof Error ? error.message : 'unknown'}`,
        );
      }
    }
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
