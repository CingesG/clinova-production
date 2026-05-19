import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/network/clinova_api.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat/doctor_chat_route.dart';
import '../../chat/services/doctor_chat_start_service.dart';

const _maxVisionImages = 4;
const _maxChatContentWidth = 720.0;
const _maxShellWidth = 1320.0;

const _primaryBlue = Color(0xFF1769FF);
const _navy = Color(0xFF071B4D);
const _muted = Color(0xFF64748B);
const _teal = Color(0xFF20C7B5);
const _cardBorder = Color(0xFFE6EEF8);
const _softBg = Color(0xFFF6FAFF);

class _ChatMessage {
  _ChatMessage.user({required this.userCaption, this.userImagePreviews}) : agentPayload = null;

  _ChatMessage.agent(this.agentPayload) : userCaption = null, userImagePreviews = null;

  /// User-visible line (fallback `зураг` when sending images only).
  final String? userCaption;

  final List<Uint8List>? userImagePreviews;
  final Map<String, dynamic>? agentPayload;

}

class _PendingAgentImage {
  _PendingAgentImage({required this.bytes, required this.mime});

  final Uint8List bytes;
  final String mime;
}

String _guessMime(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

Future<void> _showFullscreenMemoryImage(BuildContext context, Uint8List bytes) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) {
        final topInset = MediaQuery.paddingOf(ctx).top;
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: topInset + 8,
                left: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    tooltip: 'Буцах',
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

final _premiumQuickChips = <String, String>{
  'Толгой өвдөөд халуурч байна': 'Толгой өвдөөд халуурч байна',
  'Толгой маш өвдөж (латин)': 'tolgoi aimar uwduud bn',
  'Халуураад байна': 'haluurad bna',
  'Зураг үзнэ үү?': 'zurag harsan uu',
  'Арьсан дээр тууралт': 'Арьсан дээр тууралт гарсан',
  'Ямар эмч дээр очих вэ?': 'Ямар эмч дээр очих вэ?',
  'Маргааш цаг аваад өг': 'Маргааш арьсны эмч дээр цаг аваад өг',
  'Эмчтэй чат нээ': 'Эмчтэй чат нээгээд өг',
  'Миний цаг': 'Миний захиалсан цагуудыг харуул',
  'Профайл нээ': 'Миний профайлыг нээ',
  'Цаг захиалмаар байна': 'Цаг захиалмаар байна',
  'Яаралтай тусламж': 'Цээж маш хүчтэй өвдөж, амьсгал давчдаж байна.',
};

const _safetyDisclaimerShort = 'AI зөвлөгөө нь эмчийн оношийг орлохгүй.';

String _intentMnLabel(String? raw) {
  switch ((raw ?? '').trim().replaceAll('-', '_')) {
    case 'symptom_check':
      return 'Шинж тэмдэг';
    case 'image_analysis':
      return 'Зургийн үнэлгээ';
    case 'appointment_help':
      return 'Цаг захиалга';
    case 'doctor_recommendation':
      return 'Эмчийн санал';
    case 'service_info':
      return 'Үйлчилгээ';
    case 'emergency':
      return 'Яаралтай';
    case 'app_help':
      return 'Аппын тусламж';
    case 'general':
      return 'Ерөнхий';
    default:
      return raw ?? '';
  }
}

String _urgencyMn(String? code) {
  switch ((code ?? '').toUpperCase()) {
    case 'LOW':
      return 'Бага эрсдэл';
    case 'MEDIUM':
      return 'Дунд эрсдэл';
    case 'HIGH':
      return 'Өндөр эрсдэл';
    case 'EMERGENCY':
      return 'Яаралтай тусламж';
    case 'NONE':
      return 'Тодорхойгүй';
    default:
      return code ?? '—';
  }
}

Color _urgencyColor(String? code) {
  switch ((code ?? '').toUpperCase()) {
    case 'LOW':
      return const Color(0xFF16A34A);
    case 'MEDIUM':
      return const Color(0xFFF59E0B);
    case 'HIGH':
      return const Color(0xFFF97316);
    case 'EMERGENCY':
      return const Color(0xFFEF4444);
    default:
      return _muted;
  }
}

List<Map<String, dynamic>> _doctorList(dynamic raw) {
  if (raw is! List) return [];
  return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

List<Map<String, dynamic>> _actionList(dynamic raw) {
  if (raw is! List) return [];
  return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

List<Map<String, dynamic>> _serviceList(dynamic raw) {
  if (raw is! List) return [];
  return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

List<Map<String, dynamic>> _branchList(dynamic raw) {
  if (raw is! List) return [];
  return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

List<String> _followUpList(dynamic raw) {
  if (raw is! List) return [];
  return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
}

List<Map<String, dynamic>> _slotList(dynamic raw) {
  if (raw is! List) return [];
  return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

String _humanDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
}

String _normalizeAgentRoute(String route) {
  if (route.startsWith('emergency:')) return route;
  var r = route.trim();
  if (r.startsWith('/app')) {
    r = r.replaceFirst(RegExp(r'^/app'), '');
    if (r.isEmpty) return '/';
    if (!r.startsWith('/')) r = '/$r';
  }
  return r;
}

const _knownAgentRoutes = <String>{
  '/home',
  '/appointments-landing',
  '/appointments',
  '/appointments/book',
  '/doctor-chat',
  '/chat-landing',
  '/branches',
  '/emergency',
  '/profile',
  '/settings',
  '/agent',
};

bool _isAllowedAgentPath(String path) {
  if (path.startsWith('emergency:')) return true;
  if (_knownAgentRoutes.contains(path)) return true;
  if (path.startsWith('/doctor-profile/')) return true;
  return false;
}

String _fallbackRouteForActionType(String actionType) {
  switch (actionType) {
    case 'BOOK_APPOINTMENT':
      return '/appointments/book';
    case 'SHOW_SERVICES':
    case 'SHOW_DOCTORS':
    case 'SHOW_AVAILABLE_TIMES':
      return '/appointments-landing';
    case 'VIEW_MY_APPOINTMENTS':
      return '/appointments';
    case 'SHOW_BRANCHES':
      return '/branches';
    case 'OPEN_PATIENT_CHAT':
      return '/chat-landing';
    default:
      return '/agent';
  }
}

/// Word-chunk reveal + markdown (premium feel; response is already complete from API).
class _RevealingAgentMarkdown extends StatefulWidget {
  const _RevealingAgentMarkdown({required this.data});

  final String data;

  @override
  State<_RevealingAgentMarkdown> createState() => _RevealingAgentMarkdownState();
}

class _RevealingAgentMarkdownState extends State<_RevealingAgentMarkdown> {
  String _visible = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_animate()));
  }

  @override
  void didUpdateWidget(covariant _RevealingAgentMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _visible = '';
      unawaited(_animate());
    }
  }

  Future<void> _animate() async {
    final t = widget.data;
    if (t.isEmpty) return;
    const step = 18;
    for (var i = 0; i <= t.length; i += step) {
      if (!mounted) return;
      final end = i > t.length ? t.length : i;
      setState(() => _visible = t.substring(0, end));
      await Future<void>.delayed(const Duration(milliseconds: 12));
    }
    if (mounted) setState(() => _visible = t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF334155),
        height: 1.45,
      ),
      strong: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF0F172A),
        fontWeight: FontWeight.w800,
        height: 1.45,
      ),
      listBullet: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF334155),
      ),
    );
    return MarkdownBody(
      data: _visible,
      styleSheet: sheet,
      shrinkWrap: true,
      selectable: true,
    );
  }
}

/// Small professional mark: medical cross / care — no sparkle.
class _MedicalAiAvatar extends StatelessWidget {
  const _MedicalAiAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F766E),
            _primaryBlue,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.medical_services_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}

class _PremiumAiEmptyState extends StatelessWidget {
  const _PremiumAiEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MedicalAiAvatar(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Сайн байна уу, би Clinova AI',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: _navy,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Шинж тэмдэг тайлбарлах, зураг дээр урьдчилсан зөвлөгөө өгөх, зөв эмч/тасаг санал болгоно.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF475569),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _safetyDisclaimerShort,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _muted,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 520;
              const gap = 10.0;

              Widget featureCard(String title, String subtitle, IconData icon) {
                return Container(
                  width: narrow ? double.infinity : null,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 22, color: const Color(0xFF0F766E)),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: _navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    featureCard(
                      'Зураг шинжилгээ',
                      'Тууралт, шарх, эмийн шошго зэргийг ерөнхий үнэлнэ.',
                      Icons.image_search_rounded,
                    ),
                    const SizedBox(height: gap),
                    featureCard(
                      'Шинж тэмдэг асуумж',
                      'Нэг нэгээр нь асууж, танд тохирох чиглэл өгнө.',
                      Icons.chat_bubble_outline_rounded,
                    ),
                    const SizedBox(height: gap),
                    featureCard(
                      'Цаг захиалга чиглүүлэлт',
                      'Тасаг, эмч, боломжит цаг руу тань удирдана.',
                      Icons.event_available_rounded,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: featureCard(
                      'Зураг шинжилгээ',
                      'Тууралт, шарх, эмийн шошго зэргийг ерөнхий үнэлнэ.',
                      Icons.image_search_rounded,
                    ),
                  ),
                  const SizedBox(width: gap),
                  Expanded(
                    child: featureCard(
                      'Шинж тэмдэг асуумж',
                      'Нэг нэгээр нь асууж, танд тохирох чиглэл өгнө.',
                      Icons.chat_bubble_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: gap),
                  Expanded(
                    child: featureCard(
                      'Цаг захиалга чиглүүлэлт',
                      'Тасаг, эмч, боломжит цаг руу тань удирдана.',
                      Icons.event_available_rounded,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class AiAgentScreen extends ConsumerStatefulWidget {
  const AiAgentScreen({super.key});

  @override
  ConsumerState<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends ConsumerState<AiAgentScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  final List<_PendingAgentImage> _pendingImages = [];
  bool _busy = false;
  String? _conversationId;
  String _retryMessageText = '';
  final List<Map<String, dynamic>> _retryImagesPayload = [];
  bool _chatStartBusy = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<Map<String, String>> _historyFromMessages(List<_ChatMessage> msgs) {
    final out = <Map<String, String>>[];
    for (final m in msgs) {
      if (m.agentPayload != null) {
        final p = m.agentPayload!;
        final rawAns = p['answerText'] ?? p['answer'];
        final a = rawAns?.toString().trim() ?? '';
        if (a.isNotEmpty) {
          out.add({'role': 'assistant', 'content': a});
        }
      } else if (m.userCaption != null || (m.userImagePreviews?.isNotEmpty ?? false)) {
        final n = m.userImagePreviews?.length ?? 0;
        final tag = n > 0 ? '[зураг:$n] ' : '';
        final raw = (m.userCaption ?? '').trim();
        out.add({
          'role': 'user',
          'content': '$tag${raw.isEmpty && n > 0 ? 'зураг' : raw}',
        });
      }
    }
    return out.length > 20 ? out.sublist(out.length - 20) : out;
  }

  Future<void> _runAgentConversation({
    required String outgoingText,
    required List<_PendingAgentImage> outgoingImages,
  }) async {
    final previews = outgoingImages.map((e) => e.bytes).toList();
    final caption = outgoingImages.isEmpty
        ? outgoingText.trim()
        : (outgoingText.trim().isEmpty ? 'зураг' : outgoingText.trim());

    final priorHistory = _historyFromMessages(_messages);
    setState(() {
      _messages.add(
        _ChatMessage.user(
          userCaption: caption,
          userImagePreviews: previews.isEmpty ? null : previews,
        ),
      );
      _busy = true;
      _retryImagesPayload.clear();
      _retryMessageText = '';
    });
    _scrollToEnd();

    final locale = Localizations.localeOf(context).languageCode;
    final auth = ref.read(authControllerProvider);

    final imagesPayload = outgoingImages
        .map(
          (e) => <String, dynamic>{
            'base64': base64Encode(e.bytes),
            'mime': e.mime,
          },
        )
        .toList();

    try {
      final data = await ref.read(clinovaApiProvider).agentChat(
            message: outgoingText.trim(),
            images: imagesPayload.isEmpty ? null : imagesPayload,
            conversationId: _conversationId,
            userId: auth.user?.id,
            context: {
              if (auth.user?.id != null) 'userId': auth.user!.id,
              'language': locale,
              'currentScreen': 'ai',
              'history': priorHistory,
            },
          );
      if (!mounted) return;
      setState(() {
        final cid = data['conversationId']?.toString();
        if (cid != null && cid.isNotEmpty) {
          _conversationId = cid;
        }
        _messages.add(_ChatMessage.agent(data));
        _busy = false;
        _retryImagesPayload.clear();
        _retryMessageText = '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (_messages.isNotEmpty && _messages.last.userCaption != null) {
          _messages.removeLast();
        }
        _retryMessageText = outgoingText.trim();
        _retryImagesPayload
          ..clear()
          ..addAll(
            imagesPayload.map((e) => Map<String, dynamic>.from(e)).toList(),
          );
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Холболт алдаатай. Дахин оролдоно уу.'),
          action: SnackBarAction(
            label: 'Дахин',
            onPressed: _retryFromLastFailure,
          ),
        ),
      );
    }
    _scrollToEnd();
  }

  Future<void> _retryFromLastFailure() async {
    if (_busy) return;
    final text = _retryMessageText;
    if (text.isEmpty && _retryImagesPayload.isEmpty) return;
    final imgs = <_PendingAgentImage>[];
    for (final m in _retryImagesPayload) {
      final b64 = m['base64']?.toString() ?? '';
      final mime = m['mime']?.toString() ?? 'image/jpeg';
      if (b64.isEmpty) continue;
      try {
        final bytes = base64Decode(b64);
        if (bytes.isEmpty) continue;
        imgs.add(_PendingAgentImage(bytes: bytes, mime: mime));
      } catch (_) {
        continue;
      }
    }
    await _runAgentConversation(outgoingText: text, outgoingImages: imgs);
  }

  Future<void> _sendQuickPrompt(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _busy) return;
    setState(() => _pendingImages.clear());
    await _runAgentConversation(outgoingText: trimmed, outgoingImages: []);
  }

  Future<void> _sendFromComposer() async {
    final trimmed = _input.text.trim();
    final imgs = [..._pendingImages];
    if ((trimmed.isEmpty && imgs.isEmpty) || _busy) return;

    _input.clear();
    setState(() => _pendingImages.clear());
    await _runAgentConversation(outgoingText: trimmed, outgoingImages: imgs);
  }

  Future<void> _pickImagesForComposer() async {
    if (_busy) return;
    final remain = _maxVisionImages - _pendingImages.length;
    if (remain <= 0) return;

    try {
      final picks = await ImagePicker().pickMultiImage(
        imageQuality: 82,
        maxWidth: 1920,
      );
      if (picks.isEmpty || !mounted) return;

        for (final p in picks.take(remain)) {
          final bytes = await p.readAsBytes();
          if (bytes.isEmpty) continue;
          final mime = _guessMime(p.name);
          setState(() {
            _pendingImages.add(_PendingAgentImage(bytes: bytes, mime: mime));
          });
        }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Зураг сонгох үед алдаа гарлаа.')),
      );
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _startDoctorChatFlow(String? doctorProfileId) async {
    final id = doctorProfileId?.trim();
    if (id == null || id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Эмчийн мэдээлэл дутуу байна.')),
      );
      return;
    }
    if (_chatStartBusy) return;

    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      if (mounted) await context.push('/auth/login');
      return;
    }

    setState(() => _chatStartBusy = true);
    try {
      if (kDebugMode) {
        debugPrint('[AiAgent][StartChat] doctorProfileId=$id');
      }
      final flags = await ref
          .read(clinovaApiProvider)
          .getChatPermissionFlags(doctorIds: [id]);
      final pf = flags[id];
      final canChat = pf?['canChat'] == true;
      final pending = pf?['pendingRequest'] == true;
      if (!canChat) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pending
                  ? 'Таны чат хүсэлт хүлээгдэж байна.'
                  : 'Энэ эмчтэй чат эхлүүлэхийн тулд эхлээд цаг авах эсвэл чат зөвшөөрөл хэрэгтэй.',
            ),
          ),
        );
        return;
      }

      final res = await ref
          .read(doctorChatStartServiceProvider)
          .startDoctorChat(id);
      if (kDebugMode) {
        debugPrint(
          '[AiAgent][StartChat] conversationId=${res['id']} doctorId=${res['doctorId']}',
        );
      }
      final path = doctorChatDetailLocationFromStartResponse(res);
      if (!mounted) return;
      context.push(path);
    } on FormatException catch (e) {
      if (kDebugMode) {
        debugPrint('[AiAgent][StartChat] bad API response: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Чат эхлүүлэхэд алдаа гарлаа. Дахин оролдоно уу.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(DoctorChatStartService.userMessageForStartFailure(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _chatStartBusy = false);
    }
  }

  Future<void> _runAction(Map<String, dynamic> action) async {
    final actionType = action['type']?.toString() ?? '';
    final payload = action['payload'];
    final payloadMap = payload is Map
        ? Map<String, dynamic>.from(payload)
        : const <String, dynamic>{};
    final route = (payloadMap['route'] ?? action['route'])?.toString() ?? '';
    final rawParams = action['params'];
    final rawPayloadParams = payloadMap['params'];
    final params = <String, String>{};
    if (rawPayloadParams is Map) {
      rawPayloadParams.forEach((k, v) {
        final s = v?.toString() ?? '';
        if (s.isNotEmpty && s != 'null') {
          params[k.toString()] = s;
        }
      });
    }
    if (rawParams is Map) {
      rawParams.forEach((k, v) {
        final s = v?.toString() ?? '';
        if (s.isNotEmpty && s != 'null') {
          params[k.toString()] = s;
        }
      });
    }

    if (actionType == 'OPEN_EMERGENCY_PAGE') {
      if (!mounted) return;
      context.push('/emergency');
      return;
    }

    if (actionType == 'OPEN_DOCTOR_CHAT' ||
        actionType == 'START_DOCTOR_CHAT' ||
        actionType.toLowerCase() == 'open_chat_doctor') {
      final docId = params['doctorId'] ?? params['doctorProfileId'];
      await _startDoctorChatFlow(docId?.toString());
      return;
    }

    if (actionType == 'OPEN_EMERGENCY' || route.startsWith('emergency:tel')) {
      final n = params['number'] ?? '103';
      final uri = Uri(scheme: 'tel', path: n);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
      return;
    }

    var path = _normalizeAgentRoute(route);
    if (path.isEmpty || path == '/doctors') {
      path = _fallbackRouteForActionType(actionType);
    }
    if (!mounted) return;

    if (!_isAllowedAgentPath(path)) {
      final fallback = _fallbackRouteForActionType(actionType);
      if (fallback.isNotEmpty && _isAllowedAgentPath(fallback)) {
        context.push(fallback);
      }
      return;
    }

    if (path == '/appointments/book' && params.isNotEmpty) {
      context.push(Uri(path: path, queryParameters: params).toString());
      return;
    }
    if (path == '/doctor-chat') {
      final docId = params['doctorId'] ?? params['doctorProfileId'];
      await _startDoctorChatFlow(docId?.toString());
      return;
    }
    if (path == '/doctor-chat' && !params.containsKey('doctorId')) {
      context.push('/chat-landing');
      return;
    }
    context.push(path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final backLoc = clinovaNavigationFallback(
      isAuthenticated: auth.isAuthenticated,
      role: auth.user?.role,
    );
    final latestAgentPayload = _messages.reversed
        .map((m) => m.agentPayload)
        .whereType<Map<String, dynamic>>()
        .cast<Map<String, dynamic>?>()
        .firstWhere((x) => x != null, orElse: () => null);

    final emptyHero = _messages.isEmpty && !_busy;
    final listItemCount = emptyHero ? 1 : _messages.length + (_busy ? 1 : 0);

    return Stack(
      children: [
        Scaffold(
      backgroundColor: const Color(0xFFE8EEF5),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxShellWidth),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 12, 12),
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: _navy,
                            ),
                            onPressed: () => popOrGo(context, backLoc),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 8),
                          const _MedicalAiAvatar(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.aiTitle,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: _navy,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Шинж тэмдэг, зураг, цаг захиалга дээр тусална',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _muted,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ClinovaBackdrop(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxShellWidth),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final showSide = constraints.maxWidth >= 980;
                      final listView = ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        itemCount: listItemCount,
                        itemBuilder: (context, index) {
                          if (emptyHero) {
                            return const _PremiumAiEmptyState();
                          }
                          if (_busy && index == _messages.length) {
                            return const _AiTypingSkeleton();
                          }
                          final m = _messages[index];
                          if (m.agentPayload != null) {
                            return ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: _maxChatContentWidth),
                              child: _AgentCard(
                                data: m.agentPayload!,
                                onAction: _runAction,
                                onFollowUpTap: (q) => _sendQuickPrompt(q),
                              ),
                            );
                          }
                          return ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: _maxChatContentWidth),
                            child: _UserBubble(
                              caption: m.userCaption ?? 'зураг',
                              imageBytes: m.userImagePreviews,
                            ),
                          );
                        },
                      );
                      if (!showSide) return listView;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: listView,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 10, 12, 12),
                            child: SizedBox(
                              width: 300,
                              child: _AiSidePanel(
                                latestPayload: latestAgentPayload,
                                onAction: _runAction,
                                onQuestionTap: (q) => _sendQuickPrompt(q),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Material(
            color: Colors.white,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.06),
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxChatContentWidth),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      10,
                      12,
                      8 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _premiumQuickChips.entries.map((e) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8, bottom: 4),
                                child: Material(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(999),
                                  child: InkWell(
                                    onTap: _busy ? null : () => _sendQuickPrompt(e.value),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        e.key,
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          color: const Color(0xFF334155),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _safetyDisclaimerShort,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _muted,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_retryMessageText.isNotEmpty || _retryImagesPayload.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.wifi_off_outlined, color: Colors.orange.shade800, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Сүүлийн мессеж илгээгдээгүй.',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: const Color(0xFF9A3412),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _busy ? null : _retryFromLastFailure,
                                      child: const Text('Дахин'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (_pendingImages.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(_pendingImages.length, (i) {
                                  final img = _pendingImages[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: GestureDetector(
                                            onTap: () => _showFullscreenMemoryImage(context, img.bytes),
                                            child: Image.memory(
                                              img.bytes,
                                              width: 64,
                                              height: 64,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: -5,
                                          right: -5,
                                          child: Material(
                                            color: Colors.black87,
                                            shape: const CircleBorder(),
                                            clipBehavior: Clip.antiAlias,
                                            child: IconButton(
                                              visualDensity: VisualDensity.compact,
                                              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                                              padding: EdgeInsets.zero,
                                              icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                              onPressed: _busy
                                                  ? null
                                                  : () {
                                                      setState(() {
                                                        _pendingImages.removeAt(i);
                                                      });
                                                    },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton.filledTonal(
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  foregroundColor: _navy,
                                ),
                                onPressed: _busy || _pendingImages.length >= _maxVisionImages
                                    ? null
                                    : _pickImagesForComposer,
                                icon: const Icon(Icons.add_photo_alternate_outlined),
                                tooltip: 'Зураг нэмэх',
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: TextField(
                                  controller: _input,
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _sendFromComposer(),
                                  decoration: InputDecoration(
                                    hintText: 'Асуултаа бичнэ үү…',
                                    border: InputBorder.none,
                                    isDense: true,
                                    filled: false,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(14),
                                  shape: const CircleBorder(),
                                  elevation: 0,
                                ),
                                onPressed: _busy ? null : () => _sendFromComposer(),
                                child: const Icon(Icons.send_rounded, size: 22),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
        if (_chatStartBusy)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.12),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.caption, this.imageBytes});

  final String caption;
  final List<Uint8List>? imageBytes;

  @override
  Widget build(BuildContext context) {
    final trimmed = caption.trim();
    final thumbs = imageBytes;
    final hasThumbs = thumbs != null && thumbs.isNotEmpty;
    final hideCaption = hasThumbs && trimmed == 'зураг';
    final showCaption = trimmed.isNotEmpty && !hideCaption;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1D4ED8),
              _primaryBlue,
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: _primaryBlue.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasThumbs)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 6,
                children: thumbs
                    .map(
                      (b) => GestureDetector(
                        onTap: () => _showFullscreenMemoryImage(context, b),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            b,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            if (hasThumbs && showCaption)
              const SizedBox(height: 8),
            if (showCaption)
              Text(
                caption,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AiTypingSkeleton extends StatelessWidget {
  const _AiTypingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxChatContentWidth),
        child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 24, left: 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _primaryBlue.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Clinova AI хариулт бэлдэж байна…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _AiSidePanel extends StatelessWidget {
  const _AiSidePanel({
    required this.latestPayload,
    required this.onAction,
    required this.onQuestionTap,
  });

  final Map<String, dynamic>? latestPayload;
  final Future<void> Function(Map<String, dynamic>) onAction;
  final ValueChanged<String> onQuestionTap;

  @override
  Widget build(BuildContext context) {
    final p = latestPayload;
    if (p == null) return const SizedBox.shrink();
    final services = _serviceList(p['recommendedServices']);
    final doctors = _doctorList(p['recommendedDoctors']);
    final slots = _slotList(p['availableSlots']);
    var actions = _actionList(p['actions']);
    if (actions.isEmpty) {
      actions = _actionList(p['suggestedActions']);
    }
    final followUps = _followUpList(p['followUpQuestions']);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: ListView(
        children: [
          Text(
            'AI suggestions',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
          const SizedBox(height: 10),
          if (services.isNotEmpty) ...[
            const Text('Services'),
            const SizedBox(height: 6),
            ...services.take(2).map((s) => Text('• ${s['name']}')),
            const SizedBox(height: 10),
          ],
          if (doctors.isNotEmpty) ...[
            const Text('Doctors'),
            const SizedBox(height: 6),
            ...doctors.take(3).map((d) => Text('• ${d['name']}')),
            const SizedBox(height: 10),
          ],
          if (slots.isNotEmpty) ...[
            const Text('Available slots'),
            const SizedBox(height: 6),
            ...slots
                .take(3)
                .map(
                  (s) => Text('• ${_humanDateTime(s['startsAt']?.toString())}'),
                ),
            const SizedBox(height: 10),
          ],
          if (followUps.isNotEmpty) ...[
            const Text('Follow-up'),
            const SizedBox(height: 6),
            ...followUps
                .take(3)
                .map(
                  (q) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: OutlinedButton(
                      onPressed: () => onQuestionTap(q),
                      child: Text(q, textAlign: TextAlign.left),
                    ),
                  ),
                ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('Quick actions'),
            const SizedBox(height: 6),
            ...actions
                .take(4)
                .map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: FilledButton.tonal(
                      onPressed: () => onAction(a),
                      child: Text(a['label']?.toString() ?? 'Open'),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.data,
    required this.onAction,
    required this.onFollowUpTap,
  });

  final Map<String, dynamic> data;
  final Future<void> Function(Map<String, dynamic>) onAction;
  final ValueChanged<String> onFollowUpTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = data['type']?.toString() ?? 'GENERAL';
    final intentRaw = data['intent']?.toString();
    final intentLabel = (intentRaw != null && intentRaw.isNotEmpty) ? _intentMnLabel(intentRaw) : '';
    final rawAnswer = data['answerText'] ?? data['answer'];
    final answer = rawAnswer?.toString() ?? '';
    final urgency = data['urgency']?.toString();
    final dept = data['recommendedDepartment']?.toString();
    final doctors = _doctorList(data['recommendedDoctors']);
    var actions = _actionList(data['actions']);
    if (actions.isEmpty) {
      actions = _actionList(data['suggestedActions']);
    }
    final services = _serviceList(data['recommendedServices']);
    final branches = _branchList(data['recommendedBranches']);
    final slots = _slotList(data['availableSlots']);
    final followUps = _followUpList(data['followUpQuestions']);
    final disclaimer = data['safetyDisclaimer']?.toString() ?? '';
    final emergency = (urgency ?? '').toUpperCase() == 'EMERGENCY';
    final doctorTypeRaw = data['recommendedDoctorType']?.toString().trim() ?? '';
    final showDoctorType = doctorTypeRaw.isNotEmpty && doctorTypeRaw != 'null' && doctorTypeRaw != '—';
    final imgDisc = data['imageAnalysisDisclaimer'];
    final showImageDisclaimer =
        imgDisc == true || imgDisc?.toString().toLowerCase() == 'true';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 28),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: _cardBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _softBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Text(
                    intentLabel.isNotEmpty ? intentLabel : type,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _primaryBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (urgency != null &&
                    urgency.isNotEmpty &&
                    urgency.toUpperCase() != 'NONE')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _urgencyColor(urgency).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _urgencyMn(urgency),
                      style: TextStyle(
                        color: _urgencyColor(urgency),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _RevealingAgentMarkdown(data: answer),
            if (showImageDisclaimer) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cardBorder),
                ),
                child: Text(
                  'Зураг дээрх дүгнэлт нь урьдчилсан зөвлөмж бөгөөд эмчийн үзлэгийг орлохгүй.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _muted,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (dept != null && dept.isNotEmpty && dept != '—') ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _softBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_hospital_outlined,
                      color: _teal,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Зөвлөмжилсөн тасаг',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _muted,
                            ),
                          ),
                          Text(
                            dept,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: _navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (showDoctorType) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _softBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_search_outlined, color: _primaryBlue, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Зөвлөмжилсөн эмчийн чиглэл',
                            style: theme.textTheme.labelSmall?.copyWith(color: _muted),
                          ),
                          Text(
                            doctorTypeRaw,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: _navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (doctors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Санал болгож буй эмч нар',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ...doctors.take(4).map((d) {
                final docId = normalizeDoctorProfileId(d);
                final name = d['name']?.toString() ?? '';
                final spec = d['specialty']?.toString() ?? '';
                final br = d['branch']?.toString() ?? '';
                final slot = d['nextAvailableSlot']?.toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                        Text(
                          '$spec · $br',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _muted,
                          ),
                        ),
                        if (slot != null && slot.isNotEmpty)
                          Text(
                            'Цаг: ${_humanDateTime(slot)}',
                            style: theme.textTheme.labelSmall,
                          ),
                        if (docId != null) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              TextButton(
                                onPressed: () => unawaited(onAction({
                                  'type': 'OPEN_DOCTOR_PROFILE',
                                  'route': '/doctor-profile/$docId',
                                  'params': <String, dynamic>{},
                                  'payload': {
                                    'route': '/doctor-profile/$docId',
                                    'params': <String, dynamic>{},
                                  },
                                })),
                                child: const Text('Профайл'),
                              ),
                              TextButton(
                                onPressed: () => unawaited(onAction({
                                  'type': 'OPEN_DOCTOR_CHAT',
                                  'route': '/doctor-chat',
                                  'params': {'doctorId': docId},
                                  'payload': {
                                    'route': '/doctor-chat',
                                    'params': {'doctorId': docId},
                                  },
                                })),
                                child: const Text('Чат эхлүүлэх'),
                              ),
                              TextButton(
                                onPressed: () {
                                  final serviceId =
                                      d['serviceId']?.toString() ?? '';
                                  final qp = <String, String>{
                                    'doctorId': docId,
                                    if (serviceId.isNotEmpty)
                                      'serviceId': serviceId,
                                  };
                                  unawaited(onAction({
                                    'type': 'BOOK_APPOINTMENT',
                                    'route': '/appointments/book',
                                    'params': qp,
                                    'payload': {
                                      'route': '/appointments/book',
                                      'params': qp,
                                    },
                                  }));
                                },
                                child: const Text('Цаг авах'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
            if (services.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Санал болгосон үйлчилгээ',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ...services
                  .take(3)
                  .map(
                    (s) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Text(
                        '${s['name'] ?? ''} · ${s['price'] ?? '-'}₮',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
            ],
            if (branches.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Санал болгосон салбар',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: branches
                    .take(3)
                    .map((b) => Chip(label: Text('${b['name'] ?? ''}')))
                    .toList(),
              ),
            ],
            if (slots.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Боломжтой цагууд',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots.take(8).map((slot) {
                  final startsAt = slot['startsAt']?.toString() ?? '';
                  return ActionChip(
                    label: Text(_humanDateTime(startsAt)),
                    onPressed: () {
                      onAction({
                        'type': 'BOOK_APPOINTMENT',
                        'label': 'Цаг авах',
                        'route': '/appointments/book',
                        'params': {
                          if (slot['branchId'] != null)
                            'branchId': slot['branchId'].toString(),
                          if (slot['doctorId'] != null)
                            'doctorId': slot['doctorId'].toString(),
                          if (slot['serviceId'] != null)
                            'serviceId': slot['serviceId'].toString(),
                        },
                        'payload': {
                          'route': '/appointments/book',
                          'params': {
                            if (slot['branchId'] != null)
                              'branchId': slot['branchId'].toString(),
                            if (slot['doctorId'] != null)
                              'doctorId': slot['doctorId'].toString(),
                            if (slot['serviceId'] != null)
                              'serviceId': slot['serviceId'].toString(),
                          },
                        },
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            if (followUps.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Илүү зөв чиглүүлэх асуултууд',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: followUps
                    .map(
                      (q) => ActionChip(
                        label: Text(q),
                        onPressed: () => onFollowUpTap(q),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (emergency) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Яаралтай шинж илэрч болзошгүй. Энгийн чат горимыг үргэлжлүүлэхгүй.',
                        style: TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions.map((a) {
                  final label = a['label']?.toString() ?? 'Үргэлжлүүлэх';
                  final type = a['type']?.toString() ?? '';
                  final isEmergency =
                      type == 'OPEN_EMERGENCY' || type == 'OPEN_EMERGENCY_PAGE';
                  return Material(
                    color: isEmergency
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => onAction(a),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isEmergency
                                ? const Color(0xFFFECACA)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isEmergency ? const Color(0xFFB91C1C) : _navy,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (disclaimer.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                disclaimer,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _muted,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
