import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/media/doctor_avatar_mapper.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/network/clinova_api.dart';
import '../../../core/network/online_presence_provider.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/clinova_circle_avatar.dart';
import '../../../core/widgets/clinova_logo.dart';
import '../../auth/application/auth_controller.dart';

/// Premium consultation hub with live doctor directory.
class DoctorChatLandingScreen extends ConsumerStatefulWidget {
  const DoctorChatLandingScreen({super.key});

  @override
  ConsumerState<DoctorChatLandingScreen> createState() =>
      _DoctorChatLandingScreenState();
}

class _DoctorChatLandingScreenState
    extends ConsumerState<DoctorChatLandingScreen> {
  late Future<List<Map<String, dynamic>>> _doctorsFuture;
  var _futureReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_futureReady) return;
    _futureReady = true;
    _doctorsFuture = ref.read(clinovaApiProvider).getDoctors();
  }

  int _countOnline(
    List<Map<String, dynamic>> doctors,
    Set<String> onlineUserIds,
  ) {
    var n = 0;
    for (final d in doctors) {
      final u = d['user'];
      if (u is Map && u['id'] != null) {
        if (onlineUserIds.contains(u['id'].toString())) n++;
      }
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final onlineIds = ref.watch(onlineUserIdsProvider);
    const primary = Color(0xFF1769FF);
    const navy = Color(0xFF071B4D);

    return Scaffold(
      body: ClinovaBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              const maxW = 1180.0;
              final pad = c.maxWidth >= 900 ? 24.0 : 16.0;
              final wide = c.maxWidth >= 960;

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxW),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _doctorsFuture,
                    builder: (context, snapshot) {
                      final doctors = snapshot.data ?? const [];
                      final onlineN = _countOnline(doctors, onlineIds);
                      final loading = snapshot.connectionState ==
                          ConnectionState.waiting;

                      Widget body() {
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 52,
                                child: _LandingLeftPanel(
                                  l10n: l10n,
                                  theme: theme,
                                  navy: navy,
                                  primary: primary,
                                  auth: auth,
                                  doctorTotal: doctors.length,
                                  onlineDoctors: onlineN,
                                  statsLoading: loading,
                                ),
                              ),
                              const SizedBox(width: 22),
                              Expanded(
                                flex: 48,
                                child: _LandingRightPanel(
                                  l10n: l10n,
                                  theme: theme,
                                  primary: primary,
                                  auth: auth,
                                  doctors: doctors,
                                  onlineIds: onlineIds,
                                  loading: loading,
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _LandingLeftPanel(
                              l10n: l10n,
                              theme: theme,
                              navy: navy,
                              primary: primary,
                              auth: auth,
                              doctorTotal: doctors.length,
                              onlineDoctors: onlineN,
                              statsLoading: loading,
                            ),
                            const SizedBox(height: 20),
                            _LandingRightPanel(
                              l10n: l10n,
                              theme: theme,
                              primary: primary,
                              auth: auth,
                              doctors: doctors,
                              onlineIds: onlineIds,
                              loading: loading,
                            ),
                          ],
                        );
                      }

                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(pad, 12, pad, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton.filledTonal(
                                  onPressed: () => popOrGo(
                                    context,
                                    clinovaNavigationFallback(
                                      isAuthenticated: auth.isAuthenticated,
                                      role: auth.user?.role,
                                    ),
                                  ),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: ClinovaLogo(
                                    size: 36,
                                    variant: LogoVariant.dark,
                                    subtitle: 'AI Healthcare Platform',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            body(),
                          ],
                        ),
                      );
                    },
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

class _LandingLeftPanel extends StatelessWidget {
  const _LandingLeftPanel({
    required this.l10n,
    required this.theme,
    required this.navy,
    required this.primary,
    required this.auth,
    required this.doctorTotal,
    required this.onlineDoctors,
    required this.statsLoading,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final Color navy;
  final Color primary;
  final AuthState auth;
  final int doctorTotal;
  final int onlineDoctors;
  final bool statsLoading;

  @override
  Widget build(BuildContext context) {
    final isMn = l10n.localeName.toLowerCase().startsWith('mn');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.chatLandingTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: navy,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.chatLandingSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF64748B),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        if (statsLoading)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniStatChip(
                icon: Icons.groups_rounded,
                label: isMn ? 'Нийт эмч' : 'Doctors',
                value: '$doctorTotal',
                color: primary,
              ),
              _MiniStatChip(
                icon: Icons.circle,
                label: isMn ? 'Онлайн' : 'Online now',
                value: '$onlineDoctors',
                color: const Color(0xFF16A34A),
              ),
            ],
          ),
        const SizedBox(height: 18),
        _BenefitTile(
          icon: Icons.verified_user_outlined,
          title: isMn ? 'Баталгаажсан эмч нар' : 'Verified clinicians',
          subtitle: l10n.homeCardLiveChatSubtitle,
        ),
        const SizedBox(height: 10),
        _BenefitTile(
          icon: Icons.schedule_rounded,
          title: isMn ? 'Хариу хугацаа' : 'Timely replies',
          subtitle: isMn
              ? 'Идэвхтэй эмч нар ихэвчлэн хурдан хариулдаг.'
              : 'Active doctors usually reply within a few minutes.',
        ),
        const SizedBox(height: 16),
        Card(
          color: const Color(0xFFEFF6FF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.chatLandingSafety,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF0F172A),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: BorderSide(color: primary.withValues(alpha: 0.65)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => context.push('/agent'),
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            label: Text(l10n.homeHeroSecondaryCta),
          ),
        ),
      ],
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  const _MiniStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: t.textTheme.labelSmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1769FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF1769FF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingRightPanel extends StatelessWidget {
  const _LandingRightPanel({
    required this.l10n,
    required this.theme,
    required this.primary,
    required this.auth,
    required this.doctors,
    required this.onlineIds,
    required this.loading,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final Color primary;
  final AuthState auth;
  final List<Map<String, dynamic>> doctors;
  final Set<String> onlineIds;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isMn = l10n.localeName.toLowerCase().startsWith('mn');
    final preview = doctors.length > 9 ? doctors.sublist(0, 9) : doctors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF071B4D), Color(0xFF1769FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x180F172A),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMn ? 'Чат эхлүүлэх' : 'Start a consultation',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isMn
                    ? 'Доорх эмчээс сонгон шууд холбогдоно уу.'
                    : 'Pick a doctor below to chat instantly.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    if (auth.isAuthenticated) {
                      context.push('/doctor-chat');
                    } else {
                      context.push('/auth/login');
                    }
                  },
                  child: Text(
                    auth.isAuthenticated
                        ? l10n.chatLandingStart
                        : l10n.chatLandingLoginToChat,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          isMn ? 'Боломжит эмч нар' : 'Available doctors',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF102A43),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isMn
              ? 'Онлайн төлөв нь хуудас ачаалах үеийнхтэй синхронлогдоно.'
              : 'Online status syncs with the realtime service.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (preview.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              l10n.homeStaffEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              var cross = 1;
              if (c.maxWidth >= 520) cross = 2;
              if (c.maxWidth >= 720) cross = 3;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 132,
                ),
                itemCount: preview.length,
                itemBuilder: (context, i) {
                  final d = preview[i];
                  final id = d['id']?.toString() ?? '';
                  final u = d['user'];
                  final um = u is Map<String, dynamic> ? u : null;
                  final name = um == null
                      ? l10n.homeFallbackDoctor
                      : '${um['firstName'] ?? ''} ${um['lastName'] ?? ''}'
                          .trim();
                  final display = name.isEmpty ? l10n.homeFallbackDoctor : name;
                  final initial = display.isNotEmpty
                      ? String.fromCharCode(display.runes.first).toUpperCase()
                      : '?';
                  final dept =
                      d['department']?['name']?.toString() ?? '';
                  final uid = um?['id']?.toString();
                  final online = uid != null && onlineIds.contains(uid);
                  final rating = d['avgRating'] ?? d['rating'];
                  final stars = rating is num ? rating.toStringAsFixed(1) : null;

                  return Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: id.isEmpty
                          ? null
                          : () => context.push(
                                '/doctor-chat?doctorId=${Uri.encodeComponent(id)}',
                              ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClinovaCircleAvatar(
                                      radius: 22,
                                      initialsText: initial,
                                      backgroundColor:
                                          kClinovaFlatDoctorAvatarBackground,
                                      foregroundColor: const Color(0xFF475569),
                                      doctorUseFlatAssetOnly: true,
                                      doctorDisplayName: display,
                                      doctorGender: doctorGenderFromMap(um),
                                    ),
                                    if (online)
                                      Positioned(
                                        right: -1,
                                        bottom: -1,
                                        child: Container(
                                          width: 11,
                                          height: 11,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF22C55E),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        display,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (dept.isNotEmpty)
                                        Text(
                                          dept,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                if (stars != null)
                                  Text(
                                    '★ $stars',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFF59E0B),
                                    ),
                                  ),
                                const Spacer(),
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 18,
                                  color: primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        if (auth.isAuthenticated)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton(
              onPressed: () => context.push('/doctor-chat'),
              child: Text(l10n.chatLandingViewOnline),
            ),
          ),
      ],
    );
  }
}
