import 'package:flutter/material.dart';

/// Minimal tokens for Clinova premium healthcare SaaS surfaces (admin/doctor/settings).
abstract final class ClinovaPremium {
  static const Color navy = Color(0xFF071B4D);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);
  static const Color primary = Color(0xFF1769FF);
  static const Color primaryInk = Color(0xFF1D4ED8);
  static const Color pillBlueBg = Color(0xFFE8F0FF);
  static const Color primarySoft = Color(0xFFE8F4FF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSoft = Color(0xFFDCEEFE);
  static const Color surfaceTint = Color(0xFFF4F7FC);
  static const double radiusLg = 22;
  static const double radiusMd = 18;
  static const double maxContentWidth = 1240;

  static List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: Color(0x0D0F172A),
          blurRadius: 22,
          offset: Offset(0, 8),
        ),
      ];
}

/// Desktop ~1280 / mobile padding-friendly max width wrapper.
class PremiumPageCanvas extends StatelessWidget {
  const PremiumPageCanvas({
    super.key,
    required this.child,
    this.maxWidth = ClinovaPremium.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class PremiumDashboardHeader extends StatelessWidget {
  const PremiumDashboardHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.datePill,
    this.namePill,
    required this.showIconActions,
    this.narrow = false,
    this.onRefresh,
    this.onLogout,
  });

  final String title;
  final String subtitle;
  final String? datePill;
  final String? namePill;
  final bool showIconActions;
  /// Stack pills below title (mobile) to avoid horizontal overflow.
  final bool narrow;
  final VoidCallback? onRefresh;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pills = <Widget>[
      if (namePill != null && namePill!.isNotEmpty)
        _HeaderPill(text: namePill!, compact: narrow),
      if (datePill != null && datePill!.isNotEmpty)
        _HeaderPill(text: datePill!, compact: narrow),
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(narrow ? 16 : 20, narrow ? 14 : 18, narrow ? 12 : 16, narrow ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(ClinovaPremium.radiusLg),
        border: Border.all(
          color: ClinovaPremium.border.withValues(alpha: 0.75),
        ),
        boxShadow: ClinovaPremium.cardShadow,
      ),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: ClinovaPremium.textPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                        ),
                      ),
                    ),
                    if (showIconActions) ...[
                      IconButton.filledTonal(
                        tooltip: 'Шинэчлэх',
                        onPressed: onRefresh,
                        style: IconButton.styleFrom(
                          foregroundColor: ClinovaPremium.primaryInk,
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      IconButton(
                        tooltip: 'Гарах',
                        onPressed: onLogout,
                        icon: const Icon(Icons.logout_rounded),
                        color: ClinovaPremium.textSecondary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ClinovaPremium.textSecondary,
                    height: 1.35,
                  ),
                ),
                if (pills.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: pills,
                  ),
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: ClinovaPremium.textPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: ClinovaPremium.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (namePill != null && namePill!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _HeaderPill(text: namePill!, compact: false),
                ],
                if (datePill != null && datePill!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _HeaderPill(text: datePill!, compact: false),
                ],
                if (showIconActions) ...[
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    tooltip: 'Шинэчлэх',
                    onPressed: onRefresh,
                    style: IconButton.styleFrom(
                      foregroundColor: ClinovaPremium.primaryInk,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: 'Гарах',
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                    color: ClinovaPremium.textSecondary,
                  ),
                ],
              ],
            ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.text, this.compact = false});

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: ClinovaPremium.pillBlueBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: ClinovaPremium.primaryInk,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 12 : 13.5,
        ),
      ),
    );
  }
}

class PremiumStatCard extends StatelessWidget {
  const PremiumStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.footer,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ClinovaPremium.radiusMd),
        border: Border.all(color: ClinovaPremium.borderSoft),
        boxShadow: ClinovaPremium.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ClinovaPremium.primarySoft.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: ClinovaPremium.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: ClinovaPremium.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: ClinovaPremium.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (footer != null && footer!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    footer!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ClinovaPremium.textMuted,
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumSectionCard extends StatelessWidget {
  const PremiumSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
  });

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(ClinovaPremium.radiusLg),
        border: Border.all(
          color: ClinovaPremium.border.withValues(alpha: 0.72),
        ),
        boxShadow: ClinovaPremium.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: ClinovaPremium.primary, size: 22),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: ClinovaPremium.navy,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(
            height: 20,
            thickness: 1,
            color: ClinovaPremium.border.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class PremiumEmptyState extends StatelessWidget {
  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: BoxDecoration(
        color: ClinovaPremium.surfaceTint,
        borderRadius: BorderRadius.circular(ClinovaPremium.radiusMd),
        border: Border.all(color: ClinovaPremium.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: ClinovaPremium.border.withValues(alpha: 0.6)),
            ),
            child: Icon(icon, color: ClinovaPremium.textMuted, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ClinovaPremium.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ClinovaPremium.textMuted,
              height: 1.4,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumAppointmentCard extends StatelessWidget {
  const PremiumAppointmentCard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ClinovaPremium.radiusMd),
        border: Border.all(color: ClinovaPremium.borderSoft),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PremiumStatusPill extends StatelessWidget {
  const PremiumStatusPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final u = label.toUpperCase();
    final ok = u == 'CONFIRMED' ||
        u == 'COMPLETED' ||
        u == 'ACTIVE' ||
        u == 'ACCEPTED';
    final color =
        ok ? const Color(0xFF15803D) : ClinovaPremium.primaryInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        u,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class PremiumSettingsSurface extends StatelessWidget {
  const PremiumSettingsSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(ClinovaPremium.radiusLg),
        border: Border.all(color: ClinovaPremium.border.withValues(alpha: 0.65)),
        boxShadow: ClinovaPremium.cardShadow,
      ),
      child: child,
    );
  }
}

class PremiumSectionLabel extends StatelessWidget {
  const PremiumSectionLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: ClinovaPremium.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

/// Floating segmented-style bottom bar (doctor tools).
class PremiumBottomToolBar extends StatelessWidget {
  const PremiumBottomToolBar({
    super.key,
    required this.isCompact,
    required this.items,
  });

  final bool isCompact;
  final List<PremiumBottomToolItem> items;

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white.withValues(alpha: 0.97);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isCompact ? 10 : 16, 0, isCompact ? 10 : 16, isCompact ? 10 : 12),
        child: Material(
          elevation: 8,
          shadowColor: Colors.black26,
          color: bg,
          borderRadius: BorderRadius.circular(ClinovaPremium.radiusLg),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ClinovaPremium.radiusLg),
              border: Border.all(color: ClinovaPremium.border.withValues(alpha: 0.8)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: isCompact
                ? Row(
                    children: [
                      for (final item in items)
                        Expanded(
                          child: _BottomItem(item: item, compact: true),
                        ),
                    ],
                  )
                : Row(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: i == 0
                              ? FilledButton.icon(
                                  onPressed: items[i].onTap,
                                  icon: Icon(items[i].icon),
                                  label: Text(items[i].label),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: ClinovaPremium.primary,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 48),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                )
                              : OutlinedButton.icon(
                                  onPressed: items[i].onTap,
                                  icon: Icon(items[i].icon),
                                  label: Text(items[i].label),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: ClinovaPremium.textPrimary,
                                    minimumSize: const Size(0, 48),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    side: BorderSide(
                                      color: ClinovaPremium.border.withValues(alpha: 0.95),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class PremiumBottomToolItem {
  const PremiumBottomToolItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({required this.item, required this.compact});

  final PremiumBottomToolItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 22, color: ClinovaPremium.textSecondary),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: ClinovaPremium.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
