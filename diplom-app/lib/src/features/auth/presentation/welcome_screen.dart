import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/clinova_logo.dart';
import 'widgets/hero_background_video_stub.dart'
    if (dart.library.html) 'widgets/hero_background_video_web.dart';

/// Public guest landing — no user-specific data.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _primaryBlue = Color(0xFF1769FF);
  static const _navy = Color(0xFF071B4D);
  static const _teal = Color(0xFF0EA5A4);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      body: ClinovaBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final isHeroStacked = constraints.maxWidth < 700;
              final isTablet =
                  constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
              final isDesktop = constraints.maxWidth >= 1024;
              // Mobile performance: hero video is disabled to avoid simulator lag.
              final showHeroVideo = kIsWeb && !isHeroStacked && !isMobile;
              final horizontalPadding = isMobile
                  ? 20.0
                  : isTablet
                  ? 32.0
                  : 56.0;
              final maxWidth = isMobile
                  ? constraints.maxWidth
                  : isTablet
                  ? 760.0
                  : 1180.0;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isMobile ? 16 : 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth,
                      minHeight: constraints.maxHeight - 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(isDesktop: isDesktop, l10n: l10n),
                        SizedBox(height: isDesktop ? 34 : 20),
                        _HeroSection(
                          l10n: l10n,
                          theme: theme,
                          isStacked: isHeroStacked,
                          isMobile: isMobile,
                          showWebVideo: showHeroVideo,
                          onRegister: () => context.push('/auth/register'),
                          onLogin: () => context.push('/auth/login'),
                        ),
                        SizedBox(height: isDesktop ? 42 : 30),
                        Text(
                          'Explore',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: _navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: isMobile ? 1 : (isDesktop ? 4 : 2),
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: isDesktop
                              ? 1.5
                              : (isMobile ? 2.5 : 1.85),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _FeatureTile(
                              icon: Icons.health_and_safety_outlined,
                              title: l10n.welcomeFeatureAi,
                              color: _teal,
                              onTap: () => context.push('/agent'),
                            ),
                            _FeatureTile(
                              icon: Icons.calendar_month_outlined,
                              title: l10n.welcomeFeatureAppointments,
                              color: _primaryBlue,
                              onTap: () =>
                                  context.push('/appointments-landing'),
                            ),
                            _FeatureTile(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: l10n.welcomeFeatureChat,
                              color: _teal,
                              onTap: () => context.push('/chat-landing'),
                            ),
                            _FeatureTile(
                              icon: Icons.emergency_outlined,
                              title: l10n.welcomeFeatureEmergency,
                              color: const Color(0xFFEF4444),
                              onTap: () {
                                showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(l10n.welcomeFeatureEmergency),
                                    content: Text(l10n.chatLandingSafety),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: isMobile ? 30 : 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isDesktop, required this.l10n});

  final bool isDesktop;
  final dynamic l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ClinovaLogo(
          size: 52,
          variant: LogoVariant.dark,
          subtitle: 'AI Healthcare Platform',
        ),
        if (isDesktop) const Spacer() else const Spacer(),
        if (isDesktop) ...[
          OutlinedButton(
            onPressed: () => context.push('/auth/login'),
            child: Text(l10n.welcomeLogIn),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: () => context.push('/auth/register'),
            child: Text(l10n.welcomeCreateAccount),
          ),
        ],
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.l10n,
    required this.theme,
    required this.isStacked,
    required this.isMobile,
    required this.showWebVideo,
    required this.onRegister,
    required this.onLogin,
  });

  final dynamic l10n;
  final ThemeData theme;
  final bool isStacked;
  final bool isMobile;
  final bool showWebVideo;
  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final cardRadius = BorderRadius.circular(isMobile ? 28 : 32);
    final heroPadding = isMobile ? 24.0 : (isStacked ? 36.0 : 52.0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: cardRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF061D52), Color(0xFF0A3D91), Color(0xFF0B5FA8)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26071B4D),
            blurRadius: 42,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(heroPadding),
        child: isStacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroContent(
                    l10n: l10n,
                    theme: theme,
                    isMobile: true,
                    onRegister: onRegister,
                    onLogin: onLogin,
                  ),
                  const SizedBox(height: 22),
                  if (isMobile)
                    const _HeroLiteCard()
                  else
                    _HeroVideoCard(showWebVideo: showWebVideo, isCompact: true),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _HeroContent(
                      l10n: l10n,
                      theme: theme,
                      isMobile: false,
                      onRegister: onRegister,
                      onLogin: onLogin,
                    ),
                  ),
                  const SizedBox(width: 30),
                  Expanded(child: _HeroVideoCard(showWebVideo: showWebVideo)),
                ],
              ),
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({
    required this.l10n,
    required this.theme,
    required this.isMobile,
    required this.onRegister,
    required this.onLogin,
  });

  final dynamic l10n;
  final ThemeData theme;
  final bool isMobile;
  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final titleSize = isMobile ? 34.0 : 52.0;
    final subtitleSize = isMobile ? 16.0 : 19.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ClinovaLogo(
          size: 52,
          variant: LogoVariant.glass,
          subtitle: 'AI Healthcare Platform',
        ),
        const SizedBox(height: 20),
        Text(
          'Таны эрүүл мэнд.\nБидний тэргүүлэх зорилт.',
          style: theme.textTheme.displaySmall?.copyWith(
            fontSize: titleSize,
            height: 1.1,
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Цаг захиалах, шинж тэмдэг шалгах, найдвартай эмч нартай холбогдох бүгдийг нэг апп-д.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: subtitleSize,
              height: 1.42,
            ),
          ),
        ),
        const SizedBox(height: 22),
        if (isMobile)
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: WelcomeScreen._primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: onRegister,
                  child: Text(l10n.welcomeCreateAccount),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: onLogin,
                  child: Text(l10n.welcomeLogIn),
                ),
              ),
            ],
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 228,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: WelcomeScreen._primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: onRegister,
                  child: Text(l10n.welcomeCreateAccount),
                ),
              ),
              SizedBox(
                width: 220,
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: onLogin,
                  child: Text(l10n.welcomeLogIn),
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _TrustBadge(
              text: 'Илүү аюулгүй',
              icon: Icons.verified_user_outlined,
              color: WelcomeScreen._teal,
            ),
            _TrustBadge(
              text: 'AI туслахтай',
              icon: Icons.auto_awesome_rounded,
              color: Color(0xFF0EA5E9),
            ),
            _TrustBadge(
              text: 'Цаг захиалга real-time',
              icon: Icons.bolt_rounded,
              color: Color(0xFF0EA5A4),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroVideoCard extends StatelessWidget {
  const _HeroVideoCard({required this.showWebVideo, this.isCompact = false});

  final bool showWebVideo;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isCompact ? 290 : 430,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2600023A),
                      blurRadius: 28,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (showWebVideo)
                      const HeroBackgroundVideo(
                        assetPath: 'assets/videos/clinova_hero_bg.webm',
                        posterPath: 'assets/images/clinova_hero_poster.jpg',
                      )
                    else
                      Image.asset(
                        'assets/images/clinova_hero_poster.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF0F4C81),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.local_hospital_rounded,
                            size: isCompact ? 64 : 88,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0x330EA5E9), Color(0x4D1D4ED8)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: _FloatingInfoCard(
              title: 'AI шинжилгээ',
              subtitle: 'Шинж тэмдэг шалгах боломжтой',
              icon: Icons.local_hospital_rounded,
              useLogoMark: true,
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: _FloatingInfoCard(
              title: 'Өнөөдрийн боломжит цаг',
              subtitle: '09:30 • Дотрын эмч',
              icon: Icons.calendar_month_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroLiteCard extends StatelessWidget {
  const _HeroLiteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9E8FF)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MiniLine(
            icon: Icons.health_and_safety_outlined,
            title: 'AI шинжилгээ',
            subtitle: 'Шинж тэмдэг шалгалт хурдан',
          ),
          SizedBox(height: 10),
          _MiniLine(
            icon: Icons.calendar_today_rounded,
            title: 'Цаг захиалга',
            subtitle: 'Real-time сул цаг харах',
          ),
          SizedBox(height: 10),
          _MiniLine(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Эмчтэй чат',
            subtitle: 'Шууд чат, зөвлөгөө авах',
          ),
        ],
      ),
    );
  }
}

class _MiniLine extends StatelessWidget {
  const _MiniLine({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: WelcomeScreen._primaryBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: WelcomeScreen._navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FloatingInfoCard extends StatelessWidget {
  const _FloatingInfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.useLogoMark = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool useLogoMark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EEF8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: useLogoMark
                    ? const ClinovaLogo(
                        size: 16,
                        showText: false,
                        responsive: false,
                        variant: LogoVariant.dark,
                      )
                    : Icon(
                        icon,
                        size: 15,
                        color: WelcomeScreen._primaryBlue,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: WelcomeScreen._navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6EEF8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: WelcomeScreen._navy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE6EEF8)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF071B4D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
