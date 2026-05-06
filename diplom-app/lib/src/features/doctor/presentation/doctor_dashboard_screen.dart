import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/formatting/contact_display.dart';
import '../../../core/localization/context_l10n.dart';
import '../../../core/network/clinova_api.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/premium_healthcare_shell.dart';
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
        const SnackBar(
          content: Text(
            'Үзлэгийн төлөв шинэчлэхэд алдаа гарлаа. Сүлжээ эсвэл эрхээ шалгаад дахин оролдоно уу.',
          ),
        ),
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
    void onLogout() =>
        ref.read(authControllerProvider.notifier).logout();

    return Scaffold(
      key: _scaffoldKey,
      appBar: isMobile
          ? AppBar(
              title: Text(l10n.docDashboardTitle),
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
                child: PremiumPageCanvas(
                  maxWidth: 1280,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                    children: [
                      PremiumDashboardHeader(
                        title: l10n.docDashboardTitle,
                        subtitle: l10n.docDashboardWelcome(welcomeName),
                        datePill: nowLabel,
                        showIconActions: !isMobile,
                        narrow: isMobile,
                        onRefresh: _refresh,
                        onLogout: onLogout,
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final crossAxisCount = width >= 1100
                              ? 3
                              : width >= 720
                                  ? 2
                                  : 1;
                          return GridView.builder(
                            itemCount: stats.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              mainAxisExtent: 122,
                            ),
                            itemBuilder: (context, index) {
                              final stat = stats[index];
                              return PremiumStatCard(
                                title: stat.$1,
                                value: stat.$2,
                                icon: stat.$3,
                                footer: stat.$4,
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      PremiumSectionCard(
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
                      const SizedBox(height: 16),
                      PremiumSectionCard(
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
                      const SizedBox(height: 16),
                      PremiumSectionCard(
                        title: 'Appointment reminders',
                        icon: Icons.notifications_active_rounded,
                        child: _ReminderList(reminders: reminders),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      drawer: isMobile ? _buildMobileDrawer() : null,
      bottomNavigationBar: PremiumBottomToolBar(
        isCompact: isMobile,
        items: [
          PremiumBottomToolItem(
            icon: Icons.chat_bubble_rounded,
            label: 'Чат',
            onTap: () => context.go('/doctor-chat'),
          ),
          PremiumBottomToolItem(
            icon: Icons.schedule_rounded,
            label: 'Хуваарь',
            onTap: () => context.go('/doctor/schedule'),
          ),
          PremiumBottomToolItem(
            icon: Icons.note_alt_rounded,
            label: 'Тэмдэглэл',
            onTap: () => context.go('/doctor/notes'),
          ),
          PremiumBottomToolItem(
            icon: Icons.tune_rounded,
            label: 'Тохиргоо',
            onTap: () => context.go('/settings'),
          ),
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
      return PremiumEmptyState(
        icon: Icons.calendar_today_rounded,
        title: emptyTitle,
        subtitle: emptySubtitle,
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
        return PremiumAppointmentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: ClinovaPremium.pillBlueBg,
                    child: Icon(Icons.person_rounded,
                        size: 20, color: ClinovaPremium.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                          .trim(),
                      style: const TextStyle(
                        color: ClinovaPremium.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  PremiumStatusPill(label: status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${service['name'] ?? l10n.consultationFallback} • ${_fmtDateTime(appointment['startsAt'])}',
                style: const TextStyle(
                    color: ClinovaPremium.textSecondary, height: 1.3),
              ),
              const SizedBox(height: 4),
              Text(
                'Салбар: ${branch['name'] ?? '—'}',
                style: const TextStyle(
                    color: ClinovaPremium.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Өвчтөний утас: ${displayMnRegisteredPhone(patientPhoneMap)}',
                style: const TextStyle(
                    color: ClinovaPremium.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: () => onViewDetails(appointment),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ClinovaPremium.textPrimary,
                      side: BorderSide(
                          color:
                              ClinovaPremium.border.withValues(alpha: 0.95)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Дэлгэрэнгүй'),
                  ),
                  FilledButton(
                    onPressed: canStart
                        ? () => onStartVisit(appointmentId)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: ClinovaPremium.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          ClinovaPremium.border.withValues(alpha: 0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    child: Text(isBusy ? '...' : 'Үзлэг эхлүүлэх'),
                  ),
                  OutlinedButton(
                    onPressed: canComplete
                        ? () => onCompleteVisit(appointmentId)
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ClinovaPremium.primaryInk,
                      side: BorderSide(
                          color:
                              ClinovaPremium.primary.withValues(alpha: 0.45)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
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
}

class _ReminderList extends StatelessWidget {
  const _ReminderList({required this.reminders});

  final List<Map> reminders;

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return PremiumEmptyState(
        icon: Icons.notifications_off_outlined,
        title: 'Одоогоор reminder алга.',
        subtitle: 'Шинэ сануулга ирэхэд энд харагдана.',
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
