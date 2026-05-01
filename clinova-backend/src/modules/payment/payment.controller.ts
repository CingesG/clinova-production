import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { IsInt, IsNotEmpty, Min } from 'class-validator';
import { PaymentService } from './payment.service';
import { AuthGuard } from '../common/auth.guard';

class CreatePaymentIntentDto {
  @IsInt()
  @Min(1)
  amount!: number;

  @IsNotEmpty()
  appointmentId!: string;
}

@Controller('payments')
@UseGuards(AuthGuard)
export class PaymentController {
  constructor(private readonly paymentService: PaymentService) {}

  @Post('intent')
  createIntent(@Body() dto: CreatePaymentIntentDto) {
    return this.paymentService.createPaymentIntent(dto.amount, dto.appointmentId);
  }
}
