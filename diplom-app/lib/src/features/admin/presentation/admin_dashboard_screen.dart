import 'package:diplom_app/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/contact_display.dart';
import '../../../core/localization/context_l10n.dart';
import '../../../core/media/clinova_gallery_image.dart';
import '../../../core/network/clinova_api.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/premium_healthcare_shell.dart';
import '../../auth/application/auth_controller.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  late Future<Map<String, dynamic>> _future;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _dashboardStatsKey = GlobalKey();
  final GlobalKey _jobApplicationsKey = GlobalKey();
  String _roleFilter = 'ALL';

  void _scrollToSection(GlobalKey sectionKey) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = sectionKey.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _future = _loadAdminData();
  }

  Future<Map<String, dynamic>> _loadAdminData() async {
    final api = ref.read(clinovaApiProvider);
    final responses = await Future.wait<dynamic>([
      api.getAdminDashboard(),
      api.getUsers(),
      api.getJobApplications(),
      api.getBranches(),
      api.getDepartments(),
      api.getServices(),
      api.getDoctors(),
    ]);

    return {
      'stats': responses[0] as Map<String, dynamic>,
      'users': responses[1] as Map<String, dynamic>,
      'applications': responses[2] as Map<String, dynamic>,
      'branches': responses[3] as List<Map<String, dynamic>>,
      'departments': responses[4] as List<Map<String, dynamic>>,
      'services': responses[5] as List<Map<String, dynamic>>,
      'doctors': responses[6] as List<Map<String, dynamic>>,
    };
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadAdminData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final status = user['status']?.toString() == 'ACTIVE'
        ? 'INACTIVE'
        : 'ACTIVE';
    await ref
        .read(clinovaApiProvider)
        .updateUser(userId: user['id'].toString(), status: status);
    await _refresh();
  }

  Future<void> _handleUserAction(
    Map<String, dynamic> user,
    String action,
  ) async {
    switch (action) {
      case 'toggle_status':
        await _toggleUserStatus(user);
        break;
      case 'reset_password':
        await _resetDoctorPassword(user);
        break;
    }
  }

  Future<void> _resetDoctorPassword(Map<String, dynamic> user) async {
    final role = user['role']?.toString() ?? '';
    if (role != 'DOCTOR') return;
    final email = user['email']?.toString() ?? '';
    final controller = TextEditingController(text: 'ClinovaDoctor123!');
    final newPassword = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Эмчийн нууц үг шинэчлэх'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              email.isEmpty ? 'Doctor account' : email,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Шинэ password',
                hintText: 'Хамгийн багадаа 8 тэмдэгт',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Хадгалах'),
          ),
        ],
      ),
    );
    if (newPassword == null || newPassword.trim().length < 8) return;
    await ref.read(clinovaApiProvider).updateUser(
          userId: user['id'].toString(),
          password: newPassword.trim(),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Password шинэчлэгдлээ: ${email.isEmpty ? 'doctor' : email}'),
      ),
    );
    await _refresh();
  }

  Future<void> _updateApplicationStatus(
    Map<String, dynamic> application,
    String status,
  ) async {
    await ref
        .read(clinovaApiProvider)
        .updateJobApplication(
          applicationId: application['id'].toString(),
          status: status,
        );
    await _refresh();
  }

  Future<void> _showCreateBranchDialog() async {
    final loc = AppLocalizations.of(context);
    final name = TextEditingController();
    final code = TextEditingController();
    final address = TextEditingController();
    final city = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final openingHours = TextEditingController(text: 'Mon-Sat 08:00-20:00');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(loc.adminCreateBranchTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: loc.adminLabelName),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: code,
                  decoration: InputDecoration(labelText: loc.adminLabelCode),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: address,
                  decoration: InputDecoration(labelText: loc.adminLabelAddress),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: city,
                  decoration: InputDecoration(labelText: loc.adminLabelCity),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phone,
                  decoration: InputDecoration(labelText: loc.adminLabelPhone),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: email,
                  decoration: InputDecoration(labelText: loc.authEmailLabel),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: openingHours,
                  decoration: InputDecoration(
                    labelText: loc.adminLabelOpeningHours,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(loc.adminCancel),
            ),
            FilledButton(
              onPressed: () async {
                await ref.read(clinovaApiProvider).createBranch({
                  'name': name.text.trim(),
                  'code': code.text.trim(),
                  'address': address.text.trim(),
                  'city': city.text.trim(),
                  'contactPhone': phone.text.trim(),
                  'contactEmail': email.text.trim(),
                  'openingHours': openingHours.text.trim(),
                  'status': 'ACTIVE',
                });
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                await _refresh();
              },
              child: Text(loc.adminCreate),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateServiceDialog(
    List<Map<String, dynamic>> branches,
    List<Map<String, dynamic>> departments,
  ) async {
    final loc = AppLocalizations.of(context);
    final name = TextEditingController();
    final description = TextEditingController();
    final price = TextEditingController(text: '60000');
    final duration = TextEditingController(text: '30');
    String? branchId = branches.isNotEmpty
        ? branches.first['id'].toString()
        : null;
    String? departmentId = departments.isNotEmpty
        ? departments.first['id'].toString()
        : null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(loc.adminCreateServiceTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: loc.adminLabelName,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: branchId,
                      items: branches
                          .map(
                            (branch) => DropdownMenuItem<String>(
                              value: branch['id'].toString(),
                              child: Text(
                                branch['name'].toString(),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setLocalState(() => branchId = value),
                      decoration: InputDecoration(
                        labelText: loc.adminLabelBranch,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: departmentId,
                      items: departments
                          .map(
                            (department) => DropdownMenuItem<String>(
                              value: department['id'].toString(),
                              child: Text(
                                department['name'].toString(),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setLocalState(() => departmentId = value),
                      decoration: InputDecoration(
                        labelText: loc.adminLabelDepartment,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: description,
                      decoration: InputDecoration(
                        labelText: loc.adminLabelDescription,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.adminLabelPrice,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: duration,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.adminLabelDuration,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(loc.adminCancel),
                ),
                FilledButton(
                  onPressed: () async {
                    await ref.read(clinovaApiProvider).createService({
                      'name': name.text.trim(),
                      'description': description.text.trim(),
                      'branchId': branchId,
                      'departmentId': departmentId,
                      'price': int.tryParse(price.text.trim()) ?? 0,
                      'durationMinutes':
                          int.tryParse(duration.text.trim()) ?? 30,
                      'status': 'ACTIVE',
                    });
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                    await _refresh();
                  },
                  child: Text(loc.adminCreate),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateDoctorDialog(
    List<Map<String, dynamic>> branches,
    List<Map<String, dynamic>> departments,
    List<Map<String, dynamic>> services,
  ) async {
    final loc = AppLocalizations.of(context);
    final username = TextEditingController();
    final email = TextEditingController();
    final temporaryPassword = TextEditingController();
    final firstName = TextEditingController();
    final lastName = TextEditingController();
    final avatarUrl = TextEditingController();
    final bio = TextEditingController();
    final fee = TextEditingController(text: '60000');
    final phone = TextEditingController();
    final experienceYears = TextEditingController(text: '5');
    bool autoGeneratePassword = true;
    Uint8List? pickedAvatarBytes;
    String? branchId = branches.isNotEmpty
        ? branches.first['id'].toString()
        : null;
    String? departmentId = departments.isNotEmpty
        ? departments.first['id'].toString()
        : null;
    String? serviceId = services.isNotEmpty
        ? services.first['id'].toString()
        : null;

    final parentCtx = context;
    final snack = ScaffoldMessenger.of(parentCtx);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final filteredServices = services
                .where(
                  (service) => service['branch']?['id']?.toString() == branchId,
                )
                .toList();
            if (filteredServices.isNotEmpty &&
                filteredServices.every(
                  (service) => service['id'].toString() != serviceId,
                )) {
              serviceId = filteredServices.first['id'].toString();
            }

            return AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.medical_information_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(loc.adminCreateDoctorTitle)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: username,
                      decoration: const InputDecoration(
                        labelText: 'Нэвтрэх нэр (login)',
                        hintText: 'doctor.bat',
                        helperText:
                            'Имэйл байхгүй бол энд нэр өгнө; нэвтрэхэд ашиглана.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: email,
                      decoration: const InputDecoration(
                        labelText: 'Имэйл (сонголттой)',
                        hintText: 'doctor@clinova.mn',
                        helperText:
                            'Хоосон бол нэвтрэх нэрээр @clinova.local эмэйл үүснэ.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Нууц үгийг автоматаар үүсгэх'),
                      subtitle: const Text(
                        'Идэвхгүй бол нууц өөрөө оруулна (хамгийн багадаа 12 тэмдэгт).',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: autoGeneratePassword,
                      onChanged: (value) =>
                          setLocalState(() => autoGeneratePassword = value),
                    ),
                    if (!autoGeneratePassword)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: temporaryPassword,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Эмчийн нууц үг (давтагдашгүй)',
                            helperText: 'Хамгийн багадаа 12 тэмдэгт',
                          ),
                        ),
                      ),
                    TextField(
                      controller: firstName,
                      decoration: InputDecoration(labelText: loc.authFirstName),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: lastName,
                      decoration: InputDecoration(labelText: loc.authLastName),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Утас',
                        hintText: '+976XXXXXXXX',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: experienceYears,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Туршлага (жил)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: branchId,
                      items: branches
                          .map(
                            (branch) => DropdownMenuItem<String>(
                              value: branch['id'].toString(),
                              child: Text(
                                branch['name'].toString(),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setLocalState(() => branchId = value),
                      decoration: InputDecoration(
                        labelText: loc.adminLabelBranch,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: departmentId,
                      items: departments
                          .map(
                            (department) => DropdownMenuItem<String>(
                              value: department['id'].toString(),
                              child: Text(
                                department['name'].toString(),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setLocalState(() => departmentId = value),
                      decoration: InputDecoration(
                        labelText: loc.adminLabelDepartment,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: serviceId,
                      items: filteredServices
                          .map(
                            (service) => DropdownMenuItem<String>(
                              value: service['id'].toString(),
                              child: Text(
                                service['name'].toString(),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setLocalState(() => serviceId = value),
                      decoration: InputDecoration(
                        labelText: loc.adminLabelPrimaryService,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bio,
                      decoration: InputDecoration(labelText: loc.adminLabelBio),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final x = await pickClinovaGalleryJpeg();
                              if (x == null) return;
                              final bytes = await x.readAsBytes();
                              setLocalState(() {
                                pickedAvatarBytes =
                                    bytes.isEmpty ? null : bytes;
                              });
                            },
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(
                              pickedAvatarBytes != null
                                  ? 'Зураг сонгогдсон'
                                  : 'Зураг сонгох (галлерей)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: avatarUrl,
                      decoration: const InputDecoration(
                        labelText: 'Эсвэл avatar URL',
                        hintText: 'https://.../doctor.jpg',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: fee,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.adminLabelConsultationFee,
                      ),
                    ),
                  ],
                ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(loc.adminCancel),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    if (username.text.trim().isEmpty &&
                        email.text.trim().isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Эмчийн нэвтрэх нэр эсвэл имэйл заавал.',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    final trimmedPass = temporaryPassword.text.trim();
                    if (!autoGeneratePassword) {
                      if (trimmedPass.length < 12) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Нууц хамгийн багадаа 12 тэмдэгт байх ёстой.',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                    }
                    setLocalState(() => isSubmitting = true);
                    String? resolvedAvatar;
                    final avatarBytes = pickedAvatarBytes;
                    if (avatarBytes != null && avatarBytes.isNotEmpty) {
                      try {
                        final up = await ref
                            .read(clinovaApiProvider)
                            .uploadChatAttachment(
                              bytes: avatarBytes,
                              filename: 'doctor-avatar.jpg',
                            );
                        resolvedAvatar =
                            up['relativeUrl']?.toString().trim();
                        if (resolvedAvatar == null ||
                            resolvedAvatar.isEmpty) {
                          final u = up['url']?.toString().trim() ?? '';
                          if (u.startsWith('/')) resolvedAvatar = u;
                        }
                      } on DioException {
                        if (context.mounted) {
                          setLocalState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Зураг upload амжилтгүй.'),
                            ),
                          );
                        }
                        return;
                      }
                    }
                    if (resolvedAvatar == null &&
                        avatarUrl.text.trim().isNotEmpty) {
                      resolvedAvatar = avatarUrl.text.trim();
                    }

                    try {
                      final created = await ref
                          .read(clinovaApiProvider)
                          .createDoctor({
                            'username': username.text.trim(),
                            if (email.text.trim().isNotEmpty)
                              'email': email.text.trim(),
                            'firstName': firstName.text.trim(),
                            'lastName': lastName.text.trim(),
                            if (phone.text.trim().isNotEmpty)
                              'phoneNumber': phone.text.trim(),
                            'experienceYears':
                                int.tryParse(experienceYears.text.trim()) ?? 0,
                            'branchId': branchId,
                            'departmentId': departmentId,
                            'bio': bio.text.trim(),
                            'consultationFee':
                                int.tryParse(fee.text.trim()) ?? 0,
                            'avatarUrl': resolvedAvatar,
                            'serviceIds': serviceId == null ? [] : [serviceId],
                            'active': true,
                            'autoGeneratePassword': autoGeneratePassword,
                            if (!autoGeneratePassword)
                              'temporaryPassword': trimmedPass,
                          });
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();
                      final credentials =
                          created['provisionedCredentials']
                              as Map<String, dynamic>?;
                      final userMap =
                          created['user'] as Map<String, dynamic>?;
                      final nameParts = <String>[
                        userMap?['firstName']?.toString().trim() ?? '',
                        userMap?['lastName']?.toString().trim() ?? '',
                      ].where((s) => s.isNotEmpty).toList();
                      final doctorFullName =
                          nameParts.isEmpty ? 'Эмч' : nameParts.join(' ');
                      if (credentials != null && parentCtx.mounted) {
                        final loginId =
                            credentials['loginId']?.toString() ?? '';
                        final tempPw =
                            credentials['temporaryPassword']?.toString() ??
                                '';
                        final clipboardText = [
                          'Нэвтрэх ID: $loginId',
                          'Түр зуурын нууц үг: $tempPw',
                        ].join('\n');
                        await showDialog<void>(
                          context: parentCtx,
                          barrierDismissible: false,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Эмчийн бүртгэл үүслээ'),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    doctorFullName,
                                    style: Theme.of(ctx).textTheme.titleLarge
                                        ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Нэвтрэх мэдээлэл зөвхөн энэ удаа харагдана. Хуулж хадгална уу.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(ctx)
                                          .colorScheme
                                          .tertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Theme.of(ctx)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.65),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Theme.of(ctx)
                                            .colorScheme
                                            .outlineVariant,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: SelectableText(
                                        'Нэвтрэх ID: $loginId\n'
                                        'Түр зуурын нууц үг: $tempPw',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: clipboardText),
                                  );
                                  snack.showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Нэвтрэх мэдээлэл хуулагдлаа.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label:
                                    const Text('Нэвтрэх мэдээлэл хуулах'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Болсон'),
                              ),
                            ],
                          ),
                        );
                      }
                      await _refresh();
                    } on DioException catch (e) {
                      if (context.mounted) {
                        setLocalState(() => isSubmitting = false);
                        var msg = 'Эмчийн бүртгэл үүсгэхэд алдаа гарлаа.';
                        final data = e.response?.data;
                        if (data is Map && data['message'] != null) {
                          msg = data['message'].toString();
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                      }
                    }
                  },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(loc.adminCreate),
                ),
              ],
            );
          },
        );
      },
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
                'Админ цэс',
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
              leading: const Icon(Icons.add_business_rounded),
              title: const Text('Салбар нэмэх'),
              onTap: () {
                Navigator.of(context).pop();
                _showCreateBranchDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.medical_services_rounded),
              title: const Text('Үйлчилгээ нэмэх'),
              onTap: () async {
                Navigator.of(context).pop();
                final data = await _loadAdminData();
                final branches =
                    (data['branches'] as List?)?.cast<Map<String, dynamic>>() ??
                    const <Map<String, dynamic>>[];
                final departments =
                    (data['departments'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    const <Map<String, dynamic>>[];
                if (!mounted) return;
                await _showCreateServiceDialog(branches, departments);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_rounded),
              title: const Text('Эмч нэмэх'),
              onTap: () async {
                Navigator.of(context).pop();
                final data = await _loadAdminData();
                final branches =
                    (data['branches'] as List?)?.cast<Map<String, dynamic>>() ??
                    const <Map<String, dynamic>>[];
                final departments =
                    (data['departments'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    const <Map<String, dynamic>>[];
                final services =
                    (data['services'] as List?)?.cast<Map<String, dynamic>>() ??
                    const <Map<String, dynamic>>[];
                if (!mounted) return;
                await _showCreateDoctorDialog(branches, departments, services);
              },
            ),
            const Divider(height: 26),
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

  Widget _buildMobileUsersList(List<Map<String, dynamic>> filteredUsers) {
    return Column(
      children: filteredUsers.take(20).map((userItem) {
        final role = userItem['role']?.toString() ?? 'PATIENT';
        final status = userItem['status']?.toString() ?? 'ACTIVE';
        final name =
            '${userItem['firstName'] ?? ''} ${userItem['lastName'] ?? ''}'
                .trim();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? '-' : name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userItem['email']?.toString() ?? '-',
                style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'Утас: ${displayMnRegisteredPhone(Map<String, dynamic>.from(userItem))}',
                style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _RoleBadge(role: role),
                  _StatusBadge(status: status),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleUserAction(userItem, value),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'toggle_status',
                        child: Text(
                          status == 'ACTIVE'
                              ? 'Идэвхгүй болгох'
                              : 'Идэвхжүүлэх',
                        ),
                      ),
                      if (role == 'DOCTOR')
                        const PopupMenuItem(
                          value: 'reset_password',
                          child: Text('Password солих'),
                        ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        color: Colors.white,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.more_horiz_rounded, size: 18),
                          SizedBox(width: 6),
                          Text('Үйлдэл'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = ref.watch(authControllerProvider).user;
    final isMobile = MediaQuery.of(context).size.width < 760;

    return Scaffold(
      key: _scaffoldKey,
      appBar: isMobile
          ? AppBar(
              title: Text(l10n.adminControlTitle),
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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(snapshot.error.toString()),
                  ),
                );
              }

              final data = snapshot.data ?? const <String, dynamic>{};
              final stats = data['stats'] as Map<String, dynamic>? ?? const {};
              final users =
                  (data['users']?['items'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  const [];
              final applications =
                  (data['applications']?['items'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  const [];
              final branches =
                  (data['branches'] as List?)?.cast<Map<String, dynamic>>() ??
                  const [];
              final departments =
                  (data['departments'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  const [];
              final services =
                  (data['services'] as List?)?.cast<Map<String, dynamic>>() ??
                  const [];
              final doctors =
                  (data['doctors'] as List?)?.cast<Map<String, dynamic>>() ??
                  const [];
              final query = _searchController.text.trim().toLowerCase();
              final filteredUsers = users.where((userItem) {
                final role = userItem['role']?.toString() ?? '';
                final email = userItem['email']?.toString() ?? '';
                final fullName =
                    '${userItem['firstName'] ?? ''} ${userItem['lastName'] ?? ''}'
                        .trim();
                final roleMatch = _roleFilter == 'ALL' || role == _roleFilter;
                final phoneHay = '${userItem['phoneNumber']} ${userItem['phone']}';
                final searchMatch =
                    query.isEmpty ||
                    email.toLowerCase().contains(query) ||
                    fullName.toLowerCase().contains(query) ||
                    phoneHay.toLowerCase().contains(query);
                return roleMatch && searchMatch;
              }).toList();

              return RefreshIndicator(
                onRefresh: _refresh,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 12 : 20,
                        isMobile ? 12 : 18,
                        isMobile ? 12 : 20,
                        32,
                      ),
                      children: [
                        PremiumDashboardHeader(
                          title: l10n.adminControlTitle,
                          subtitle:
                              'Clinova системийн ерөнхий хяналтын самбар',
                          namePill: user?.displayName ?? l10n.adminDefaultName,
                          narrow: isMobile,
                          showIconActions: !isMobile,
                          onRefresh: _refresh,
                          onLogout: () => ref
                              .read(authControllerProvider.notifier)
                              .logout(),
                        ),
                        const SizedBox(height: 18),
                        _AdminHero(key: _dashboardStatsKey, stats: stats, l10n: l10n),
                        const SizedBox(height: 16),
                        PremiumSectionCard(
                          title: 'Шуурхай үйлдлүүд',
                          icon: Icons.bolt_rounded,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: ClinovaPremium.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _showCreateBranchDialog,
                                icon: const Icon(Icons.add_business_rounded),
                                label: Text(l10n.adminAddBranch),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: ClinovaPremium.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => _showCreateServiceDialog(
                                  branches,
                                  departments,
                                ),
                                icon: const Icon(
                                  Icons.medical_services_rounded,
                                ),
                                label: Text(l10n.adminAddService),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: ClinovaPremium.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => _showCreateDoctorDialog(
                                  branches,
                                  departments,
                                  services,
                                ),
                                icon: const Icon(Icons.person_add_alt_rounded),
                                label: Text(l10n.adminAddDoctor),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ClinovaPremium.textPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  side: BorderSide(
                                    color: ClinovaPremium.border
                                        .withValues(alpha: 0.9),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () =>
                                    _scrollToSection(_jobApplicationsKey),
                                icon: const Icon(Icons.assignment_rounded),
                                label: const Text('Өргөдөл харах'),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ClinovaPremium.textPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  side: BorderSide(
                                    color: ClinovaPremium.border
                                        .withValues(alpha: 0.9),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () =>
                                    _scrollToSection(_dashboardStatsKey),
                                icon: const Icon(Icons.analytics_rounded),
                                label: const Text('Тайлан харах'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        PremiumSectionCard(
                          title: 'Хэрэглэгчийн удирдлага',
                          icon: Icons.group_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    width: 280,
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                        prefixIcon: Icon(Icons.search_rounded),
                                        labelText: 'Хэрэглэгч хайх...',
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 180,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _roleFilter,
                                      decoration: const InputDecoration(
                                        labelText: 'Бүх role',
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'ALL',
                                          child: Text('Бүх role'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'ADMIN',
                                          child: Text('ADMIN'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'DOCTOR',
                                          child: Text('DOCTOR'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'STAFF',
                                          child: Text('STAFF'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'PATIENT',
                                          child: Text('PATIENT'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(
                                          () => _roleFilter = value ?? 'ALL',
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (filteredUsers.isEmpty)
                                PremiumEmptyState(
                                  icon: Icons.group_off_rounded,
                                  title: 'Одоогоор бүртгэлтэй хэрэглэгч алга.',
                                  subtitle:
                                      'Шүүлтүүр эсвэл хайлтын нөхцөлд тохирох хэрэглэгч олдсонгүй.',
                                )
                              else if (isMobile)
                                _buildMobileUsersList(filteredUsers)
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: ClinovaPremium.border
                                          .withValues(alpha: 0.75),
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                        dividerColor: ClinovaPremium.border
                                            .withValues(alpha: 0.35),
                                      ),
                                      child: DataTable(
                                    headingRowHeight: 48,
                                    dataRowMinHeight: 52,
                                    headingTextStyle: const TextStyle(
                                      color: ClinovaPremium.navy,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('Хэрэглэгч')),
                                      DataColumn(label: Text('Role')),
                                      DataColumn(label: Text('Төлөв')),
                                      DataColumn(label: Text('Имэйл')),
                                      DataColumn(label: Text('Утас')),
                                      DataColumn(label: Text('Үйлдэл')),
                                    ],
                                    rows: filteredUsers.take(20).map((
                                      userItem,
                                    ) {
                                      final role =
                                          userItem['role']?.toString() ??
                                          'PATIENT';
                                      final status =
                                          userItem['status']?.toString() ??
                                          'ACTIVE';
                                      final name =
                                          '${userItem['firstName'] ?? ''} ${userItem['lastName'] ?? ''}'
                                              .trim();
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(name.isEmpty ? '-' : name),
                                          ),
                                          DataCell(_RoleBadge(role: role)),
                                          DataCell(
                                            _StatusBadge(status: status),
                                          ),
                                          DataCell(
                                            Text(
                                              userItem['email']?.toString() ??
                                                  '-',
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              displayMnRegisteredPhone(
                                                Map<String, dynamic>.from(
                                                  userItem,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            PopupMenuButton<String>(
                                              onSelected: (value) =>
                                                  _handleUserAction(
                                                    userItem,
                                                    value,
                                                  ),
                                              itemBuilder: (context) => [
                                                PopupMenuItem(
                                                  value: 'toggle_status',
                                                  child: Text(
                                                    status == 'ACTIVE'
                                                        ? 'Идэвхгүй болгох'
                                                        : 'Идэвхжүүлэх',
                                                  ),
                                                ),
                                                if (role == 'DOCTOR')
                                                  const PopupMenuItem(
                                                    value: 'reset_password',
                                                    child: Text('Password солих'),
                                                  ),
                                              ],
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFCBD5E1,
                                                    ),
                                                  ),
                                                  color: Colors.white,
                                                ),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.more_horiz_rounded,
                                                      size: 18,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text('Үйлдэл'),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        KeyedSubtree(
                          key: _jobApplicationsKey,
                          child: PremiumSectionCard(
                            title: l10n.adminJobApplications,
                            icon: Icons.assignment_rounded,
                            child: applications.isEmpty
                                ? PremiumEmptyState(
                                    icon: Icons.assignment_late_rounded,
                                    title: 'Одоогоор өргөдөл алга.',
                                    subtitle:
                                        'Шинэ ажлын өргөдөл ирэхэд энэ хэсэгт харагдана.',
                                  )
                                : Column(
                                    children:
                                        applications.take(6).map((
                                      application,
                                    ) {
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                          Icons.description_rounded,
                                        ),
                                        title: Text(
                                          application['fullName']
                                                  ?.toString() ??
                                              '',
                                        ),
                                        subtitle: Text(
                                          '${application['desiredRole']} • ${application['status']}',
                                        ),
                                        trailing: PopupMenuButton<String>(
                                          onSelected: (status) =>
                                              _updateApplicationStatus(
                                                application,
                                                status,
                                              ),
                                          itemBuilder: (menuCtx) => [
                                            PopupMenuItem(
                                              value: 'REVIEWING',
                                              child: Text(
                                                  l10n.adminJobReviewing),
                                            ),
                                            PopupMenuItem(
                                              value: 'INTERVIEW',
                                              child: Text(
                                                  l10n.adminJobInterview),
                                            ),
                                            PopupMenuItem(
                                              value: 'ACCEPTED',
                                              child: Text(
                                                  l10n.adminJobAccepted),
                                            ),
                                            PopupMenuItem(
                                              value: 'REJECTED',
                                              child: Text(
                                                  l10n.adminJobRejected),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        PremiumSectionCard(
                          title: 'Салбар, үйлчилгээ, эмчийн товч мэдээлэл',
                          icon: Icons.insights_rounded,
                          child: Column(
                            children: [
                              _miniListTile(
                                icon: Icons.local_hospital_rounded,
                                title: 'Салбар',
                                count: branches.length,
                              ),
                              _miniListTile(
                                icon: Icons.medical_services_rounded,
                                title: 'Үйлчилгээ',
                                count: services.length,
                              ),
                              _miniListTile(
                                icon: Icons.badge_rounded,
                                title: 'Эмч',
                                count: doctors.length,
                              ),
                            ],
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
      drawer: isMobile ? _buildMobileDrawer() : null,
    );
  }

  Widget _miniListTile({
    required IconData icon,
    required String title,
    required int count,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ClinovaPremium.pillBlueBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: ClinovaPremium.primary, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: ClinovaPremium.textPrimary,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ClinovaPremium.surfaceTint,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: ClinovaPremium.border.withValues(alpha: 0.7)),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: ClinovaPremium.primaryInk,
          ),
        ),
      ),
    );
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero({
    super.key,
    required this.stats,
    required this.l10n,
  });

  final Map<String, dynamic> stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    const footer = 'Системийн бодит өгөгдөл';
    final List<(String, String, IconData)> items = [
      (
        l10n.adminHeroUsers,
        stats['totalUsers']?.toString() ?? '0',
        Icons.group_rounded,
      ),
      (
        l10n.adminHeroDoctors,
        stats['totalDoctors']?.toString() ?? '0',
        Icons.badge_rounded,
      ),
      (
        l10n.adminHeroPatients,
        stats['totalPatients']?.toString() ?? '0',
        Icons.personal_injury_rounded,
      ),
      (
        'Өнөөдрийн цаг',
        stats['todayAppointments']?.toString() ?? '0',
        Icons.today_rounded,
      ),
      (
        'Дууссан цаг',
        stats['completedAppointments']?.toString() ?? '0',
        Icons.check_circle_rounded,
      ),
      (
        l10n.adminHeroJobs,
        stats['applicationsCount']?.toString() ?? '0',
        Icons.description_rounded,
      ),
      (
        l10n.adminHeroBranches,
        stats['activeBranches']?.toString() ?? '0',
        Icons.apartment_rounded,
      ),
      (
        'Feedback',
        stats['feedbackCount']?.toString() ?? '0',
        Icons.reviews_rounded,
      ),
      (
        'Дундаж үнэлгээ',
        stats['avgDoctorStars']?.toString() ?? '0',
        Icons.stars_rounded,
      ),
      (
        'Bonus Pool',
        stats['estimatedMonthlyBonusPoolMnt']?.toString() ?? '0',
        Icons.payments_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1150
            ? 5
            : width >= 900
                ? 4
                : width >= 650
                    ? 2
                    : 1;
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 122,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return PremiumStatCard(
              title: item.$1,
              value: item.$2,
              icon: item.$3,
              footer: footer,
            );
          },
        );
      },
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final mapping = switch (role) {
      'ADMIN' => (Color(0xFF7C3AED), 'ADMIN'),
      'DOCTOR' => (Color(0xFF2563EB), 'DOCTOR'),
      'STAFF' => (Color(0xFF16A34A), 'STAFF'),
      _ => (Color(0xFF64748B), 'PATIENT'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: mapping.$1.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        mapping.$2,
        style: TextStyle(
          color: mapping.$1,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'ACTIVE';
    final color = isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

