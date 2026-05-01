import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Stripe from 'stripe';

import { PrismaService } from '../common/prisma.service';

@Injectable()
export class PaymentService {
  private readonly stripe?: Stripe;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    const secretKey = this.config.get<string>('STRIPE_SECRET_KEY');
    if (secretKey) {
      this.stripe = new Stripe(secretKey);
    }
  }

  async createPaymentIntent(amount: number, appointmentId: string) {
    await this.prisma.payment.upsert({
      where: { appointmentId },
      create: {
        appointmentId,
        amount,
        currency: 'usd',
        status: 'PENDING',
      },
      update: {
        amount,
        currency: 'usd',
        status: 'PENDING',
      },
    });

    if (this.stripe) {
      const intent = await this.stripe.paymentIntents.create({
        amount,
        currency: 'usd',
        metadata: { appointmentId },
      });
      await this.prisma.payment.update({
        where: { appointmentId },
        data: {
          status: 'INTENT_CREATED',
        },
      });
      return {
        mode: 'stripe',
        clientSecret: intent.client_secret,
        amount,
        currency: 'usd',
        appointmentId,
      };
    }

    return {
      mode: 'mock',
      clientSecret: `pi_demo_${Date.now()}_secret`,
      amount,
      currency: 'usd',
      appointmentId,
    };
  }
}
