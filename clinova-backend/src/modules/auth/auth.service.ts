import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { AuthProvider, OtpPurpose, Role, UserStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';
import type { SignOptions } from 'jsonwebtoken';
import { OAuth2Client, type TokenPayload } from 'google-auth-library';

import { MailerService } from '../common/mailer.service';
import {
  MONGOLIA_PHONE_INVALID_MESSAGE,
  normalizeOptionalMongoliaPhone,
} from '../common/mongolia-phone.util';
import { PrismaService } from '../common/prisma.service';
import { CurrentUserPayload } from '../common/current-user.decorator';

type RequestOtpInput = {
  email: string;
  firstName?: string;
  lastName?: string;
  /** Optional; normalized +976xxxxxxxx when present. */
  phoneNumber?: string;
};

type RegisterInput = RequestOtpInput & {
  password?: string;
};

const USER_INCLUDE = {
  branch: { select: { id: true, name: true } },
  patientProfile: { select: { id: true } },
  doctorProfile: { select: { id: true } },
} as const;

const OTP_EMAIL_FAILED_MN =
  'Баталгаажуулах код илгээхэд алдаа гарлаа. Имэйл тохиргоог шалгана уу.';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private bootstrapSeeded = false;
  private bootstrapSeedPromise?: Promise<void>;
  private readonly doctorDemoRoster: Array<{
    email: string;
    firstName: string;
    lastName: string;
    avatarUrl: string;
  }> = [
    { email: 'demo.doctor01@clinova.local', firstName: 'Naran', lastName: 'Erdene', avatarUrl: '/uploads/image/doctor-01.png' },
    { email: 'demo.doctor02@clinova.local', firstName: 'Saran', lastName: 'Tuya', avatarUrl: '/uploads/image/doctor-02.png' },
    { email: 'demo.doctor03@clinova.local', firstName: 'Ariunaa', lastName: 'Munkh', avatarUrl: '/uploads/image/doctor-03.png' },
    { email: 'demo.doctor04@clinova.local', firstName: 'Bat', lastName: 'Erdene', avatarUrl: '/uploads/image/doctor-04.png' },
    { email: 'demo.doctor05@clinova.local', firstName: 'Enkh', lastName: 'Amgalan', avatarUrl: '/uploads/image/doctor-05.png' },
    { email: 'demo.doctor06@clinova.local', firstName: 'Oyun', lastName: 'Khulan', avatarUrl: '/uploads/image/doctor-06.png' },
    { email: 'demo.doctor07@clinova.local', firstName: 'Gan', lastName: 'Bold', avatarUrl: '/uploads/image/doctor-07.png' },
    { email: 'demo.doctor08@clinova.local', firstName: 'Temuulen', lastName: 'Sukh', avatarUrl: '/uploads/image/doctor-08.png' },
  ];

  constructor(
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly mailer: MailerService,
  ) {}

  private async ensureBootstrapSeeded() {
    if (this.bootstrapSeeded) return;
    if (this.bootstrapSeedPromise) {
      await this.bootstrapSeedPromise;
      return;
    }
    this.bootstrapSeedPromise = (async () => {
      await this.ensureBootstrapAdmin();
      this.bootstrapSeeded = true;
    })();
    try {
      await this.bootstrapSeedPromise;
    } finally {
      this.bootstrapSeedPromise = undefined;
    }
  }

  private normalizeEmail(email: string) {
    return email.trim().toLowerCase();
  }

  private normalizeLoginIdentifier(value: string) {
    const normalized = this.normalizeEmail(value);
    if (normalized.includes('@')) return normalized;
    return `${normalized}@clinova.local`;
  }

  private async audit(
    userId: string | null,
    eventType: string,
    metadata?: Record<string, unknown>,
  ) {
    await this.prisma.auditLog.create({
      data: {
        userId: userId ?? undefined,
        eventType,
        metadata: metadata as object | undefined,
      },
    });
  }

  private async ensureBootstrapAdmin() {
    const email = this.normalizeEmail(
      this.config.get<string>('DEFAULT_ADMIN_EMAIL') ??
        'chinges_chinges@icloud.com',
    );
    const password =
      this.config.get<string>('DEFAULT_ADMIN_PASSWORD') ?? 'ClinovaAdmin123!';

    const existing = await this.prisma.user.findUnique({
      where: { email },
    });

    if (!existing) {
      const passwordHash = await bcrypt.hash(password, 10);
      await this.prisma.user.create({
        data: {
          email,
          passwordHash,
          role: Role.ADMIN,
          status: UserStatus.ACTIVE,
          authProvider: AuthProvider.EMAIL,
          emailVerified: true,
          firstName: 'Chinges',
          lastName: 'Admin',
        },
      });
    }

    await this.ensureDemoAccounts();

    return this.prisma.user.findUniqueOrThrow({
      where: { email },
    });
  }

  private async ensureDemoAccounts() {
    await this.ensureDemoPatientAccount();
    await this.ensureDemoDoctorAccount();
    await this.ensureDoctorDemoRosterAccounts();
  }

  private async ensureDemoPatientAccount() {
    const email = this.normalizeEmail(
      this.config.get<string>('DEMO_PATIENT_EMAIL') ?? 'demo.patient@clinova.local',
    );
    const password = this.config.get<string>('DEMO_PATIENT_PASSWORD') ?? 'DemoPatient123!';

    const existing = await this.prisma.user.findUnique({
      where: { email },
      include: { patientProfile: true },
    });

    if (existing?.patientProfile) {
      return;
    }
    if (existing && existing.role !== Role.PATIENT) {
      this.logger.warn(
        `Skipped demo patient seed because ${email} already exists as ${existing.role}.`,
      );
      return;
    }

    const passwordHash = await bcrypt.hash(password, 10);
    if (existing) {
      await this.prisma.user.update({
        where: { id: existing.id },
        data: {
          role: Role.PATIENT,
          status: UserStatus.ACTIVE,
          authProvider: AuthProvider.EMAIL,
          emailVerified: true,
          firstName: existing.firstName || 'Demo',
          lastName: existing.lastName || 'Patient',
          passwordHash,
          patientProfile: { create: {} },
        },
      });
      return;
    }

    await this.prisma.user.create({
      data: {
        email,
        passwordHash,
        role: Role.PATIENT,
        status: UserStatus.ACTIVE,
        authProvider: AuthProvider.EMAIL,
        emailVerified: true,
        firstName: 'Demo',
        lastName: 'Patient',
        patientProfile: { create: {} },
      },
    });
  }

  private async ensureDemoDoctorAccount() {
    const email = this.normalizeEmail(
      this.config.get<string>('DEMO_DOCTOR_EMAIL') ?? 'demo.doctor@clinova.local',
    );
    const password = this.config.get<string>('DEMO_DOCTOR_PASSWORD') ?? 'DemoDoctor123!';

    const [branch, department] = await Promise.all([
      this.prisma.branch.findFirst({ orderBy: { createdAt: 'asc' } }),
      this.prisma.department.findFirst({ orderBy: { createdAt: 'asc' } }),
    ]);
    if (!branch || !department) {
      return;
    }

    const existing = await this.prisma.user.findUnique({
      where: { email },
      include: { doctorProfile: true },
    });
    if (existing?.doctorProfile) {
      return;
    }
    if (existing && existing.role !== Role.DOCTOR) {
      this.logger.warn(
        `Skipped demo doctor seed because ${email} already exists as ${existing.role}.`,
      );
      return;
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const service = await this.prisma.service.findFirst({
      where: { branchId: branch.id },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });

    const doctorUser = existing
      ? await this.prisma.user.update({
          where: { id: existing.id },
          data: {
            role: Role.DOCTOR,
            status: UserStatus.ACTIVE,
            authProvider: AuthProvider.EMAIL,
            emailVerified: true,
            firstName: existing.firstName || 'Demo',
            lastName: existing.lastName || 'Doctor',
            passwordHash,
            branchId: branch.id,
          },
        })
      : await this.prisma.user.create({
          data: {
            email,
            passwordHash,
            role: Role.DOCTOR,
            status: UserStatus.ACTIVE,
            authProvider: AuthProvider.EMAIL,
            emailVerified: true,
            firstName: 'Demo',
            lastName: 'Doctor',
            branchId: branch.id,
          },
        });

    await this.prisma.doctorProfile.create({
      data: {
        userId: doctorUser.id,
        branchId: branch.id,
        departmentId: department.id,
        bio: 'Demo doctor account',
        experienceYears: 5,
        consultationFee: 50000,
        active: true,
        services: service
            ? {
                create: [{ serviceId: service.id }],
              }
            : undefined,
      },
    });
  }

  private async ensureDoctorDemoRosterAccounts() {
    const [branch, department] = await Promise.all([
      this.prisma.branch.findFirst({ orderBy: { createdAt: 'asc' } }),
      this.prisma.department.findFirst({ orderBy: { createdAt: 'asc' } }),
    ]);
    if (!branch || !department) {
      return;
    }
    const defaultService = await this.prisma.service.findFirst({
      where: { branchId: branch.id },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });

    const basePassword =
      this.config.get<string>('DEMO_DOCTOR_PASSWORD') ?? 'DemoDoctor123!';
    const passwordHash = await bcrypt.hash(basePassword, 10);

    for (const demo of this.doctorDemoRoster) {
      const email = this.normalizeEmail(demo.email);
      const existing = await this.prisma.user.findUnique({
        where: { email },
        include: { doctorProfile: true },
      });

      const user = existing
        ? await this.prisma.user.update({
            where: { id: existing.id },
            data: {
              role: Role.DOCTOR,
              status: UserStatus.ACTIVE,
              authProvider: AuthProvider.EMAIL,
              emailVerified: true,
              firstName: demo.firstName,
              lastName: demo.lastName,
              avatarUrl: demo.avatarUrl,
              branchId: branch.id,
            },
          })
        : await this.prisma.user.create({
            data: {
              email,
              passwordHash,
              role: Role.DOCTOR,
              status: UserStatus.ACTIVE,
              authProvider: AuthProvider.EMAIL,
              emailVerified: true,
              firstName: demo.firstName,
              lastName: demo.lastName,
              avatarUrl: demo.avatarUrl,
              branchId: branch.id,
            },
          });

      const doctorProfile = existing?.doctorProfile
        ? await this.prisma.doctorProfile.update({
            where: { id: existing.doctorProfile.id },
            data: {
              branchId: branch.id,
              departmentId: department.id,
              bio: 'Demo doctor account',
              experienceYears: 4,
              consultationFee: 50000,
              avatarUrl: demo.avatarUrl,
              active: true,
            },
          })
        : await this.prisma.doctorProfile.create({
            data: {
              userId: user.id,
              branchId: branch.id,
              departmentId: department.id,
              bio: 'Demo doctor account',
              experienceYears: 4,
              consultationFee: 50000,
              avatarUrl: demo.avatarUrl,
              active: true,
            },
          });

      if (defaultService) {
        await this.prisma.doctorService.upsert({
          where: {
            doctorId_serviceId: {
              doctorId: doctorProfile.id,
              serviceId: defaultService.id,
            },
          },
          update: {},
          create: {
            doctorId: doctorProfile.id,
            serviceId: defaultService.id,
          },
        });
      }
    }
  }

  private async createPatientUser(input: RequestOtpInput, password?: string) {
    const passwordHash = password ? await bcrypt.hash(password, 10) : null;

    let phoneNormalized: string | undefined;
    if (
      input.phoneNumber != null &&
      String(input.phoneNumber).trim().length > 0
    ) {
      const norm = normalizeOptionalMongoliaPhone(input.phoneNumber);
      if (norm === null) {
        throw new BadRequestException(MONGOLIA_PHONE_INVALID_MESSAGE);
      }
      phoneNormalized = norm;
    }

    return this.prisma.user.create({
      data: {
        email: this.normalizeEmail(input.email),
        passwordHash,
        role: Role.PATIENT,
        authProvider: AuthProvider.EMAIL,
        emailVerified: false,
        status: UserStatus.PENDING,
        firstName: input.firstName?.trim() || 'Clinova',
        lastName: input.lastName?.trim() || 'Patient',
        phoneNumber: phoneNormalized,
        patientProfile: {
          create: {},
        },
      },
      include: {
        patientProfile: true,
        branch: true,
        doctorProfile: true,
      },
    });
  }

  private issueAccessToken(payload: CurrentUserPayload) {
    const expiresIn = this.config.get<string>('JWT_ACCESS_EXPIRES_IN', '30m');
    return this.jwtService.sign(payload, {
      expiresIn: expiresIn as SignOptions['expiresIn'],
    });
  }

  private serializeUser(user: {
    id: string;
    email: string;
    role: Role;
    status: UserStatus;
    firstName: string | null;
    lastName: string | null;
    nickname: string | null;
    phoneNumber: string | null;
    avatarUrl: string | null;
    branch: { id: string; name: string } | null;
    patientProfile?: { id: string } | null;
    doctorProfile?: { id: string } | null;
  }) {
    return {
      id: user.id,
      email: user.email,
      role: user.role,
      status: user.status,
      firstName: user.firstName,
      lastName: user.lastName,
      nickname: user.nickname,
      phoneNumber: user.phoneNumber,
      phone: user.phoneNumber,
      avatarUrl: user.avatarUrl,
      branch: user.branch,
      patientProfileId: user.patientProfile?.id ?? null,
      doctorProfileId: user.doctorProfile?.id ?? null,
    };
  }

  private genericForgotPasswordResponse() {
    return {
      message:
        'If an account exists for this email, we sent a 6-digit verification code.',
      expiresInSeconds: 600,
    };
  }

  private async enforceResendCooldown(email: string, purpose: OtpPurpose) {
    const last = await this.prisma.otpCode.findFirst({
      where: { email, purpose },
      orderBy: { createdAt: 'desc' },
    });
    if (!last) return;
    const elapsed = Date.now() - last.createdAt.getTime();
    if (elapsed < 60_000) {
      throw new HttpException(
        'Please wait before requesting another code.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  private async createOtpAndEmail(
    email: string,
    userId: string,
    purpose: OtpPurpose,
  ): Promise<{
    message: string;
    expiresInSeconds: number;
    emailDelivered: boolean;
    debugCode?: string;
  }> {
    // LOGIN OTP is re-issued on each successful password check; do not block quick repeats.
    if (purpose !== OtpPurpose.LOGIN) {
      await this.enforceResendCooldown(email, purpose);
    }

    await this.prisma.otpCode.updateMany({
      where: {
        email,
        purpose,
        consumedAt: null,
      },
      data: {
        consumedAt: new Date(),
      },
    });

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const codeHash = await bcrypt.hash(code, 10);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
    const resendAvailableAt = new Date(Date.now() + 60 * 1000);

    const otpRow = await this.prisma.otpCode.create({
      data: {
        email,
        userId,
        codeHash,
        purpose,
        expiresAt,
        resendAvailableAt,
        attempts: 0,
        maxAttempts: 5,
      },
    });

    this.logger.log(
      `[OTP flow] purpose=${purpose} recipient=${email} prismaRowId=${otpRow.id} codeGenerated=******`,
    );

    const requireDelivered = purpose !== OtpPurpose.PASSWORD_RESET;

    const mailResult = await this.mailer.sendOtpEmail(email, code, {
      purpose: String(purpose),
    });

    if (mailResult.delivered) {
      await this.audit(userId, 'OTP_SENT', { purpose });
      return {
        message: 'Verification code sent.',
        expiresInSeconds: 600,
        emailDelivered: true,
      };
    }

    if (mailResult.debugCode !== undefined && mailResult.debugCode !== '') {
      await this.audit(userId, 'OTP_SENT_DEBUG_FALLBACK', { purpose });
      return {
        message: 'Verification code sent (SMTP unavailable; debug code returned).',
        expiresInSeconds: 600,
        emailDelivered: false,
        debugCode: mailResult.debugCode,
      };
    }

    await this.prisma.otpCode
      .delete({ where: { id: otpRow.id } })
      .catch(() => undefined);
    await this.audit(userId, 'OTP_EMAIL_FAILED', {
      purpose,
      smtpCode: mailResult.smtpError?.code,
    });

    if (requireDelivered) {
      throw new ServiceUnavailableException(OTP_EMAIL_FAILED_MN);
    }

    return {
      message: 'Verification code sent.',
      expiresInSeconds: 600,
      emailDelivered: false,
    };
  }

  private async issueTokenPair(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: USER_INCLUDE,
    });
    if (!user) {
      throw new NotFoundException('User not found.');
    }

    const accessToken = this.issueAccessToken({
      sub: user.id,
      email: user.email,
      role: user.role,
    });

    const raw = randomBytes(32).toString('hex');
    const tokenHash = await bcrypt.hash(raw, 10);
    const days = Number(this.config.get<string>('REFRESH_TOKEN_DAYS', '14'));
    const expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);

    const row = await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash,
        expiresAt,
      },
    });

    return {
      accessToken,
      refreshToken: `${row.id}.${raw}`,
      refreshExpiresAt: expiresAt.toISOString(),
      user: this.serializeUser(user),
    };
  }

  async requestOtp(input: RequestOtpInput) {
    await this.ensureBootstrapSeeded();

    const email = this.normalizeEmail(input.email);
    let user = await this.prisma.user.findUnique({
      where: { email },
      include: {
        branch: true,
        patientProfile: true,
        doctorProfile: true,
      },
    });

    if (!user) {
      user = await this.createPatientUser(input);
    }

    if (
      user.role === Role.PATIENT &&
      input.phoneNumber != null &&
      String(input.phoneNumber).trim().length > 0
    ) {
      const norm = normalizeOptionalMongoliaPhone(input.phoneNumber);
      if (norm === null) {
        throw new BadRequestException(MONGOLIA_PHONE_INVALID_MESSAGE);
      }
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: { phoneNumber: norm },
        include: {
          branch: true,
          patientProfile: true,
          doctorProfile: true,
        },
      });
    }

    if (
      user.status !== UserStatus.ACTIVE &&
      user.status !== UserStatus.PENDING
    ) {
      throw new ForbiddenException('This account is not active.');
    }

    const purpose =
      user.status === UserStatus.PENDING
        ? OtpPurpose.REGISTER
        : OtpPurpose.LOGIN;

    return this.createOtpAndEmail(email, user.id, purpose);
  }

  async forgotPassword(emailInput: string) {
    await this.ensureBootstrapSeeded();

    const email = this.normalizeEmail(emailInput);
    const user = await this.prisma.user.findUnique({
      where: { email },
    });

    const generic = this.genericForgotPasswordResponse();

    if (!user || user.status !== UserStatus.ACTIVE) {
      return generic;
    }

    const sent = await this.createOtpAndEmail(
      email,
      user.id,
      OtpPurpose.PASSWORD_RESET,
    );
    await this.audit(user.id, 'PASSWORD_RESET_REQUESTED', {});

    if (!sent.emailDelivered && !sent.debugCode) {
      return generic;
    }

    return {
      message: generic.message,
      expiresInSeconds: sent.expiresInSeconds,
      debugCode: sent.debugCode,
    };
  }

  async verifyOtp(emailInput: string, otp: string, purpose: OtpPurpose) {
    await this.ensureBootstrapSeeded();

    if (purpose === OtpPurpose.PASSWORD_RESET) {
      throw new BadRequestException(
        'Use the password reset endpoint for reset codes.',
      );
    }

    const email = this.normalizeEmail(emailInput);
    const otpRecord = await this.prisma.otpCode.findFirst({
      where: {
        email,
        purpose,
        consumedAt: null,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    if (!otpRecord) {
      throw new UnauthorizedException('Invalid or expired verification code.');
    }

    if (otpRecord.lockedUntil && otpRecord.lockedUntil.getTime() > Date.now()) {
      throw new ForbiddenException(
        'Too many attempts. Please request a new code.',
      );
    }

    if (otpRecord.expiresAt.getTime() < Date.now()) {
      throw new UnauthorizedException(
        'This code has expired. Please request a new one.',
      );
    }

    const valid = await bcrypt.compare(otp, otpRecord.codeHash);
    if (!valid) {
      const attempts = otpRecord.attempts + 1;
      const lockedUntil =
        attempts >= otpRecord.maxAttempts
          ? new Date(Date.now() + 15 * 60 * 1000)
          : null;
      await this.prisma.otpCode.update({
        where: { id: otpRecord.id },
        data: { attempts, lockedUntil },
      });
      await this.audit(otpRecord.userId ?? null, 'OTP_FAILED', { purpose });
      throw new UnauthorizedException('Invalid verification code.');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: otpRecord.userId ?? '' },
      include: USER_INCLUDE,
    });

    if (!user) {
      throw new NotFoundException('User not found.');
    }

    if (
      user.status !== UserStatus.ACTIVE &&
      user.status !== UserStatus.PENDING
    ) {
      throw new ForbiddenException('This account is not active.');
    }

    await this.prisma.otpCode.update({
      where: { id: otpRecord.id },
      data: { consumedAt: new Date() },
    });

    if (user.status === UserStatus.PENDING && purpose === OtpPurpose.REGISTER) {
      await this.prisma.user.update({
        where: { id: user.id },
        data: {
          status: UserStatus.ACTIVE,
          emailVerified: true,
        },
      });
    }

    const verified = await this.prisma.user.findUnique({
      where: { id: user.id },
      include: USER_INCLUDE,
    });

    if (!verified) {
      throw new NotFoundException('User not found.');
    }

    const tokens = await this.issueTokenPair(verified.id);
    await this.audit(verified.id, 'OTP_VERIFIED', { purpose });
    await this.audit(verified.id, 'LOGIN_SUCCESS', {
      method: 'EMAIL_PASSWORD_OTP',
    });

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      refreshExpiresAt: tokens.refreshExpiresAt,
      user: tokens.user,
    };
  }

  async resetPassword(emailInput: string, otp: string, newPassword: string) {
    await this.ensureBootstrapSeeded();

    const email = this.normalizeEmail(emailInput);
    const otpRecord = await this.prisma.otpCode.findFirst({
      where: {
        email,
        purpose: OtpPurpose.PASSWORD_RESET,
        consumedAt: null,
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otpRecord) {
      throw new UnauthorizedException('Invalid or expired verification code.');
    }

    if (otpRecord.lockedUntil && otpRecord.lockedUntil.getTime() > Date.now()) {
      throw new ForbiddenException(
        'Too many attempts. Please request a new code.',
      );
    }

    if (otpRecord.expiresAt.getTime() < Date.now()) {
      throw new UnauthorizedException(
        'This code has expired. Please request a new one.',
      );
    }

    const valid = await bcrypt.compare(otp, otpRecord.codeHash);
    if (!valid) {
      const attempts = otpRecord.attempts + 1;
      const lockedUntil =
        attempts >= otpRecord.maxAttempts
          ? new Date(Date.now() + 15 * 60 * 1000)
          : null;
      await this.prisma.otpCode.update({
        where: { id: otpRecord.id },
        data: { attempts, lockedUntil },
      });
      await this.audit(otpRecord.userId ?? null, 'OTP_FAILED', {
        purpose: 'PASSWORD_RESET',
      });
      throw new UnauthorizedException('Invalid verification code.');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: otpRecord.userId ?? '' },
    });
    if (!user) {
      throw new NotFoundException('User not found.');
    }

    const passwordHash = await bcrypt.hash(newPassword, 10);
    await this.prisma.user.update({
      where: { id: user.id },
      data: { passwordHash },
    });

    await this.prisma.otpCode.update({
      where: { id: otpRecord.id },
      data: { consumedAt: new Date() },
    });

    await this.audit(user.id, 'PASSWORD_RESET_COMPLETED', {});

    return {
      message: 'Password updated. You can sign in.',
    };
  }

  async registerPatient(input: RegisterInput) {
    await this.ensureBootstrapSeeded();

    const email = this.normalizeEmail(input.email);
    const existing = await this.prisma.user.findUnique({
      where: { email },
    });

    if (existing) {
      throw new ConflictException(
        'This email is already registered. Please sign in.',
      );
    }

    const user = await this.createPatientUser(
      { ...input, email },
      input.password,
    );

    const skipRegisterOtp =
      this.config
        .get<string>('REGISTER_SKIP_EMAIL_VERIFICATION', 'false')
        .toLowerCase() === 'true';
    if (skipRegisterOtp) {
      await this.prisma.user.update({
        where: { id: user.id },
        data: { status: UserStatus.ACTIVE, emailVerified: true },
      });
      const tokens = await this.issueTokenPair(user.id);
      await this.audit(user.id, 'REGISTER_AUTO_VERIFIED', { email });
      return {
        message: 'Patient account created and signed in.',
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        refreshExpiresAt: tokens.refreshExpiresAt,
        user: tokens.user,
      };
    }

    const otpResult = await this.createOtpAndEmail(
      email,
      user.id,
      OtpPurpose.REGISTER,
    );

    return {
      message: 'Patient account created. Verification code sent.',
      expiresInSeconds: otpResult.expiresInSeconds,
      debugCode: otpResult.debugCode,
    };
  }

  async passwordLogin(emailInput: string, password: string) {
    await this.ensureBootstrapSeeded();

    const email = this.normalizeLoginIdentifier(emailInput);
    const user = await this.prisma.user.findUnique({
      where: { email },
      include: USER_INCLUDE,
    });

    if (!user?.passwordHash) {
      await this.audit(null, 'LOGIN_FAILED', { email });
      throw new UnauthorizedException('Email or password is incorrect.');
    }

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      await this.audit(user.id, 'LOGIN_FAILED', { email });
      throw new UnauthorizedException('Email or password is incorrect.');
    }

    if (user.status === UserStatus.PENDING) {
      throw new ForbiddenException(
        'Please verify your email with the 6-digit code we sent, then sign in.',
      );
    }

    if (user.status !== UserStatus.ACTIVE) {
      throw new ForbiddenException('This account is not active.');
    }

    const allowPasswordOnlyStaffLogin =
      this.config.get<string>('ALLOW_PASSWORD_ONLY_STAFF_LOGIN', 'true').toLowerCase() ===
      'true';
    if (
      allowPasswordOnlyStaffLogin &&
      (user.role === Role.ADMIN || user.role === Role.DOCTOR || user.role === Role.STAFF)
    ) {
      await this.audit(user.id, 'LOGIN_PASSWORD_ONLY_SUCCESS', { role: user.role });
      return this.issueTokenPair(user.id);
    }

    const demoPatientEmail = this.normalizeEmail(
      this.config.get<string>('DEMO_PATIENT_EMAIL') ?? 'demo.patient@clinova.local',
    );
    const demoDoctorEmail = this.normalizeEmail(
      this.config.get<string>('DEMO_DOCTOR_EMAIL') ?? 'demo.doctor@clinova.local',
    );
    const isDemoAccount =
      user.email === demoPatientEmail || user.email === demoDoctorEmail;
    if (isDemoAccount) {
      await this.audit(user.id, 'LOGIN_DEMO_ACCOUNT_SUCCESS', { role: user.role });
      return this.issueTokenPair(user.id);
    }

    const allowDirectPatientPasswordLogin =
      this.config
        .get<string>('ALLOW_DIRECT_PATIENT_PASSWORD_LOGIN', 'false')
        .toLowerCase() === 'true';
    if (allowDirectPatientPasswordLogin && user.role === Role.PATIENT) {
      await this.audit(user.id, 'LOGIN_PASSWORD_DIRECT', { role: 'PATIENT' });
      return this.issueTokenPair(user.id);
    }

    const otpResult = await this.createOtpAndEmail(
      email,
      user.id,
      OtpPurpose.LOGIN,
    );

    return {
      requiresEmailVerification: true,
      email: user.email,
      expiresInSeconds: otpResult.expiresInSeconds,
      message:
        'Check your email for a 6-digit code to finish signing in.',
      debugCode: otpResult.debugCode,
    };
  }

  async resendLoginOtp(emailInput: string, password: string) {
    return this.passwordLogin(emailInput, password);
  }

  private googleIdTokenAudiences(): string[] {
    const listRaw = this.config.get<string>('GOOGLE_CLIENT_IDS') ?? '';
    const fromList = listRaw
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    const single = this.config.get<string>('GOOGLE_CLIENT_ID')?.trim();
    return [...new Set([...(single ? [single] : []), ...fromList])];
  }

  async googleSignIn(idToken: string) {
    await this.ensureBootstrapSeeded();

    const audiences = this.googleIdTokenAudiences();
    if (audiences.length === 0) {
      throw new BadRequestException('Google sign-in is not configured.');
    }

    const client = new OAuth2Client();
    let payload: TokenPayload | undefined;
    try {
      const ticket = await client.verifyIdToken({
        idToken,
        audience: audiences.length === 1 ? audiences[0] : audiences,
      });
      payload = ticket.getPayload() ?? undefined;
    } catch {
      throw new UnauthorizedException(
        'Invalid Google token — use the OAuth Web Client ID from Google Cloud Console (or match GOOGLE_CLIENT_ID / comma-separated GOOGLE_CLIENT_IDS).',
      );
    }

    if (!payload?.email) {
      throw new UnauthorizedException('Google account has no email.');
    }

    const email = this.normalizeEmail(payload.email);
    let user = await this.prisma.user.findUnique({
      where: { email },
      include: USER_INCLUDE,
    });

    if (!user) {
      user = await this.prisma.user.create({
        data: {
          email,
          authProvider: AuthProvider.GOOGLE,
          emailVerified: true,
          status: UserStatus.ACTIVE,
          role: Role.PATIENT,
          firstName: payload.given_name?.trim() || 'Clinova',
          lastName: payload.family_name?.trim() || 'Patient',
          avatarUrl: payload.picture ?? null,
          patientProfile: { create: {} },
        },
        include: USER_INCLUDE,
      });
    } else {
      if (user.status !== UserStatus.ACTIVE) {
        throw new ForbiddenException('This account is not active.');
      }
    }

    const tokens = await this.issueTokenPair(user.id);
    await this.audit(user.id, 'LOGIN_SUCCESS', { provider: 'GOOGLE' });

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      refreshExpiresAt: tokens.refreshExpiresAt,
      user: tokens.user,
    };
  }

  async refreshTokens(refreshToken: string) {
    const parts = refreshToken.split('.');
    if (parts.length !== 2) {
      throw new UnauthorizedException('Invalid refresh token.');
    }
    const [id, raw] = parts;
    const row = await this.prisma.refreshToken.findUnique({
      where: { id },
    });
    if (!row || row.revokedAt || row.expiresAt.getTime() < Date.now()) {
      throw new UnauthorizedException('Invalid or expired refresh token.');
    }
    const ok = await bcrypt.compare(raw, row.tokenHash);
    if (!ok) {
      throw new UnauthorizedException('Invalid refresh token.');
    }

    await this.prisma.refreshToken.update({
      where: { id: row.id },
      data: { revokedAt: new Date() },
    });

    const tokens = await this.issueTokenPair(row.userId);
    await this.audit(row.userId, 'TOKEN_REFRESH', {});

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      refreshExpiresAt: tokens.refreshExpiresAt,
      user: tokens.user,
    };
  }

  async getCurrentUser(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: USER_INCLUDE,
    });

    if (!user) {
      throw new NotFoundException('User not found.');
    }

    return this.serializeUser(user);
  }

  async logout(userId: string, refreshToken?: string) {
    if (refreshToken) {
      const parts = refreshToken.split('.');
      if (parts.length === 2) {
        const [id, raw] = parts;
        const row = await this.prisma.refreshToken.findFirst({
          where: { id, userId },
        });
        if (row && !row.revokedAt) {
          const ok = await bcrypt.compare(raw, row.tokenHash);
          if (ok) {
            await this.prisma.refreshToken.update({
              where: { id: row.id },
              data: { revokedAt: new Date() },
            });
          }
        }
      }
    } else {
      await this.prisma.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }

    await this.audit(userId, 'LOGOUT', {});

    return { success: true };
  }
}
