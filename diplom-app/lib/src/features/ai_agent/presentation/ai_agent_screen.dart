import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/network/clinova_api.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../auth/application/auth_controller.dart';

const _maxVisionImages = 4;

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

final _starterChips = <String, String>{
  'Цаг яаж авах вэ?': 'Цаг яаж авах вэ?',
  'Эмчтэй чатлах': 'Эмчтэй чат хаана байна, яаж эхлүүлэх вэ?',
  'Халуурч байна': 'Би хэд хоног халуураад, ханиаж байна.',
  'Толгой өвдөж байна': 'Толгой өвдөж, нойр муутай байна.',
  'Яаралтай тусламж': 'Цээж маш хүчтэй өвдөж, амьсгал давчдаж байна.',
};

final _quickActionPrompts = <String, String>{
  'Цаг авах': 'Цаг авахад туслаач',
  'Эмчтэй чатлах': 'Эмчтэй чатлах хэсэг рүү чиглүүлээч',
  'Боломжтой цаг': 'Надад боломжтой цаг шалгаад өгөөч',
  'Яаралтай тусламж': 'Яаралтай тусламж хэрэгтэй бол яах вэ?',
};

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
  '/profile',
  '/settings',
  '/agent',
};

String _fallbackRouteForActionType(String actionType) {
  switch (actionType) {
    case 'BOOK_APPOINTMENT':
      return '/appointments/book';
    case 'SHOW_SERVICES':
    case 'SHOW_DOCTORS':
    case 'SHOW_AVAILABLE_TIMES':
    case 'VIEW_MY_APPOINTMENTS':
      return '/appointments-landing';
    case 'SHOW_BRANCHES':
      return '/branches';
    case 'OPEN_PATIENT_CHAT':
      return '/chat-landing';
    default:
      return '/agent';
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

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage.agent({
        'type': 'GENERAL',
        'answer':
            'Сайн байна уу! Би **Clinova AI** — эрүүл мэндийн зөвлөгөө, апп ашиглах тусламж, шинж тэмдгийн чиглүүлэлт өгнө. Асуултаа бичнэ үү.\n\n'
            'Энэ нь эмчийн онош биш. Хүнд шинж илэрвэл эмч эсвэл яаралтай тусламжид хандана уу.',
        'urgency': 'NONE',
        'recommendedDepartment': null,
        'recommendedDoctors': [],
        'actions': <dynamic>[],
        'safetyDisclaimer': '',
      }),
    );
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
        final a = m.agentPayload!['answer']?.toString() ?? '';
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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _messages.add(
          _ChatMessage.agent({
            'type': 'GENERAL',
            'answer':
                'AI түр хугацаанд хариу өгөх боломжгүй байна. Та дахин оролдоно уу.',
            'urgency': 'NONE',
            'recommendedDepartment': null,
            'recommendedDoctors': [],
            'actions': <dynamic>[],
            'safetyDisclaimer': '',
          }),
        );
      });
    }
    _scrollToEnd();
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

    if (actionType == 'OPEN_EMERGENCY' || route.startsWith('emergency:tel')) {
      final n = params['number'] ?? '102';
      final uri = Uri(scheme: 'tel', path: n);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
      return;
    }

    var path = _normalizeAgentRoute(route);
    if (path.isEmpty || path == '/doctors') {
      path = _fallbackRouteForActionType(actionType);
    }
    if (!mounted) return;

    if (!_knownAgentRoutes.contains(path)) {
      final fallback = _fallbackRouteForActionType(actionType);
      if (fallback.isNotEmpty && _knownAgentRoutes.contains(fallback)) {
        context.push(fallback);
      }
      return;
    }

    if (path == '/appointments/book' && params.isNotEmpty) {
      context.push(Uri(path: path, queryParameters: params).toString());
      return;
    }
    if (path == '/doctor-chat' && params.containsKey('doctorId')) {
      context.push(
        Uri(
          path: path,
          queryParameters: {'doctorId': params['doctorId']!},
        ).toString(),
      );
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
    final backLoc = auth.isAuthenticated ? '/home' : '/welcome';
    final latestAgentPayload = _messages.reversed
        .map((m) => m.agentPayload)
        .whereType<Map<String, dynamic>>()
        .cast<Map<String, dynamic>?>()
        .firstWhere((x) => x != null, orElse: () => null);

    return Scaffold(
      body: ClinovaBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => popOrGo(context, backLoc),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
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
                          Text(
                            'Асуулт, шинж тэмдэг, аппын тусламж',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [_navy, _primaryBlue],
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final showSide = constraints.maxWidth >= 980;
                    final convo = ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      itemCount: _messages.length + (_busy ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_busy && index == _messages.length) {
                          return const _AiTypingSkeleton();
                        }
                        final m = _messages[index];
                        if (m.agentPayload != null) {
                          return _AgentCard(
                            data: m.agentPayload!,
                            onAction: _runAction,
                            onFollowUpTap: (q) => _sendQuickPrompt(q),
                          );
                        }
                        return _UserBubble(
                          caption: m.userCaption ?? 'зураг',
                          imageBytes: m.userImagePreviews,
                        );
                      },
                    );
                    if (!showSide) return convo;
                    return Row(
                      children: [
                        Expanded(flex: 3, child: convo),
                        Container(
                          width: 320,
                          margin: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                          child: _AiSidePanel(
                            latestPayload: latestAgentPayload,
                            onAction: _runAction,
                            onQuestionTap: (q) => _sendQuickPrompt(q),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: _starterChips.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(e.key),
                        backgroundColor: _teal.withValues(alpha: 0.14),
                        side: const BorderSide(color: _cardBorder),
                        onPressed: _busy ? null : () => _sendQuickPrompt(e.value),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: _quickActionPrompts.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilledButton.tonal(
                        onPressed: _busy ? null : () => _sendQuickPrompt(e.value),
                        child: Text(e.key),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  8 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                                      borderRadius: BorderRadius.circular(10),
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
                                      top: -6,
                                      right: -6,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: _teal.withValues(alpha: 0.2),
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
                              hintText: 'Асуулт, зурагтай хамт тайлбар…',
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.95),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: _cardBorder),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _primaryBlue,
                            padding: const EdgeInsets.all(16),
                            shape: const CircleBorder(),
                          ),
                          onPressed: _busy ? null : () => _sendFromComposer(),
                          child: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
          color: _primaryBlue,
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 40, left: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Clinova AI хариулт бэлдэж байна...'),
          ],
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
    final actions = _actionList(p['actions']);
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
    final answer = data['answer']?.toString() ?? '';
    final urgency = data['urgency']?.toString();
    final dept = data['recommendedDepartment']?.toString();
    final doctors = _doctorList(data['recommendedDoctors']);
    final actions = _actionList(data['actions']);
    final services = _serviceList(data['recommendedServices']);
    final branches = _branchList(data['recommendedBranches']);
    final slots = _slotList(data['availableSlots']);
    final followUps = _followUpList(data['followUpQuestions']);
    final disclaimer = data['safetyDisclaimer']?.toString() ?? '';
    final emergency = (urgency ?? '').toUpperCase() == 'EMERGENCY';

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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _softBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Text(
                    type,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _primaryBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (urgency != null &&
                    urgency.isNotEmpty &&
                    urgency.toUpperCase() != 'NONE') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _urgencyColor(urgency).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
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
              ],
            ),
            const SizedBox(height: 10),
            Text(
              answer.replaceAll('**', ''),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF334155),
                height: 1.45,
              ),
            ),
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
                  final isEmergency = type == 'OPEN_EMERGENCY';
                  return FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: isEmergency
                          ? const Color(0xFFFEE2E2)
                          : _primaryBlue.withValues(alpha: 0.12),
                      foregroundColor: isEmergency
                          ? const Color(0xFFB91C1C)
                          : _navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => onAction(a),
                    child: Text(label),
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
