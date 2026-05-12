import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../localization/context_l10n.dart';
import 'clinova_circle_avatar.dart';
import 'clinova_logo.dart';
import 'premium_healthcare_shell.dart';

/// Presentation tokens: Apple Health–adjacent calm surfaces + Clinova ink.
abstract final class _DrawerVisual {
  static const Color canvasA = Color(0xFFF7F8FA);
  static const Color canvasB = Color(0xFFF0F2F5);
  static const Color hairline = Color(0x143C3C43);
  static const Color hairlineLight = Color(0x0D3C3C43);
  static const Color rowSurface = Color(0xFFFFFFFF);
  static const Color activeFill = Color(0xFFE8F1FF);
  static const Color activeInk = Color(0xFF1557C7);
  static const Color iconWell = Color(0xFFF2F4F7);
  static const Color quickPanel = Color(0xFF101828);
  static const Color quickPanel2 = Color(0xFF1D2939);
  static List<BoxShadow> get panelLift => const [
    BoxShadow(color: Color(0x14000000), blurRadius: 1, offset: Offset(0, 0.5)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 24, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x06000000), blurRadius: 48, offset: Offset(0, 24)),
  ];
}

/// Premium Clinova drawer shell: width, rounded edge, glass-style surface.
/// [leadingEdgeRounded] true = end drawer (rounded on inner left edge);
/// false = start drawer (rounded on inner right edge).
class ClinovaPremiumDrawerFrame extends StatelessWidget {
  const ClinovaPremiumDrawerFrame({
    super.key,
    required this.child,
    this.leadingEdgeRounded = true,
  });

  final Widget child;
  final bool leadingEdgeRounded;

  static double drawerWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.85).clamp(280.0, 360.0);
  }

  @override
  Widget build(BuildContext context) {
    final mqW = MediaQuery.sizeOf(context).width;
    final width = drawerWidth(context);
    final radius = mqW >= 900 ? 32.0 : 28.0;

    final shape = leadingEdgeRounded
        ? BorderRadius.only(
            topLeft: Radius.circular(radius),
            bottomLeft: Radius.circular(radius),
          )
        : BorderRadius.only(
            topRight: Radius.circular(radius),
            bottomRight: Radius.circular(radius),
          );

    final shadowDx = leadingEdgeRounded ? -6.0 : 6.0;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!kIsWeb)
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.transparent),
                    child: const SizedBox.expand(),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFCFCFD),
                      _DrawerVisual.canvasA,
                      _DrawerVisual.canvasB,
                    ],
                    stops: [0.0, 0.38, 1.0],
                  ),
                  border: Border.all(color: _DrawerVisual.hairline, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x22000000),
                      blurRadius: 1,
                      spreadRadius: 0,
                      offset: Offset(shadowDx * 0.25, 0),
                    ),
                    const BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 40,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: const SizedBox.expand(),
              ),
              Positioned.fill(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo row + app name + optional badge.
class ClinovaDrawerBrandingHeader extends StatelessWidget {
  const ClinovaDrawerBrandingHeader({
    super.key,
    this.badgeText = 'AI Healthcare',
  });

  final String badgeText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ClinovaLogo(size: 40, variant: LogoVariant.dark, showText: false),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Clinova',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ClinovaPremium.navy,
                  letterSpacing: -0.45,
                  height: 1.05,
                  fontSize: 21,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _DrawerVisual.activeFill.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _DrawerVisual.activeInk.withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  badgeText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _DrawerVisual.activeInk.withValues(alpha: 0.92),
                    letterSpacing: 0.15,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String clinovaDrawerAvatarInitials({
  required String displayName,
  String? email,
}) {
  final parts = displayName.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    final a = parts[0].isNotEmpty ? parts[0][0] : '';
    final b = parts[1].isNotEmpty ? parts[1][0] : '';
    return ('$a$b').toUpperCase();
  }
  final single = displayName.trim();
  if (single.length >= 2) return single.substring(0, 2).toUpperCase();
  final em = email?.trim() ?? '';
  if (em.length >= 2) return em.substring(0, 2).toUpperCase();
  return 'C';
}

String clinovaDrawerRoleLabelMn(String? role) {
  switch (role) {
    case 'DOCTOR':
      return 'Эмч';
    case 'ADMIN':
      return 'Админ';
    case 'STAFF':
      return 'Ажилтан';
    case 'PATIENT':
    default:
      return 'Өвчтөн';
  }
}

class ClinovaDrawerUserCard extends StatelessWidget {
  const ClinovaDrawerUserCard({
    super.key,
    required this.displayName,
    required this.roleLabel,
    required this.initialsText,
    this.email,
    this.avatarUrl,
    this.subline,
  });

  final String displayName;
  final String roleLabel;
  final String initialsText;
  final String? email;
  final String? avatarUrl;
  final String? subline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _DrawerVisual.rowSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _DrawerVisual.hairlineLight, width: 0.5),
        boxShadow: _DrawerVisual.panelLift,
      ),
      child: Row(
        children: [
          ClinovaCircleAvatar(
            radius: 26,
            initialsText: initialsText.isNotEmpty ? initialsText : 'C',
            backgroundColor: _DrawerVisual.iconWell,
            foregroundColor: ClinovaPremium.primaryInk,
            networkUrl: avatarUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ClinovaPremium.textPrimary,
                    letterSpacing: -0.25,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _DrawerVisual.hairlineLight,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        roleLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF344054),
                          letterSpacing: 0.05,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (subline != null && subline!.isNotEmpty)
                      Text(
                        subline!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: ClinovaPremium.textMuted,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                if (email != null && email!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ClinovaPremium.textSecondary,
                      fontWeight: FontWeight.w400,
                      fontSize: 12.5,
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

class ClinovaDrawerMenuItem extends StatelessWidget {
  const ClinovaDrawerMenuItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.isActive,
    required this.onTap,
    this.animationT = 1.0,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isActive;
  final VoidCallback onTap;
  final double animationT;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = animationT.clamp(0.0, 1.0);
    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.28,
      height: 1.18,
      fontSize: 16,
      color: isActive ? _DrawerVisual.activeInk : ClinovaPremium.navy,
    );
    final subStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.28,
      fontSize: 12.5,
      letterSpacing: -0.05,
      color: isActive
          ? _DrawerVisual.activeInk.withValues(alpha: 0.72)
          : const Color(0xFF667085),
    );

    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(8 * (1 - t), 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.black.withValues(alpha: 0.05),
              highlightColor: Colors.black.withValues(alpha: 0.03),
              hoverColor: Colors.black.withValues(alpha: 0.04),
              child: Ink(
                decoration: BoxDecoration(
                  color: isActive
                      ? _DrawerVisual.activeFill
                      : _DrawerVisual.rowSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive
                        ? _DrawerVisual.activeInk.withValues(alpha: 0.14)
                        : _DrawerVisual.hairlineLight,
                    width: 0.5,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: _DrawerVisual.activeInk.withValues(
                              alpha: 0.08,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        width: 3,
                        height: isActive ? 28 : 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: isActive
                              ? _DrawerVisual.activeInk
                              : const Color(0xFFE4E7EC),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive
                              ? _DrawerVisual.activeInk.withValues(alpha: 0.1)
                              : _DrawerVisual.iconWell,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: isActive
                                ? _DrawerVisual.activeInk.withValues(
                                    alpha: 0.08,
                                  )
                                : _DrawerVisual.hairlineLight,
                            width: 0.5,
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: isActive
                              ? _DrawerVisual.activeInk
                              : const Color(0xFF475467),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: titleStyle),
                            if (subtitle != null && subtitle!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: subStyle,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color:
                            (isActive
                                    ? _DrawerVisual.activeInk
                                    : const Color(0xFF98A2B3))
                                .withValues(alpha: isActive ? 0.55 : 0.65),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ClinovaDrawerQuickActionCard extends StatelessWidget {
  const ClinovaDrawerQuickActionCard({
    super.key,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.onSecondary,
    this.showSecondary = true,
  });

  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final VoidCallback onSecondary;
  final bool showSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_DrawerVisual.quickPanel, _DrawerVisual.quickPanel2],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
        boxShadow: _DrawerVisual.panelLift,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  primaryIcon,
                  color: const Color(0xFF84CAFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Шуурхай үйлдэл',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92),
                    letterSpacing: -0.15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            button: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPrimary,
                borderRadius: BorderRadius.circular(14),
                splashColor: Colors.white.withValues(alpha: 0.12),
                child: Ink(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(primaryIcon, size: 19, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          primaryLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            letterSpacing: -0.25,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showSecondary) ...[
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSecondary,
                borderRadius: BorderRadius.circular(14),
                splashColor: Colors.white.withValues(alpha: 0.08),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 0.5,
                    ),
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        secondaryIcon,
                        size: 18,
                        color: const Color(0xFFBAE6FD),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        secondaryLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: -0.2,
                          color: Color(0xFFE0F2FE),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ClinovaDrawerFooter extends StatelessWidget {
  const ClinovaDrawerFooter({
    super.key,
    required this.versionLabel,
    this.onLogout,
    this.showLogout = false,
  });

  final String versionLabel;
  final VoidCallback? onLogout;
  final bool showLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(
            height: 1,
            thickness: 0.5,
            color: _DrawerVisual.hairlineLight,
          ),
          const SizedBox(height: 12),
          Text(
            versionLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: const Color(0xFF98A2B3),
              letterSpacing: 0.2,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Secure healthcare platform',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF667085),
              fontWeight: FontWeight.w400,
              fontSize: 12,
              height: 1.35,
              letterSpacing: -0.05,
            ),
          ),
          if (showLogout && onLogout != null) ...[
            const SizedBox(height: 14),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onLogout,
                borderRadius: BorderRadius.circular(14),
                splashColor: const Color(0xFFB91C1C).withValues(alpha: 0.12),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFECACA).withValues(alpha: 0.9),
                      width: 0.5,
                    ),
                    color: const Color(0xFFFFFBFA),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 19,
                          color: const Color(0xFFB42318),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Гарах',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFB42318),
                            letterSpacing: -0.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DrawerDismissChip extends StatelessWidget {
  const _DrawerDismissChip();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Хаах',
      child: Material(
        color: const Color(0x08000000),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).pop(),
          splashColor: Colors.black.withValues(alpha: 0.08),
          highlightColor: Colors.black.withValues(alpha: 0.04),
          child: const SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              Icons.close_rounded,
              size: 19,
              color: Color(0xFF667085),
            ),
          ),
        ),
      ),
    );
  }
}

/// Patient home [endDrawer] — Mongolian nav, auth-aware header, quick actions.
class ClinovaPatientHomeDrawer extends ConsumerStatefulWidget {
  const ClinovaPatientHomeDrawer({super.key});

  @override
  ConsumerState<ClinovaPatientHomeDrawer> createState() =>
      _ClinovaPatientHomeDrawerState();
}

class _ClinovaPatientHomeDrawerState
    extends ConsumerState<ClinovaPatientHomeDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  double _staggerT(int index, int total) {
    final start = index / (total + 2);
    final end = start + 0.45;
    return CurvedAnimation(
      parent: _ac,
      curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    ).value;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final isAuthed = auth.isAuthenticated;
    final path = GoRouterState.of(context).uri.path;

    void closeThen(void Function(BuildContext c) fn) {
      final nav = Navigator.of(context);
      nav.pop();
      fn(context);
    }

    bool activeHome(String p) => p == '/home';
    bool activeAppt(String p) =>
        p == '/appointments' || p.startsWith('/appointments/');
    bool activeAi(String p) => p == '/agent' || p.startsWith('/agent');
    bool activeChat(String p) =>
        p == '/chat-landing' ||
        p == '/doctor-chat' ||
        p.startsWith('/doctor-chat/');
    bool activeBranches(String p) => p == '/branches';
    bool activeProfile(String p) =>
        p == '/profile' || p.startsWith('/profile/');
    bool activeSettings(String p) => p == '/settings';

    final displayName = isAuthed
        ? (user!.displayName.isNotEmpty
              ? user.displayName
              : 'Clinova хэрэглэгч')
        : 'Зочин';
    final roleLabel = isAuthed ? clinovaDrawerRoleLabelMn(user!.role) : 'Зочин';
    final email = isAuthed && user!.email.isNotEmpty ? user.email : null;
    final avatarUrl = isAuthed ? user!.avatarUrl : null;
    final initials = clinovaDrawerAvatarInitials(
      displayName: isAuthed ? user!.displayName : displayName,
      email: user?.email,
    );

    final entries =
        <
          ({
            IconData icon,
            String title,
            String? sub,
            bool active,
            void Function(BuildContext) onTap,
          })
        >[
          (
            icon: Icons.home_rounded,
            title: 'Нүүр',
            sub: 'Ерөнхий хяналтын самбар',
            active: activeHome(path),
            onTap: (c) => c.go('/home'),
          ),
          (
            icon: Icons.calendar_month_rounded,
            title: 'Цаг захиалах',
            sub: 'Дараагийн чөлөөт цагийг олох',
            active: activeAppt(path),
            onTap: (c) => c.go('/appointments'),
          ),
          (
            icon: Icons.auto_awesome_rounded,
            title: 'Clinova AI · Агент',
            sub: 'AI зөвлөгөө, туслах нэг дор',
            active: activeAi(path),
            onTap: (c) => c.push('/agent'),
          ),
          (
            icon: Icons.chat_bubble_rounded,
            title: 'Эмчтэй чат',
            sub: 'Бодит цагт холбогдох',
            active: activeChat(path),
            onTap: (c) => c.go('/chat-landing'),
          ),
          (
            icon: Icons.location_on_rounded,
            title: 'Эмнэлгийн салбарууд',
            sub: 'Хаяг, холбоо барих, сонгосон салбар',
            active: activeBranches(path),
            onTap: (c) => c.push('/branches'),
          ),
          (
            icon: Icons.person_rounded,
            title: 'Профайл',
            sub: 'Хувийн мэдээлэл',
            active: activeProfile(path),
            onTap: (c) => c.go('/profile'),
          ),
          (
            icon: Icons.tune_rounded,
            title: 'Тохиргоо',
            sub: 'Апп тохиргоо',
            active: activeSettings(path),
            onTap: (c) => c.push('/settings'),
          ),
        ];

    final n = entries.length;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: ClinovaPremiumDrawerFrame.drawerWidth(context),
      child: ClinovaPremiumDrawerFrame(
        leadingEdgeRounded: true,
        child: SafeArea(
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.black.withValues(alpha: 0.06),
              highlightColor: Colors.black.withValues(alpha: 0.03),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _ac,
                            curve: const Interval(
                              0,
                              0.35,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: const ClinovaDrawerBrandingHeader(
                            badgeText: 'AI Healthcare',
                          ),
                        ),
                      ),
                      const _DrawerDismissChip(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Divider(
                    height: 1,
                    thickness: 0.5,
                    color: _DrawerVisual.hairlineLight,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _ac,
                      curve: const Interval(0.05, 0.4, curve: Curves.easeOut),
                    ),
                    child: ClinovaDrawerUserCard(
                      displayName: displayName,
                      roleLabel: roleLabel,
                      initialsText: initials,
                      email: email,
                      avatarUrl: avatarUrl,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        ClinovaDrawerMenuItem(
                          icon: entries[i].icon,
                          title: entries[i].title,
                          subtitle: entries[i].sub,
                          isActive: entries[i].active,
                          animationT: _staggerT(i, n),
                          onTap: () => closeThen((c) => entries[i].onTap(c)),
                        ),
                      ClinovaDrawerQuickActionCard(
                        primaryLabel: 'Яаралтай тусламж',
                        primaryIcon: Icons.emergency_rounded,
                        onPrimary: () => closeThen((c) => c.push('/emergency')),
                        secondaryLabel: 'AI асуух',
                        secondaryIcon: Icons.psychology_rounded,
                        onSecondary: () => closeThen((c) => c.push('/agent')),
                      ),
                    ],
                  ),
                ),
                ClinovaDrawerFooter(
                  versionLabel: 'Clinova v1.0',
                  showLogout: isAuthed,
                  onLogout: isAuthed
                      ? () {
                          Navigator.of(context).pop();
                          ref.read(authControllerProvider.notifier).logout();
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Doctor mobile [drawer] — never shows patient «Эмчтэй чат» wording.
class ClinovaDoctorPremiumDrawer extends ConsumerStatefulWidget {
  const ClinovaDoctorPremiumDrawer({super.key, required this.onReload});

  final Future<void> Function() onReload;

  @override
  ConsumerState<ClinovaDoctorPremiumDrawer> createState() =>
      _ClinovaDoctorPremiumDrawerState();
}

class _ClinovaDoctorPremiumDrawerState
    extends ConsumerState<ClinovaDoctorPremiumDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  double _staggerT(int index, int total) {
    final start = index / (total + 2);
    final end = start + 0.45;
    return CurvedAnimation(
      parent: _ac,
      curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    ).value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authControllerProvider);
    final user = auth.user!;
    final path = GoRouterState.of(context).uri.path;

    void closeThen(void Function(BuildContext c) fn) {
      Navigator.of(context).pop();
      fn(context);
    }

    final displayName = user.displayName.isNotEmpty
        ? user.displayName
        : 'Clinova хэрэглэгч';
    final initials = clinovaDrawerAvatarInitials(
      displayName: user.displayName,
      email: user.email,
    );

    final entries =
        <
          ({
            IconData icon,
            String title,
            String? sub,
            bool active,
            void Function(BuildContext) onTap,
          })
        >[
          (
            icon: Icons.dashboard_rounded,
            title: 'Нүүр',
            sub: 'Эмчийн ерөнхий самбар',
            active: path == '/doctor',
            onTap: (c) => c.go('/doctor'),
          ),
          (
            icon: Icons.chat_bubble_rounded,
            title: 'Өвчтөнүүдийн чат',
            sub: 'Бодит цагт холбогдох',
            active: path == '/doctor-chat' || path.startsWith('/doctor-chat/'),
            onTap: (c) => c.go('/doctor-chat'),
          ),
          (
            icon: Icons.schedule_rounded,
            title: 'Цагийн хуваарь',
            sub: 'Өөрийн ажлын цаг',
            active: path == '/doctor/schedule',
            onTap: (c) => c.go('/doctor/schedule'),
          ),
          (
            icon: Icons.medical_information_rounded,
            title: 'Үзлэгүүд',
            sub: 'Үзлэгийн тэмдэглэл, түүх',
            active: path == '/doctor/notes',
            onTap: (c) => c.go('/doctor/notes'),
          ),
          (
            icon: Icons.person_rounded,
            title: 'Профайл',
            sub: 'Хувийн мэдээлэл',
            active: path == '/profile' || path.startsWith('/profile/'),
            onTap: (c) => c.go('/profile'),
          ),
          (
            icon: Icons.tune_rounded,
            title: l10n.settings,
            sub: 'Апп тохиргоо',
            active: path == '/settings',
            onTap: (c) => c.go('/settings'),
          ),
        ];
    final n = entries.length;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: ClinovaPremiumDrawerFrame.drawerWidth(context),
      child: ClinovaPremiumDrawerFrame(
        leadingEdgeRounded: false,
        child: SafeArea(
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.black.withValues(alpha: 0.06),
              highlightColor: Colors.black.withValues(alpha: 0.03),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _ac,
                            curve: const Interval(
                              0,
                              0.35,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: const ClinovaDrawerBrandingHeader(),
                        ),
                      ),
                      const _DrawerDismissChip(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Divider(
                    height: 1,
                    thickness: 0.5,
                    color: _DrawerVisual.hairlineLight,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _ac,
                      curve: const Interval(0.05, 0.4, curve: Curves.easeOut),
                    ),
                    child: ClinovaDrawerUserCard(
                      displayName: displayName,
                      roleLabel: clinovaDrawerRoleLabelMn(user.role),
                      initialsText: initials,
                      email: user.email.isNotEmpty ? user.email : null,
                      avatarUrl: user.avatarUrl,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await widget.onReload();
                      },
                      splashColor: Colors.black.withValues(alpha: 0.05),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _DrawerVisual.hairlineLight,
                            width: 0.5,
                          ),
                          color: _DrawerVisual.rowSurface,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                size: 19,
                                color: ClinovaPremium.primaryInk,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Дахин ачаалах',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: ClinovaPremium.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        ClinovaDrawerMenuItem(
                          icon: entries[i].icon,
                          title: entries[i].title,
                          subtitle: entries[i].sub,
                          isActive: entries[i].active,
                          animationT: _staggerT(i, n),
                          onTap: () => closeThen((c) => entries[i].onTap(c)),
                        ),
                      ClinovaDrawerQuickActionCard(
                        primaryLabel: 'Яаралтай тусламж',
                        primaryIcon: Icons.emergency_rounded,
                        onPrimary: () => closeThen((c) => c.push('/emergency')),
                        secondaryLabel: 'AI асуух',
                        secondaryIcon: Icons.psychology_rounded,
                        onSecondary: () => closeThen((c) => c.push('/agent')),
                      ),
                    ],
                  ),
                ),
                ClinovaDrawerFooter(
                  versionLabel: 'Clinova v1.0',
                  showLogout: true,
                  onLogout: () {
                    Navigator.of(context).pop();
                    ref.read(authControllerProvider.notifier).logout();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Admin mobile drawer: navigation-style jumps + existing admin quick actions.
class ClinovaAdminPremiumDrawer extends ConsumerStatefulWidget {
  const ClinovaAdminPremiumDrawer({
    super.key,
    required this.onReload,
    required this.onScrollDashboard,
    required this.onScrollUsers,
    required this.onScrollApplications,
    required this.onScrollBranchesInsights,
    required this.onAddBranch,
    required this.onAddService,
    required this.onAddDoctor,
  });

  final Future<void> Function() onReload;
  final VoidCallback onScrollDashboard;
  final VoidCallback onScrollUsers;
  final VoidCallback onScrollApplications;
  final VoidCallback onScrollBranchesInsights;
  final VoidCallback onAddBranch;
  final VoidCallback onAddService;
  final VoidCallback onAddDoctor;

  @override
  ConsumerState<ClinovaAdminPremiumDrawer> createState() =>
      _ClinovaAdminPremiumDrawerState();
}

class _ClinovaAdminPremiumDrawerState
    extends ConsumerState<ClinovaAdminPremiumDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  double _staggerT(int index, int total) {
    final start = index / (total + 2);
    final end = start + 0.45;
    return CurvedAnimation(
      parent: _ac,
      curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    ).value;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user!;
    final path = GoRouterState.of(context).uri.path;

    void popDrawerThen(void Function() fn) {
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        fn();
      });
    }

    void closeThenRoute(void Function(BuildContext c) fn) {
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        fn(context);
      });
    }

    final displayName = user.displayName.isNotEmpty
        ? user.displayName
        : 'Clinova хэрэглэгч';
    final initials = clinovaDrawerAvatarInitials(
      displayName: user.displayName,
      email: user.email,
    );

    final entries =
        <
          ({
            IconData icon,
            String title,
            String? sub,
            bool active,
            bool isRoute,
            String? routePath,
            void Function()? scrollAction,
          })
        >[
          (
            icon: Icons.dashboard_rounded,
            title: 'Dashboard',
            sub: 'KPIs, өнөөдрийн статистик',
            active: path == '/admin',
            isRoute: false,
            routePath: null,
            scrollAction: widget.onScrollDashboard,
          ),
          (
            icon: Icons.event_available_rounded,
            title: 'Appointments',
            sub: 'Цагийн тоо, дууссан үзлэг',
            active: path == '/admin',
            isRoute: false,
            routePath: null,
            scrollAction: widget.onScrollDashboard,
          ),
          (
            icon: Icons.groups_rounded,
            title: 'Patients',
            sub: 'Өвчтөн, хэрэглэгчийн жагсаалт',
            active: path == '/admin',
            isRoute: false,
            routePath: null,
            scrollAction: widget.onScrollUsers,
          ),
          (
            icon: Icons.badge_rounded,
            title: 'Doctors',
            sub: 'Эмчийн тоо, салбарын тойм',
            active: path == '/admin',
            isRoute: false,
            routePath: null,
            scrollAction: widget.onScrollBranchesInsights,
          ),
          (
            icon: Icons.assignment_rounded,
            title: 'Job applications',
            sub: 'Ажлын өргөдөл, статус',
            active: path == '/admin',
            isRoute: false,
            routePath: null,
            scrollAction: widget.onScrollApplications,
          ),
          (
            icon: Icons.auto_awesome_rounded,
            title: 'AI System',
            sub: 'Clinova AI агент',
            active: path == '/agent' || path.startsWith('/agent'),
            isRoute: true,
            routePath: '/agent',
            scrollAction: null,
          ),
          (
            icon: Icons.medical_services_rounded,
            title: 'Services',
            sub: 'Салбар, үйлчилгээний тойм',
            active: path == '/admin',
            isRoute: false,
            routePath: null,
            scrollAction: widget.onScrollBranchesInsights,
          ),
          (
            icon: Icons.chat_bubble_rounded,
            title: 'Messages / Chat',
            sub: 'Чат, мессежийн төв',
            active: path == '/doctor-chat' || path.startsWith('/doctor-chat/'),
            isRoute: true,
            routePath: '/doctor-chat',
            scrollAction: null,
          ),
          (
            icon: Icons.tune_rounded,
            title: 'Settings',
            sub: 'Системийн тохиргоо',
            active: path == '/settings',
            isRoute: true,
            routePath: '/settings',
            scrollAction: null,
          ),
        ];

    final n = entries.length;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: ClinovaPremiumDrawerFrame.drawerWidth(context),
      child: ClinovaPremiumDrawerFrame(
        leadingEdgeRounded: false,
        child: SafeArea(
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.black.withValues(alpha: 0.06),
              highlightColor: Colors.black.withValues(alpha: 0.03),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _ac,
                            curve: const Interval(
                              0,
                              0.35,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: const ClinovaDrawerBrandingHeader(),
                        ),
                      ),
                      const _DrawerDismissChip(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Divider(
                    height: 1,
                    thickness: 0.5,
                    color: _DrawerVisual.hairlineLight,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _ac,
                      curve: const Interval(0.05, 0.4, curve: Curves.easeOut),
                    ),
                    child: ClinovaDrawerUserCard(
                      displayName: displayName,
                      roleLabel: clinovaDrawerRoleLabelMn(user.role),
                      initialsText: initials,
                      email: user.email.isNotEmpty ? user.email : null,
                      avatarUrl: user.avatarUrl,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await widget.onReload();
                      },
                      splashColor: Colors.black.withValues(alpha: 0.05),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _DrawerVisual.hairlineLight,
                            width: 0.5,
                          ),
                          color: _DrawerVisual.rowSurface,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                size: 19,
                                color: ClinovaPremium.primaryInk,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Дахин ачаалах',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: ClinovaPremium.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        ClinovaDrawerMenuItem(
                          icon: entries[i].icon,
                          title: entries[i].title,
                          subtitle: entries[i].sub,
                          isActive: entries[i].active,
                          animationT: _staggerT(i, n),
                          onTap: () {
                            final e = entries[i];
                            if (e.isRoute && e.routePath != null) {
                              final p = e.routePath!;
                              closeThenRoute((c) => c.push(p));
                            } else {
                              final fn = e.scrollAction;
                              if (fn != null) popDrawerThen(fn);
                            }
                          },
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                        child: Text(
                          'Удирдлагын хэрэгсэл',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF344054),
                                letterSpacing: -0.15,
                              ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () =>
                                  popDrawerThen(widget.onAddBranch),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF344054),
                                side: BorderSide(
                                  color: _DrawerVisual.hairlineLight,
                                  width: 0.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                              child: const Text('Салбар нэмэх'),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  popDrawerThen(widget.onAddService),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF344054),
                                side: BorderSide(
                                  color: _DrawerVisual.hairlineLight,
                                  width: 0.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                              child: const Text('Үйлчилгээ нэмэх'),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  popDrawerThen(widget.onAddDoctor),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF344054),
                                side: BorderSide(
                                  color: _DrawerVisual.hairlineLight,
                                  width: 0.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                              child: const Text('Эмч нэмэх'),
                            ),
                          ],
                        ),
                      ),
                      ClinovaDrawerQuickActionCard(
                        primaryLabel: 'Яаралтай тусламж',
                        primaryIcon: Icons.emergency_rounded,
                        onPrimary: () =>
                            closeThenRoute((c) => c.push('/emergency')),
                        secondaryLabel: 'AI асуух',
                        secondaryIcon: Icons.psychology_rounded,
                        onSecondary: () =>
                            closeThenRoute((c) => c.push('/agent')),
                      ),
                    ],
                  ),
                ),
                ClinovaDrawerFooter(
                  versionLabel: 'Clinova v1.0',
                  showLogout: true,
                  onLogout: () {
                    Navigator.of(context).pop();
                    ref.read(authControllerProvider.notifier).logout();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
