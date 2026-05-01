import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/clinova_api.dart';
import '../../../core/widgets/clinova_backdrop.dart';

class DoctorNotesScreen extends ConsumerStatefulWidget {
  const DoctorNotesScreen({super.key});

  @override
  ConsumerState<DoctorNotesScreen> createState() => _DoctorNotesScreenState();
}

class _DoctorNotesScreenState extends ConsumerState<DoctorNotesScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _items = const [];

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
      final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      setState(() {
        _items = items.where((e) => (e['status']?.toString() ?? '') != 'CANCELLED').toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/doctor'),
        ),
        title: const Text('Үзлэгийн тэмдэглэл'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: ClinovaBackdrop(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final ap = _items[index];
                    final patient = ap['patient']?['user'] as Map<String, dynamic>? ?? const {};
                    final service = ap['service'] as Map<String, dynamic>? ?? const {};
                    final branch = ap['branch'] as Map<String, dynamic>? ?? const {};
                    final starts = DateTime.tryParse(ap['startsAt']?.toString() ?? '');
                    final time = starts == null
                        ? '--'
                        : DateFormat('yyyy-MM-dd HH:mm').format(starts.toLocal());
                    final reason = (ap['reason']?.toString() ?? '').trim();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.93),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text('${service['name'] ?? '—'} • ${branch['name'] ?? '—'}'),
                          const SizedBox(height: 4),
                          Text('Цаг: $time'),
                          const SizedBox(height: 8),
                          Text(
                            reason.isEmpty ? 'Тэмдэглэл: (хоосон)' : 'Тэмдэглэл: $reason',
                            style: const TextStyle(color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
