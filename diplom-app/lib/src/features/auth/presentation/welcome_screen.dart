import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/clinova_logo.dart';
import '../../pwa/presentation/install_app_banner.dart';
import 'auth_view_entrance.dart';
import 'widgets/hero_background_video_stub.dart'
    if (dart.library.html) 'widgets/hero_background_video_web.dart';

const _kClinovaAccentBlue = Color(0xFF1769FF);
const _kClinovaNavy = Color(0xFF071B4D);
const _kClinovaTeal = Color(0xFF0EA5A4);

/// Public guest landing — no user-specific data.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _featuresKey = GlobalKey();
  late final AnimationController _intro;

  late final Animation<double> _heroTitleIn;
  late final Animation<double> _heroSubIn;
  late final Animation<double> _heroCtasIn;
  late final Animation<double> _heroTrustIn;
  late final Animation<double> _heroVisualIn;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _heroTitleIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.06, 0.42, curve: Curves.easeOutCubic),
    );
    _heroSubIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.18, 0.52, curve: Curves.easeOutCubic),
    );
    _heroCtasIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.28, 0.62, curve: Curves.easeOutCubic),
    );
    _heroTrustIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.34, 0.72, curve: Curves.easeOutCubic),
    );
    _heroVisualIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.2, 0.75, curve: Curves.easeOutCubic),
    );
    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToFeatures() {
    final ctx = _featuresKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showTrustDialog(AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.welcomeTrustDialogTitle),
        content: Text(l10n.welcomeTrustDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: _WelcomeDrawer(
        l10n: l10n,
        onHome: () {
          Navigator.pop(context);
          _scrollToTop();
        },
        onServices: () {
          Navigator.pop(context);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToFeatures(),
          );
        },
        onDoctors: () {
          Navigator.pop(context);
          context.push('/appointments-landing');
        },
        onAbout: () {
          Navigator.pop(context);
          _showTrustDialog(l10n);
        },
        onLogin: () {
          Navigator.pop(context);
          context.push('/auth/login');
        },
        onRegister: () {
          Navigator.pop(context);
          context.push('/auth/register');
        },
      ),
      body: ClinovaBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final isHeroStacked = constraints.maxWidth < 720;
              final isTablet =
                  constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
              final isDesktop = constraints.maxWidth >= 1024;
              final showDesktopNav = constraints.maxWidth >= 900;
              final showHeroVideo = kIsWeb && !isHeroStacked && !isMobile;
              final horizontalPadding = isMobile
                  ? 20.0
                  : isTablet
                  ? 36.0
                  : 64.0;
              final maxWidth = isMobile
                  ? constraints.maxWidth
                  : isTablet
                  ? 920.0
                  : 1280.0;

              return Scrollbar(
                controller: _scroll,
                thumbVisibility: isDesktop,
                child: SingleChildScrollView(
                  controller: _scroll,
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
                          if (kIsWeb) const PwaWebAutoInstallTrigger(),
                          AuthViewEntrance(
                            delay: Duration.zero,
                            child: _Header(
                              l10n: l10n,
                              showDesktopNav: showDesktopNav,
                              showDrawerTrigger: !showDesktopNav,
                              onOpenDrawer: () =>
                                  _scaffoldKey.currentState?.openDrawer(),
                              onHome: _scrollToTop,
                              onServices: _scrollToFeatures,
                              onDoctors: () =>
                                  context.push('/appointments-landing'),
                              onAbout: () => _showTrustDialog(l10n),
                              onLogin: () => context.push('/auth/login'),
                              onRegister: () => context.push('/auth/register'),
                            ),
                          ),
                          SizedBox(height: isDesktop ? 36 : 20),
                          _HeroSection(
                            l10n: l10n,
                            theme: theme,
                            isStacked: isHeroStacked,
                            isMobile: isMobile,
                            showWebVideo: showHeroVideo,
                            titleIn: _heroTitleIn,
                            subIn: _heroSubIn,
                            ctasIn: _heroCtasIn,
                            trustIn: _heroTrustIn,
                            visualIn: _heroVisualIn,
                            onRegister: () => context.push('/auth/register'),
                            onLogin: () => context.push('/auth/login'),
                            onExplore: _scrollToFeatures,
                          ),
                          SizedBox(height: isDesktop ? 48 : 32),
                          Text(
                            l10n.welcomeSectionFeaturesTitle,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: _kClinovaNavy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 18),
                          KeyedSubtree(
                            key: _featuresKey,
                            child: GridView.count(
                              crossAxisCount: isMobile
                                  ? 1
                                  : (isDesktop ? 4 : 2),
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: isDesktop
                                  ? 1.55
                                  : (isMobile ? 2.55 : 1.9),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _FeatureTile(
                                  icon: Icons.medical_services_outlined,
                                  title: l10n.welcomeFeatureAi,
                                  color: _kClinovaTeal,
                                  onTap: () => context.push('/agent'),
                                ),
                                _FeatureTile(
                                  icon: Icons.groups_2_outlined,
                                  title: l10n.welcomeFeatureChat,
                                  color: _kClinovaAccentBlue,
                                  onTap: () =>
                                      context.push('/appointments-landing'),
                                ),
                                _FeatureTile(
                                  icon: Icons.calendar_month_outlined,
                                  title: l10n.welcomeFeatureAppointments,
                                  color: _kClinovaTeal,
                                  onTap: () =>
                                      context.push('/appointments-landing'),
                                ),
                                _FeatureTile(
                                  icon: Icons.verified_user_outlined,
                                  title: l10n.welcomeFeatureSecureProfile,
                                  color: const Color(0xFF1D4ED8),
                                  onTap: () => _showTrustDialog(l10n),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isMobile ? 32 : 24),
                        ],
                      ),
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

class _WelcomeDrawer extends StatelessWidget {
  const _WelcomeDrawer({
    required this.l10n,
    required this.onHome,
    required this.onServices,
    required this.onDoctors,
    required this.onAbout,
    required this.onLogin,
    required this.onRegister,
  });

  final AppLocalizations l10n;
  final VoidCallback onHome;
  final VoidCallback onServices;
  final VoidCallback onDoctors;
  final VoidCallback onAbout;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: ClinovaLogo(
                size: 48,
                variant: LogoVariant.dark,
                subtitle: l10n.welcomeBrandSubtitle,
              ),
            ),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.home_rounded),
              title: Text(l10n.welcomeNavHome),
              onTap: onHome,
            ),
            ListTile(
              leading: const Icon(Icons.apps_rounded),
              title: Text(l10n.welcomeNavServices),
              onTap: onServices,
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital_outlined),
              title: Text(l10n.welcomeNavDoctors),
              onTap: onDoctors,
            ),
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: Text(l10n.welcomeNavAbout),
              onTap: onAbout,
            ),
            const Divider(height: 32),
            ListTile(
              leading: Icon(
                Icons.login_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(l10n.welcomeLogIn),
              onTap: onLogin,
            ),
            ListTile(
              leading: Icon(
                Icons.person_add_alt_1_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(l10n.welcomeCreateAccount),
              onTap: onRegister,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.l10n,
    required this.showDesktopNav,
    required this.showDrawerTrigger,
    required this.onOpenDrawer,
    required this.onHome,
    required this.onServices,
    required this.onDoctors,
    required this.onAbout,
    required this.onLogin,
    required this.onRegister,
  });

  final AppLocalizations l10n;
  final bool showDesktopNav;
  final bool showDrawerTrigger;
  final VoidCallback onOpenDrawer;
  final VoidCallback onHome;
  final VoidCallback onServices;
  final VoidCallback onDoctors;
  final VoidCallback onAbout;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final navStyle = TextButton.styleFrom(
      foregroundColor: _kClinovaNavy,
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );

    return Row(
      children: [
        if (showDrawerTrigger)
          IconButton.filledTonal(
            onPressed: onOpenDrawer,
            icon: const Icon(Icons.menu_rounded),
          ),
        if (showDrawerTrigger) const SizedBox(width: 6),
        Expanded(
          child: ClinovaLogo(
            size: showDesktopNav ? 52 : 46,
            variant: LogoVariant.dark,
            subtitle: l10n.welcomeBrandSubtitle,
          ),
        ),
        if (showDesktopNav) ...[
          TextButton(
            style: navStyle,
            onPressed: onHome,
            child: Text(l10n.welcomeNavHome),
          ),
          TextButton(
            style: navStyle,
            onPressed: onServices,
            child: Text(l10n.welcomeNavServices),
          ),
          TextButton(
            style: navStyle,
            onPressed: onDoctors,
            child: Text(l10n.welcomeNavDoctors),
          ),
          TextButton(
            style: navStyle,
            onPressed: onAbout,
            child: Text(l10n.welcomeNavAbout),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onLogin, child: Text(l10n.welcomeLogIn)),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onRegister,
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
    required this.titleIn,
    required this.subIn,
    required this.ctasIn,
    required this.trustIn,
    required this.visualIn,
    required this.onRegister,
    required this.onLogin,
    required this.onExplore,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final bool isStacked;
  final bool isMobile;
  final bool showWebVideo;
  final Animation<double> titleIn;
  final Animation<double> subIn;
  final Animation<double> ctasIn;
  final Animation<double> trustIn;
  final Animation<double> visualIn;
  final VoidCallback onRegister;
  final VoidCallback onLogin;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final cardRadius = BorderRadius.circular(isMobile ? 28 : 36);
    final heroPadding = isMobile ? 24.0 : (isStacked ? 32.0 : 48.0);

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
            blurRadius: 48,
            offset: Offset(0, 18),
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
                    isMobile: isMobile,
                    titleIn: titleIn,
                    subIn: subIn,
                    ctasIn: ctasIn,
                    trustIn: trustIn,
                    onRegister: onRegister,
                    onLogin: onLogin,
                    onExplore: onExplore,
                  ),
                  const SizedBox(height: 22),
                  FadeTransition(
                    opacity: visualIn,
                    child: AnimatedBuilder(
                      animation: visualIn,
                      builder: (context, _) {
                        final y = 14 * (1 - visualIn.value.clamp(0.0, 1.0));
                        return Transform.translate(
                          offset: Offset(0, y),
                          child: isMobile
                              ? const _HeroLiteCard()
                              : _HeroVideoCard(
                                  showWebVideo: showWebVideo,
                                  isCompact: true,
                                ),
                        );
                      },
                    ),
                  ),
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
                      titleIn: titleIn,
                      subIn: subIn,
                      ctasIn: ctasIn,
                      trustIn: trustIn,
                      onRegister: onRegister,
                      onLogin: onLogin,
                      onExplore: onExplore,
                    ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: FadeTransition(
                      opacity: visualIn,
                      child: AnimatedBuilder(
                        animation: visualIn,
                        builder: (context, _) {
                          final y = 18 * (1 - visualIn.value.clamp(0.0, 1.0));
                          return Transform.translate(
                            offset: Offset(0, y),
                            child: _HeroVideoCard(showWebVideo: showWebVideo),
                          );
                        },
                      ),
                    ),
                  ),
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
    required this.titleIn,
    required this.subIn,
    required this.ctasIn,
    required this.trustIn,
    required this.onRegister,
    required this.onLogin,
    required this.onExplore,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final bool isMobile;
  final Animation<double> titleIn;
  final Animation<double> subIn;
  final Animation<double> ctasIn;
  final Animation<double> trustIn;
  final VoidCallback onRegister;
  final VoidCallback onLogin;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final titleSize = isMobile ? 30.0 : 44.0;
    final subtitleSize = isMobile ? 16.0 : 18.0;

    Widget ctaFilled({required VoidCallback onPressed, required String label}) {
      return SizedBox(
        height: 54,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _kClinovaAccentBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      );
    }

    Widget ctaOutlined({
      required VoidCallback onPressed,
      required String label,
    }) {
      return SizedBox(
        height: 54,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      );
    }

    Widget ctaGhost({required VoidCallback onPressed, required String label}) {
      return SizedBox(
        height: 50,
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.92),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeTransition(
          opacity: titleIn,
          child: Text(
            l10n.welcomeHeroHeadline,
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: titleSize,
              height: 1.12,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 14),
        FadeTransition(
          opacity: subIn,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              l10n.welcomeHeroSub,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: subtitleSize,
                height: 1.45,
              ),
            ),
          ),
        ),
        SizedBox(height: isMobile ? 18 : 22),
        FadeTransition(
          opacity: ctasIn,
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ctaFilled(
                      onPressed: onRegister,
                      label: l10n.welcomeCreateAccount,
                    ),
                    const SizedBox(height: 12),
                    ctaOutlined(onPressed: onLogin, label: l10n.welcomeLogIn),
                    const SizedBox(height: 6),
                    ctaGhost(
                      onPressed: onExplore,
                      label: l10n.welcomeCtaExploreServices,
                    ),
                  ],
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 210,
                      child: ctaFilled(
                        onPressed: onRegister,
                        label: l10n.welcomeCreateAccount,
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: ctaOutlined(
                        onPressed: onLogin,
                        label: l10n.welcomeLogIn,
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: ctaGhost(
                        onPressed: onExplore,
                        label: l10n.welcomeCtaExploreServices,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        FadeTransition(
          opacity: trustIn,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TrustBadge(
                text: l10n.welcomeTrustAiAssist,
                icon: Icons.auto_awesome_rounded,
                color: const Color(0xFF38BDF8),
              ),
              _TrustBadge(
                text: l10n.welcomeTrustRealtimeBooking,
                icon: Icons.bolt_rounded,
                color: _kClinovaTeal,
              ),
              _TrustBadge(
                text: l10n.welcomeTrustSecureRegistration,
                icon: Icons.verified_outlined,
                color: const Color(0xFF93C5FD),
              ),
              _TrustBadge(
                text: l10n.welcomeTrustDoctorChat,
                icon: Icons.chat_bubble_outline_rounded,
                color: const Color(0xFF5EEAD4),
              ),
            ],
          ),
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
          child: Icon(icon, size: 18, color: _kClinovaAccentBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _kClinovaNavy,
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
                    : Icon(icon, size: 15, color: _kClinovaAccentBlue),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _kClinovaNavy,
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
    return Material(
      color: Colors.transparent,
      child: Container(
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _kClinovaNavy,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
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
