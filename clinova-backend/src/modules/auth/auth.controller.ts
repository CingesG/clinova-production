import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Headers,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ConfigService } from '@nestjs/config';
import {
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  Length,
  MinLength,
} from 'class-validator';
import { OtpPurpose } from '@prisma/client';

import { CurrentUser, CurrentUserPayload } from '../common/current-user.decorator';
import { AuthGuard } from '../common/auth.guard';
import { MailerService } from '../common/mailer.service';
import { AuthService } from './auth.service';

class RequestOtpDto {
  @IsEmail()
  email!: string;

  @IsOptional()
  @IsString()
  firstName?: string;

  @IsOptional()
  @IsString()
  lastName?: string;

  @IsOptional()
  @IsString()
  phoneNumber?: string;
}

class VerifyOtpDto {
  @IsEmail()
  email!: string;

  @Length(6, 6)
  otp!: string;

  @IsIn([OtpPurpose.REGISTER, OtpPurpose.LOGIN])
  purpose!: OtpPurpose;
}

class RegisterDto extends RequestOtpDto {
  @IsOptional()
  @MinLength(8)
  password?: string;
}

class PasswordLoginDto {
  @IsString()
  email!: string;

  @MinLength(8)
  password!: string;
}

class ForgotPasswordDto {
  @IsEmail()
  email!: string;
}

class ResetPasswordDto {
  @IsEmail()
  email!: string;

  @Length(6, 6)
  otp!: string;

  @MinLength(8)
  newPassword!: string;
}

class GoogleAuthDto {
  @IsString()
  @MinLength(10)
  idToken!: string;
}

class RefreshDto {
  @IsString()
  @MinLength(20)
  refreshToken!: string;
}

class LogoutDto {
  @IsOptional()
  @IsString()
  refreshToken?: string;
}

class TestEmailDto {
  @IsEmail()
  email!: string;
}

class MaintenanceDeleteTestUserDto {
  @IsEmail()
  email!: string;
}

const MAINTENANCE_SECRET_HEADER = 'x-clinova-maintenance-secret';

@Controller('auth')
@Throttle({ default: { limit: 30, ttl: 60000 } })
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly config: ConfigService,
    private readonly mailer: MailerService,
  ) {}

  @Post('request-otp')
  @Throttle({ default: { limit: 8, ttl: 60000 } })
  requestOtp(@Body() dto: RequestOtpDto) {
    return this.authService.requestOtp(dto);
  }

  @Post('verify-otp')
  @Throttle({ default: { limit: 15, ttl: 60000 } })
  verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtp(dto.email, dto.otp, dto.purpose);
  }

  @Post('register')
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  register(@Body() dto: RegisterDto) {
    return this.authService.registerPatient(dto);
  }

  @Post('password-login')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  passwordLogin(@Body() dto: PasswordLoginDto) {
    return this.authService.passwordLogin(dto.email, dto.password);
  }

  @Post('resend-login-otp')
  @Throttle({ default: { limit: 8, ttl: 60000 } })
  resendLoginOtp(@Body() dto: PasswordLoginDto) {
    return this.authService.resendLoginOtp(dto.email, dto.password);
  }

  @Post('google')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  google(@Body() dto: GoogleAuthDto) {
    return this.authService.googleSignIn(dto.idToken);
  }

  @Post('refresh')
  @Throttle({ default: { limit: 30, ttl: 60000 } })
  refresh(@Body() dto: RefreshDto) {
    return this.authService.refreshTokens(dto.refreshToken);
  }

  @Post('forgot-password')
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.authService.forgotPassword(dto.email);
  }

  @Post('reset-password')
  @Throttle({ default: { limit: 8, ttl: 60000 } })
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(
      dto.email,
      dto.otp,
      dto.newPassword,
    );
  }

  /**
   * TEMPORARY: delete one allowlisted test user (MAINTENANCE_SECRET + header).
   * Remove before final production deploy.
   */
  @Post('maintenance/delete-test-user')
  @Throttle({ default: { limit: 3, ttl: 60000 } })
  maintenanceDeleteTestUser(
    @Headers(MAINTENANCE_SECRET_HEADER) secret: string | undefined,
    @Body() dto: MaintenanceDeleteTestUserDto,
  ) {
    const expected = this.config.get<string>('MAINTENANCE_SECRET')?.trim();
    if (!expected) {
      throw new ForbiddenException('Maintenance endpoint disabled.');
    }
    if (!secret || secret !== expected) {
      throw new ForbiddenException('Invalid maintenance credentials.');
    }
    return this.authService.maintenanceDeleteSingleTestUser(dto.email);
  }

  /** SMTP шалгалт (зөвхөн EMAIL_TEST_SECRET + header-д таарах үед идэвхтэй). */
  @Post('test-email')
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  testOutboundEmail(
    @Headers('x-clinova-email-test-secret') secret: string | undefined,
    @Body() dto: TestEmailDto,
  ) {
    const expected = this.config.get<string>('EMAIL_TEST_SECRET')?.trim();
    if (!expected || secret !== expected) {
      throw new ForbiddenException(
        'Test email endpoint disabled or invalid secret.',
      );
    }
    return this.mailer.sendTestEmail(dto.email.trim().toLowerCase());
  }

  @Get('me')
  @UseGuards(AuthGuard)
  me(@CurrentUser() user: CurrentUserPayload) {
    return this.authService.getCurrentUser(user.sub);
  }

  @Post('logout')
  @UseGuards(AuthGuard)
  logout(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: LogoutDto,
  ) {
    return this.authService.logout(user.sub, dto.refreshToken);
  }
}
