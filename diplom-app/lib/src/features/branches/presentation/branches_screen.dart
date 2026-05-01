import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/network/clinova_api.dart';
import '../../../core/widgets/clinova_backdrop.dart';

class BranchesScreen extends ConsumerStatefulWidget {
  const BranchesScreen({super.key});

  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen> {
  List<Map<String, dynamic>> branches = const [];
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      final list = await ref.read(clinovaApiProvider).getBranches();
      if (!mounted) return;
      setState(() {
        branches = list;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = error.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrGo(context, '/home'),
        ),
        title: Text(l10n.branchesTitle),
      ),
      body: ClinovaBackdrop(
        child: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: Text(l10n.branchesRetry),
                        ),
                      ],
                    ),
                  ),
                )
              : branches.isEmpty
              ? Center(child: Text(l10n.branchesEmpty))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: branches.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final b = branches[index];
                    final name = b['name']?.toString() ?? '';
                    final address = b['address']?.toString() ?? '';
                    final city = b['city']?.toString() ?? '';
                    final phone = b['contactPhone']?.toString() ?? '';
                    final line2 = [
                      if (address.isNotEmpty) address,
                      if (city.isNotEmpty) city,
                    ].join(', ');
                    return Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          final id = b['id']?.toString();
                          if (id == null || id.isEmpty) return;
                          context.go(
                            Uri(
                              path: '/appointments/book',
                              queryParameters: {'branchId': id},
                            ).toString(),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: theme.textTheme.titleMedium,
                              ),
                              if (line2.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  line2,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                              if (phone.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  phone,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                l10n.branchesBookHere,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
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
    );
  }
}
