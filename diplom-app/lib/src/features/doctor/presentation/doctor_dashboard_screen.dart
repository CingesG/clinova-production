import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/formatting/contact_display.dart';
import '../../../core/localization/context_l10n.dart';
import '../../../core/network/clinova_api.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../auth/application/auth_controller.dart';

class DoctorDashboardScreen extends ConsumerStatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  ConsumerState<DoctorDashboardScreen> createState() =>
      _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends ConsumerState<DoctorDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<Map<String, dynamic>> _future;
  final Set<String> _busyAppointmentIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = ref.read(clinovaApiProvider).getDoctorDashboard();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ref.read(clinovaApiProvider).getDoctorDashboard();
    });
  }

  Future<void> _updateAppointmentStatus({
    required String appointmentId,
    required String status,
    required String successMessage,
  }) async {
    if (_busyAppointmentIds.contains(appointmentId)) return;
    setState(() => _busyAppointmentIds.add(appointmentId));
    try {
      await ref.read(clinovaApiProvider).updateAppointmentStatus(
            appointmentId: appointmentId,
            status: status,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _busyAppointmentIds.remove(appointmentId));
      }
    }
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    final patient = appointment['patient'] as Map? ?? const {};
    final user = patient['user'] as Map? ?? const {};
    final userMap = Map<String, dynamic>.from(user);
    final service = appointment['service'] as Map? ?? const {};
    final branch = appointment['branch'] as Map? ?? const {};
    final startsAt = appointment['startsAt']?.toString() ?? '';
    final starts = DateTime.tryParse(startsAt);
    final timeLabel = starts == null
        ? startsAt
        : DateFormat('yyyy-MM-dd HH:mm').format(starts.toLocal());
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Үзлэгийн дэлгэрэнгүй'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Өвчтөн: ${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()),
            const SizedBox(height: 6),
            Text('Имэйл: ${user['email'] ?? '—'}'),
            const SizedBox(height: 6),
            Text(
              'Өвчтөний утас: ${displayMnRegisteredPhone(userMap)}',
            ),
            const SizedBox(height: 6),
            Text('Үйлчилгээ: ${service['name'] ?? '—'}'),
            const SizedBox(height: 6),
            Text('Салбар: ${branch['name'] ?? '—'}'),
            const SizedBox(height: 6),
            Text('Цаг: $timeLabel'),
            const SizedBox(height: 6),
            Text('Төлөв: ${appointment['status'] ?? '—'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Хаах'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          children: [
            const ListTile(
              title: Text(
                'Эмчийн цэс',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Дахин ачаалах'),
              onTap: () async {
                Navigator.of(context).pop();
                await _refresh();
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_rounded),
              title: const Text('Өвчтөнтэй чатлах'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/doctor-chat');
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Миний цагийн хуваарь'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/doctor/schedule');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Профайл'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_alt_rounded),
              title: const Text('Үзлэгийн тэмдэглэл'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/doctor/notes');
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: Text(context.l10n.settings),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Гарах'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authControllerProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = ref.watch(authControllerProvider).user;
    final welcomeName = user?.displayName ?? l10n.doctorRoleFallback;
    final nowLabel = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isMobile = MediaQuery.of(context).size.width < 760;

    return Scaffold(
      key: _scaffoldKey,
      appBar: isMobile
          ? AppBar(
              title: const Text('Эмчийн самбар'),
              leading: IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            )
          : null,
      body: ClinovaBackdrop(
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              final theme = Theme.of(context);
              final data = snapshot.data ?? const <String, dynamic>{};
              final todayAppointments =
                  (data['todayAppointments'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  const <Map<String, dynamic>>[];
              final upcomingAppointments =
                  (data['upcomingAppointments'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  const <Map<String, dynamic>>[];
              final reminders =
                  (data['reminders'] as List?)?.cast<Map>() ?? const [];
              final unreadReminderCount =
                  int.tryParse('${data['unreadReminderCount'] ?? 0}') ?? 0;
              final stats = [
                (
                  'Өнөөдрийн үзлэг',
                  todayAppointments.length.toString(),
                  Icons.today_rounded,
                  'Өнөөдөр төлөвлөгдсөн үзлэгүүд',
                ),
                (
                  'Удахгүй үзүүлэх',
                  upcomingAppointments.length.toString(),
                  Icons.schedule_rounded,
                  'Ирэх цагийн өвчтөнүүд',
                ),
                (
                  'Нийт өвчтөн',
                  data['patientCount']?.toString() ?? '0',
                  Icons.groups_2_rounded,
                  'Тантай үзүүлсэн өвчтөнүүд',
                ),
                (
                  'Reminder',
                  unreadReminderCount.toString(),
                  Icons.notifications_active_rounded,
                  'Уншаагүй сануулга',
                ),
                (
                  'Feedback',
                  data['feedbackCount']?.toString() ?? '0',
                  Icons.reviews_rounded,
                  'Өвчтөнөөс ирсэн үнэлгээ',
                ),
                (
                  'Дундаж үнэлгээ',
                  data['avgStars']?.toString() ?? '0',
                  Icons.stars_rounded,
                  '5 онооноос дундаж үнэлгээ',
                ),
                (
                  'Bonus (MNT)',
                  data['estimatedBonusMnt']?.toString() ?? '0',
                  Icons.payments_rounded,
                  'Тооцоолсон нэмэгдэл орлого',
                ),
              ];

              return RefreshIndicator(
                onRefresh: _refresh,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x140F172A),
                                blurRadius: 24,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Эмчийн самбар',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            color: const Color(0xFF0F172A),
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Сайн байна уу, $welcomeName',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: const Color(0xFF475569),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF2FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  nowLabel,
                                  style: const TextStyle(
                                    color: Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (!isMobile) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Шинэчлэх',
                                  onPressed: _refresh,
                                  icon: const Icon(Icons.refresh_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Гарах',
                                  onPressed: () => ref
                                      .read(authControllerProvider.notifier)
                                      .logout(),
                                  icon: const Icon(Icons.logout_rounded),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final crossAxisCount = width >= 1100
                                ? 3
                                : width >= 720
                                ? 2
                                : 1;
                            final ratio = crossAxisCount == 1 ? 3.1 : 2.35;
                            return GridView.builder(
                              itemCount: stats.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: ratio,
                                  ),
                              itemBuilder: (context, index) {
                                final stat = stats[index];
                                return _DoctorStatCard(
                                  title: stat.$1,
                                  value: stat.$2,
                                  icon: stat.$3,
                                  helper: stat.$4,
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Өнөөдрийн цагууд',
                          icon: Icons.calendar_month_rounded,
                          child: _AppointmentList(
                            appointments: todayAppointments,
                            emptyTitle: 'Өнөөдөр захиалгатай өвчтөн алга.',
                            emptySubtitle: 'Шинэ цаг орж ирвэл энд харагдана.',
                            busyAppointmentIds: _busyAppointmentIds,
                            onViewDetails: _showAppointmentDetails,
                            onStartVisit: (appointmentId) => _updateAppointmentStatus(
                              appointmentId: appointmentId,
                              status: 'CONFIRMED',
                              successMessage: 'Үзлэг эхэллээ (CONFIRMED).',
                            ),
                            onCompleteVisit: (appointmentId) => _updateAppointmentStatus(
                              appointmentId: appointmentId,
                              status: 'COMPLETED',
                              successMessage: 'Үзлэг дууслаа (COMPLETED).',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SectionCard(
                          title: 'Удахгүй үзүүлэх өвчтөнүүд',
                          icon: Icons.watch_later_rounded,
                          child: _AppointmentList(
                            appointments: upcomingAppointments,
                            emptyTitle:
                                'Одоогоор удахгүй үзүүлэх цаг олдсонгүй.',
                            emptySubtitle:
                                'Шинэ захиалга нэмэгдэхэд энд гарна.',
                            busyAppointmentIds: _busyAppointmentIds,
                            onViewDetails: _showAppointmentDetails,
                            onStartVisit: (appointmentId) => _updateAppointmentStatus(
                              appointmentId: appointmentId,
                              status: 'CONFIRMED',
                              successMessage: 'Үзлэг эхэллээ (CONFIRMED).',
                            ),
                            onCompleteVisit: (appointmentId) => _updateAppointmentStatus(
                              appointmentId: appointmentId,
                              status: 'COMPLETED',
                              successMessage: 'Үзлэг дууслаа (COMPLETED).',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SectionCard(
                          title: 'Appointment reminders',
                          icon: Icons.notifications_active_rounded,
                          child: _ReminderList(reminders: reminders),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      drawer: isMobile ? _buildMobileDrawer() : null,
      bottomNavigationBar: _DoctorBottomActionBar(
        onChat: () => context.go('/doctor-chat'),
        onSchedule: () => context.go('/doctor/schedule'),
        onNotes: () => context.go('/doctor/notes'),
        onSettings: () => context.go('/settings'),
      ),
    );
  }
}

class _DoctorBottomActionBar extends StatelessWidget {
  const _DoctorBottomActionBar({
    required this.onChat,
    required this.onSchedule,
    required this.onNotes,
    required this.onSettings,
  });

  final VoidCallback onChat;
  final VoidCallback onSchedule;
  final VoidCallback onNotes;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 760;
    final background = Colors.white.withValues(alpha: 0.95);
    final borderColor = const Color(0x1A0F172A);
    final actions = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: Icons.chat_bubble_rounded,
        label: 'Чат',
        onTap: onChat,
      ),
      (
        icon: Icons.schedule_rounded,
        label: 'Хуваарь',
        onTap: onSchedule,
      ),
      (
        icon: Icons.note_alt_rounded,
        label: 'Тэмдэглэл',
        onTap: onNotes,
      ),
      (
        icon: Icons.tune_rounded,
        label: 'Тохиргоо',
        onTap: onSettings,
      ),
    ];

    if (isMobile) {
      return SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: background,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              for (final action in actions)
                Expanded(
                  child: InkWell(
                    onTap: action.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(action.icon, size: 20, color: const Color(0xFF334155)),
                          const SizedBox(height: 2),
                          Text(
                            action.label,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: background,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onChat,
                icon: const Icon(Icons.chat_bubble_rounded),
                label: const Text('Чат'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSchedule,
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('Хуваарь'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onNotes,
                icon: const Icon(Icons.note_alt_rounded),
                label: const Text('Тэмдэглэл'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSettings,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Тохиргоо'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorStatCard extends StatelessWidget {
  const _DoctorStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.helper,
  });

  final String title;
  final String value;
  final IconData icon;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FBFF), Color(0xFFF0F8FF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCEAFE)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF1D4ED8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  helper,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12.5,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1D4ED8), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({
    required this.appointments,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.busyAppointmentIds,
    required this.onViewDetails,
    required this.onStartVisit,
    required this.onCompleteVisit,
  });

  final List<Map<String, dynamic>> appointments;
  final String emptyTitle;
  final String emptySubtitle;
  final Set<String> busyAppointmentIds;
  final void Function(Map<String, dynamic> appointment) onViewDetails;
  final Future<void> Function(String appointmentId) onStartVisit;
  final Future<void> Function(String appointmentId) onCompleteVisit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (appointments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(
              emptyTitle,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              emptySubtitle,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: appointments.map((appointment) {
        final appointmentId = appointment['id']?.toString() ?? '';
        final isBusy = busyAppointmentIds.contains(appointmentId);
        final patient = appointment['patient'] as Map? ?? const {};
        final user = patient['user'] as Map? ?? const {};
        final patientPhoneMap = Map<String, dynamic>.from(user);
        final service = appointment['service'] as Map? ?? const {};
        final branch = appointment['branch'] as Map? ?? const {};
        final status = (appointment['status']?.toString() ?? 'PENDING').toUpperCase();
        final canStart = appointmentId.isNotEmpty &&
            !isBusy &&
            (status == 'PENDING' || status == 'CONFIRMED');
        final canComplete = appointmentId.isNotEmpty &&
            !isBusy &&
            (status == 'CONFIRMED' || status == 'NO_SHOW');
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDDEBFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.person_rounded, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                          .trim(),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${service['name'] ?? l10n.consultationFallback} • ${_fmtDateTime(appointment['startsAt'])}',
                style: const TextStyle(color: Color(0xFF334155)),
              ),
              const SizedBox(height: 4),
              Text(
                'Салбар: ${branch['name'] ?? '—'}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Өвчтөний утас: ${displayMnRegisteredPhone(patientPhoneMap)}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => onViewDetails(appointment),
                    child: const Text('Дэлгэрэнгүй'),
                  ),
                  FilledButton(
                    onPressed: canStart
                        ? () => onStartVisit(appointmentId)
                        : null,
                    child: Text(isBusy ? '...' : 'Үзлэг эхлүүлэх'),
                  ),
                  OutlinedButton(
                    onPressed: canComplete
                        ? () => onCompleteVisit(appointmentId)
                        : null,
                    child: Text(isBusy ? '...' : 'Дуусгах'),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _fmtDateTime(dynamic value) {
    final raw = value?.toString() ?? '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
  }

  Widget _statusBadge(String status) {
    final normalized = status.toUpperCase();
    final bool isConfirmed =
        normalized == 'CONFIRMED' || normalized == 'COMPLETED';
    final color = isConfirmed
        ? const Color(0xFF16A34A)
        : const Color(0xFF1D4ED8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ReminderList extends StatelessWidget {
  const _ReminderList({required this.reminders});

  final List<Map> reminders;

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'Одоогоор reminder алга.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }
    return Column(
      children: reminders.take(6).map((r) {
        final body = r['body']?.toString() ?? '';
        final readAt = r['readAt']?.toString();
        final createdAt = r['createdAt']?.toString() ?? '';
        final dt = DateTime.tryParse(createdAt);
        final ts = dt == null
            ? createdAt
            : DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: readAt == null
                ? const Color(0xFFFFFBEB)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: readAt == null
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                body,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ts,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
