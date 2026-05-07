import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/media/doctor_avatar_mapper.dart';
import '../../../core/network/clinova_api.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/clinova_circle_avatar.dart';
import '../../auth/application/auth_controller.dart';

final _doctorPublicProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
      return ref.read(clinovaApiProvider).getDoctor(id);
    });

class DoctorPublicProfileScreen extends ConsumerWidget {
  const DoctorPublicProfileScreen({super.key, required this.doctorProfileId});

  final String doctorProfileId;

  static const _days = ['Ням', 'Дав', 'Мяг', 'Лха', 'Пүр', 'Баас', 'Бям'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final async = ref.watch(_doctorPublicProvider(doctorProfileId));

    Future<void> openChat() async {
      final auth = ref.read(authControllerProvider);
      if (!auth.isAuthenticated) {
        if (context.mounted) {
          await context.push('/auth/login');
        }
        return;
      }
      if (context.mounted) {
        context.push(
          '/doctor-chat?doctorId=${Uri.encodeComponent(doctorProfileId)}',
        );
      }
    }

    void openBook() {
      context.push(
        Uri(
          path: '/appointments/book',
          queryParameters: {'doctorId': doctorProfileId},
        ).toString(),
      );
    }

    return ClinovaBackdrop(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Эмчийн профайл'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
        ),
        body: async.when(
          data: (d) {
            final u = d['user'] as Map<String, dynamic>?;
            final name = u == null
                ? '—'
                : '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
            final initial = name.isNotEmpty
                ? String.fromCharCode(name.runes.first).toUpperCase()
                : '?';
            final branch = d['branch'] as Map<String, dynamic>?;
            final dept = d['department'] as Map<String, dynamic>?;
            final deptName = dept?['name']?.toString() ?? '';
            final branchName = branch?['name']?.toString() ?? '';
            final bio = d['bio']?.toString() ?? '';
            final exp = d['experienceYears'];
            final fee = d['consultationFee'];
            final schedules =
                (d['weeklySchedules'] as List?)?.cast<Map<String, dynamic>>() ??
                const <Map<String, dynamic>>[];

            final hoursLines = <String>[];
            for (final s in schedules.where((x) => x['isActive'] != false)) {
              final dow = (s['dayOfWeek'] is int)
                  ? s['dayOfWeek'] as int
                  : int.tryParse(s['dayOfWeek']?.toString() ?? '') ?? 0;
              final label = dow >= 0 && dow < _days.length
                  ? _days[dow]
                  : '$dow';
              final st = s['startTime']?.toString() ?? '';
              final en = s['endTime']?.toString() ?? '';
              if (st.isNotEmpty && en.isNotEmpty) {
                hoursLines.add('$label · $st–$en');
              }
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClinovaCircleAvatar(
                      radius: 36,
                      initialsText: initial,
                      backgroundColor: kClinovaFlatDoctorAvatarBackground,
                      foregroundColor: const Color(0xFF475569),
                      doctorUseFlatAssetOnly: true,
                      doctorDisplayName: name,
                      doctorGender: doctorGenderFromMap(u),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          if (deptName.isNotEmpty)
                            Text(
                              deptName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (branchName.isNotEmpty)
                            Text(
                              branchName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: openChat,
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Чат эхлүүлэх'),
                    ),
                    OutlinedButton.icon(
                      onPressed: openBook,
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(l10n.homeNavBook),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (exp != null)
                  _InfoRow(
                    icon: Icons.work_history_outlined,
                    label: 'Туршлага',
                    value: '$exp жил',
                  ),
                if (fee != null)
                  _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Консультацийн төлбөр',
                    value:
                        '${NumberFormat.decimalPattern(l10n.localeName).format(fee is int ? fee : int.tryParse('$fee') ?? 0)} ₮',
                  ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Танилцуулга',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(bio, style: theme.textTheme.bodyMedium),
                ],
                if (hoursLines.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Хуваарийн горим',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...hoursLines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(line)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
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
