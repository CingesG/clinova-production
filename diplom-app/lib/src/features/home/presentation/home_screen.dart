import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/media/doctor_avatar_mapper.dart';
import '../../../core/network/clinova_api.dart';
import '../../../core/network/online_presence_provider.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/clinova_circle_avatar.dart';
import '../../../core/widgets/clinova_logo.dart';
import '../../auth/application/auth_controller.dart';
import 'patient_desktop_nav_bar.dart';

/// Shared layout rhythm for the patient home dashboard (centered ~1360).
class _HomeLayout {
  _HomeLayout._();

  static const double sectionGap = 22;
  static const double blockGap = 12;
  static const double cardRadius = 18;

  static BorderRadius get radiusCard => BorderRadius.circular(cardRadius);

  static double paddingH(double screenWidth) {
    if (screenWidth >= 1200) return 28;
    if (screenWidth >= 900) return 22;
    return 16;
  }
}

String? _findDepartmentIdByKeywords(
  List<Map<String, dynamic>> departments,
  List<String> keywords,
) {
  for (final d in departments) {
    final name = (d['name'] ?? '').toString().toLowerCase();
    if (keywords.any((k) => name.contains(k.toLowerCase()))) {
      return d['id'].toString();
    }
  }
  return null;
}

String _userFullName(Map<String, dynamic>? user) {
  if (user == null) return '';
  return '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
}

String _appointmentDoctorName(Map<String, dynamic> ap) {
  final doctor = ap['doctor'];
  if (doctor is! Map<String, dynamic>) return '';
  final u = doctor['user'];
  if (u is! Map<String, dynamic>) return '';
  return _userFullName(u);
}

void _goAppointments(BuildContext context, Map<String, String?> queryMap) {
  final q = <String, String>{};
  for (final e in queryMap.entries) {
    final v = e.value?.trim();
    if (v != null && v.isNotEmpty) q[e.key] = v;
  }
  context.push(
    Uri(
      path: '/appointments/book',
      queryParameters: q.isEmpty ? null : q,
    ).toString(),
  );
}

Future<void> _homeOpenDoctorChatFlow(
  BuildContext context,
  WidgetRef ref, {
  required String doctorId,
  required bool patientAuthed,
  required Map<String, Map<String, dynamic>> chatPermissionByDoctor,
}) async {
  if (doctorId.isEmpty) return;
  if (!patientAuthed) {
    if (context.mounted) await context.push('/auth/login');
    return;
  }
  final f = chatPermissionByDoctor[doctorId];
  final canChat = f?['canChat'] == true;
  final pending = f?['pendingRequest'] == true;
  if (canChat) {
    if (context.mounted) {
      context.push(
        '/doctor-chat?doctorId=${Uri.encodeComponent(doctorId)}',
      );
    }
    return;
  }
  if (pending) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Таны чат хүсэлт хүлээгдэж байна.'),
        ),
      );
    }
    return;
  }
  final note = TextEditingController();
  final submitted = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Чат хүсэлт илгээх'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Эмч танд зөвшөөрөл өгөх хүртэл шууд чат нээгдэхгүй.',
            style: TextStyle(height: 1.35),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Шалтгаан (заавал биш)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Болих'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Илгээх'),
        ),
      ],
    ),
  );
  if (submitted == true && context.mounted) {
    try {
      await ref.read(clinovaApiProvider).createDoctorChatRequest(
            doctorProfileId: doctorId,
            note: note.text.trim().isEmpty ? null : note.text.trim(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Чат хүсэлт илгээгдлээ.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }
  note.dispose();
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey _doctorsSectionKey = GlobalKey();

  Future<List<dynamic>>? _homeBootstrapFuture;
  String? _homeBootstrapCacheKey;

  Future<List<dynamic>> _ensureHomeBootstrap({
    required String today,
    required bool isAuthed,
    required String? userId,
    required String? role,
  }) {
    final cacheKey = '$today|$isAuthed|${role ?? ''}|${userId ?? ''}';
    if (_homeBootstrapFuture != null && _homeBootstrapCacheKey == cacheKey) {
      return _homeBootstrapFuture!;
    }
    _homeBootstrapCacheKey = cacheKey;
    final api = ref.read(clinovaApiProvider);
    _homeBootstrapFuture = () async {
      final base = await Future.wait<dynamic>([
        isAuthed && role == 'PATIENT'
            ? api.getPatientDashboard()
            : Future<Map<String, dynamic>>.value(const <String, dynamic>{}),
        api.getAvailableSlots(date: today),
        api.getDepartments(),
        api.getBranches(),
        api.getDoctors(),
      ]);
      Map<String, Map<String, dynamic>> flags = {};
      if (isAuthed && role == 'PATIENT' && base.length > 4) {
        final doctorsList = base[4] as List<Map<String, dynamic>>;
        final ids = doctorsList
            .take(16)
            .map((d) => d['id']?.toString() ?? '')
            .where((x) => x.isNotEmpty)
            .toList();
        if (ids.isNotEmpty) {
          try {
            flags = await api.getChatPermissionFlags(doctorIds: ids);
          } catch (_) {}
        }
      }
      return [...base, flags];
    }();
    return _homeBootstrapFuture!;
  }

  void _scrollToDoctors() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _doctorsSectionKey.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
    });
  }

  void _reloadHomeBootstrap() {
    if (!mounted) return;
    setState(() {
      _homeBootstrapFuture = null;
      _homeBootstrapCacheKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final isAuthed = authState.isAuthenticated;
    final screenW = MediaQuery.sizeOf(context).width;
    final isDesktop = PatientDesktopContainer.isDesktopWidth(screenW);
    final showDockSpace = isAuthed && user?.role == 'PATIENT' && !isDesktop;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      endDrawer: isDesktop ? null : const _HomeDrawer(),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: theme.colorScheme.surface.withValues(
                alpha: 0.78,
              ),
              surfaceTintColor: Colors.transparent,
              centerTitle: false,
              leadingWidth: 148,
              leading: const Padding(
                padding: EdgeInsets.only(left: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ClinovaLogo(size: 46, variant: LogoVariant.dark),
                ),
              ),
              actions: [
                Builder(
                  builder: (ctx) => IconButton(
                    tooltip: l10n.homeMenuTitle,
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                  ),
                ),
              ],
            ),
      body: ClinovaBackdrop(
        child: SafeArea(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: FutureBuilder<List<dynamic>>(
                  future: _ensureHomeBootstrap(
                    today: today,
                    isAuthed: isAuthed,
                    userId: user?.id,
                    role: user?.role,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Нүүр хуудас ачааллахад алдаа гарлаа.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _reloadHomeBootstrap,
                                child: Text(l10n.branchesRetry),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final dashboard =
                        snapshot.hasData && snapshot.data!.isNotEmpty
                        ? snapshot.data![0] as Map<String, dynamic>
                        : const <String, dynamic>{};
                    final slots = snapshot.hasData && snapshot.data!.length > 1
                        ? snapshot.data![1] as List<Map<String, dynamic>>
                        : const <Map<String, dynamic>>[];
                    final departments =
                        snapshot.hasData && snapshot.data!.length > 2
                        ? snapshot.data![2] as List<Map<String, dynamic>>
                        : const <Map<String, dynamic>>[];
                    final branchesList =
                        snapshot.hasData && snapshot.data!.length > 3
                        ? snapshot.data![3] as List<Map<String, dynamic>>
                        : const <Map<String, dynamic>>[];
                    final doctorsList =
                        snapshot.hasData && snapshot.data!.length > 4
                        ? snapshot.data![4] as List<Map<String, dynamic>>
                        : const <Map<String, dynamic>>[];
                    final chatPermissionByDoctor =
                        snapshot.hasData && snapshot.data!.length > 5
                        ? snapshot.data![5] as Map<String, Map<String, dynamic>>
                        : const <String, Map<String, dynamic>>{};
                    final myChatDoctorsRaw =
                        (dashboard['myChatDoctors'] as List?)
                            ?.cast<Map<String, dynamic>>() ??
                        const <Map<String, dynamic>>[];
                    final entDeptId = _findDepartmentIdByKeywords(departments, [
                      'ent',
                    ]);
                    final pedDeptId = _findDepartmentIdByKeywords(departments, [
                      'pediatric',
                    ]);
                    final dermDeptId = _findDepartmentIdByKeywords(
                      departments,
                      ['dermatolog'],
                    );
                    final gynDeptId = _findDepartmentIdByKeywords(departments, [
                      'gynec',
                      'women',
                      'obstetr',
                    ]);
                    final upcomingAppointments =
                        (dashboard['upcomingAppointments'] as List?)
                            ?.cast<Map<String, dynamic>>() ??
                        const [];
                    final profileCompletion =
                        dashboard['profileCompletion']?.toString() ?? '0';

                    final slotDoctorIds = slots
                        .map((s) => s['doctorId']?.toString())
                        .whereType<String>()
                        .toSet();
                    final onlineIds = ref.watch(onlineUserIdsProvider);

                    final myDoctorsById = <String, Map<String, dynamic>>{};
                    final myDoctorStatus = <String, String>{};
                    if (isAuthed && user?.role == 'PATIENT') {
                      if (myChatDoctorsRaw.isNotEmpty) {
                        for (final row in myChatDoctorsRaw) {
                          final doc = row['doctor'];
                          if (doc is! Map<String, dynamic>) continue;
                          final did = doc['id']?.toString() ?? '';
                          if (did.isEmpty) continue;
                          myDoctorsById[did] = doc;
                          myDoctorStatus[did] =
                              row['appointmentStatusLabel']?.toString() ?? '—';
                        }
                      } else {
                        final pastAp =
                            (dashboard['appointmentHistory'] as List?)
                                ?.cast<Map<String, dynamic>>() ??
                            const <Map<String, dynamic>>[];
                        for (final ap in [
                          ...upcomingAppointments,
                          ...pastAp,
                        ]) {
                          final st = (ap['status'] ?? '')
                              .toString()
                              .toUpperCase();
                          if (st == 'CANCELLED') continue;
                          final doc = ap['doctor'];
                          if (doc is! Map<String, dynamic>) continue;
                          final did = doc['id']?.toString() ?? '';
                          if (did.isEmpty) continue;
                          myDoctorsById[did] = doc;
                          myDoctorStatus[did] =
                              ap['status']?.toString() ?? st;
                        }
                      }
                    }

                    final padH = _HomeLayout.paddingH(screenW);
                    final nextAppointment = upcomingAppointments.isNotEmpty
                        ? upcomingAppointments.first
                        : null;

                    return CustomScrollView(
                      primary: true,
                      slivers: [
                        if (isDesktop)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(padH, 8, padH, 8),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: PatientDesktopContainer.maxWidth,
                                  ),
                                  child: PatientDesktopNavBar(
                                    isAuthenticated: isAuthed,
                                    onScrollToDoctors: _scrollToDoctors,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            padH,
                            isDesktop ? 8 : 8,
                            padH,
                            showDockSpace ? 152 : (isDesktop ? 72 : 112),
                          ),
                          sliver: SliverList.list(
                            children: [
                              PatientDesktopContainer(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _HeroPanel(
                                      isWide: isDesktop,
                                      isAuthed: isAuthed,
                                      upcomingCount: upcomingAppointments.length
                                          .toString(),
                                      profileCompletion: '$profileCompletion%',
                                      nextAppointment: nextAppointment,
                                      onBook: () =>
                                          context.push('/appointments/book'),
                                      onAi: () => context.push('/agent'),
                                    ),
                                    const SizedBox(height: _HomeLayout.blockGap),
                                    RepaintBoundary(
                                      child: _HomeQuickActions(
                                        screenWidth: screenW,
                                        l10n: l10n,
                                        theme: theme,
                                      ),
                                    ),
                                    const SizedBox(height: _HomeLayout.sectionGap),
                                    _HomeDepartmentStrip(
                                      l10n: l10n,
                                      entDeptId: entDeptId,
                                      pedDeptId: pedDeptId,
                                      dermDeptId: dermDeptId,
                                      gynDeptId: gynDeptId,
                                    ),
                                    const SizedBox(height: _HomeLayout.sectionGap),
                                    if (isAuthed && user?.role == 'PATIENT')
                                      _PatientHealthSection(
                                        l10n: l10n,
                                        theme: theme,
                                        dashboard: dashboard,
                                        profileCompletionRaw: profileCompletion,
                                      ),
                                    if (isAuthed && user?.role == 'PATIENT')
                                      const SizedBox(height: _HomeLayout.sectionGap),
                                    if (isAuthed &&
                                        user?.role == 'PATIENT' &&
                                        myDoctorsById.isNotEmpty)
                                      _MyDoctorsSection(
                                        l10n: l10n,
                                        theme: theme,
                                        doctorsById: myDoctorsById,
                                        statusById: myDoctorStatus,
                                      ),
                                    if (isAuthed &&
                                        user?.role == 'PATIENT' &&
                                        myDoctorsById.isNotEmpty)
                                      const SizedBox(height: _HomeLayout.sectionGap),
                                    RepaintBoundary(
                                      child: _HomeAiPromoSection(
                                        l10n: l10n,
                                        theme: theme,
                                      ),
                                    ),
                                    const SizedBox(height: _HomeLayout.sectionGap),
                                    _SectionHeader(
                                      title: l10n.homeTodayTitle,
                                      subtitle: l10n.homeTodaySubtitle,
                                    ),
                                    const SizedBox(height: _HomeLayout.blockGap),
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting)
                                      const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(20),
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    else if (slots.isEmpty)
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.92,
                                          ),
                                          borderRadius: _HomeLayout.radiusCard,
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x080F172A),
                                              blurRadius: 14,
                                              offset: Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Text(l10n.homeNoSlotsToday),
                                      )
                                    else
                                      ...slots.take(3).map((slot) {
                                        final start = DateTime.tryParse(
                                          slot['startsAt']?.toString() ?? '',
                                        );
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: _AvailabilityCard(
                                            doctor:
                                                slot['doctorName']
                                                    ?.toString() ??
                                                l10n.homeFallbackDoctor,
                                            specialty:
                                                slot['departmentName']
                                                    ?.toString() ??
                                                l10n.homeFallbackDepartment,
                                            branch:
                                                slot['branchName']
                                                    ?.toString() ??
                                                l10n.homeFallbackBranch,
                                            slot: start != null
                                                ? DateFormat(
                                                    'HH:mm',
                                                  ).format(start)
                                                : '--:--',
                                            accent: const Color(0xFF0F766E),
                                            branchId: slot['branchId']
                                                ?.toString(),
                                            departmentId: slot['departmentId']
                                                ?.toString(),
                                            serviceId: slot['serviceId']
                                                ?.toString(),
                                            doctorId: slot['doctorId']
                                                ?.toString(),
                                          ),
                                        );
                                      }),
                                    const SizedBox(height: _HomeLayout.sectionGap),
                                    RepaintBoundary(
                                      child: _StaffPreviewSection(
                                        key: _doctorsSectionKey,
                                        l10n: l10n,
                                        theme: theme,
                                        doctors: doctorsList,
                                        onlineUserIds: onlineIds,
                                        todayDoctorIds: slotDoctorIds,
                                        patientAuthed:
                                            isAuthed && user?.role == 'PATIENT',
                                        chatPermissionByDoctor:
                                            chatPermissionByDoctor,
                                      ),
                                    ),
                                    const SizedBox(height: _HomeLayout.sectionGap),
                                    RepaintBoundary(
                                      child: _BranchesPreviewSection(
                                        l10n: l10n,
                                        theme: theme,
                                        branches: branchesList,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (!isDesktop)
                Positioned(
                  right: 20,
                  bottom: showDockSpace ? 36 : 24,
                  child: const _HomeAiAgentFab(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions({
    required this.screenWidth,
    required this.l10n,
    required this.theme,
  });

  final double screenWidth;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final items = <_QuickActionSpec>[
      _QuickActionSpec(
        icon: Icons.calendar_month_rounded,
        title: l10n.homeBookNow,
        subtitle: l10n.homeCardBookVisitSubtitle,
        accent: const Color(0xFF0D9488),
        onTap: () => context.push('/appointments/book'),
      ),
      _QuickActionSpec(
        icon: Icons.chat_bubble_outline_rounded,
        title: l10n.homeCardLiveChatTitle,
        subtitle: l10n.homeCardLiveChatSubtitle,
        accent: const Color(0xFF1769FF),
        onTap: () => context.push('/chat-landing'),
      ),
      _QuickActionSpec(
        icon: Icons.auto_awesome_rounded,
        title: l10n.homeHeroSecondaryCta,
        subtitle: l10n.homeCardAskAiSubtitle,
        accent: const Color(0xFF7C3AED),
        onTap: () => context.push('/agent'),
      ),
      _QuickActionSpec(
        icon: Icons.health_and_safety_rounded,
        title: l10n.welcomeFeatureEmergency,
        subtitle: l10n.emergencyIntakeSubtitle,
        accent: const Color(0xFFDC2626),
        onTap: () => context.push('/emergency'),
      ),
    ];

    final isDesktop = screenWidth >= 900;
    final useHScroll = screenWidth < 600;

    Widget card(_QuickActionSpec s) {
      return _QuickActionCard(spec: s, theme: theme);
    }

    if (useHScroll) {
      return SizedBox(
        height: 118,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, i) => SizedBox(
            width: 168,
            child: card(items[i]),
          ),
        ),
      );
    }

    if (isDesktop) {
      return Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: card(items[i])),
          ],
        ],
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.15,
      children: items.map(card).toList(),
    );
  }
}

class _QuickActionSpec {
  const _QuickActionSpec({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.spec, required this.theme});

  final _QuickActionSpec spec;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: _HomeLayout.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: spec.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: _HomeLayout.radiusCard,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: spec.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(spec.icon, color: spec.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        spec.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF102A43),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        spec.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.55,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeDepartmentStrip extends StatelessWidget {
  const _HomeDepartmentStrip({
    required this.l10n,
    required this.entDeptId,
    required this.pedDeptId,
    required this.dermDeptId,
    required this.gynDeptId,
  });

  final AppLocalizations l10n;
  final String? entDeptId;
  final String? pedDeptId;
  final String? dermDeptId;
  final String? gynDeptId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homeMoveFasterTitle,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF102A43),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.homeMoveFasterSubtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterPill(
                label: l10n.homeFilterEnt,
                icon: Icons.hearing_rounded,
                onTap: () => _goAppointments(
                  context,
                  entDeptId != null ? {'departmentId': entDeptId!} : {},
                ),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: l10n.homeFilterPediatrics,
                icon: Icons.child_friendly_rounded,
                onTap: () => _goAppointments(
                  context,
                  pedDeptId != null ? {'departmentId': pedDeptId!} : {},
                ),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: l10n.homeFilterDermatology,
                icon: Icons.spa_rounded,
                onTap: () => _goAppointments(
                  context,
                  dermDeptId != null ? {'departmentId': dermDeptId!} : {},
                ),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: l10n.homeFilterWomensCare,
                icon: Icons.favorite_rounded,
                onTap: () => _goAppointments(
                  context,
                  gynDeptId != null ? {'departmentId': gynDeptId!} : {},
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeAiPromoSection extends StatelessWidget {
  const _HomeAiPromoSection({required this.l10n, required this.theme});

  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/agent'),
        borderRadius: _HomeLayout.radiusCard,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: _HomeLayout.radiusCard,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF071B4D), Color(0xFF1769FF)],
              stops: [0.0, 1.0],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeCardAskAiTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.homeCardAskAiSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => context.push('/agent'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1769FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(l10n.homeAskAi),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Home only — дарахад Clinova AI (`/agent`). Доод навигацаас зайтай, баруун доод.
class _HomeAiAgentFab extends StatelessWidget {
  const _HomeAiAgentFab();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: 'Clinova AI',
      child: Tooltip(
        message: '${l10n.aiTitle} · ${l10n.homeDrawerAgent}',
        child: Material(
          elevation: 10,
          shadowColor: const Color(0x400F172A),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/agent'),
            child: Ink(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF071B4D), Color(0xFF1769FF)],
                ),
              ),
              child: const SizedBox(
                width: 58,
                height: 58,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PatientHealthSection extends StatelessWidget {
  const _PatientHealthSection({
    required this.l10n,
    required this.theme,
    required this.dashboard,
    required this.profileCompletionRaw,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final Map<String, dynamic> dashboard;
  final String profileCompletionRaw;

  static String _visitOneLiner(Map<String, dynamic> ap) {
    final svc = ap['service']?['name']?.toString() ?? '';
    final dt = ap['startsAt']?.toString() ?? '';
    final st = DateTime.tryParse(dt);
    final when = st != null ? DateFormat.yMMMd().format(st) : dt;
    final dname = _appointmentDoctorName(ap);
    final bits = <String>[
      if (when.isNotEmpty) when,
      if (svc.isNotEmpty) svc,
      if (dname.isNotEmpty) dname,
    ];
    return bits.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final summary = dashboard['medicalHistorySummary']?.toString().trim();
    final records =
        (dashboard['recentMedicalRecords'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final past =
        (dashboard['appointmentHistory'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final upcoming =
        (dashboard['upcomingAppointments'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];

    final hasContent =
        (summary != null && summary.isNotEmpty) ||
        records.isNotEmpty ||
        past.isNotEmpty ||
        upcoming.isNotEmpty;

    final profilePct = int.tryParse(
          profileCompletionRaw.replaceAll('%', '').trim(),
        )?.clamp(0, 100) ??
        0;

    final lastLine =
        past.isNotEmpty ? _visitOneLiner(past.first) : '';
    final nextLine =
        upcoming.isNotEmpty ? _visitOneLiner(upcoming.first) : '';

    Widget miniCard({
      required IconData icon,
      required String title,
      required String body,
      Color? iconColor,
      Widget? footer,
    }) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor ?? cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body.isEmpty ? '—' : body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
            if (footer != null) ...[const SizedBox(height: 8), footer],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 720;
        final grid = <Widget>[
          miniCard(
            icon: Icons.history_rounded,
            title: l10n.homePastVisitsTitle,
            body: lastLine,
          ),
          miniCard(
            icon: Icons.event_available_rounded,
            title: l10n.homeMetricUpcoming,
            body: nextLine,
          ),
          miniCard(
            icon: Icons.person_outline_rounded,
            title: l10n.homeMetricProfile,
            body: '$profilePct%',
            footer: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: profilePct / 100,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                color: cs.primary,
              ),
            ),
          ),
          Material(
            color: cs.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/chat-landing'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 20,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.homeCardLiveChatTitle,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.homeCardLiveChatSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ];

        final topGrid = wide
            ? Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: grid[0]),
                      const SizedBox(width: 12),
                      Expanded(child: grid[1]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: grid[2]),
                      const SizedBox(width: 12),
                      Expanded(child: grid[3]),
                    ],
                  ),
                ],
              )
            : Column(
                children: [
                  for (var i = 0; i < grid.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    grid[i],
                  ],
                ],
              );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: _HomeLayout.radiusCard,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite_rounded, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.homeYourCareTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.homeYourCareSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              topGrid,
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push('/agent'),
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1769FF).withValues(alpha: 0.35)),
                      color: const Color(0xFF1769FF).withValues(alpha: 0.06),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF1769FF),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.homeCardAskAiTitle,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                l10n.homeCardAskAiSubtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: cs.primary),
                      ],
                    ),
                  ),
                ),
              ),
              if (summary != null && summary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.homeMedicalNoteTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ],
              if (records.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.homeRecentRecordsTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ...records.take(2).map((r) {
                  final dx = r['diagnosis']?.toString() ?? '';
                  final sx = r['symptoms']?.toString() ?? '';
                  final line = [dx, sx].where((e) => e.isNotEmpty).join(' · ');
                  final du = r['doctor']?['user'];
                  final dname =
                      du is Map<String, dynamic> ? _userFullName(du) : '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.isEmpty ? '—' : line,
                                style: theme.textTheme.bodySmall,
                              ),
                              if (dname.isNotEmpty)
                                Text(
                                  dname,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              if (!hasContent)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.homeNoHealthDataYet,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MyDoctorsSection extends StatelessWidget {
  const _MyDoctorsSection({
    required this.l10n,
    required this.theme,
    required this.doctorsById,
    required this.statusById,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final Map<String, Map<String, dynamic>> doctorsById;
  final Map<String, String> statusById;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final entries = doctorsById.entries.toList();

    Widget doctorCard(int i) {
      final e = entries[i];
      final docId = e.key;
      final d = e.value;
      final u = d['user'] as Map<String, dynamic>?;
      final name = _userFullName(u);
      final dept = d['department']?['name']?.toString() ?? '';
      final initial = name.isNotEmpty
          ? String.fromCharCode(name.runes.first).toUpperCase()
          : '?';
      final gender = doctorGenderFromMap(u);
      final st = statusById[docId] ?? '—';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: _HomeLayout.radiusCard,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x100F172A),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => context.push('/doctor-profile/$docId'),
              borderRadius: BorderRadius.circular(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DoctorAvatar(
                    doctorName: name,
                    initial: initial,
                    gender: gender,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? '—' : name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        if (dept.isNotEmpty)
                          Text(
                            dept,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  st,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/doctor-profile/$docId'),
                    icon: const Icon(Icons.person_outline_rounded, size: 17),
                    label: const Text('Профайл харах'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.push(
                      '/doctor-chat?doctorId=${Uri.encodeComponent(docId)}',
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                    label: const Text('Чатлах'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.medical_information_outlined, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Миний эмч нар',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Таны захиалсан үзлэгүүдийн эмч нар',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            if (w < 560) {
              return SizedBox(
                height: 202,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: entries.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => SizedBox(
                    width: 268,
                    child: doctorCard(i),
                  ),
                ),
              );
            }
            var cross = 2;
            if (w >= 1200) {
              cross = 4;
            } else if (w >= 900) {
              cross = 3;
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cross,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 202,
              ),
              itemCount: entries.length,
              itemBuilder: (context, i) => doctorCard(i),
            );
          },
        ),
      ],
    );
  }
}

class _StaffPreviewSection extends ConsumerWidget {
  const _StaffPreviewSection({
    super.key,
    required this.l10n,
    required this.theme,
    required this.doctors,
    required this.onlineUserIds,
    required this.todayDoctorIds,
    required this.patientAuthed,
    required this.chatPermissionByDoctor,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final List<Map<String, dynamic>> doctors;
  final Set<String> onlineUserIds;
  final Set<String> todayDoctorIds;
  final bool patientAuthed;
  final Map<String, Map<String, dynamic>> chatPermissionByDoctor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (doctors.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.homeStaffTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(l10n.homeStaffSubtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            ),
            child: Text(
              l10n.homeStaffEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    final cs = theme.colorScheme;
    final preview = doctors.length > 12 ? doctors.sublist(0, 12) : doctors;
    final sw = MediaQuery.sizeOf(context).width;
    final bannerH = sw >= 900 ? 290.0 : (sw >= 600 ? 238.0 : 198.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homeStaffTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.homeStaffSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: _HomeLayout.radiusCard,
            border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: RepaintBoundary(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  height: bannerH,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/clinova_team_card.jpg',
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.25),
                        cacheWidth: 1200,
                        cacheHeight: 500,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF0D3B66),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.groups_rounded,
                            size: 56,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.02),
                              Colors.black.withValues(alpha: 0.52),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC071B4D),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Манай эмнэлгийн хамт олон',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 234,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: preview.length,
            separatorBuilder: (context, i) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final d = preview[i];
              final docId = d['id']?.toString() ?? '';
              final u = d['user'] as Map<String, dynamic>?;
              final userId = u?['id']?.toString() ?? '';
              final name = _userFullName(u);
              final dept = d['department']?['name']?.toString() ?? '';
              final branch = d['branch']?['name']?.toString() ?? '';
              final initial = name.isNotEmpty
                  ? String.fromCharCode(name.runes.first).toUpperCase()
                  : '?';
              final gender = doctorGenderFromMap(u);
              final isOnline =
                  userId.isNotEmpty && onlineUserIds.contains(userId);
              final hasSlotToday =
                  docId.isNotEmpty && todayDoctorIds.contains(docId);
              final ratingVal = d['avgRating'] ?? d['rating'];
              final ratingText = ratingVal is num
                  ? ratingVal.toStringAsFixed(1)
                  : '4.8';
              final perm = chatPermissionByDoctor[docId];
              final canChat =
                  patientAuthed && (perm?['canChat'] == true);
              final pendingReq =
                  patientAuthed && (perm?['pendingRequest'] == true);
              final chatLabel = !patientAuthed
                  ? 'Чат'
                  : canChat
                      ? 'Чатлах'
                      : pendingReq
                          ? 'Хүлээгдэж'
                          : 'Чат хүсэлт';
              return Container(
                    width: 206,
                    padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F0F172A),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _DoctorAvatar(
                                  doctorName: name,
                                  initial: initial,
                                  gender: gender,
                                ),
                                if (isOnline)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 14,
                                      height: 14,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hasSlotToday)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Text(
                                          'Өнөөдөр',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF166534),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Text(
                                    '★ $ratingText',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFF59E0B),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: docId.isEmpty
                              ? null
                              : () => context.push('/doctor-profile/$docId'),
                          child: Text(
                            name.isEmpty ? '—' : name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (dept.isNotEmpty)
                          Text(
                            dept,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        if (branch.isNotEmpty)
                          Text(
                            branch,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          alignment: WrapAlignment.start,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: docId.isEmpty
                                  ? null
                                  : () => context.push(
                                        '/doctor-profile/$docId',
                                      ),
                              child: const Text(
                                'Профайл харах',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: docId.isEmpty
                                  ? null
                                  : () => _goAppointments(context, {
                                        'doctorId': docId,
                                      }),
                              child: const Text(
                                'Цаг',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: docId.isEmpty
                                  ? null
                                  : () => _homeOpenDoctorChatFlow(
                                        context,
                                        ref,
                                        doctorId: docId,
                                        patientAuthed: patientAuthed,
                                        chatPermissionByDoctor:
                                            chatPermissionByDoctor,
                                      ),
                              child: Text(
                                chatLabel,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
            },
          ),
        ),
      ],
    );
  }
}

class _DoctorAvatar extends StatelessWidget {
  const _DoctorAvatar({
    required this.doctorName,
    required this.initial,
    this.gender,
  });

  final String doctorName;
  final String initial;
  final String? gender;

  @override
  Widget build(BuildContext context) {
    return ClinovaCircleAvatar(
      radius: kClinovaDoctorListAvatarRadius,
      initialsText: initial,
      backgroundColor: kClinovaFlatDoctorAvatarBackground,
      foregroundColor: const Color(0xFF475569),
      doctorUseFlatAssetOnly: true,
      doctorDisplayName: doctorName.isEmpty ? initial : doctorName,
      doctorGender: gender,
    );
  }
}

class _BranchesPreviewSection extends StatelessWidget {
  const _BranchesPreviewSection({
    required this.l10n,
    required this.theme,
    required this.branches,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final List<Map<String, dynamic>> branches;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeBranchesSectionTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.homeBranchesSectionSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push('/branches'),
              child: Text(l10n.homeSeeAll),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (branches.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: _HomeLayout.radiusCard,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              l10n.branchesEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final cross = c.maxWidth >= 640 ? 2 : 1;
              final slice = branches.take(4).toList();
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: cross == 2 ? 2.85 : 2.35,
                ),
                itemCount: slice.length,
                itemBuilder: (context, i) {
                  final b = slice[i];
                  final name = b['name']?.toString() ?? '';
                  final city = b['city']?.toString() ?? '';
                  return Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: _HomeLayout.radiusCard,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.push('/branches'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.apartment_rounded,
                                color: cs.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    name.isEmpty ? '—' : name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (city.isNotEmpty)
                                    Text(
                                      city,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_outward_rounded,
                              size: 20,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
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
      ],
    );
  }
}

class _HomeDrawer extends StatelessWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.4,
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeMenuTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const ClinovaLogo(size: 44, variant: LogoVariant.dark),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.calendar_month_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(l10n.homeCardBookVisitTitle),
              subtitle: Text(l10n.homeCardBookVisitSubtitle),
              onTap: () {
                Navigator.pop(context);
                context.push('/appointments');
              },
            ),
            ListTile(
              leading: Icon(
                Icons.auto_awesome_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text('${l10n.aiTitle} · ${l10n.homeDrawerAgent}'),
              subtitle: Text(l10n.homeDrawerAiAgentSubtitle),
              onTap: () {
                Navigator.pop(context);
                context.push('/agent');
              },
            ),
            ListTile(
              leading: Icon(
                Icons.chat_bubble_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(l10n.homeCardLiveChatTitle),
              subtitle: Text(l10n.homeCardLiveChatSubtitle),
              onTap: () {
                Navigator.pop(context);
                context.push('/doctor-chat');
              },
            ),
            ListTile(
              leading: Icon(
                Icons.tune_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(l10n.settings),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
            ListTile(
              leading: Icon(
                Icons.location_on_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(l10n.homeCardBranchesTitle),
              subtitle: Text(l10n.homeCardBranchesSubtitle),
              onTap: () {
                Navigator.pop(context);
                context.push('/branches');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.isWide,
    required this.isAuthed,
    required this.upcomingCount,
    required this.profileCompletion,
    this.nextAppointment,
    required this.onBook,
    required this.onAi,
  });

  final bool isWide;
  final bool isAuthed;
  final String upcomingCount;
  final String profileCompletion;
  final Map<String, dynamic>? nextAppointment;
  final VoidCallback onBook;
  final VoidCallback onAi;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final headline = isAuthed
        ? l10n.homePremiumHeadlineAuthed
        : l10n.homePremiumHeadlineGuest;
    final subtitle = l10n.homePremiumSubtitle;

    final profilePct = int.tryParse(
          profileCompletion.replaceAll('%', '').trim(),
        )?.clamp(0, 100) ??
        0;

    final gradientBox = BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0E7490), Color(0xFF155E75), Color(0xFF0F172A)],
        stops: [0.0, 0.45, 1.0],
      ),
      borderRadius: _HomeLayout.radiusCard,
      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x140F172A),
          blurRadius: 20,
          offset: Offset(0, 10),
        ),
      ],
    );

    final headlineStyle = isWide
        ? theme.textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.12,
            fontSize: 28,
            letterSpacing: -0.55,
          )
        : theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.2,
            fontSize: 22,
          );

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        l10n.homeBadgePremiumCare,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );

    final subtitleWidget = Text(
      subtitle,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: Colors.white.withValues(alpha: 0.82),
        height: 1.4,
        fontWeight: FontWeight.w500,
        fontSize: isWide ? 15.5 : null,
      ),
    );

    final ctas = Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: onBook,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF155E75),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.calendar_month_rounded, size: 20),
          label: Text(l10n.homeBookNow),
        ),
        OutlinedButton.icon(
          onPressed: onAi,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.auto_awesome_rounded, size: 19),
          label: Text(l10n.homeHeroSecondaryCta),
        ),
      ],
    );

    String? apptPreview;
    if (nextAppointment != null) {
      final ap = nextAppointment!;
      final dt = ap['startsAt']?.toString() ?? '';
      final st = DateTime.tryParse(dt);
      final when = st != null
          ? DateFormat('MMM d · HH:mm').format(st)
          : dt;
      final doc = _appointmentDoctorName(ap);
      apptPreview = [when, doc].where((e) => e.isNotEmpty).join(' · ');
    }

    final rightStack = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (apptPreview != null && apptPreview.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeMetricUpcoming,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  apptPreview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                Text(
                  l10n.homeMetricUpcoming,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  upcomingCount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Text(
          l10n.homeMetricProfile,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: profilePct / 100,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          profileCompletion,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onAi,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.homeCardAskAiTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          l10n.homeAskAi,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (isWide) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 448),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: gradientBox,
          alignment: Alignment.center,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 56,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    badge,
                    const SizedBox(height: 12),
                    Text(headline, style: headlineStyle),
                    const SizedBox(height: 10),
                    subtitleWidget,
                    const SizedBox(height: 18),
                    ctas,
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(flex: 44, child: rightStack),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: gradientBox,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          badge,
          const SizedBox(height: 12),
          Text(headline, style: headlineStyle),
          const SizedBox(height: 8),
          subtitleWidget,
          const SizedBox(height: 14),
          rightStack,
          const SizedBox(height: 16),
          ctas,
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF102A43),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.doctor,
    required this.specialty,
    required this.branch,
    required this.slot,
    required this.accent,
    this.branchId,
    this.departmentId,
    this.serviceId,
    this.doctorId,
  });

  final String doctor;
  final String specialty;
  final String branch;
  final String slot;
  final Color accent;
  final String? branchId;
  final String? departmentId;
  final String? serviceId;
  final String? doctorId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClinovaCircleAvatar(
            radius: 28,
            initialsText: doctor.isNotEmpty
                ? String.fromCharCode(doctor.runes.first).toUpperCase()
                : '?',
            backgroundColor: kClinovaFlatDoctorAvatarBackground,
            foregroundColor: const Color(0xFF475569),
            doctorUseFlatAssetOnly: true,
            doctorDisplayName: doctor,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '$specialty  •  $branch',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10n.homeTodayAt(slot),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () {
              final q = <String, String>{};
              if (branchId != null && branchId!.isNotEmpty) {
                q['branchId'] = branchId!;
              }
              if (departmentId != null && departmentId!.isNotEmpty) {
                q['departmentId'] = departmentId!;
              }
              if (serviceId != null && serviceId!.isNotEmpty) {
                q['serviceId'] = serviceId!;
              }
              if (doctorId != null && doctorId!.isNotEmpty) {
                q['doctorId'] = doctorId!;
              }
              _goAppointments(context, q);
            },
            child: Text(l10n.homeSlotBook),
          ),
        ],
      ),
    );
  }
}
