import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/clinova_api.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/clinova_circle_avatar.dart';
import '../../../core/widgets/clinova_logo.dart';
import '../../auth/application/auth_controller.dart';
import 'patient_desktop_nav_bar.dart';

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

String? _absoluteUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  final base = Uri.tryParse(AppConfig.apiBaseUrl);
  if (base == null) return value;
  final fixedPath = value.startsWith('/') ? value : '/$value';
  return base.resolve(fixedPath).toString();
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey _doctorsSectionKey = GlobalKey();

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
                  future: Future.wait<dynamic>([
                    isAuthed
                        ? ref.read(clinovaApiProvider).getPatientDashboard()
                        : Future<Map<String, dynamic>>.value(const {}),
                    ref.read(clinovaApiProvider).getAvailableSlots(date: today),
                    ref.read(clinovaApiProvider).getDepartments(),
                    ref.read(clinovaApiProvider).getBranches(),
                    ref.read(clinovaApiProvider).getDoctors(),
                  ]),
                  builder: (context, snapshot) {
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

                    return CustomScrollView(
                      primary: true,
                      slivers: [
                        if (isDesktop)
                          SliverToBoxAdapter(
                            child: PatientDesktopContainer(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  20,
                                  24,
                                  0,
                                ),
                                child: PatientDesktopNavBar(
                                  isAuthenticated: isAuthed,
                                  onScrollToDoctors: _scrollToDoctors,
                                ),
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 32 : 20,
                            isDesktop ? 16 : 12,
                            isDesktop ? 32 : 20,
                            showDockSpace ? 156 : (isDesktop ? 88 : 128),
                          ),
                          sliver: SliverList.list(
                            children: [
                              PatientDesktopContainer(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      l10n.homeTagline,
                                      style:
                                          (isDesktop
                                                  ? theme
                                                        .textTheme
                                                        .headlineMedium
                                                  : theme.textTheme.titleLarge)
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.5,
                                                color: const Color(0xFF102A43),
                                              ),
                                    ),
                                    SizedBox(height: isDesktop ? 28 : 20),
                                    _HeroPanel(
                                      isWide: isDesktop,
                                      isAuthed: isAuthed,
                                      upcomingCount: upcomingAppointments.length
                                          .toString(),
                                      profileCompletion: '$profileCompletion%',
                                      onBook: () =>
                                          context.push('/appointments/book'),
                                      onAi: () => context.push('/agent'),
                                    ),
                                    const SizedBox(height: 18),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        _FilterPill(
                                          label: l10n.homeFilterEnt,
                                          icon: Icons.hearing_rounded,
                                          onTap: () => _goAppointments(
                                            context,
                                            entDeptId != null
                                                ? {'departmentId': entDeptId}
                                                : {},
                                          ),
                                        ),
                                        _FilterPill(
                                          label: l10n.homeFilterPediatrics,
                                          icon: Icons.child_friendly_rounded,
                                          onTap: () => _goAppointments(
                                            context,
                                            pedDeptId != null
                                                ? {'departmentId': pedDeptId}
                                                : {},
                                          ),
                                        ),
                                        _FilterPill(
                                          label: l10n.homeFilterDermatology,
                                          icon: Icons.spa_rounded,
                                          onTap: () => _goAppointments(
                                            context,
                                            dermDeptId != null
                                                ? {'departmentId': dermDeptId}
                                                : {},
                                          ),
                                        ),
                                        _FilterPill(
                                          label: l10n.homeFilterWomensCare,
                                          icon: Icons.favorite_rounded,
                                          onTap: () => _goAppointments(
                                            context,
                                            gynDeptId != null
                                                ? {'departmentId': gynDeptId}
                                                : {},
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    if (isAuthed && user?.role == 'PATIENT')
                                      _PatientHealthSection(
                                        l10n: l10n,
                                        theme: theme,
                                        dashboard: dashboard,
                                      ),
                                    if (isAuthed && user?.role == 'PATIENT')
                                      const SizedBox(height: 20),
                                    _StaffPreviewSection(
                                      key: _doctorsSectionKey,
                                      l10n: l10n,
                                      theme: theme,
                                      doctors: doctorsList,
                                    ),
                                    const SizedBox(height: 20),
                                    _BranchesPreviewSection(
                                      l10n: l10n,
                                      theme: theme,
                                      branches: branchesList,
                                    ),
                                    const SizedBox(height: 26),
                                    _SectionHeader(
                                      title: l10n.homeTodayTitle,
                                      subtitle: l10n.homeTodaySubtitle,
                                    ),
                                    const SizedBox(height: 14),
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting)
                                      const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    else if (slots.isEmpty)
                                      Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.92,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
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
                                            bottom: 12,
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
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final Map<String, dynamic> dashboard;

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

    Widget visitLine(Map<String, dynamic> ap) {
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
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ', style: theme.textTheme.bodySmall),
            Expanded(
              child: Text(bits.join(' · '), style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      );
    }

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
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(l10n.homeYourCareSubtitle, style: theme.textTheme.bodySmall),
          if (summary != null && summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.homeMedicalNoteTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(summary, style: theme.textTheme.bodyMedium),
          ],
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              l10n.homeMetricUpcoming,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...upcoming.take(4).map(visitLine),
          ],
          if (records.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              l10n.homeRecentRecordsTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...records.take(4).map((r) {
              final dx = r['diagnosis']?.toString() ?? '';
              final sx = r['symptoms']?.toString() ?? '';
              final line = [dx, sx].where((e) => e.isNotEmpty).join(' · ');
              final du = r['doctor']?['user'];
              final dname = du is Map<String, dynamic> ? _userFullName(du) : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
                            style: theme.textTheme.bodyMedium,
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
          if (past.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              l10n.homePastVisitsTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...past.take(4).map(visitLine),
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
  }
}

class _StaffPreviewSection extends StatelessWidget {
  const _StaffPreviewSection({
    super.key,
    required this.l10n,
    required this.theme,
    required this.doctors,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final List<Map<String, dynamic>> doctors;

  @override
  Widget build(BuildContext context) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.homeStaffTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(l10n.homeStaffSubtitle, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  'assets/images/clinova_team.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF0D3B66),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.groups_rounded,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
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
        const SizedBox(height: 14),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: preview.length,
            separatorBuilder: (context, i) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final d = preview[i];
              final u = d['user'] as Map<String, dynamic>?;
              final name = _userFullName(u);
              final dept = d['department']?['name']?.toString() ?? '';
              final branch = d['branch']?['name']?.toString() ?? '';
              final avatarUrl = _absoluteUrl(
                u?['avatarUrl']?.toString() ?? d['avatarUrl']?.toString(),
              );
              final initial = name.isNotEmpty
                  ? String.fromCharCode(name.runes.first).toUpperCase()
                  : '?';
              return Container(
                width: 208,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x100F172A),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DoctorAvatar(
                      avatarUrl: avatarUrl,
                      initial: initial,
                      backgroundColor: cs.primaryContainer,
                      textColor: cs.onPrimaryContainer,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      name.isEmpty ? '—' : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
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
    required this.avatarUrl,
    required this.initial,
    required this.backgroundColor,
    required this.textColor,
  });

  final String? avatarUrl;
  final String initial;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ClinovaCircleAvatar(
      radius: 22,
      initialsText: initial,
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
      networkUrl: avatarUrl,
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
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.homeBranchesSectionSubtitle,
                    style: theme.textTheme.bodyMedium,
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
        const SizedBox(height: 12),
        if (branches.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            ),
            child: Text(
              l10n.branchesEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...branches.take(4).map((b) {
            final name = b['name']?.toString() ?? '';
            final city = b['city']?.toString() ?? '';
            final line = [name, city].where((e) => e.isNotEmpty).join(' · ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white.withValues(alpha: 0.92),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => context.push('/branches'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            line.isEmpty ? '—' : line,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
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
    required this.onBook,
    required this.onAi,
  });

  final bool isWide;
  final bool isAuthed;
  final String upcomingCount;
  final String profileCompletion;
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

    final gradientBox = BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0E7490), Color(0xFF155E75), Color(0xFF0F172A)],
        stops: [0.0, 0.45, 1.0],
      ),
      borderRadius: BorderRadius.circular(24),
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
            height: 1.15,
            fontSize: 30,
            letterSpacing: -0.6,
          )
        : theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.2,
            fontSize: 22,
          );

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
      style: theme.textTheme.bodyLarge?.copyWith(
        color: Colors.white.withValues(alpha: 0.82),
        height: 1.45,
        fontWeight: FontWeight.w500,
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
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.auto_awesome_rounded, size: 19),
          label: Text(l10n.homeHeroSecondaryCta),
        ),
      ],
    );

    final summaryCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
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
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            upcomingCount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.homeMetricProfile,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            profileCompletion,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (isWide) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        decoration: gradientBox,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  badge,
                  const SizedBox(height: 16),
                  Text(headline, style: headlineStyle),
                  const SizedBox(height: 12),
                  subtitleWidget,
                  const SizedBox(height: 22),
                  ctas,
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(flex: 42, child: summaryCard),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: gradientBox,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          badge,
          const SizedBox(height: 14),
          Text(headline, style: headlineStyle),
          const SizedBox(height: 10),
          subtitleWidget,
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricChip(
                  label: l10n.homeMetricUpcoming,
                  value: upcomingCount,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricChip(
                  label: l10n.homeMetricProfile,
                  value: profileCompletion,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ctas,
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
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
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: theme.textTheme.bodyMedium),
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
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.local_hospital_rounded, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('$specialty  •  $branch'),
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
          const SizedBox(width: 10),
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
