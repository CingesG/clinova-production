import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/clinova_api.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/premium_healthcare_shell.dart';
import 'appointment_list_utils.dart';

class DoctorScheduleScreen extends ConsumerStatefulWidget {
  const DoctorScheduleScreen({super.key});

  @override
  ConsumerState<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends ConsumerState<DoctorScheduleScreen> {
  String _status = 'ALL';
  bool _loading = false;
  final Set<String> _busyIds = <String>{};
  List<Map<String, dynamic>> _appointments = const [];

  List<Map<String, dynamic>> get _filteredAppointments {
    if (_status == 'ALL') return _appointments;
    return _appointments
        .where(
          (a) =>
              (a['status']?.toString() ?? '').toUpperCase() == _status,
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ref.read(clinovaApiProvider).getAppointments();
      if (!mounted) return;
      setState(() {
        _appointments =
            (data['items'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(String appointmentId, String status) async {
    if (_busyIds.contains(appointmentId)) return;
    setState(() => _busyIds.add(appointmentId));
    try {
      final updated = await ref.read(clinovaApiProvider).updateAppointmentStatus(
            appointmentId: appointmentId,
            status: status,
          );
      if (!mounted) return;
      setState(() {
        _appointments = patchAppointmentInList(
          _appointments,
          appointmentId,
          updated,
          status,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Цагийн төлөв шинэчлэгдлээ: $status')),
      );
      unawaited(_load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(appointmentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filteredAppointments;

    return Scaffold(
      backgroundColor: ClinovaPremium.surfaceTint,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ClinovaPremium.surfaceTint,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/doctor'),
        ),
        title: const Text(
          'Миний хуваарь',
          style: TextStyle(
            color: ClinovaPremium.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Шинэчлэх',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ClinovaBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final s in const [
                          'ALL',
                          'PENDING',
                          'CONFIRMED',
                          'COMPLETED',
                          'CANCELLED',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(s),
                              selected: _status == s,
                              onSelected: (_) {
                                setState(() => _status = s);
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              showCheckmark: false,
                              selectedColor: ClinovaPremium.pillBlueBg,
                              checkmarkColor: ClinovaPremium.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _loading && _appointments.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: visible.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 120),
                                  Center(
                                    child: Text(
                                      'Энэ шүүлтүүрт захиалга олдсонгүй.',
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  18,
                                ),
                                itemCount: visible.length,
                                itemBuilder: (context, index) {
                                  final ap = visible[index];
                                  final id = ap['id']?.toString() ?? '';
                                  final patient =
                                      ap['patient']?['user']
                                          as Map<String, dynamic>? ??
                                      const {};
                                  final service =
                                      ap['service'] as Map<String, dynamic>? ??
                                      const {};
                                  final starts = DateTime.tryParse(
                                    ap['startsAt']?.toString() ?? '',
                                  );
                                  final status =
                                      (ap['status']?.toString() ?? '')
                                          .toUpperCase();
                                  final busy = _busyIds.contains(id);
                                  final time = starts == null
                                      ? '--'
                                      : DateFormat('yyyy-MM-dd HH:mm').format(
                                          starts.toLocal(),
                                        );
                                  return PremiumAppointmentCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'
                                              .trim(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${service['name'] ?? '—'} • $time',
                                        ),
                                        const SizedBox(height: 8),
                                        Text('Төлөв: $status'),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            FilledButton(
                                              onPressed: id.isEmpty || busy
                                                  ? null
                                                  : () => _setStatus(
                                                        id,
                                                        'CONFIRMED',
                                                      ),
                                              child: Text(
                                                busy ? '...' : 'Эхлүүлэх',
                                              ),
                                            ),
                                            OutlinedButton(
                                              onPressed: id.isEmpty || busy
                                                  ? null
                                                  : () => _setStatus(
                                                        id,
                                                        'COMPLETED',
                                                      ),
                                              child: Text(
                                                busy ? '...' : 'Дуусгах',
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
