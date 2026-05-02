import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { existsSync } from 'fs';
import * as nodemailer from 'nodemailer';
import { resolve } from 'path';

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
  };
};

function smtpErrorShape(err: unknown): NonNullable<OtpEmailSendResult['smtpError']> {
  if (!err || typeof err !== 'object') {
    return { message: String(err) };
  }
  const e = err as Record<string, unknown>;
  return {
    name: typeof e.name === 'string' ? e.name : undefined,
    message:
      typeof e.message === 'string'
        ? e.message
        : typeof e.toString === 'function'
          ? (e.toString() as string)
          : 'Unknown error',
    code: typeof e.code === 'string' ? e.code : undefined,
    command: typeof e.command === 'string' ? e.command : undefined,
    response:
      typeof e.response === 'string'
        ? e.response
        : e.response != null
          ? String(e.response)
          : undefined,
  };
}

@Injectable()
export class MailerService implements OnModuleInit {
  private readonly logger = new Logger(MailerService.name);
  private readonly transporter?: nodemailer.Transporter;
  private readonly fromEmail: string;

  constructor(private readonly config: ConfigService) {
    const host = (
      this.config.get<string>('SMTP_HOST') ??
      this.config.get<string>('EMAIL_HOST') ??
      'smtp.gmail.com'
    ).trim();

    const port = Number(
      this.config.get<string>('SMTP_PORT') ??
        this.config.get<string>('EMAIL_PORT') ??
        '587',
    );

    const secure =
      this.config.get<string>('SMTP_SECURE', 'false').toLowerCase() ===
      'true';

    const user =
      this.config.get<string>('SMTP_USER') ??
      this.config.get<string>('EMAIL_USER');
    const smtpPassKey = ['SMTP_', 'PASS'].join('');
    const pass =
      this.config.get<string>(smtpPassKey) ??
      this.config.get<string>('EMAIL_PASS');

    this.fromEmail =
      this.config.get<string>('SMTP_FROM') ??
      this.config.get<string>('EMAIL_FROM') ??
      user ??
      'no-reply@clinova.local';

    if (host && user && pass) {
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

  private logSmtpEnvPresence() {
    const has = (key: string) => {
      const v = this.config.get<string>(key);
      return v != null && String(v).trim().length > 0;
    };
    this.logger.log(
      `[SMTP env] SMTP_HOST=${has('SMTP_HOST') || has('EMAIL_HOST')} ` +
        `SMTP_PORT=${has('SMTP_PORT') || has('EMAIL_PORT')} ` +
        `SMTP_SECURE=${has('SMTP_SECURE')} ` +
        `SMTP_USER=${has('SMTP_USER') || has('EMAIL_USER')} ` +
        `SMTP_PASS=${has('SMTP_PASS') || has('EMAIL_PASS')} ` +
        `SMTP_FROM=${has('SMTP_FROM') || has('EMAIL_FROM')}`,
    );
  }

  async onModuleInit() {
    this.logSmtpEnvPresence();
    if (!this.transporter) {
      this.logger.warn(
        'SMTP transporter not created (missing host/user/pass or invalid). OTP emails will not send unless EMAIL_DEBUG returns debugCode.',
      );
      return;
    }
    try {
      await this.transporter.verify();
      this.logger.log('SMTP transporter.verify() OK — connection ready.');
    } catch (err) {
      const s = smtpErrorShape(err);
      this.logger.error(
        `SMTP transporter.verify() FAILED name=${s.name ?? 'n/a'} code=${s.code ?? 'n/a'} message=${s.message}`,
      );
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

  private otpDebugEnabled(): boolean {
    return (
      this.config.get<string>('OTP_DEBUG', 'false').toLowerCase() === 'true'
    );
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

  /**
   * Safe diagnostic email (no secrets in response). Use with POST /auth/test-email + header.
   */
  async sendTestEmail(to: string): Promise<{
    ok: boolean;
    messageId?: string;
    error?: OtpEmailSendResult['smtpError'];
  }> {
    if (!this.transporter) {
      return {
        ok: false,
        error: { message: 'SMTP transporter not configured' },
      };
    }
    try {
      const info = await this.transporter.sendMail({
        from: this.fromEmail,
        to,
        subject: 'Clinova SMTP test',
        text: 'If you received this, outbound SMTP from Render is working.',
      });
      const messageId =
        typeof info.messageId === 'string' ? info.messageId : undefined;
      this.logger.log(
        `[SMTP test] sent to ${to} messageId=${messageId ?? 'n/a'}`,
      );
      return { ok: true, messageId };
    } catch (err) {
      const s = smtpErrorShape(err);
      this.logger.error(
        `[SMTP test] FAILED to=${to} name=${s.name ?? 'n/a'} code=${s.code ?? 'n/a'} command=${s.command ?? 'n/a'} message=${s.message}`,
      );
      return { ok: false, error: s };
    }
  }

  async sendOtpEmail(
    email: string,
    code: string,
    context: { purpose: string },
  ): Promise<OtpEmailSendResult> {
    if (this.otpDebugEnabled()) {
      // eslint-disable-next-line no-console -- explicit Render log when OTP_DEBUG=true only
      console.log('[OTP DEBUG]', email, code);
    }

    const appNameRaw = this.config.get<string>('APP_NAME', 'Clinova');
    const appName = this.escapeHtml(appNameRaw);
    const otpCode = this.escapeHtml(code);
    const logoUrl = (this.config.get<string>('APP_LOGO_URL') ?? '').trim();
    const logoPathRaw = (this.config.get<string>('APP_LOGO_PATH') ?? '').trim();
    const logoPath = logoPathRaw
      ? resolve(process.cwd(), logoPathRaw)
      : '';
    const hasInlineLogo = logoPath.length > 0 && existsSync(logoPath);
    const safeLogoUrl = this.escapeHtml(logoUrl);
    const logoCid = 'clinova-logo';
    const logoBlock = safeLogoUrl
      ? `<img src="${safeLogoUrl}" alt="${appName} logo" width="44" height="44" style="display:block;width:44px;height:44px;border-radius:12px;object-fit:cover;border:1px solid #dbeafe;" />`
      : hasInlineLogo
        ? `<img src="cid:${logoCid}" alt="${appName} logo" width="44" height="44" style="display:block;width:44px;height:44px;border-radius:12px;object-fit:contain;background:#ffffff;border:1px solid #dbeafe;" />`
        : `<div style="display:inline-flex;align-items:center;justify-content:center;width:44px;height:44px;border-radius:12px;background:#eaf2ff;color:#1d4ed8;font-weight:700;font-size:14px;letter-spacing:0.4px;">CL</div>`;
    const subject = `Your ${appNameRaw} verification code`;
    const html = `
      <div style="margin:0;padding:24px 12px;background:#f3f7ff;font-family:Arial,sans-serif;">
        <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:560px;margin:0 auto;background:#ffffff;border:1px solid #dbe7ff;border-radius:16px;overflow:hidden;">
          <tr>
            <td style="padding:24px 24px 10px;">
              <table role="presentation" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td style="width:52px;vertical-align:middle;">${logoBlock}</td>
                  <td style="vertical-align:middle;padding-left:10px;">
                    <div style="font-size:18px;line-height:1.2;font-weight:700;color:#0f172a;">${appName}</div>
                    <div style="font-size:12px;color:#64748b;margin-top:2px;">Secure verification</div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:0 24px 22px;">
              <h2 style="margin:12px 0 10px;font-size:24px;line-height:1.2;color:#0f172a;">Verify your email</h2>
              <p style="margin:0 0 14px;font-size:15px;line-height:1.5;color:#334155;">
                Your 6-digit ${appName} verification code is:
              </p>
              <div style="display:inline-block;margin:0 0 14px;padding:10px 16px;border-radius:12px;background:#eff6ff;border:1px solid #bfdbfe;font-size:28px;line-height:1;font-weight:700;letter-spacing:4px;color:#1d4ed8;">
                ${otpCode}
              </div>
              <p style="margin:0 0 8px;font-size:14px;line-height:1.5;color:#475569;">
                This code expires in <strong>10 minutes</strong>.
              </p>
              <p style="margin:0;font-size:14px;line-height:1.5;color:#64748b;">
                If you did not request this email, you can safely ignore it.
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding:14px 24px;background:#f8fbff;border-top:1px solid #e2e8f0;">
              <p style="margin:0;font-size:12px;line-height:1.5;color:#94a3b8;">
                This is an automated message from ${appName}. Please do not reply directly.
              </p>
            </td>
          </tr>
        </table>
      </div>
    `;

    const emailDebug = this.emailDebugEnabled();

    if (!this.transporter) {
      this.logger.warn(
        `[OTP email] purpose=${context.purpose} recipient=${email} — transporter missing, email NOT sent`,
      );
      return { delivered: false, debugCode: emailDebug ? code : undefined };
    }

    this.logger.log(
      `[OTP email] purpose=${context.purpose} recipient=${email} — send starting`,
    );

    const attachments: nodemailer.Attachment[] = hasInlineLogo
      ? [
          {
            filename: 'clinova-logo.svg',
            path: logoPath,
            cid: logoCid,
          },
        ]
      : [];

    try {
      const info = await this.transporter.sendMail({
        from: this.fromEmail,
        to: email,
        subject,
        html,
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
