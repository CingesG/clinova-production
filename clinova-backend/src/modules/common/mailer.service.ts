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
  private readonly transporter?: nodemailer.Transporter;
  private readonly fromEmail: string;
  private readonly resend?: Resend;

  constructor(private readonly config: ConfigService) {
    const resendKey = this.config.get<string>('RESEND_API_KEY')?.trim();
    if (resendKey) {
      this.resend = new Resend(resendKey);
    }

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

    const ap = this.activeProvider();
    if (ap === 'none') {
      this.logger.warn(
        'No usable email provider (Resend missing key / SMTP incomplete). OTP emails depend on EMAIL_DEBUG debugCode fallback.',
      );
    }

    this.scheduleSmtpVerify();
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

  /** HTML + SMTP extras for OTP; skips CID when `forApi` so Resend does not send broken inline images without attachments. */
  private buildOtpContents(
    code: string,
    forApi: boolean,
  ): {
    html: string;
    subjectSmtp: string;
    attachments: nodemailer.Attachment[];
  } {
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

    const useCidLogo = !forApi && hasInlineLogo;
    const logoBlock =
      safeLogoUrl.length > 0
        ? `<img src="${safeLogoUrl}" alt="${appName} logo" width="44" height="44" style="display:block;width:44px;height:44px;border-radius:12px;object-fit:cover;border:1px solid #dbeafe;" />`
        : useCidLogo
          ? `<img src="cid:${logoCid}" alt="${appName} logo" width="44" height="44" style="display:block;width:44px;height:44px;border-radius:12px;object-fit:contain;background:#ffffff;border:1px solid #dbeafe;" />`
          : `<div style="display:inline-flex;align-items:center;justify-content:center;width:44px;height:44px;border-radius:12px;background:#eaf2ff;color:#1d4ed8;font-weight:700;font-size:14px;letter-spacing:0.4px;">CL</div>`;

    const subjectSmtp = `Your ${appNameRaw} verification code`;
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

    return { html, subjectSmtp, attachments };
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

    const emailDebug = this.emailDebugEnabled();
    const provider = this.activeProvider();

    if (provider === 'none') {
      this.logger.warn(
        `[OTP email] purpose=${context.purpose} recipient=${email} — no provider, email NOT sent`,
      );
      return { delivered: false, debugCode: emailDebug ? code : undefined };
    }

    this.logger.log(
      `[OTP email] purpose=${context.purpose} recipient=${email} provider=${provider} — send starting`,
    );

    if (provider === 'resend' && this.resend) {
      const { html } = this.buildOtpContents(code, true);
      try {
        const { data, error } = await this.resend.emails.send({
          from: this.resendDefaultFrom(),
          to: [email],
          subject: 'Clinova баталгаажуулах код',
          html,
          text: `Clinova баталгаажуулах код: ${code}`,
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

    const { html, subjectSmtp, attachments } = this.buildOtpContents(
      code,
      false,
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
        subject: subjectSmtp,
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
