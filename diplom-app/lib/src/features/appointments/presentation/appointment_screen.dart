import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/network/clinova_api.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/guest_auth_prompt.dart';
import '../../auth/application/auth_controller.dart';

class AppointmentScreen extends ConsumerStatefulWidget {
  const AppointmentScreen({
    super.key,
    this.initialBranchId,
    this.initialDepartmentId,
    this.initialServiceId,
    this.initialDoctorId,
  });

  final String? initialBranchId;
  final String? initialDepartmentId;
  final String? initialServiceId;
  final String? initialDoctorId;

  @override
  ConsumerState<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends ConsumerState<AppointmentScreen> {
  final reasonController = TextEditingController();

  List<Map<String, dynamic>> branches = const [];

  /// Full catalog from API (reference only).
  List<Map<String, dynamic>> allDepartments = const [];

  /// Departments that actually have at least one service on [selectedBranchId].
  List<Map<String, dynamic>> departments = const [];
  List<Map<String, dynamic>> services = const [];
  List<Map<String, dynamic>> doctors = const [];
  List<Map<String, dynamic>> slots = const [];
  List<Map<String, dynamic>> recommendedSlots = const [];
  List<Map<String, dynamic>> loadBalancedDoctors = const [];
  List<Map<String, dynamic>> upcomingAppointments = const [];

  bool isCatalogLoading = true;
  bool isSlotsLoading = false;
  bool isBooking = false;
  String? errorMessage;

  String? selectedBranchId;
  String? selectedDepartmentId;
  String? selectedServiceId;
  String? selectedDoctorId;
  DateTime selectedDate = DateTime.now();
  int currentStep = 1;
  Map<String, dynamic>? selectedSlot;
  String? activeSlotLockId;
  List<Map<String, dynamic>> intakeFields = const [];
  final Map<String, dynamic> intakeAnswers = {};

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadInitialData);
  }

  @override
  void dispose() {
    _releaseActiveLock();
    reasonController.dispose();
    super.dispose();
  }

  Future<void> _releaseActiveLock() async {
    final lockId = activeSlotLockId;
    if (lockId == null) return;
    activeSlotLockId = null;
    try {
      await ref.read(clinovaApiProvider).releaseSlotLock(lockId);
    } catch (_) {}
  }

  Future<void> _clearSlotSelection({bool releaseLock = true}) async {
    if (releaseLock) {
      await _releaseActiveLock();
    }
    if (!mounted) return;
    setState(() {
      selectedSlot = null;
      currentStep = currentStep < 2 ? currentStep : 2;
    });
  }

  Future<void> _loadInitialData() async {
    setState(() {
      isCatalogLoading = true;
      errorMessage = null;
    });

    try {
      final api = ref.read(clinovaApiProvider);
      final authed = ref.read(authControllerProvider).isAuthenticated;
      final fetchedBranches = await api.getBranches();
      final fetchedDepartments = await api.getDepartments();
      final appointmentsResponse = authed
          ? await api.getAppointments(status: 'PENDING')
          : <String, dynamic>{};
      final items =
          (appointmentsResponse['items'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          const [];

      bool idInList(String? id, List<Map<String, dynamic>> list) =>
          id != null && list.any((e) => e['id'].toString() == id);

      final branchFromLink = idInList(widget.initialBranchId, fetchedBranches)
          ? widget.initialBranchId
          : null;
      final deptFromLink =
          idInList(widget.initialDepartmentId, fetchedDepartments)
          ? widget.initialDepartmentId
          : null;

      if (!mounted) return;
      setState(() {
        branches = fetchedBranches;
        allDepartments = fetchedDepartments;
        departments = fetchedDepartments;
        upcomingAppointments = items;
        selectedBranchId =
            branchFromLink ??
            (fetchedBranches.isNotEmpty
                ? fetchedBranches.first['id'].toString()
                : null);
      });

      await _applyBranchSelection(preferDepartmentId: deptFromLink);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isCatalogLoading = false;
        });
      }
    }
  }

  /// Loads departments available at the current branch (from `/services?branchId=…`),
  /// then loads services/doctors/slots for the chosen department.
  Future<void> _applyBranchSelection({String? preferDepartmentId}) async {
    final branchId = selectedBranchId;
    if (branchId == null) {
      if (!mounted) return;
      setState(() {
        departments = List<Map<String, dynamic>>.from(allDepartments);
        selectedDepartmentId = null;
        services = [];
        selectedServiceId = null;
        doctors = [];
        selectedDoctorId = null;
        slots = [];
        recommendedSlots = [];
        loadBalancedDoctors = [];
        selectedSlot = null;
        currentStep = 1;
      });
      return;
    }

    try {
      final svcs = await ref
          .read(clinovaApiProvider)
          .getServices(branchId: branchId);
      final byDept = <String, Map<String, dynamic>>{};
      for (final s in svcs) {
        final d = s['department'];
        if (d is Map<String, dynamic>) {
          final id = d['id']?.toString();
          if (id != null) {
            byDept[id] = Map<String, dynamic>.from(d);
          }
        }
      }
      final list = byDept.values.toList()
        ..sort(
          (a, b) => (a['name'] ?? '').toString().compareTo(
            (b['name'] ?? '').toString(),
          ),
        );

      if (!mounted) return;

      if (list.isEmpty) {
        setState(() {
          departments = [];
          selectedDepartmentId = null;
          services = [];
          selectedServiceId = null;
          doctors = [];
          selectedDoctorId = null;
          slots = [];
          recommendedSlots = [];
          loadBalancedDoctors = [];
          selectedSlot = null;
          currentStep = 1;
        });
        return;
      }

      String? pickDept;
      final prefer = preferDepartmentId;
      if (prefer != null && list.any((e) => e['id'].toString() == prefer)) {
        pickDept = prefer;
      } else if (selectedDepartmentId != null &&
          list.any((e) => e['id'].toString() == selectedDepartmentId)) {
        pickDept = selectedDepartmentId;
      } else {
        pickDept = list.first['id']?.toString();
      }

      setState(() {
        departments = list;
        selectedDepartmentId = pickDept;
        selectedServiceId = null;
        selectedDoctorId = null;
        slots = [];
        recommendedSlots = [];
        services = [];
        selectedSlot = null;
        currentStep = 1;
      });

      await _loadServices();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadServices() async {
    final branchId = selectedBranchId;
    final departmentId = selectedDepartmentId;
    if (branchId == null || departmentId == null) return;

    final fetchedServices = await ref
        .read(clinovaApiProvider)
        .getServices(branchId: branchId, departmentId: departmentId);
    final wantService = widget.initialServiceId;
    final servicePick =
        wantService != null &&
            fetchedServices.any((s) => s['id'].toString() == wantService)
        ? wantService
        : (fetchedServices.isNotEmpty
              ? fetchedServices.first['id'].toString()
              : null);

    setState(() {
      services = fetchedServices;
      selectedServiceId = servicePick;
      doctors = const [];
      selectedDoctorId = null;
      slots = const [];
      recommendedSlots = const [];
      loadBalancedDoctors = const [];
      selectedSlot = null;
      currentStep = 1;
    });

    await _loadIntakeSchema();
    await _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    if (selectedServiceId == null) return;

    final fetchedDoctors = await ref
        .read(clinovaApiProvider)
        .getDoctors(
          branchId: selectedBranchId,
          departmentId: selectedDepartmentId,
          serviceId: selectedServiceId,
        );

    final wantDoctor = widget.initialDoctorId;
    final doctorPick =
        wantDoctor != null &&
            fetchedDoctors.any((d) => d['id'].toString() == wantDoctor)
        ? wantDoctor
        : (fetchedDoctors.isNotEmpty
              ? fetchedDoctors.first['id'].toString()
              : null);

    setState(() {
      doctors = fetchedDoctors;
      selectedDoctorId = doctorPick;
      slots = const [];
      recommendedSlots = const [];
      loadBalancedDoctors = const [];
      selectedSlot = null;
      currentStep = 2;
    });

    await _loadSlots();
  }

  Future<void> _loadIntakeSchema() async {
    final serviceId = selectedServiceId;
    if (serviceId == null) {
      if (!mounted) return;
      setState(() {
        intakeFields = const [];
        intakeAnswers.clear();
      });
      return;
    }
    try {
      final schemaRes = await ref
          .read(clinovaApiProvider)
          .getServiceIntakeSchema(serviceId);
      final schema = schemaRes['schema'];
      final fields = <Map<String, dynamic>>[];
      if (schema is List) {
        for (final item in schema) {
          if (item is Map<String, dynamic>) {
            fields.add(item);
          }
        }
      }
      if (!mounted) return;
      setState(() {
        intakeFields = fields;
        intakeAnswers.removeWhere(
          (key, _) => !fields.any((f) => f['id'] == key),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        intakeFields = const [];
        intakeAnswers.clear();
      });
    }
  }

  Future<void> _loadSlots() async {
    if (selectedDoctorId == null || selectedServiceId == null) return;

    setState(() {
      isSlotsLoading = true;
      errorMessage = null;
    });

    try {
      final api = ref.read(clinovaApiProvider);
      final date = DateFormat('yyyy-MM-dd').format(selectedDate);
      final fetchedSlots = await api.getAvailableSlots(
        date: date,
        branchId: selectedBranchId,
        departmentId: selectedDepartmentId,
        serviceId: selectedServiceId,
        doctorId: selectedDoctorId,
      );
      final fetchedRecommended = await api.getRecommendedSlots(
        date: date,
        branchId: selectedBranchId,
        departmentId: selectedDepartmentId,
        serviceId: selectedServiceId,
        doctorId: selectedDoctorId,
        preferredStartHour: 9,
        preferredEndHour: 20,
        limit: 3,
      );
      final fetchedBalancedDoctors = await api.getLoadBalancedDoctors(
        serviceId: selectedServiceId!,
        branchId: selectedBranchId,
        departmentId: selectedDepartmentId,
        limit: 3,
      );

      setState(() {
        slots = fetchedSlots;
        recommendedSlots = fetchedRecommended;
        loadBalancedDoctors = fetchedBalancedDoctors;
        if (currentStep < 2) currentStep = 2;
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isSlotsLoading = false;
        });
      }
    }
  }

  Future<void> _selectSlot(Map<String, dynamic> slot) async {
    if (!ref.read(authControllerProvider).isAuthenticated) {
      await showGuestAuthPrompt(context);
      return;
    }

    if (selectedServiceId == null) return;

    setState(() {
      isBooking = true;
      errorMessage = null;
    });

    try {
      await _releaseActiveLock();
      final lock = await ref
          .read(clinovaApiProvider)
          .acquireSlotLock(
            doctorId: slot['doctorId'].toString(),
            serviceId: selectedServiceId!,
            startsAt: slot['startsAt'].toString(),
          );
      if (!mounted) return;
      setState(() {
        selectedSlot = slot;
        activeSlotLockId = lock['lockId']?.toString();
        currentStep = 3;
      });
      await _confirmSelectedSlot();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isBooking = false;
        });
      }
    }
  }

  Future<void> _confirmSelectedSlot() async {
    if (selectedSlot == null || selectedServiceId == null) return;
    final slotLockId = activeSlotLockId;
    if (slotLockId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.aptSlotLockExpired)));
      return;
    }

    setState(() {
      isBooking = true;
      errorMessage = null;
    });

    try {
      final slot = selectedSlot!;
      final result = await ref
          .read(clinovaApiProvider)
          .createAppointment(
            doctorId: slot['doctorId'].toString(),
            serviceId: selectedServiceId!,
            startsAt: slot['startsAt'].toString(),
            reason: reasonController.text.trim().isEmpty
                ? null
                : reasonController.text.trim(),
            slotLockId: slotLockId,
            intakeAnswers: intakeAnswers,
            withPaymentIntent: true,
          );
      activeSlotLockId = null;

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.aptBookedSuccess)));
      final paymentIntent = result['paymentIntent'];
      if (paymentIntent is Map) {
        final mode = paymentIntent['mode']?.toString() ?? 'mock';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.aptPaymentIntentCreated(mode))),
        );
      }

      await _loadSlots();
      if (ref.read(authControllerProvider).isAuthenticated) {
        final appointmentsResponse = await ref
            .read(clinovaApiProvider)
            .getAppointments(status: 'PENDING');
        setState(() {
          selectedSlot = null;
          currentStep = 2;
          upcomingAppointments =
              (appointmentsResponse['items'] as List?)
                  ?.cast<Map<String, dynamic>>() ??
              const [];
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      await _clearSlotSelection();
      if (mounted) {
        setState(() => currentStep = 2);
      }
    } finally {
      if (mounted) {
        setState(() {
          isBooking = false;
        });
      }
    }
  }

  String _displayBranch(AppLocalizations l10n) {
    final id = selectedBranchId;
    if (id == null) return l10n.aptTapToChoose;
    for (final b in branches) {
      if (b['id'].toString() == id) {
        return b['name']?.toString() ?? l10n.aptTapToChoose;
      }
    }
    return l10n.aptTapToChoose;
  }

  String _displayDepartment(AppLocalizations l10n) {
    final id = selectedDepartmentId;
    if (id == null) return l10n.aptTapToChoose;
    for (final d in departments) {
      if (d['id'].toString() == id) {
        return d['name']?.toString() ?? l10n.aptTapToChoose;
      }
    }
    return l10n.aptTapToChoose;
  }

  String _displayService(AppLocalizations l10n) {
    final id = selectedServiceId;
    if (id == null) return l10n.aptTapToChoose;
    for (final s in services) {
      if (s['id'].toString() == id) {
        return s['name']?.toString() ?? l10n.aptTapToChoose;
      }
    }
    return l10n.aptTapToChoose;
  }

  String _displayDoctor(AppLocalizations l10n) {
    final id = selectedDoctorId;
    if (id == null) return l10n.aptTapToChoose;
    for (final doc in doctors) {
      if (doc['id'].toString() == id) {
        final name =
            '${doc['user']?['firstName'] ?? ''} ${doc['user']?['lastName'] ?? ''}'
                .trim();
        return name.isEmpty ? l10n.aptTapToChoose : name;
      }
    }
    return l10n.aptTapToChoose;
  }

  Future<String?> _showOptionSheet({
    required BuildContext context,
    required String title,
    required List<({String id, String label})> options,
    String? selectedId,
  }) {
    final theme = Theme.of(context);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.42,
          minChildSize: 0.28,
          maxChildSize: 0.88,
          builder: (context, scrollController) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x220F172A),
                    blurRadius: 24,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.28,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 28),
                      itemCount: options.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: theme.dividerColor.withValues(alpha: 0.25),
                      ),
                      itemBuilder: (c, i) {
                        final o = options[i];
                        final sel = o.id == selectedId;
                        return ListTile(
                          title: Text(
                            o.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: sel
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          onTap: () => Navigator.pop(ctx, o.id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onPickBranch(AppLocalizations l10n) async {
    if (branches.isEmpty) return;
    final options = <({String id, String label})>[
      for (final b in branches)
        (id: b['id'].toString(), label: b['name']?.toString() ?? ''),
    ];
    final id = await _showOptionSheet(
      context: context,
      title: l10n.aptChooseBranch,
      options: options,
      selectedId: selectedBranchId,
    );
    if (!mounted || id == null || id == selectedBranchId) return;
    await _clearSlotSelection();
    setState(() => selectedBranchId = id);
    await _applyBranchSelection();
  }

  Future<void> _onPickDepartment(AppLocalizations l10n) async {
    if (departments.isEmpty) return;
    final options = <({String id, String label})>[
      for (final d in departments)
        (id: d['id'].toString(), label: d['name']?.toString() ?? ''),
    ];
    final id = await _showOptionSheet(
      context: context,
      title: l10n.aptChooseDepartment,
      options: options,
      selectedId: selectedDepartmentId,
    );
    if (!mounted || id == null || id == selectedDepartmentId) return;
    await _clearSlotSelection();
    setState(() => selectedDepartmentId = id);
    await _loadServices();
  }

  Future<void> _onPickService(AppLocalizations l10n) async {
    if (services.isEmpty) return;
    final options = <({String id, String label})>[
      for (final s in services)
        (id: s['id'].toString(), label: s['name']?.toString() ?? ''),
    ];
    final id = await _showOptionSheet(
      context: context,
      title: l10n.aptChooseService,
      options: options,
      selectedId: selectedServiceId,
    );
    if (!mounted || id == null || id == selectedServiceId) return;
    await _clearSlotSelection();
    setState(() => selectedServiceId = id);
    await _loadDoctors();
  }

  Future<void> _onPickDoctor(AppLocalizations l10n) async {
    if (doctors.isEmpty) return;
    final options = <({String id, String label})>[
      for (final doc in doctors)
        (
          id: doc['id'].toString(),
          label: () {
            final name =
                '${doc['user']?['firstName'] ?? ''} ${doc['user']?['lastName'] ?? ''}'
                    .trim();
            return name.isEmpty ? l10n.homeFallbackDoctor : name;
          }(),
        ),
    ];
    final id = await _showOptionSheet(
      context: context,
      title: l10n.aptChooseDoctor,
      options: options,
      selectedId: selectedDoctorId,
    );
    if (!mounted || id == null || id == selectedDoctorId) return;
    await _clearSlotSelection();
    setState(() => selectedDoctorId = id);
    await _loadSlots();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: ClinovaBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => popOrGo(
                      context,
                      clinovaNavigationFallback(
                        isAuthenticated:
                            ref.read(authControllerProvider).isAuthenticated,
                        role: ref.read(authControllerProvider).user?.role,
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.aptTitle, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          l10n.aptSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.72),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.calendar_month_rounded, color: cs.primary),
                ],
              ),
              const SizedBox(height: 12),
              if (isCatalogLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (departments.isEmpty && branches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      l10n.aptBranchNoServices,
                      style: TextStyle(
                        color: cs.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                _BookingChoicesCard(
                  l10n: l10n,
                  branchLabel: l10n.aptChooseBranch,
                  branchValue: _displayBranch(l10n),
                  branchFilled: selectedBranchId != null,
                  onBranch: () => _onPickBranch(l10n),
                  branchEnabled: branches.isNotEmpty,
                  departmentLabel: l10n.aptChooseDepartment,
                  departmentValue: _displayDepartment(l10n),
                  departmentFilled: selectedDepartmentId != null,
                  onDepartment: () => _onPickDepartment(l10n),
                  departmentEnabled: departments.isNotEmpty,
                  serviceLabel: l10n.aptChooseService,
                  serviceValue: _displayService(l10n),
                  serviceFilled: selectedServiceId != null,
                  onService: () => _onPickService(l10n),
                  serviceEnabled: services.isNotEmpty,
                  doctorLabel: l10n.aptChooseDoctor,
                  doctorValue: _displayDoctor(l10n),
                  doctorFilled: selectedDoctorId != null,
                  onDoctor: () => _onPickDoctor(l10n),
                  doctorEnabled: doctors.isNotEmpty,
                  reasonTitle: l10n.aptVisitReason,
                  reasonHint: l10n.aptReasonHint,
                  reasonController: reasonController,
                ),
                if (intakeFields.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DynamicIntakeCard(
                    fields: intakeFields,
                    answers: intakeAnswers,
                    onChanged: (id, value) {
                      setState(() {
                        if (value == null ||
                            (value is String && value.trim().isEmpty)) {
                          intakeAnswers.remove(id);
                        } else {
                          intakeAnswers[id] = value;
                        }
                      });
                    },
                  ),
                ],
                if (services.isEmpty &&
                    departments.isNotEmpty &&
                    selectedDepartmentId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      l10n.aptNoServicesForDept,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                _BookingStepBar(currentStep: currentStep, l10n: l10n),
                const SizedBox(height: 12),
                Text(
                  l10n.aptAvailableSlots,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (index) {
                    final date = DateTime.now().add(Duration(days: index));
                    final selected =
                        DateFormat('yyyy-MM-dd').format(date) ==
                        DateFormat('yyyy-MM-dd').format(selectedDate);
                    return ChoiceChip(
                      label: Text(
                        DateFormat('EEE d', l10n.localeName).format(date),
                      ),
                      selected: selected,
                      onSelected: (_) async {
                        await _clearSlotSelection();
                        setState(() {
                          selectedDate = date;
                        });
                        await _loadSlots();
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
                if (recommendedSlots.isNotEmpty) ...[
                  Text(
                    l10n.aptRecommendedTimesTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...recommendedSlots.map(
                    (slot) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SlotCard(
                        slot: slot,
                        isBooking: isBooking,
                        onBook: () => _selectSlot(slot),
                        doctorFallback: l10n.homeFallbackDoctor,
                        bookingLabel: l10n.aptBooking,
                        bookLabel: l10n.aptSelect,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (loadBalancedDoctors.isNotEmpty) ...[
                  Text(
                    l10n.aptSuggestedDoctorsTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final doc in loadBalancedDoctors)
                        ActionChip(
                          label: Text(
                            '${doc['doctorName'] ?? l10n.homeFallbackDoctor} · ${l10n.aptQueueLabel(int.tryParse((doc['activeQueueToday'] ?? doc['doctorLoad'] ?? 0).toString()) ?? 0)}',
                          ),
                          onPressed: () async {
                            final id = doc['doctorId']?.toString();
                            if (id == null || id.isEmpty) return;
                            await _clearSlotSelection();
                            setState(() => selectedDoctorId = id);
                            await _loadSlots();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (isSlotsLoading)
                  const Center(child: CircularProgressIndicator())
                else if (slots.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.aptNoSlots),
                        const SizedBox(height: 10),
                        FilledButton.tonal(
                          onPressed:
                              selectedServiceId == null ||
                                  !ref
                                      .read(authControllerProvider)
                                      .isAuthenticated
                              ? null
                              : () async {
                                  final date = DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(selectedDate);
                                  await ref
                                      .read(clinovaApiProvider)
                                      .joinAppointmentWaitlist(
                                        serviceId: selectedServiceId!,
                                        branchId: selectedBranchId,
                                        departmentId: selectedDepartmentId,
                                        preferredDate: date,
                                        preferredHourStart: 9,
                                        preferredHourEnd: 20,
                                        note: reasonController.text.trim(),
                                      );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.aptAddedToWaitlist),
                                    ),
                                  );
                                },
                          child: Text(l10n.aptJoinWaitingList),
                        ),
                      ],
                    ),
                  )
                else
                  ...slots.map(
                    (slot) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SlotCard(
                        slot: slot,
                        isBooking: isBooking,
                        onBook: () => _selectSlot(slot),
                        doctorFallback: l10n.homeFallbackDoctor,
                        bookingLabel: l10n.aptBooking,
                        bookLabel: l10n.aptSelect,
                      ),
                    ),
                  ),
                if (selectedSlot != null) ...[
                  const SizedBox(height: 12),
                  _BookingConfirmCard(
                    slot: selectedSlot!,
                    l10n: l10n,
                    isBooking: isBooking,
                    onConfirm: _confirmSelectedSlot,
                    onCancel: () async {
                      await _clearSlotSelection();
                      if (!mounted) return;
                      setState(() => currentStep = 2);
                    },
                  ),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ],
                const SizedBox(height: 8),
                Material(
                  color: Colors.white.withValues(alpha: 0.88),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      title: Text(
                        l10n.aptPendingListTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: upcomingAppointments.isEmpty
                          ? null
                          : Text(
                              '${upcomingAppointments.length}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                      children: [
                        if (upcomingAppointments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(l10n.aptNoPending),
                          )
                        else
                          ...upcomingAppointments.map(
                            (appointment) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _MyAppointmentCard(
                                appointment: appointment,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingStepBar extends StatelessWidget {
  const _BookingStepBar({required this.currentStep, required this.l10n});

  final int currentStep;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final labels = [l10n.aptStepDetails, l10n.aptStepTime, l10n.aptStepConfirm];
    return Row(
      children: List.generate(labels.length, (index) {
        final step = index + 1;
        final active = currentStep >= step;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? cs.primary.withValues(alpha: 0.14)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: Text(
                  '$step. ${labels[index]}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: active ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _BookingConfirmCard extends StatelessWidget {
  const _BookingConfirmCard({
    required this.slot,
    required this.l10n,
    required this.isBooking,
    required this.onConfirm,
    required this.onCancel,
  });

  final Map<String, dynamic> slot;
  final AppLocalizations l10n;
  final bool isBooking;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startsAt = DateTime.tryParse(slot['startsAt']?.toString() ?? '');
    final timeLabel = startsAt != null
        ? DateFormat('MMM d, HH:mm', l10n.localeName).format(startsAt)
        : '--';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.aptConfirmBookingTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${slot['doctorName'] ?? ''} • ${slot['departmentName'] ?? ''}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            timeLabel,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isBooking ? null : onCancel,
                  child: Text(l10n.aptChangeSlot),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: isBooking ? null : onConfirm,
                  child: Text(isBooking ? l10n.aptBooking : l10n.aptConfirm),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingChoicesCard extends StatelessWidget {
  const _BookingChoicesCard({
    required this.l10n,
    required this.branchLabel,
    required this.branchValue,
    required this.branchFilled,
    required this.onBranch,
    required this.branchEnabled,
    required this.departmentLabel,
    required this.departmentValue,
    required this.departmentFilled,
    required this.onDepartment,
    required this.departmentEnabled,
    required this.serviceLabel,
    required this.serviceValue,
    required this.serviceFilled,
    required this.onService,
    required this.serviceEnabled,
    required this.doctorLabel,
    required this.doctorValue,
    required this.doctorFilled,
    required this.onDoctor,
    required this.doctorEnabled,
    required this.reasonTitle,
    required this.reasonHint,
    required this.reasonController,
  });

  final AppLocalizations l10n;
  final String branchLabel;
  final String branchValue;
  final bool branchFilled;
  final VoidCallback onBranch;
  final bool branchEnabled;
  final String departmentLabel;
  final String departmentValue;
  final bool departmentFilled;
  final VoidCallback onDepartment;
  final bool departmentEnabled;
  final String serviceLabel;
  final String serviceValue;
  final bool serviceFilled;
  final VoidCallback onService;
  final bool serviceEnabled;
  final String doctorLabel;
  final String doctorValue;
  final bool doctorFilled;
  final VoidCallback onDoctor;
  final bool doctorEnabled;
  final String reasonTitle;
  final String reasonHint;
  final TextEditingController reasonController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final compactWidth = isWide
            ? (constraints.maxWidth - 28 - 10) / 2
            : constraints.maxWidth;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, isWide ? 12 : 14, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_rounded, size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.aptBookingChoicesTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outline.withValues(alpha: 0.22)),
              if (isWide)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: compactWidth,
                        child: _CompactPickTile(
                          label: branchLabel,
                          value: branchValue,
                          isFilled: branchFilled,
                          enabled: branchEnabled,
                          onTap: onBranch,
                          dense: true,
                          boxed: true,
                        ),
                      ),
                      SizedBox(
                        width: compactWidth,
                        child: _CompactPickTile(
                          label: departmentLabel,
                          value: departmentValue,
                          isFilled: departmentFilled,
                          enabled: departmentEnabled,
                          onTap: onDepartment,
                          dense: true,
                          boxed: true,
                        ),
                      ),
                      SizedBox(
                        width: compactWidth,
                        child: _CompactPickTile(
                          label: serviceLabel,
                          value: serviceValue,
                          isFilled: serviceFilled,
                          enabled: serviceEnabled,
                          onTap: onService,
                          dense: true,
                          boxed: true,
                        ),
                      ),
                      SizedBox(
                        width: compactWidth,
                        child: _CompactPickTile(
                          label: doctorLabel,
                          value: doctorValue,
                          isFilled: doctorFilled,
                          enabled: doctorEnabled,
                          onTap: onDoctor,
                          dense: true,
                          boxed: true,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                _CompactPickTile(
                  label: branchLabel,
                  value: branchValue,
                  isFilled: branchFilled,
                  enabled: branchEnabled,
                  onTap: onBranch,
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outline.withValues(alpha: 0.12),
                ),
                _CompactPickTile(
                  label: departmentLabel,
                  value: departmentValue,
                  isFilled: departmentFilled,
                  enabled: departmentEnabled,
                  onTap: onDepartment,
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outline.withValues(alpha: 0.12),
                ),
                _CompactPickTile(
                  label: serviceLabel,
                  value: serviceValue,
                  isFilled: serviceFilled,
                  enabled: serviceEnabled,
                  onTap: onService,
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outline.withValues(alpha: 0.12),
                ),
                _CompactPickTile(
                  label: doctorLabel,
                  value: doctorValue,
                  isFilled: doctorFilled,
                  enabled: doctorEnabled,
                  onTap: onDoctor,
                ),
              ],
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: cs.outline.withValues(alpha: 0.12),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, isWide ? 12 : 14),
                child: TextField(
                  controller: reasonController,
                  maxLines: isWide ? 1 : 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: reasonTitle,
                    hintText: reasonHint,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: isWide ? 10 : 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
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

class _DynamicIntakeCard extends StatelessWidget {
  const _DynamicIntakeCard({
    required this.fields,
    required this.answers,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> fields;
  final Map<String, dynamic> answers;
  final void Function(String id, dynamic value) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    bool shouldShow(Map<String, dynamic> field) {
      final raw = field['showWhen'];
      if (raw is! Map<String, dynamic>) return true;
      final depField = raw['field']?.toString();
      if (depField == null || depField.isEmpty) return true;
      final expected = raw['equals'];
      return answers[depField] == expected;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.aptDynamicIntakeTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final field in fields.where(shouldShow)) ...[
            _DynamicIntakeField(
              field: field,
              value: answers[field['id']?.toString() ?? ''],
              onChanged: (value) =>
                  onChanged(field['id']?.toString() ?? '', value),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _DynamicIntakeField extends StatelessWidget {
  const _DynamicIntakeField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final Map<String, dynamic> field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  String? _mnFallbackLabel(String id) {
    switch (id) {
      case 'mainConcern':
        return 'Гол зовиур';
      case 'symptomDurationDays':
        return 'Шинж тэмдэг хэдэн өдөр үргэлжилж байна вэ?';
      case 'painLevel':
        return 'Өвдөлтийн түвшин (0-10)';
      case 'sensitiveToCold':
        return 'Хүйтэнд мэдрэмтгий юу?';
      case 'painLocation':
        return 'Өвдөлтийн байрлал';
      case 'recentTreatment':
        return 'Сүүлийн шүдний эмчилгээ';
      case 'hasRash':
        return 'Арьсан дээр ил харагдах тууралт байна уу?';
      case 'skinImageUrl':
        return 'Арьсны зураг (URL)';
      case 'itchingLevel':
        return 'Загатнах түвшин (0-10)';
      case 'heightCm':
        return 'Өндөр (см)';
      case 'weightKg':
        return 'Жин (кг)';
      case 'takesMedication':
        return 'Одоогоор эм ууж байгаа юу?';
      case 'shortnessOfBreath':
        return 'Амьсгаадах шинж байна уу?';
      case 'bloodPressure':
        return 'Сүүлийн цусны даралт';
      default:
        return null;
    }
  }

  String _mnOptionLabel(String option) {
    switch (option) {
      case 'Upper left':
        return 'Дээд зүүн';
      case 'Upper right':
        return 'Дээд баруун';
      case 'Lower left':
        return 'Доод зүүн';
      case 'Lower right':
        return 'Доод баруун';
      case 'Front':
        return 'Урд';
      default:
        return option;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMn = context.l10n.localeName.startsWith('mn');
    final id = field['id']?.toString() ?? '';
    final label =
        (isMn ? field['labelMn'] : null)?.toString().trim().isNotEmpty == true
        ? field['labelMn'].toString()
        : (isMn ? _mnFallbackLabel(id) : null) ??
              field['label']?.toString() ??
              id;
    final type = (field['type']?.toString() ?? 'text').toLowerCase();
    if (type == 'boolean') {
      return SwitchListTile.adaptive(
        value: value == true,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
      );
    }
    if (type == 'select') {
      final optionsRaw = field['options'];
      final options = optionsRaw is List
          ? optionsRaw
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList()
          : const <String>[];
      final optionsMnRaw = field['optionsMn'];
      final optionsMn = optionsMnRaw is List
          ? optionsMnRaw
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList()
          : const <String>[];
      return DropdownButtonFormField<String>(
        initialValue: (value?.toString().isNotEmpty ?? false)
            ? value.toString()
            : null,
        items: [
          for (var i = 0; i < options.length; i++)
            DropdownMenuItem<String>(
              value: options[i],
              child: Text(
                isMn
                    ? (i < optionsMn.length
                          ? optionsMn[i]
                          : _mnOptionLabel(options[i]))
                    : options[i],
              ),
            ),
        ],
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: onChanged,
      );
    }
    return TextFormField(
      initialValue: value?.toString() ?? '',
      keyboardType: type == 'number'
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: type == 'image_url' ? 'https://...' : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onChanged: onChanged,
    );
  }
}

class _CompactPickTile extends StatelessWidget {
  const _CompactPickTile({
    required this.label,
    required this.value,
    required this.isFilled,
    required this.enabled,
    required this.onTap,
    this.dense = false,
    this.boxed = false,
  });

  final String label;
  final String value;
  final bool isFilled;
  final bool enabled;
  final VoidCallback onTap;
  final bool dense;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: boxed
          ? cs.surfaceContainerHighest.withValues(alpha: 0.32)
          : Colors.transparent,
      shape: boxed
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cs.outline.withValues(alpha: 0.14)),
            )
          : null,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(boxed ? 14 : 0),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 12 : 16,
            vertical: dense ? 9 : 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style:
                          (dense
                                  ? theme.textTheme.labelSmall
                                  : theme.textTheme.labelMedium)
                              ?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    SizedBox(height: dense ? 2 : 4),
                    Text(
                      value,
                      style:
                          (dense
                                  ? theme.textTheme.bodyMedium
                                  : theme.textTheme.bodyLarge)
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isFilled
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant.withValues(
                                        alpha: 0.85,
                                      ),
                              ),
                      maxLines: dense ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.expand_more_rounded,
                color: enabled
                    ? cs.primary
                    : cs.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.onBook,
    required this.isBooking,
    required this.doctorFallback,
    required this.bookingLabel,
    required this.bookLabel,
  });

  final Map<String, dynamic> slot;
  final VoidCallback onBook;
  final bool isBooking;
  final String doctorFallback;
  final String bookingLabel;
  final String bookLabel;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(slot['startsAt']?.toString() ?? '');
    final locale = context.l10n.localeName;
    final formattedTime = start != null
        ? DateFormat('MMM d, HH:mm', locale).format(start)
        : '--';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot['doctorName']?.toString() ?? doctorFallback,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${slot['departmentName'] ?? ''} • ${slot['branchName'] ?? ''}',
                ),
                const SizedBox(height: 8),
                Text(
                  formattedTime,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: isBooking ? null : onBook,
            child: Text(isBooking ? bookingLabel : bookLabel),
          ),
        ],
      ),
    );
  }
}

class _MyAppointmentCard extends StatelessWidget {
  const _MyAppointmentCard({required this.appointment});

  final Map<String, dynamic> appointment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final doctor = appointment['doctor'] as Map<String, dynamic>? ?? const {};
    final user = doctor['user'] as Map<String, dynamic>? ?? const {};
    final service = appointment['service'] as Map<String, dynamic>? ?? const {};
    final branch = appointment['branch'] as Map<String, dynamic>? ?? const {};
    final start = DateTime.tryParse(appointment['startsAt']?.toString() ?? '');
    final fn = user['firstName']?.toString() ?? '';
    final ln = user['lastName']?.toString() ?? '';
    final locale = l10n.localeName;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service['name']?.toString() ?? l10n.consultationFallback,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(l10n.aptDoctorLabel(fn, ln)),
          const SizedBox(height: 4),
          Text(branch['name']?.toString() ?? ''),
          const SizedBox(height: 8),
          Text(
            start != null
                ? DateFormat('MMM d, HH:mm', locale).format(start)
                : '',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
