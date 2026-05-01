import { Injectable } from '@nestjs/common';
import { NotificationType, Prisma } from '@prisma/client';

import { PrismaService } from '../common/prisma.service';

@Injectable()
export class NotificationService {
  constructor(private readonly prisma: PrismaService) {}

  createForUsers(
    userIds: string[],
    input: {
      type: NotificationType;
      title: string;
      body: string;
      appointmentId?: string;
      data?: Record<string, unknown>;
    },
  ) {
    if (userIds.length === 0) {
      return Promise.resolve({ count: 0 });
    }

    return this.prisma.notification.createMany({
      data: userIds.map((userId) => ({
        userId,
        type: input.type,
        title: input.title,
        body: input.body,
        appointmentId: input.appointmentId,
          data: input.data as Prisma.InputJsonValue | undefined,
        })),
    });
  }

  listForUser(userId: string) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async markRead(userId: string, notificationId: string) {
    await this.prisma.notification.updateMany({
      where: {
        id: notificationId,
        userId,
      },
      data: {
        readAt: new Date(),
      },
    });

    return { success: true };
  }
}
