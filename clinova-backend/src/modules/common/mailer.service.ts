import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { existsSync } from 'fs';
import * as nodemailer from 'nodemailer';
import { resolve } from 'path';
import { Resend } from 'resend';

export type OtpEmailSendResult = {
  delivered: boolean;
  messageId?: string;
  debugCode?: string;
  smtpError?: {
    name?: string;
    message: string;
    code?: string;
    command?: string;
    response?: string;
    statusCode?: number;
  };
};

function smtpErrorShape(err: unknown): NonNullable<OtpEmailSendResult['smtpError']> {
  if (!err || typeof err !== 'object') {
    return { message: String(err) };
  }
  const e = err as Record<string, unknown>;
  const statusRaw = e.statusCode ?? e.code;
  const statusNum =
    typeof statusRaw === 'number'
      ? statusRaw
      : typeof statusRaw === 'string'
        ? Number.parseInt(statusRaw, 10)
        : undefined;
  return {
    name: typeof e.name === 'string' ? e.name : undefined,
    message:
      typeof e.message === 'string'
        ? e.message
        : typeof e.toString === 'function'
          ? (e.toString() as string)
          : 'Unknown error',
    code:
      typeof e.code === 'string'
        ? e.code
        : typeof e.code === 'number'
          ? String(e.code)
          : undefined,
    command: typeof e.command === 'string' ? e.command : undefined,
    response:
      typeof e.response === 'string'
        ? e.response
        : e.response != null
          ? String(e.response)
          : undefined,
    statusCode:
      Number.isFinite(statusNum) && typeof statusNum === 'number'
        ? statusNum
        : undefined,
  };
}

type ActiveProvider = 'resend' | 'smtp' | 'none';

@Injectable()
export class MailerService implements OnModuleInit {
  private readonly logger = new Logger(MailerService.name);
  private transporter?: nodemailer.Transporter;
  private resend?: Resend;
  private readonly fromEmail: string;

  constructor(private readonly config: ConfigService) {
    const isProduction = this.isProduction();

    const resendKey =
      this.config.get<string>('RESEND_API_KEY')?.trim() ?? '';
    const explicitProvider = (
      this.config.get<string>('EMAIL_PROVIDER') ?? ''
    )
      .trim()
      .toLowerCase();

    const allowResendInit =
      resendKey.length > 0 &&
      (isProduction ||
        explicitProvider === 'resend' ||
        explicitProvider.length === 0);

    if (allowResendInit) {
      this.resend = new Resend(resendKey);
    }

    const host = (
      this.config.get<string>('SMTP_HOST') ??
      this.config.get<string>('EMAIL_HOST') ??
      ''
    ).trim();

    const port = Number(
      this.config.get<string>('SMTP_PORT') ??
        this.config.get<string>('EMAIL_PORT') ??
        '587',
    );

    const secure =
      this.config.get<string>('SMTP_SECURE', 'false').toLowerCase() ===
      'true';

    const user = (
      this.config.get<string>('SMTP_USER') ??
      this.config.get<string>('EMAIL_USER') ??
      ''
    ).trim();

    const pass = (
      this.config.get<string>('SMTP_PASS') ??
      this.config.get<string>('EMAIL_PASS') ??
      ''
    ).trim();

    this.fromEmail =
      this.config.get<string>('SMTP_FROM') ??
      this.config.get<string>('EMAIL_FROM') ??
      (user.length > 0 ? user : 'no-reply@clinova.local');

    const smtpComplete = host.length > 0 && user.length > 0 && pass.length > 0;
    if (!smtpComplete && !isProduction) {
      return;
    }

    if (smtpComplete) {
      this.transporter = nodemailer.createTransport({
        host,
        port,
        secure,
        auth: {
          user,
          pass,
        },
      });
    }
  }

  private isProduction(): boolean {
    return (
      this.config.get<string>('NODE_ENV', 'development').toLowerCase() ===
      'production'
    );
  }

  private smtpCredentialsPresent(): boolean {
    const host = (
      this.config.get<string>('SMTP_HOST') ??
      this.config.get<string>('EMAIL_HOST') ??
      ''
    ).trim();
    const user = (
      this.config.get<string>('SMTP_USER') ??
      this.config.get<string>('EMAIL_USER') ??
      ''
    ).trim();
    const pass = (
      this.config.get<string>('SMTP_PASS') ??
      this.config.get<string>('EMAIL_PASS') ??
      ''
    ).trim();
    return host.length > 0 && user.length > 0 && pass.length > 0;
  }

  private validateProductionEmailConfig(): void {
    if (!this.isProduction()) return;

    const p = (
      this.config.get<string>('EMAIL_PROVIDER') ?? ''
    )
      .trim()
      .toLowerCase();

    if (p === 'resend') {
      const key = this.config.get<string>('RESEND_API_KEY')?.trim();
      if (!key) {
        throw new Error(
          'Production misconfiguration: EMAIL_PROVIDER=resend requires a non-empty RESEND_API_KEY.',
        );
      }
      if (!this.resend) {
        throw new Error(
          'Production misconfiguration: Resend client failed to initialize (check RESEND_API_KEY).',
        );
      }
    }

    if (p === 'smtp') {
      if (!this.smtpCredentialsPresent()) {
        throw new Error(
          'Production misconfiguration: EMAIL_PROVIDER=smtp requires SMTP_HOST (or EMAIL_HOST), SMTP_USER (or EMAIL_USER), and SMTP_PASS (or EMAIL_PASS).',
        );
      }
      if (!this.transporter) {
        throw new Error(
          'Production misconfiguration: SMTP transporter was not created; check host, user, and password env vars.',
        );
      }
    }
  }

  private hasEnv(key: string, alt?: string) {
    const v = alt
      ? this.config.get<string>(key) ?? this.config.get<string>(alt)
      : this.config.get<string>(key);
    return v != null && String(v).trim().length > 0;
  }

  private logEmailEnvPresence() {
    const raw = (
      this.config.get<string>('EMAIL_PROVIDER') ??
      '(unset)'
    ).trim();
    const display =
      raw.length > 0 ? raw : '(unset)';
    this.logger.log(
      `[Email env] EMAIL_PROVIDER=${display} ` +
        `RESEND_API_KEY=${this.hasEnv('RESEND_API_KEY')} ` +
        `RESEND_FROM=${this.hasEnv('RESEND_FROM')}`,
    );
  }

  private logSmtpEnvPresence() {
    this.logger.log(
      `[SMTP env] SMTP_HOST=${this.hasEnv('SMTP_HOST', 'EMAIL_HOST')} ` +
        `SMTP_PORT=${this.hasEnv('SMTP_PORT', 'EMAIL_PORT')} ` +
        `SMTP_SECURE=${this.hasEnv('SMTP_SECURE')} ` +
        `SMTP_USER=${this.hasEnv('SMTP_USER', 'EMAIL_USER')} ` +
        `SMTP_PASS=${this.hasEnv('SMTP_PASS', 'EMAIL_PASS')} ` +
        `SMTP_FROM=${this.hasEnv('SMTP_FROM', 'EMAIL_FROM')}`,
    );
  }

  private scheduleSmtpVerify() {
    if (!this.transporter) return;
    void (async () => {
      try {
        await this.transporter!.verify();
        this.logger.log('SMTP transporter.verify() OK — connection ready.');
      } catch (err) {
        const s = smtpErrorShape(err);
        this.logger.error(
          `SMTP transporter.verify() FAILED name=${s.name ?? 'n/a'} code=${s.code ?? 'n/a'} statusCode=${s.statusCode ?? 'n/a'} message=${s.message}`,
        );
      }
    })();
  }

  /** Which transport is used when sending OTP / test emails. */
  private activeProvider(): ActiveProvider {
    const explicit = (
      this.config.get<string>('EMAIL_PROVIDER') ?? ''
    ).trim()
      .toLowerCase();

    const hasResendApi = !!(this.config.get<string>('RESEND_API_KEY')?.trim());
    const hasSmtpTransport = !!this.transporter;

    if (explicit === 'smtp') {
      return hasSmtpTransport ? 'smtp' : 'none';
    }
    if (explicit === 'resend') {
      return hasResendApi && this.resend ? 'resend' : 'none';
    }

    const isProduction =
      this.config.get<string>('NODE_ENV', 'development').toLowerCase() ===
      'production';
    if (isProduction && hasResendApi && this.resend) {
      return 'resend';
    }
    if (hasSmtpTransport) return 'smtp';
    if (hasResendApi && this.resend) return 'resend';
    return 'none';
  }

  async onModuleInit() {
    this.logEmailEnvPresence();
    this.logSmtpEnvPresence();
    this.validateProductionEmailConfig();

    const explicitProvider = (
      this.config.get<string>('EMAIL_PROVIDER') ?? ''
    )
      .trim()
      .toLowerCase();
    if (
      explicitProvider === 'smtp' &&
      !this.transporter &&
      !this.isProduction()
    ) {
      this.logger.warn(
        'EMAIL_PROVIDER=smtp but the SMTP transporter was not created. ' +
          'Set SMTP_HOST (or EMAIL_HOST), SMTP_USER (or EMAIL_USER), and SMTP_PASS (or EMAIL_PASS). ' +
          'Registration OTP emails will not be delivered until SMTP is configured.',
      );
    }

    const ap = this.activeProvider();
    if (ap === 'none') {
      this.logger.warn(
        'No usable email provider (EMAIL_PROVIDER vs credentials): OTP may not be delivered. ' +
          'Use EMAIL_PROVIDER=resend with RESEND_API_KEY or EMAIL_PROVIDER=smtp with complete SMTP_* vars.',
      );
    }

    if (this.isProduction() && this.transporter) {
      this.scheduleSmtpVerify();
    }
  }

  private escapeHtml(value: string) {
    return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
  }

  private emailDebugEnabled(): boolean {
    const isProduction =
      this.config.get<string>('NODE_ENV', 'development').toLowerCase() ===
      'production';
    return (
      this.config
        .get<string>('EMAIL_DEBUG', isProduction ? 'false' : 'true')
        .toLowerCase() === 'true'
    );
  }

  /** Log plaintext OTP only in non-production when OTP_DEBUG=true (never log in production). */
  private otpDebugLogEnabled(): boolean {
    if (this.isProduction()) return false;
    return (
      (this.config.get<string>('OTP_DEBUG') ?? '').trim().toLowerCase() ===
      'true'
    );
  }

  /** Minutes shown in OTP email copy; keep aligned with auth OTP TTL (default 10). */
  private getOtpExpireMinutesForEmail(): number {
    const raw = this.config.get<string>('OTP_EMAIL_EXPIRE_MINUTES', '10') ?? '10';
    const n = Number.parseInt(String(raw).trim(), 10);
    return Number.isFinite(n) && n > 0 ? n : 10;
  }

  private buildOtpEmailPlainText(
    code: string,
    appNameRaw: string,
    expiresMinutes: number,
  ): string {
    return (
      `Имэйлээ баталгаажуулна уу\n\n` +
      `Таны 6 оронтой ${appNameRaw} баталгаажуулах код: ${code}\n\n` +
      `Энэ код ${expiresMinutes} минутын дараа хүчингүй болно.\n\n` +
      `Хэрэв та энэ хүсэлтийг гаргаагүй бол энэхүү имэйлийг үл тоож болно.\n\n` +
      `Энэ нь ${appNameRaw} системээс автоматаар илгээгдсэн зурвас тул reply хийх шаардлагагүй.`
    );
  }

  private resendDefaultFrom(): string {
    const from = (
      process.env['RESEND_FROM'] ??
      this.config.get<string>('RESEND_FROM') ??
      ''
    ).trim();
    return from.length > 0 ? from : 'Clinova <onboarding@resend.dev>';
  }

  /**
   * Safe diagnostic email (no secrets in response). Use with POST /auth/test-email + header.
   */
  async sendTestEmail(to: string): Promise<{
    ok: boolean;
    provider?: 'resend' | 'smtp';
    id?: string;
    messageId?: string;
    error?: OtpEmailSendResult['smtpError'];
  }> {
    const provider = this.activeProvider();
    if (provider === 'none') {
      return {
        ok: false,
        error: {
          message: 'No configured email provider (set EMAIL_PROVIDER and credentials).',
        },
      };
    }

    if (provider === 'resend' && this.resend) {
      try {
        const { data, error } = await this.resend.emails.send({
          from: this.resendDefaultFrom(),
          to: [to],
          subject: 'Clinova Resend test',
          html: `<p>If you received this, outbound email via Resend is working.</p>`,
          text: 'If you received this, outbound email via Resend is working.',
        });
        if (error) {
          const statusCode =
            typeof error.statusCode === 'number' ? error.statusCode : undefined;
          this.logger.error(
            `[Resend test] FAILED to=${to} name=${error.name ?? 'n/a'} statusCode=${statusCode ?? 'n/a'} message=${error.message}`,
          );
          return {
            ok: false,
            provider: 'resend',
            error: {
              name: error.name,
              message: error.message,
              statusCode: statusCode ?? undefined,
            },
          };
        }
        const id =
          typeof data?.id === 'string' ? data.id : '(no id)';
        this.logger.log(`[Resend test] sent to ${to} id=${id}`);
        return { ok: true, provider: 'resend', id: data!.id };
      } catch (err) {
        const s = smtpErrorShape(err);
        this.logger.error(
          `[Resend test] EXCEPTION to=${to} name=${s.name ?? 'n/a'} statusCode=${s.statusCode ?? 'n/a'} message=${s.message}`,
        );
        return { ok: false, provider: 'resend', error: s };
      }
    }

    if (!this.transporter) {
      return {
        ok: false,
        provider: 'smtp',
        error: { message: 'SMTP transporter not configured' },
      };
    }

    try {
      const info = await this.transporter.sendMail({
        from: this.fromEmail,
        to,
        subject: 'Clinova SMTP test',
        text: 'If you received this, outbound SMTP is working.',
      });
      const messageId =
        typeof info.messageId === 'string' ? info.messageId : undefined;
      this.logger.log(
        `[SMTP test] sent to ${to} messageId=${messageId ?? 'n/a'}`,
      );
      return { ok: true, provider: 'smtp', messageId };
    } catch (err) {
      const s = smtpErrorShape(err);
      this.logger.error(
        `[SMTP test] FAILED to=${to} name=${s.name ?? 'n/a'} code=${s.code ?? 'n/a'} command=${s.command ?? 'n/a'} message=${s.message}`,
      );
      return { ok: false, provider: 'smtp', error: s };
    }
  }

  /**
   * OTP / verification email: HTML + plain text + subject. CID attachments only for SMTP (`forApi` false).
   */
  private buildOtpEmailTemplate(
    code: string,
    options: { forApi: boolean },
  ): {
    html: string;
    subject: string;
    textPlain: string;
    attachments: nodemailer.Attachment[];
  } {
    const { forApi } = options;
    const appNameRaw = this.config.get<string>('APP_NAME', 'Clinova');
    const appName = this.escapeHtml(appNameRaw);
    const otpCode = this.escapeHtml(code);
    const expiresMinutes = this.getOtpExpireMinutesForEmail();
    const expiresMn = this.escapeHtml(String(expiresMinutes));

    const subject = 'Clinova баталгаажуулах код';

    const textPlain = this.buildOtpEmailPlainText(
      code,
      appNameRaw,
      expiresMinutes,
    );

    const logoUrl = (this.config.get<string>('APP_LOGO_URL') ?? '').trim();
    const logoPathRaw = (this.config.get<string>('APP_LOGO_PATH') ?? '').trim();
    const logoPath = logoPathRaw
      ? resolve(process.cwd(), logoPathRaw)
      : '';
    const hasInlineLogo = logoPath.length > 0 && existsSync(logoPath);
    const safeLogoUrl = this.escapeHtml(logoUrl);
    const logoCid = 'clinova-logo';

    const useCidLogo = !forApi && hasInlineLogo;
    const logoBlock =
      safeLogoUrl.length > 0
        ? `<img src="${safeLogoUrl}" alt="${appName} logo" width="52" height="52" style="display:block;width:52px;height:52px;border-radius:16px;object-fit:cover;border:1px solid rgba(255,255,255,0.4);" />`
        : useCidLogo
          ? `<img src="cid:${logoCid}" alt="${appName} logo" width="52" height="52" style="display:block;width:52px;height:52px;border-radius:16px;object-fit:contain;background:#ffffff;border:1px solid rgba(255,255,255,0.35);" />`
          : `<div style="display:inline-flex;align-items:center;justify-content:center;width:52px;height:52px;border-radius:16px;background:rgba(255,255,255,0.18);color:#ffffff;font-weight:800;font-size:17px;letter-spacing:0.6px;border:1px solid rgba(255,255,255,0.4);">CL</div>`;

    const html = `
<!DOCTYPE html>
<html lang="mn">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="color-scheme" content="light dark" />
  <meta name="supported-color-schemes" content="light dark" />
  <title>${this.escapeHtml(subject)}</title>
  <!--[if mso]><style type="text/css">table, td { border-collapse:collapse; }</style><![endif]-->
  <style type="text/css">
    @media only screen and (max-width: 620px) {
      .otp-code { font-size: 32px !important; letter-spacing: 10px !important; }
      .pad { padding-left: 20px !important; padding-right: 20px !important; }
    }
    @media (prefers-color-scheme: dark) {
      .email-outer { background-color: #0f172a !important; }
      .email-card { background-color: #1e293b !important; border-color: #334155 !important; }
      .email-muted { color: #94a3b8 !important; }
      .email-body { color: #e2e8f0 !important; }
      .otp-outer { background-color: #0f172a !important; }
      .otp-wrap {
        background-color: #0c4a6e !important;
        border-color: #2dd4bf !important;
        box-shadow: 0 0 0 1px rgba(45,212,191,0.35) !important;
      }
      .otp-code { color: #e0f2fe !important; }
    }
  </style>
</head>
<body style="margin:0;padding:0;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;background-color:#e8f2f7;">
<table role="presentation" class="email-outer" cellpadding="0" cellspacing="0" width="100%" style="background:#e8f2f7;">
  <tr>
    <td align="center" style="padding:28px 14px;">
      <table role="presentation" class="email-card" cellpadding="0" cellspacing="0" width="100%" style="max-width:560px;background:#ffffff;border:1px solid #b9d4e8;border-radius:20px;overflow:hidden;box-shadow:0 16px 48px rgba(15,23,42,0.1);">
        <tr>
          <td style="background-color:#0c4a6e;padding:24px 26px;">
            <table role="presentation" cellpadding="0" cellspacing="0" width="100%">
              <tr>
                <td style="width:60px;vertical-align:middle;">${logoBlock}</td>
                <td class="pad" style="vertical-align:middle;padding-left:16px;">
                  <div style="font-family:Georgia,'Times New Roman',serif;font-size:24px;line-height:1.15;font-weight:700;color:#ffffff;letter-spacing:0.2px;">${appName}</div>
                  <div style="font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:1.35;color:rgba(255,255,255,0.95);margin-top:6px;font-weight:600;">AI Healthcare Platform</div>
                  <div style="font-family:Arial,Helvetica,sans-serif;font-size:11px;line-height:1.4;color:rgba(255,255,255,0.8);margin-top:4px;">Secure verification</div>
                </td>
              </tr>
            </table>
          </td>
        </tr>
        <tr>
          <td class="pad" style="padding:28px 28px 10px;font-family:Arial,Helvetica,sans-serif;">
            <h1 class="email-body" style="margin:0 0 14px;font-size:23px;line-height:1.25;font-weight:700;color:#0f172a;">Имэйлээ баталгаажуулна уу</h1>
            <p class="email-body email-muted" style="margin:0 0 22px;font-size:15px;line-height:1.55;color:#475569;">
              Таны 6 оронтой ${appName} баталгаажуулах код:
            </p>
            <table role="presentation" class="otp-outer" cellpadding="0" cellspacing="0" width="100%" style="margin:0 0 22px;background:#f8fafc;border-radius:16px;">
              <tr>
                <td style="padding:8px;">
                  <table role="presentation" cellpadding="0" cellspacing="0" width="100%" class="otp-wrap" style="border-radius:14px;border:2px solid #0d9488;border-collapse:separate;background:#ecfeff;">
                    <tr>
                      <td align="center" style="padding:22px 18px;">
                        <div class="otp-code" style="font-family:'Courier New',Courier,monospace;font-size:38px;line-height:1.15;font-weight:800;letter-spacing:12px;color:#0e7490;mso-line-height-rule:exactly;">${otpCode}</div>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
            <p class="email-body email-muted" style="margin:0 0 14px;font-size:14px;line-height:1.55;color:#475569;">
              Энэ код ${expiresMn} минутын дараа хүчингүй болно.
            </p>
            <p class="email-body email-muted" style="margin:0;font-size:14px;line-height:1.55;color:#64748b;">
              Хэрэв та энэ хүсэлтийг гаргаагүй бол энэхүү имэйлийг үл тоож болно.
            </p>
          </td>
        </tr>
        <tr>
          <td style="padding:0 28px 26px;font-family:Arial,Helvetica,sans-serif;">
            <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="border-top:1px solid #e2e8f0;">
              <tr>
                <td style="padding-top:16px;">
                  <p class="email-muted" style="margin:0;font-size:12px;line-height:1.6;color:#94a3b8;">
                    Энэ нь ${appName} системээс автоматаар илгээгдсэн зурвас тул reply хийх шаардлагагүй.
                  </p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>
    `.trim();

    const attachments: nodemailer.Attachment[] =
      useCidLogo ?
        [
          {
            filename: 'clinova-logo.svg',
            path: logoPath,
            cid: logoCid,
          },
        ]
      : [];

    return { html, subject, textPlain, attachments };
  }

  async sendOtpEmail(
    email: string,
    code: string,
    context: { purpose: string },
  ): Promise<OtpEmailSendResult> {
    const emailDebug = this.emailDebugEnabled();
    const normalized = email.trim().toLowerCase();
    if (normalized.endsWith('@clinova.local')) {
      this.logger.warn(
        `[OTP email] purpose=${context.purpose} recipient=${email} — skipped (non-deliverable @clinova.local domain)`,
      );
      return { delivered: false, debugCode: emailDebug ? code : undefined };
    }

    const provider = this.activeProvider();

    if (provider === 'none') {
      this.logger.warn(
        `[OTP email] purpose=${context.purpose} recipient=${email} — no provider, email NOT sent. ` +
          `Set EMAIL_PROVIDER=resend|smtp with credentials (RESEND_API_KEY or SMTP_*), or use EMAIL_DEBUG=true for API debugCode fallback.`,
      );
      return { delivered: false, debugCode: emailDebug ? code : undefined };
    }

    this.logger.log(
      `[OTP email] purpose=${context.purpose} recipient=${email} provider=${provider} — send starting`,
    );

    if (this.otpDebugLogEnabled()) {
      this.logger.warn(
        `[OTP email] OTP_DEBUG=true (non-production) — verification code=${code}`,
      );
    }

    if (provider === 'resend' && this.resend) {
      const { html, subject, textPlain } = this.buildOtpEmailTemplate(code, {
        forApi: true,
      });
      try {
        const { data, error } = await this.resend.emails.send({
          from: this.resendDefaultFrom(),
          to: [email],
          subject,
          html,
          text: textPlain,
        });
        if (error) {
          const statusCode =
            typeof error.statusCode === 'number' ? error.statusCode : undefined;
          this.logger.error(
            `[OTP email] purpose=${context.purpose} recipient=${email} — Resend FAILED name=${error.name ?? 'n/a'} statusCode=${statusCode ?? 'n/a'} message=${error.message}`,
          );
          return {
            delivered: false,
            debugCode: emailDebug ? code : undefined,
            smtpError: {
              name: error.name,
              message: error.message,
              statusCode: statusCode ?? undefined,
            },
          };
        }
        const id = data?.id;
        this.logger.log(
          `[OTP email] purpose=${context.purpose} recipient=${email} — SUCCESS resend.id=${typeof id === 'string' ? id : 'n/a'}`,
        );
        return { delivered: true, messageId: typeof id === 'string' ? id : undefined };
      } catch (err) {
        const s = smtpErrorShape(err);
        this.logger.error(
          `[OTP email] purpose=${context.purpose} recipient=${email} — Resend EXCEPTION name=${s.name ?? 'n/a'} statusCode=${s.statusCode ?? 'n/a'} message=${s.message}`,
        );
        return {
          delivered: false,
          debugCode: emailDebug ? code : undefined,
          smtpError: s,
        };
      }
    }

    const { html, subject, textPlain, attachments } = this.buildOtpEmailTemplate(
      code,
      { forApi: false },
    );

    if (!this.transporter) {
      this.logger.warn(
        `[OTP email] purpose=${context.purpose} recipient=${email} — SMTP transporter missing, email NOT sent`,
      );
      return { delivered: false, debugCode: emailDebug ? code : undefined };
    }

    try {
      const info = await this.transporter.sendMail({
        from: this.fromEmail,
        to: email,
        subject,
        html,
        text: textPlain,
        attachments,
      });
      const messageId =
        typeof info.messageId === 'string' ? info.messageId : undefined;
      this.logger.log(
        `[OTP email] purpose=${context.purpose} recipient=${email} — SUCCESS messageId=${messageId ?? 'n/a'}`,
      );
      return { delivered: true, messageId };
    } catch (err) {
      const s = smtpErrorShape(err);
      this.logger.error(
        `[OTP email] purpose=${context.purpose} recipient=${email} — FAILED name=${s.name ?? 'n/a'} code=${s.code ?? 'n/a'} command=${s.command ?? 'n/a'} response=${s.response ?? 'n/a'} message=${s.message}`,
      );
      return {
        delivered: false,
        debugCode: emailDebug ? code : undefined,
        smtpError: s,
      };
    }
  }
}
