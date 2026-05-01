import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/clinova_gallery_image.dart';
import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/network/clinova_api.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/clinova_circle_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/app_user.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _nickname;
  Uint8List? _pickedAvatarBytes;
  bool _clearAvatar = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authControllerProvider).user!;
    _nickname = TextEditingController(text: _seedNickname(u));
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  String _seedNickname(AppUser user) {
    final n = user.nickname?.trim();
    if (n != null && n.isNotEmpty) return n;
    final joined = [user.firstName, user.lastName]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(' ')
        .trim();
    if (joined.isNotEmpty) return joined;
    final email = user.email;
    final at = email.indexOf('@');
    if (at > 0) return email.substring(0, at);
    return email;
  }

  Future<void> _pickPhoto() async {
    final picked = await pickClinovaGalleryJpeg();
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return;
    setState(() {
      _pickedAvatarBytes = bytes;
      _clearAvatar = false;
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = ref.read(clinovaApiProvider);
      String? relativeAvatar;
      if (_pickedAvatarBytes != null) {
        final up = await api.uploadChatAttachment(
          bytes: _pickedAvatarBytes!,
          filename: 'profile.jpg',
        );
        relativeAvatar = up['relativeUrl']?.toString().trim();
        if (relativeAvatar == null || relativeAvatar.isEmpty) {
          final u = up['url']?.toString().trim() ?? '';
          if (u.startsWith('/')) {
            relativeAvatar = u;
          }
        }
      }

      final payload = <String, dynamic>{
        'nickname': _nickname.text.trim(),
      };

      if (_pickedAvatarBytes != null) {
        if (relativeAvatar != null && relativeAvatar.isNotEmpty) {
          payload['avatarUrl'] = relativeAvatar;
        }
      } else if (_clearAvatar) {
        payload['avatarUrl'] = null;
      }

      await api.patchMyProfile(payload);
      await ref.read(authControllerProvider.notifier).reloadCurrentUser();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileEditSavedSnack)));
      context.pop();
    } on DioException {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileEditErrorSnack)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/welcome');
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final avatarNet =
        (_clearAvatar || _pickedAvatarBytes != null)
            ? null
            : user.avatarUrl?.trim();

    final hasNetAvatar =
        avatarNet != null && avatarNet.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileEditTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrGo(context, '/profile'),
        ),
      ),
      body: ClinovaBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              l10n.profileEditSubtitle,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Center(
              child: ClinovaCircleAvatar(
                radius: 56,
                initialsText: _initials(user.displayName),
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                memoryBytes: _pickedAvatarBytes,
                networkUrl:
                    _pickedAvatarBytes != null ? null : (hasNetAvatar ? avatarNet : null),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l10n.profileEditPickPhoto),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() {
                            if (_pickedAvatarBytes != null) {
                              _pickedAvatarBytes = null;
                              return;
                            }
                            if (user.avatarUrl != null &&
                                user.avatarUrl!.trim().isNotEmpty) {
                              _clearAvatar = true;
                            }
                          });
                        },
                  child: Text(l10n.profileEditRemovePhoto),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nickname,
              maxLength: 64,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.profileEditNicknameLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.profileEditSave),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      if (s.length >= 2) return s.substring(0, 2).toUpperCase();
      return s.toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
