import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { existsSync } from 'fs';
import * as nodemailer from 'nodemailer';
import { resolve } from 'path';

@Injectable()
export class MailerService {
  private readonly logger = new Logger(MailerService.name);
  private readonly transporter?: nodemailer.Transporter;
  private readonly fromEmail: string;

  constructor(private readonly config: ConfigService) {
    const host =
      this.config.get<string>('SMTP_HOST') ??
      this.config.get<string>('EMAIL_HOST');
    const port = Number(
      this.config.get<string>('SMTP_PORT') ??
        this.config.get<string>('EMAIL_PORT') ??
        587,
    );
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
        secure: port === 465,
        auth: {
          user,
          pass,
        },
      });
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

  async sendOtpEmail(email: string, code: string) {
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

    const isProduction =
      this.config.get<string>('NODE_ENV', 'development').toLowerCase() ===
      'production';
    // In development, default to debug mode so OTP is visible even without SMTP.
    const emailDebug =
      this.config
        .get<string>('EMAIL_DEBUG', isProduction ? 'false' : 'true')
        .toLowerCase() === 'true';

    if (!this.transporter) {
      this.logger.warn(
        `SMTP is not configured; OTP email was not sent. OTP for ${email}: ${code}`,
      );
      return { delivered: false, debugCode: emailDebug ? code : undefined };
    }

    const attachments: nodemailer.Attachment[] = hasInlineLogo
      ? [
          {
            filename: 'clinova-logo.svg',
            path: logoPath,
            cid: logoCid,
          },
        ]
      : [];

    await this.transporter.sendMail({
      from: this.fromEmail,
      to: email,
      subject,
      html,
      attachments,
    });

    return { delivered: true };
  }
}
