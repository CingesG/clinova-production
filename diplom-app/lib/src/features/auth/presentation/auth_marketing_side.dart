import 'package:flutter/material.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/widgets/clinova_logo.dart';

enum AuthMarketingVariant { login, register, recovery, verify }

class AuthMarketingSide extends StatelessWidget {
  const AuthMarketingSide({super.key, required this.variant});

  final AuthMarketingVariant variant;

  static const _teal = Color(0xFF0EA5A4);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    late final String title;
    late final List<String> lines;
    late final List<IconData> icons;

    switch (variant) {
      case AuthMarketingVariant.login:
        title = l10n.authMarketingLoginTitle;
        lines = [
          l10n.authMarketingLoginLine1,
          l10n.authMarketingLoginLine2,
          l10n.authMarketingLoginLine3,
        ];
        icons = [
          Icons.auto_awesome_rounded,
          Icons.calendar_month_rounded,
          Icons.verified_user_outlined,
        ];
      case AuthMarketingVariant.register:
        title = l10n.authMarketingRegisterTitle;
        lines = [
          l10n.authMarketingRegisterLine1,
          l10n.authMarketingRegisterLine2,
          l10n.authMarketingRegisterLine3,
        ];
        icons = [
          Icons.health_and_safety_outlined,
          Icons.chat_bubble_outline_rounded,
          Icons.lock_person_outlined,
        ];
      case AuthMarketingVariant.recovery:
        title = l10n.authMarketingRecoveryTitle;
        lines = [
          l10n.authMarketingRecoveryLine1,
          l10n.authMarketingRecoveryLine2,
          l10n.authMarketingRecoveryLine3,
        ];
        icons = [
          Icons.mark_email_read_outlined,
          Icons.password_rounded,
          Icons.policy_outlined,
        ];
      case AuthMarketingVariant.verify:
        title = l10n.authMarketingVerifyTitle;
        lines = [
          l10n.authMarketingVerifyLine1,
          l10n.authMarketingVerifyLine2,
          l10n.authMarketingVerifyLine3,
        ];
        icons = [
          Icons.forward_to_inbox_rounded,
          Icons.verified_outlined,
          Icons.enhanced_encryption_outlined,
        ];
    }

    return Semantics(
      container: true,
      label: title,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF061D52).withValues(alpha: 0.94),
              const Color(0xFF0B5FA8).withValues(alpha: 0.92),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22071B4D),
              blurRadius: 32,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ClinovaLogo(size: 44, variant: LogoVariant.glass),
            const SizedBox(height: 8),
            Text(
              'Clinova',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < lines.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == lines.length - 1 ? 0 : 16,
                ),
                child: _Bullet(icon: icons[i], text: lines[i]),
              ),
            const SizedBox(height: 28),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_moon_rounded,
                      color: _teal.withValues(alpha: 0.95),
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.authFooterSecure,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
