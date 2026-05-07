import 'dart:async';

import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/formatting/contact_display.dart';
import '../../../core/localization/context_l10n.dart';
import '../../../core/navigation/go_router_pop.dart';
import '../../../core/media/clinova_gallery_image.dart';
import '../../../core/media/doctor_avatar_mapper.dart';
import '../../../core/network/clinova_api.dart';
import '../../../core/network/doctor_chat_dm_room.dart';
import '../../../core/network/pending_inbound_call_provider.dart';
import '../../../core/network/realtime_service.dart';
import '../../../core/network/online_presence_provider.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../../core/widgets/clinova_circle_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../services/chat_attachment_download.dart';
import '../services/clinova_rtc_call_session.dart';
import 'doctor_chat_pick_raw.dart';

class DoctorChatScreen extends ConsumerStatefulWidget {
  const DoctorChatScreen({super.key, this.initialDoctorProfileId});

  /// Doctor profile id (`DoctorProfile.id`) from deep link / AI triage.
  final String? initialDoctorProfileId;

  @override
  ConsumerState<DoctorChatScreen> createState() => _DoctorChatScreenState();
}

class _DoctorChatScreenState extends ConsumerState<DoctorChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final messages = <Map<String, dynamic>>[];

  List<Map<String, dynamic>> doctors = const [];
  Map<String, dynamic>? lockedOutDoctor;
  Map<String, int> unreadByContact = const {};
  Map<String, dynamic>? selectedDoctor;
  String activeRoomId = '';
  bool loadingDoctors = true;
  bool loadingMessages = false;
  String? loadError;

  StreamSubscription<Map<String, dynamic>>? _chatSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  StreamSubscription<Map<String, dynamic>>? _callSub;
  StreamSubscription<Map<String, dynamic>>? _chatRequestResolvedSub;
  Timer? _typingDebounce;
  String? typingUserId;
  ClinovaRtcCallSession? _rtcSession;
  bool _attachmentBusy = false;
  AudioRecorder? _voiceRecorder;
  Completer<void>? _voiceFingerRelease;
  bool _recordingVoiceHud = false;

  /// One room per signed-in patient + doctor so messages are not shared across patients.
  String _roomForPatientAndDoctor({
    required String patientUserId,
    required String doctorProfileId,
  }) => 'room-$patientUserId-doc-$doctorProfileId';

  static const Map<String, String> _mnSpecialtyMap = {
    'cardiology': 'Зүрх судас',
    'dentistry': 'Шүд',
    'dermatology': 'Арьс',
    'pediatrics': 'Хүүхэд',
    'ent': 'Чих, хамар, хоолой',
    'internal medicine': 'Дотор',
    'neurology': 'Мэдрэл',
    'gynecology': 'Эх барих, эмэгтэйчүүд',
    'orthopedics': 'Үе мөч, яс',
    'surgery': 'Мэс засал',
    'ophthalmology': 'Нүд',
    'urology': 'Урологи',
  };

  String _doctorDisplayName(Map<String, dynamic> d) {
    final u = d['user'];
    if (u is Map<String, dynamic>) {
      final fn = u['firstName']?.toString().trim() ?? '';
      final ln = u['lastName']?.toString().trim() ?? '';
      final full = '$fn $ln'.trim();
      if (full.isNotEmpty) return full;
    }
    final name = d['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    return d['id']?.toString() ?? '';
  }

  String? _doctorUserId(Map<String, dynamic> d) {
    final patientUserId = d['patientUserId']?.toString();
    if (patientUserId != null && patientUserId.isNotEmpty) return patientUserId;
    final u = d['user'];
    if (u is Map<String, dynamic>) {
      final id = u['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  String? _doctorAvatarUrl(Map<String, dynamic> d) {
    final u = d['user'];
    if (u is Map<String, dynamic>) {
      final url = u['avatarUrl']?.toString().trim();
      if (url != null && url.isNotEmpty) return url;
    }
    final top = d['avatarUrl']?.toString().trim();
    if (top != null && top.isNotEmpty) return top;
    return null;
  }

  String? _normalizeAttachmentUrl(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final base = Uri.tryParse(AppConfig.apiBaseUrl);
    if (base == null) return value;
    final fixedPath = value.startsWith('/') ? value : '/$value';
    return base.resolve(fixedPath).toString();
  }

  String _localizedSpecialty(String raw, String locale) {
    final value = raw.trim();
    if (value.isEmpty || !locale.startsWith('mn')) return value;
    final lower = value.toLowerCase();
    for (final e in _mnSpecialtyMap.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return value;
  }

  String _contactSubtitle(
    Map<String, dynamic> contact,
    bool isDoctorRole,
    String locale,
  ) {
    if (isDoctorRole) {
      final raw = contact['user'];
      Map<String, dynamic>? u;
      if (raw is Map<String, dynamic>) {
        u = raw;
      } else if (raw is Map) {
        u = Map<String, dynamic>.from(raw);
      }
      final phoneLabel = displayMnRegisteredPhone(u);
      final svc = contact['serviceName']?.toString().trim() ?? '';
      final specialty = svc.isNotEmpty
          ? _localizedSpecialty(svc, locale)
          : 'Өвчтөн';
      return '$specialty · Өвчтөний утас: $phoneLabel';
    }
    final dept = contact['department'];
    final deptName = dept is Map<String, dynamic>
        ? dept['name']?.toString().trim() ?? ''
        : contact['departmentName']?.toString().trim() ?? '';
    return _localizedSpecialty(deptName, locale);
  }

  String? get _patientUserId {
    final id = ref.read(authControllerProvider).user?.id;
    if (id == null || id.isEmpty) return null;
    return id;
  }

  String? _contactKeyForDoctor(
    Map<String, dynamic> contact,
    bool isDoctorRole,
  ) {
    if (isDoctorRole) {
      final id =
          contact['patientUserId']?.toString() ?? contact['id']?.toString();
      return (id == null || id.isEmpty) ? null : id;
    }
    final id = contact['id']?.toString();
    return (id == null || id.isEmpty) ? null : id;
  }

  String? _contactKeyFromIncomingMessage(Map<String, dynamic> data) {
    final senderId = data['senderId']?.toString();
    final myId = _patientUserId;
    if (senderId == null || senderId.isEmpty || senderId == myId) return null;
    final role = ref.read(authControllerProvider).user?.role ?? 'PATIENT';
    final isDoctorRole = role == 'DOCTOR';
    if (isDoctorRole) {
      // Doctor inbox keys by patient userId.
      return senderId;
    }
    // Patient inbox keys by doctor profile id.
    for (final d in doctors) {
      final userId = _doctorUserId(d);
      if (userId == senderId) {
        final key = d['id']?.toString();
        if (key != null && key.isNotEmpty) return key;
      }
    }
    final roomId = data['roomId']?.toString() ?? '';
    final marker = '-doc-';
    final idx = roomId.lastIndexOf(marker);
    if (idx == -1) return null;
    final docId = roomId.substring(idx + marker.length).trim();
    return docId.isEmpty ? null : docId;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _resetRtcSession() async {
    await _rtcSession?.disposeSession();
    _rtcSession = null;
  }

  Future<void> _disposeRtcQuiet() async {
    await _resetRtcSession();
  }

  ClinovaRtcCallSession ensureRtcPeer() {
    final my = _patientUserId;
    final peer = selectedDoctor != null ? _doctorUserId(selectedDoctor!) : null;
    if (my == null || peer == null || activeRoomId.isEmpty) {
      throw StateError('RTC requires contact + room.');
    }
    _rtcSession ??= ClinovaRtcCallSession(
      realtime: ref.read(realtimeServiceProvider),
      selfUserId: my,
      peerUserId: peer,
      roomId: activeRoomId,
      onPhaseChanged: () {
        if (mounted) setState(() {});
      },
    );
    return _rtcSession!;
  }

  Future<void> _tryFlushInboundAfterDoctorsLoaded() async {
    final pending = ref.read(pendingInboundCallSignalProvider);
    if (!mounted || pending == null) return;
    final event = pending['event']?.toString() ?? '';
    if (event != 'call:offer') return;
    ref.read(pendingInboundCallSignalProvider.notifier).state = null;
    await _routeCallSignal(Map<String, dynamic>.from(pending));
  }

  Map<String, dynamic>? _findContactForRoom(String roomId) {
    final parsed = parseDoctorChatDmRoom(roomId);
    if (parsed == null) return null;
    final user = ref.read(authControllerProvider).user;
    final role = user?.role ?? 'PATIENT';
    final isDoctorRole = role == 'DOCTOR';
    final myId = user?.id.trim() ?? '';
    final myDocId = user?.doctorProfileId?.trim() ?? '';

    if (!isDoctorRole) {
      if (parsed.patientUserId != myId) return null;
      for (final d in doctors) {
        if (d['id']?.toString() == parsed.doctorProfileId) return d;
      }
      return null;
    }

    if (myDocId.isEmpty || parsed.doctorProfileId != myDocId) {
      return null;
    }
    for (final d in doctors) {
      final pu = d['patientUserId']?.toString().trim() ?? '';
      if (pu.isNotEmpty && pu == parsed.patientUserId) return d;
      final alt = _doctorUserId(d)?.trim() ?? '';
      if (alt.isNotEmpty && alt == parsed.patientUserId) return d;
    }
    return null;
  }

  Future<void> _routeCallSignal(Map<String, dynamic> data) async {
    final roomId = (data['roomId'] ?? '').toString();
    final myId = _patientUserId;
    if (myId == null || roomId.isEmpty) return;

    final event = data['event']?.toString() ?? '';

    if (event != 'call:offer') {
      if (roomId != activeRoomId) return;
      await _handleRealtimeCall(data);
      return;
    }

    final toUid = data['toUserId']?.toString();
    if (toUid != myId) return;

    if (roomId == activeRoomId) {
      await _handleRealtimeCall(data);
      return;
    }

    final contact = _findContactForRoom(roomId);
    if (contact == null) return;

    await _resetRtcSession();
    await _selectDoctor(contact);
    if (!mounted) return;
    if ((data['roomId'] ?? '').toString() != activeRoomId) return;
    await _handleRealtimeCall(data);
  }

  Future<void> _handleRealtimeCall(Map<String, dynamic> data) async {
    final event = data['event']?.toString() ?? '';
    if (_patientUserId == null) return;

    ClinovaRtcCallSession rtc;
    try {
      rtc = ensureRtcPeer();
    } catch (_) {
      return;
    }

    switch (event) {
      case 'call:offer':
        final toUid = data['toUserId']?.toString();
        if (toUid != _patientUserId) return;
        await rtc.onInboundOffer(data, isForMe: true);
        break;
      case 'call:answer':
        await rtc.handleRemoteAnswer(data['sdp']);
        break;
      case 'call:ice':
        await rtc.addRemoteIceCandidate(data['candidate']);
        break;
      case 'call:end':
        await rtc.hangup(skipSocket: true);
        break;
    }
  }

  Future<void> _startWebRtcCall({required bool video}) async {
    if (_patientUserId == null ||
        selectedDoctor == null ||
        activeRoomId.isEmpty) {
      return;
    }
    final peer = _doctorUserId(selectedDoctor!);
    if (peer == null) return;
    try {
      final rtc = ensureRtcPeer();
      await rtc.ensureRenderers();
      await rtc.startOutbound(video: video);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Дуудлага эхлүүлэхэд алдаа: $e')));
    }
  }

  Future<void> _saveAttachmentToDisk(String urlHint, String fileHint) async {
    final resolved = _normalizeAttachmentUrl(urlHint) ?? urlHint;
    try {
      await downloadChatAttachment(
        api: ref.read(clinovaApiProvider),
        resolvedUrl: resolved,
        suggestedName: fileHint.isNotEmpty ? fileHint : 'clinova_file',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Файл хадгалагдлаа.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Татахад алдаа гарлаа.')));
    }
  }

  @override
  void initState() {
    super.initState();
    final realtime = ref.read(realtimeServiceProvider);
    _chatSub = realtime.chatMessageStream.listen((data) {
      if (!mounted) return;
      final roomId = (data['roomId'] ?? '').toString();
      if (roomId != activeRoomId) {
        final key = _contactKeyFromIncomingMessage(data);
        if (key != null && key.isNotEmpty) {
          setState(() {
            unreadByContact = {
              ...unreadByContact,
              key: (unreadByContact[key] ?? 0) + 1,
            };
          });
        }
        return;
      }
      final id = data['id']?.toString();
      if (id != null && messages.any((m) => m['id']?.toString() == id)) {
        return;
      }
      setState(() {
        messages.add(data);
      });
      _scrollToBottom();
    });
    _typingSub = realtime.typingStream.listen((data) {
      if (!mounted) return;
      if ((data['roomId'] ?? '').toString() != activeRoomId) return;
      setState(() {
        typingUserId = data['isTyping'] == true
            ? data['userId']?.toString()
            : null;
      });
    });
    _callSub = realtime.callSignalStream.listen((data) {
      if (!mounted) return;
      unawaited(_routeCallSignal(data));
    });
    _chatRequestResolvedSub =
        realtime.chatRequestResolvedStream.listen((data) {
      if (!mounted) return;
      if (data['outcome']?.toString() == 'ACCEPTED') {
        unawaited(_loadDoctors());
      }
    });
    Future<void>.microtask(_loadDoctors);
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _typingSub?.cancel();
    _callSub?.cancel();
    _chatRequestResolvedSub?.cancel();
    _typingDebounce?.cancel();
    final rel = _voiceFingerRelease;
    if (rel != null && !rel.isCompleted) {
      rel.complete();
    }
    final vr = _voiceRecorder;
    _voiceRecorder = null;
    if (vr != null) {
      unawaited(vr.dispose());
    }
    unawaited(_disposeRtcQuiet());
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      loadingDoctors = true;
      loadError = null;
    });
    try {
      final api = ref.read(clinovaApiProvider);
      final authState = ref.read(authControllerProvider);
      final role = authState.user?.role ?? 'PATIENT';
      final isDoctorRole = role == 'DOCTOR';
      final authedPatient = authState.isAuthenticated && role == 'PATIENT';

      final list = isDoctorRole
          ? await _loadDoctorPatients()
          : (authedPatient
              ? await api.getPatientAllowedChatDoctors()
              : await api.getDoctors());

      if (!mounted) return;

      final presetId = widget.initialDoctorProfileId?.trim();
      Map<String, dynamic>? presetDoctor;
      Map<String, dynamic>? lockedDoc;
      if (presetId != null && presetId.isNotEmpty) {
        for (final d in list) {
          if (d['id']?.toString() == presetId) {
            presetDoctor = d;
            break;
          }
        }
        if (authedPatient && presetDoctor == null) {
          try {
            lockedDoc = await api.getDoctor(presetId);
          } catch (_) {}
        }
      }

      final initialUnread = <String, int>{};
      for (final d in list) {
        final key = _contactKeyForDoctor(d, isDoctorRole);
        if (key != null) initialUnread[key] = unreadByContact[key] ?? 0;
      }

      setState(() {
        doctors = list;
        unreadByContact = initialUnread;
        lockedOutDoctor = lockedDoc;
        loadingDoctors = false;
      });

      if (list.isEmpty && lockedDoc == null) {
        setState(() {
          selectedDoctor = null;
          activeRoomId = '';
          messages.clear();
        });
        return;
      }

      final patientId = _patientUserId;
      final pick = presetDoctor ?? (list.isNotEmpty ? list.first : null);

      if (lockedDoc != null && pick == null) {
        setState(() {
          selectedDoctor = null;
          activeRoomId = '';
          messages.clear();
        });
        return;
      }

      if (pick != null) {
        if (patientId != null) {
          await _selectDoctor(pick);
        } else {
          setState(() {
            selectedDoctor = pick;
            activeRoomId = '';
            messages.clear();
          });
        }
      }

      if (mounted) {
        await _tryFlushInboundAfterDoctorsLoaded();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadError = e.toString();
        loadingDoctors = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadDoctorPatients() async {
    final contacts = await ref.read(clinovaApiProvider).getDoctorPatients();
    contacts.sort((a, b) {
      final aVisited = a['hasVisitedDoctor'] == true ? 1 : 0;
      final bVisited = b['hasVisitedDoctor'] == true ? 1 : 0;
      if (aVisited != bVisited) return bVisited.compareTo(aVisited);
      final aLast = a['lastAppointmentAt']?.toString() ?? '';
      final bLast = b['lastAppointmentAt']?.toString() ?? '';
      if (aLast != bLast) return bLast.compareTo(aLast);
      final aName = _doctorDisplayName(a).toLowerCase();
      final bName = _doctorDisplayName(b).toLowerCase();
      return aName.compareTo(bName);
    });
    return contacts;
  }

  Future<void> _promptChatRequest(String doctorProfileId) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Чат хүсэлт илгээх'),
        content: TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Шалтгаан (заавал биш)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Илгээх'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await ref.read(clinovaApiProvider).createDoctorChatRequest(
              doctorProfileId: doctorProfileId,
              note: note.text.trim().isEmpty ? null : note.text.trim(),
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Чат хүсэлт илгээгдлээ.')),
          );
          setState(() => lockedOutDoctor = null);
          await _loadDoctors();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      }
    }
    note.dispose();
  }

  Widget _buildLockedOutDoctorPanel(ThemeData theme, ColorScheme cs) {
    final d = lockedOutDoctor!;
    final docId = d['id']?.toString() ?? '';
    final name = _doctorDisplayName(d);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Энэ эмчтэй чатлахын тулд цаг захиалах эсвэл чат хүсэлт илгээнэ үү.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: const Color(0xFF334155),
                ),
              ),
              if (name.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: docId.isEmpty
                          ? null
                          : () => context.push(
                                Uri(
                                  path: '/appointments/book',
                                  queryParameters: {'doctorId': docId},
                                ).toString(),
                              ),
                      child: const Text('Цаг захиалах'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: docId.isEmpty
                          ? null
                          : () => unawaited(_promptChatRequest(docId)),
                      child: const Text('Чат хүсэлт илгээх'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDoctor(Map<String, dynamic> doctor) async {
    final user = ref.read(authControllerProvider).user;
    final role = user?.role ?? 'PATIENT';
    final isDoctorRole = role == 'DOCTOR';
    final myUserId = _patientUserId;
    if (myUserId == null) {
      setState(() {
        selectedDoctor = doctor;
        activeRoomId = '';
        messages.clear();
      });
      return;
    }

    String room = '';
    if (isDoctorRole) {
      final myDoctorProfileId = user?.doctorProfileId?.trim() ?? '';
      final patientUserId =
          doctor['patientUserId']?.toString().trim() ??
          _doctorUserId(doctor)?.trim() ??
          '';
      if (myDoctorProfileId.isEmpty || patientUserId.isEmpty) return;
      room = _roomForPatientAndDoctor(
        patientUserId: patientUserId,
        doctorProfileId: myDoctorProfileId,
      );
    } else {
      final docProfileId = doctor['id']?.toString().trim() ?? '';
      if (docProfileId.isEmpty) return;
      room = _roomForPatientAndDoctor(
        patientUserId: myUserId,
        doctorProfileId: docProfileId,
      );
    }

    await _resetRtcSession();

    setState(() {
      selectedDoctor = doctor;
      activeRoomId = room;
      messages.clear();
      loadingMessages = true;
    });

    ref.read(realtimeServiceProvider).joinRoom(room);
    ref
        .read(realtimeServiceProvider)
        .joinCall(room, myUserId, callType: 'voice');

    try {
      final history = await ref.read(clinovaApiProvider).getChatMessages(room);
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(history);
        final key = _contactKeyForDoctor(doctor, isDoctorRole);
        if (key != null) {
          unreadByContact = {...unreadByContact, key: 0};
        }
        loadingMessages = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      var msg = 'Зурвасыг ачаалж чадсангүй.';
      if (e is DioException) {
        final code = e.response?.statusCode;
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          msg = data['message'].toString();
        } else if (code == 403) {
          msg =
              'Эмчтэй чатлахын тулд цаг захиалах эсвэл чат хүсэлтээ зөвшөөрүүлэх шаардлагатай.';
        }
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg)));
      setState(() {
        loadingMessages = false;
      });
    }
  }

  Future<void> _showFeedbackDialog() async {
    final doctor = selectedDoctor;
    if (doctor == null) return;
    final doctorId = doctor['id']?.toString();
    if (doctorId == null || doctorId.isEmpty) return;
    final commentController = TextEditingController();
    int stars = 5;
    int care = 5;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: const Text('Doctor feedback'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Stars: $stars/5'),
                  ),
                  Slider(
                    value: stars.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$stars',
                    onChanged: (value) =>
                        setLocalState(() => stars = value.round()),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Care points: $care/5'),
                  ),
                  Slider(
                    value: care.toDouble(),
                    min: 0,
                    max: 5,
                    divisions: 5,
                    label: '$care',
                    onChanged: (value) =>
                        setLocalState(() => care = value.round()),
                  ),
                  TextField(
                    controller: commentController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Comment (optional)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(clinovaApiProvider)
                      .submitDoctorFeedback(
                        doctorProfileId: doctorId,
                        stars: stars,
                        carePoints: care,
                        comment: commentController.text,
                      );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Thanks! Your feedback was submitted.'),
                    ),
                  );
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        );
      },
    );
    commentController.dispose();
  }

  Future<void> _sendPickedImage() async {
    if (activeRoomId.isEmpty || _patientUserId == null || _attachmentBusy) {
      return;
    }
    setState(() => _attachmentBusy = true);
    try {
      final picked = await pickClinovaGalleryJpeg();
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;
      await _uploadAndSendAttachment(
        messageType: 'IMAGE',
        bytes: bytes,
        filename: picked.name.isNotEmpty ? picked.name : 'photo.jpg',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Зураг сонгох үед алдаа гарлаа.')),
      );
    } finally {
      if (mounted) {
        setState(() => _attachmentBusy = false);
      }
    }
  }

  Future<void> _sendPickedFile({
    String messageType = 'FILE',
    bool audioOnly = false,
  }) async {
    if (activeRoomId.isEmpty || _patientUserId == null || _attachmentBusy) {
      return;
    }
    setState(() => _attachmentBusy = true);
    try {
      final result = await _pickFileSafely(
        allowMultiple: false,
        withData: true,
        type: audioOnly ? FileType.audio : FileType.any,
      );
      final file = result?.files.single;
      if (file == null) return;
      final bytes = await _extractPlatformFileBytes(file);
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл унших боломжгүй байна.')),
        );
        return;
      }
      await _uploadAndSendAttachment(
        messageType: messageType,
        bytes: bytes,
        filename: file.name.isNotEmpty ? file.name : 'attachment.bin',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл сонгох үед алдаа гарлаа.')),
      );
    } finally {
      if (mounted) {
        setState(() => _attachmentBusy = false);
      }
    }
  }

  Future<Uint8List?> _extractPlatformFileBytes(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null && bytes.isNotEmpty) return bytes;
    final stream = file.readStream;
    if (stream != null) {
      final data = <int>[];
      await for (final chunk in stream) {
        data.addAll(chunk);
      }
      if (data.isNotEmpty) return Uint8List.fromList(data);
    }
    if (file.path != null) {
      return XFile(file.path!).readAsBytes();
    }
    return null;
  }

  Future<FilePickerResult?> _pickFileSafely({
    required bool allowMultiple,
    required bool withData,
    required FileType type,
    List<String>? allowedExtensions,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await pickDoctorChatFilesRaw(
          allowMultiple: allowMultiple,
          withData: withData,
          type: type,
          allowedExtensions: allowedExtensions,
        );
      } on PlatformException catch (e) {
        final message = '${e.code} ${e.message}'.toLowerCase();
        if (message.contains('multiple_request') && attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          continue;
        }
        rethrow;
      }
    }
    return null;
  }

  Future<void> _uploadAndSendAttachment({
    required String messageType,
    required Uint8List bytes,
    required String filename,
  }) async {
    if (activeRoomId.isEmpty || _patientUserId == null) return;
    try {
      final uploaded = await ref
          .read(clinovaApiProvider)
          .uploadChatAttachment(bytes: bytes, filename: filename);
      final url = _normalizeAttachmentUrl(uploaded['url']?.toString()) ?? '';
      if (url.isEmpty) return;
      final receiver = selectedDoctor != null
          ? _doctorUserId(selectedDoctor!)
          : null;
      ref
          .read(realtimeServiceProvider)
          .sendMessage(
            activeRoomId,
            _patientUserId!,
            '',
            receiverId: receiver,
            messageType: messageType,
            attachmentUrl: url,
            attachmentName: uploaded['name']?.toString() ?? filename,
            attachmentMime: uploaded['mime']?.toString(),
            attachmentSize: int.tryParse('${uploaded['size'] ?? ''}'),
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Файл илгээх үед алдаа гарлаа. Дахин оролдоно уу.'),
        ),
      );
    }
  }

  Future<void> _openExternal(String url) async {
    final normalized = _normalizeAttachmentUrl(url);
    final uri = Uri.tryParse(normalized ?? url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showImageLightbox(BuildContext context, String url) {
    final resolved = _normalizeAttachmentUrl(url) ?? url;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 0.25,
                maxScale: 5,
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final dpr = MediaQuery.devicePixelRatioOf(context);
                      final mw = (c.biggest.shortestSide * dpr * 2)
                          .round()
                          .clamp(480, 2200);
                      return CachedNetworkImage(
                        imageUrl: resolved,
                        fit: BoxFit.contain,
                        memCacheWidth: mw,
                        fadeInDuration: const Duration(milliseconds: 220),
                        fadeOutDuration: Duration.zero,
                        placeholder: (context, url) => const Padding(
                          padding: EdgeInsets.all(48),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Opacity(
                              opacity: 0.9,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, error, stackTrace) =>
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Зураг ачааллах боломжгүй',
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ),
                      );
                    },
                  ),
                ),
              ),
              SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Татах',
                      icon: const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () async {
                        await _saveAttachmentToDisk(resolved, 'image.jpg');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<({RecordConfig config, String path})> _voiceRecordSetup(
    AudioRecorder recorder,
  ) async {
    if (await recorder.isEncoderSupported(AudioEncoder.aacLc)) {
      final path = await _temporaryVoicePath('m4a');
      return (
        config: const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
    }
    if (await recorder.isEncoderSupported(AudioEncoder.wav)) {
      final path = await _temporaryVoicePath('wav');
      return (
        config: const RecordConfig(encoder: AudioEncoder.wav),
        path: path,
      );
    }
    final path = await _temporaryVoicePath('wav');
    return (config: const RecordConfig(encoder: AudioEncoder.wav), path: path);
  }

  Future<String> _temporaryVoicePath(String extDot) async {
    if (kIsWeb) return 'voice.$extDot';
    final dir = await getTemporaryDirectory();
    return '${dir.path}/clinova_voice_${DateTime.now().millisecondsSinceEpoch}.$extDot';
  }

  AudioRecorder _recorderEnsure() => _voiceRecorder ??= AudioRecorder();

  /// Press and hold mic: records while finger is down; on release uploads as [VOICE] (not text input).
  Future<void> _runVoiceHoldUntilRelease(Completer<void> released) async {
    if (_patientUserId == null ||
        activeRoomId.isEmpty ||
        selectedDoctor == null) {
      return;
    }
    final otherParty = _doctorUserId(selectedDoctor!);
    if (otherParty == null || otherParty.isEmpty) return;

    setState(() => _attachmentBusy = true);
    final recorder = _recorderEnsure();

    Future<void> cancelSafe() async {
      try {
        await recorder.cancel();
      } catch (_) {}
    }

    try {
      if (!await recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Микрофоны зөвшөөрөл хэрэгтэй.')),
          );
        }
        return;
      }
      if (released.isCompleted) return;

      final setup = await _voiceRecordSetup(recorder);
      await recorder.start(setup.config, path: setup.path);

      if (released.isCompleted) {
        await cancelSafe();
        return;
      }

      if (mounted) {
        setState(() => _recordingVoiceHud = true);
      }

      final startedMs = DateTime.now().millisecondsSinceEpoch;
      await released.future;

      final outPath = await recorder.stop();

      final elapsedMs = DateTime.now().millisecondsSinceEpoch - startedMs;
      if (outPath == null || outPath.isEmpty) return;
      if (elapsedMs < 450) return;

      Uint8List bytes;
      try {
        bytes = await XFile(outPath).readAsBytes();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Дууг уншихад алдаа гарлаа.')),
        );
        return;
      }
      if (!mounted || bytes.isEmpty) return;

      final ext = setup.path.toLowerCase().endsWith('.wav') ? 'wav' : 'm4a';
      final fname = 'voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _uploadAndSendAttachment(
        messageType: 'VOICE',
        bytes: bytes,
        filename: fname,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Дуу бичих үед алдаа гарлаа.')),
      );
      await cancelSafe();
    } finally {
      if (mounted) {
        setState(() {
          _recordingVoiceHud = false;
          _attachmentBusy = false;
        });
      } else {
        _recordingVoiceHud = false;
        _attachmentBusy = false;
      }
    }
  }

  void _voicePointerDown() {
    if (activeRoomId.isEmpty ||
        _patientUserId == null ||
        _attachmentBusy ||
        selectedDoctor == null) {
      return;
    }
    if (_voiceFingerRelease != null && !_voiceFingerRelease!.isCompleted) {
      return;
    }
    _voiceFingerRelease = Completer<void>();
    final c = _voiceFingerRelease!;
    unawaited(_runVoiceHoldUntilRelease(c));
  }

  void _voicePointerEnd() {
    final c = _voiceFingerRelease;
    if (c == null || c.isCompleted) return;
    c.complete();
  }

  void _sendCurrentMessage() {
    final myId = _patientUserId ?? '';
    final text = input.text.trim();
    if (myId.isEmpty || activeRoomId.isEmpty || text.isEmpty) return;
    final doc = selectedDoctor;
    final receiver = doc != null ? _doctorUserId(doc) : null;
    ref
        .read(realtimeServiceProvider)
        .sendMessage(activeRoomId, myId, text, receiverId: receiver);
    input.clear();
    ref.read(realtimeServiceProvider).sendTyping(activeRoomId, myId, false);
  }

  String _formatChatTimestamp(Map<String, dynamic> m) {
    final raw = m['sentAt'] ?? m['createdAt'];
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '';
    return DateFormat('MMM d, HH:mm').format(dt.toLocal());
  }

  Widget _buildMessageContent(Map<String, dynamic> m, bool mine) {
    final type = (m['messageType']?.toString() ?? 'TEXT').toUpperCase();
    final textColor = mine ? Colors.white : Colors.black87;
    final text = m['text']?.toString() ?? '';
    final attachmentUrl =
        _normalizeAttachmentUrl(m['attachmentUrl']?.toString()) ?? '';
    if (type == 'IMAGE' && attachmentUrl.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showImageLightbox(context, attachmentUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Builder(
                      builder: (context) {
                        final dpr = MediaQuery.devicePixelRatioOf(context);
                        final mw = (220 * dpr).round().clamp(160, 900);
                        final mh = (140 * dpr).round().clamp(100, 600);
                        return CachedNetworkImage(
                          imageUrl: attachmentUrl,
                          width: 220,
                          height: 140,
                          fit: BoxFit.cover,
                          memCacheWidth: mw,
                          memCacheHeight: mh,
                          fadeInDuration: const Duration(milliseconds: 200),
                          fadeOutDuration: Duration.zero,
                          placeholder: (context, url) => Container(
                            width: 220,
                            height: 140,
                            color: Colors.black12,
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 220,
                            height: 140,
                            color: Colors.black12,
                            alignment: Alignment.center,
                            child: Text(
                              'Image unavailable',
                              style: TextStyle(color: textColor),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Татах',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.download_rounded, color: textColor, size: 22),
                onPressed: () => _saveAttachmentToDisk(
                  attachmentUrl,
                  (m['attachmentName']?.toString().isNotEmpty == true)
                      ? m['attachmentName'].toString()
                      : 'image.jpg',
                ),
              ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(text, style: TextStyle(color: textColor)),
          ],
        ],
      );
    }
    if ((type == 'FILE' || type == 'VOICE') && attachmentUrl.isNotEmpty) {
      final fname = type == 'VOICE'
          ? (m['attachmentName']?.toString().isNotEmpty == true
                ? m['attachmentName'].toString()
                : 'voice.m4a')
          : (m['attachmentName']?.toString().isNotEmpty == true
                ? m['attachmentName'].toString()
                : 'file');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _openExternal(attachmentUrl),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  type == 'VOICE'
                      ? Icons.mic_rounded
                      : Icons.attach_file_rounded,
                  color: textColor,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    fname,
                    style: TextStyle(
                      color: textColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _saveAttachmentToDisk(attachmentUrl, fname),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Татах'),
              style: TextButton.styleFrom(foregroundColor: textColor),
            ),
          ),
        ],
      );
    }
    return Text(text, style: TextStyle(color: textColor));
  }

  bool _rtcCallBarsVisible() {
    final p = _rtcSession?.phase;
    return p != null && p != ChatCallOverlayPhase.idle;
  }

  /// Chat peer: patients see doctor flat-avatar fallback; doctors see patient initials.
  Widget _peerCallAvatar(BuildContext context, {required double radius}) {
    final auth = ref.read(authControllerProvider);
    final isDoctorSide = auth.user?.role == 'DOCTOR';
    final peer = selectedDoctor;
    if (peer == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        child: Icon(
          Icons.person_rounded,
          size: radius * 1.05,
          color: Colors.white,
        ),
      );
    }
    final name = _doctorDisplayName(peer);
    final initial = name.isNotEmpty
        ? String.fromCharCode(name.runes.first).toUpperCase()
        : '?';
    final peerUser = peer['user'];
    final userMap = peerUser is Map<String, dynamic>
        ? peerUser
        : (peerUser is Map ? Map<String, dynamic>.from(peerUser) : null);
    return ClinovaCircleAvatar(
      radius: radius,
      initialsText: initial,
      backgroundColor: Colors.white.withValues(alpha: 0.12),
      foregroundColor: Colors.white,
      networkUrl: isDoctorSide ? _doctorAvatarUrl(peer) : null,
      doctorUseFlatAssetOnly: !isDoctorSide,
      doctorDisplayName: name,
      doctorGender: isDoctorSide ? null : doctorGenderFromMap(userMap),
    );
  }

  Widget _buildCallOverlay() {
    final rtc = _rtcSession;
    if (rtc == null) return const SizedBox.shrink();

    Widget audioOnlyBackdrop({required Widget child}) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF111827), Color(0xFF020617)],
          ),
        ),
        child: child,
      );
    }

    switch (rtc.phase) {
      case ChatCallOverlayPhase.idle:
      case ChatCallOverlayPhase.ending:
        return const SizedBox.shrink();
      case ChatCallOverlayPhase.incoming:
        final peerName = selectedDoctor != null
            ? _doctorDisplayName(selectedDoctor!)
            : '';
        return Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: audioOnlyBackdrop(
              child: SafeArea(
                child: Column(
                  children: [
                    const Spacer(),
                    _peerCallAvatar(context, radius: 44),
                    const SizedBox(height: 14),
                    Icon(
                      Icons.call_received_rounded,
                      size: 56,
                      color: Colors.green.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      peerName.isNotEmpty ? peerName : 'Дуудлага',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ирсэн дуудлага',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FloatingActionButton(
                              heroTag: 'callDecline',
                              backgroundColor: const Color(0xFFDC2626),
                              onPressed: () => rtc.rejectIncoming(),
                              child: const Icon(Icons.call_end_rounded),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Татгалзах',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FloatingActionButton(
                              heroTag: 'callAccept',
                              backgroundColor: const Color(0xFF16A34A),
                              onPressed: () => unawaited(rtc.acceptIncoming()),
                              child: const Icon(Icons.call_rounded),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Хүлээн авах',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      case ChatCallOverlayPhase.outgoing:
        final peerName = selectedDoctor != null
            ? _doctorDisplayName(selectedDoctor!)
            : '';
        final video = rtc.expectsVideoTiles;
        return Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: video
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width,
                            height: MediaQuery.sizeOf(context).height,
                            child: RTCVideoView(
                              rtc.localRenderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 36),
                            child: FloatingActionButton.large(
                              backgroundColor: const Color(0xFFDC2626),
                              onPressed: () => unawaited(rtc.hangup()),
                              child: const Icon(Icons.call_end_rounded),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : audioOnlyBackdrop(
                    child: SafeArea(
                      child: Column(
                        children: [
                          const Spacer(),
                          _peerCallAvatar(context, radius: 48),
                          const SizedBox(height: 20),
                          Text(
                            peerName.isNotEmpty ? peerName : 'Эмч',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Дуудлага…',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.white60),
                          ),
                          const Spacer(),
                          FloatingActionButton.large(
                            backgroundColor: const Color(0xFFDC2626),
                            onPressed: () => unawaited(rtc.hangup()),
                            child: const Icon(Icons.call_end_rounded),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      case ChatCallOverlayPhase.active:
        final peerName = selectedDoctor != null
            ? _doctorDisplayName(selectedDoctor!)
            : '';
        final videoTiles = rtc.expectsVideoTiles;
        return Positioned.fill(
          child: Material(
            color: Colors.black,
            child: videoTiles
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: RTCVideoView(
                          rtc.remoteRenderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                      Positioned(
                        right: 14,
                        bottom: 108,
                        width: 120,
                        height: 168,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: RTCVideoView(
                            rtc.localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              peerName.isNotEmpty ? peerName : 'Дуудлага',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 36),
                            child: FloatingActionButton.large(
                              backgroundColor: const Color(0xFFDC2626),
                              onPressed: () => unawaited(rtc.hangup()),
                              child: const Icon(Icons.call_end_rounded),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : audioOnlyBackdrop(
                    child: SafeArea(
                      child: Column(
                        children: [
                          const Spacer(),
                          _peerCallAvatar(context, radius: 48),
                          const SizedBox(height: 20),
                          Text(
                            peerName.isNotEmpty ? peerName : 'Дуудлага',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            'Дуудлагад',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.white54),
                          ),
                          const Spacer(),
                          FloatingActionButton.large(
                            backgroundColor: const Color(0xFFDC2626),
                            onPressed: () => unawaited(rtc.hangup()),
                            child: const Icon(Icons.call_end_rounded),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final auth = ref.watch(authControllerProvider);
    final isAuthed = auth.isAuthenticated && _patientUserId != null;
    final role = auth.user?.role ?? 'PATIENT';
    final isDoctorRole = role == 'DOCTOR';
    final pageTitle = isDoctorRole
        ? 'Өвчтөнүүдийн чат'
        : l10n.homeCardLiveChatTitle;
    final noDoctorsLabel = isDoctorRole
        ? 'Одоогоор системд идэвхтэй өвчтөн алга байна.'
        : l10n.chatNoDoctors;
    final selectLabel = isDoctorRole
        ? 'Өвчтөн сонгох (бүх өвчтөн)'
        : l10n.chatSelectDoctor;
    final myId = _patientUserId ?? '';

    Widget body;
    if (loadingDoctors) {
      body = const Center(child: CircularProgressIndicator());
    } else if (loadError != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadDoctors,
                child: Text(l10n.branchesRetry),
              ),
            ],
          ),
        ),
      );
    } else if (doctors.isEmpty && lockedOutDoctor == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(noDoctorsLabel, textAlign: TextAlign.center),
        ),
      );
    } else {
      body = Column(
        children: [
          if (lockedOutDoctor != null)
            _buildLockedOutDoctorPanel(theme, cs),
          if (!isAuthed)
            Material(
              color: cs.primaryContainer.withValues(alpha: 0.55),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.chatSignInToSaveMessages,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/auth/login'),
                      child: Text(l10n.authFormLogInTitle),
                    ),
                  ],
                ),
              ),
            ),
          if (doctors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedDoctor?['id']?.toString(),
                          borderRadius: BorderRadius.circular(16),
                          items: [
                            for (final d in doctors)
                              if (d['id'] != null)
                                DropdownMenuItem<String>(
                                  value: d['id'].toString(),
                                  child: Text(() {
                                    final key = _contactKeyForDoctor(
                                      d,
                                      isDoctorRole,
                                    );
                                    final unread = key == null
                                        ? 0
                                        : (unreadByContact[key] ?? 0);
                                    final badge =
                                        unread > 0 ? ' ($unread)' : '';
                                    return '${_doctorDisplayName(d)} · ${_contactSubtitle(d, isDoctorRole, l10n.localeName)}$badge';
                                  }(), overflow: TextOverflow.ellipsis),
                                ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => lockedOutDoctor = null);
                            for (final d in doctors) {
                              if (d['id']?.toString() == v) {
                                _selectDoctor(d);
                                break;
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: loadingMessages
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final m = messages[index];
                      final mine = m['senderId']?.toString() == myId;
                      final ts = _formatChatTimestamp(m);
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: mine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                decoration: BoxDecoration(
                                  color: mine
                                      ? const Color(0xFF1877F2)
                                      : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(mine ? 18 : 6),
                                    bottomRight: Radius.circular(mine ? 6 : 18),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: _buildMessageContent(m, mine),
                              ),
                              if (ts.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    left: 6,
                                    right: 6,
                                  ),
                                  child: Text(
                                    ts,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (typingUserId != null &&
              typingUserId!.isNotEmpty &&
              typingUserId != myId &&
              activeRoomId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Бичиж байна…',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (activeRoomId.isNotEmpty && isAuthed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _attachmentBusy
                                ? null
                                : _sendPickedImage,
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('Photo'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _attachmentBusy ? null : _sendPickedFile,
                            icon: const Icon(Icons.attach_file_rounded),
                            label: const Text('File'),
                          ),
                          const SizedBox(width: 8),
                          Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (_) => _voicePointerDown(),
                            onPointerUp: (_) {
                              _voicePointerEnd();
                              _voiceFingerRelease = null;
                            },
                            onPointerCancel: (_) {
                              _voicePointerEnd();
                              _voiceFingerRelease = null;
                            },
                            child: Tooltip(
                              message:
                                  'Дарж барь — бичиж байна / сулласан — илгээнэ',
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _recordingVoiceHud
                                        ? Colors.red
                                        : cs.outline,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: _recordingVoiceHud
                                      ? cs.errorContainer.withValues(
                                          alpha: 0.35,
                                        )
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.mic_rounded,
                                      size: 18,
                                      color: _recordingVoiceHud
                                          ? cs.error
                                          : cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Дуу',
                                      style: theme.textTheme.labelLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          enabled: isAuthed && activeRoomId.isNotEmpty,
                          autocorrect: false,
                          enableSuggestions: false,
                          maxLines: 1,
                          textInputAction: TextInputAction.send,
                          keyboardType: TextInputType.text,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
                          ],
                          onSubmitted: (_) => _sendCurrentMessage(),
                          onChanged: (value) {
                            if (_patientUserId == null ||
                                activeRoomId.isEmpty) {
                              return;
                            }
                            ref
                                .read(realtimeServiceProvider)
                                .sendTyping(
                                  activeRoomId,
                                  _patientUserId!,
                                  value.trim().isNotEmpty,
                                );
                            _typingDebounce?.cancel();
                            _typingDebounce = Timer(
                              const Duration(milliseconds: 900),
                              () {
                                if (!mounted ||
                                    _patientUserId == null ||
                                    activeRoomId.isEmpty) {
                                  return;
                                }
                                ref
                                    .read(realtimeServiceProvider)
                                    .sendTyping(
                                      activeRoomId,
                                      _patientUserId!,
                                      false,
                                    );
                              },
                            );
                          },
                          decoration: InputDecoration(
                            hintText: l10n.chatWriteMessageHint,
                            filled: true,
                            border: const OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: !isAuthed || activeRoomId.isEmpty
                            ? null
                            : _sendCurrentMessage,
                        child: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            final auth = ref.read(authControllerProvider);
            popOrGo(
              context,
              clinovaNavigationFallback(
                isAuthenticated: auth.isAuthenticated,
                role: auth.user?.role,
              ),
            );
          },
        ),
        title: Row(
          children: [
            Builder(
              builder: (context) {
                final name = selectedDoctor != null
                    ? _doctorDisplayName(selectedDoctor!)
                    : '';
                final initial = name.isNotEmpty
                    ? String.fromCharCode(name.runes.first).toUpperCase()
                    : '?';
                final peerUid = selectedDoctor != null
                    ? _doctorUserId(selectedDoctor!)
                    : null;
                final peerOnline =
                    peerUid != null &&
                    peerUid.isNotEmpty &&
                    ref.watch(onlineUserIdsProvider).contains(peerUid);
                final selUser = selectedDoctor?['user'];
                final selUserMap = selUser is Map<String, dynamic>
                    ? selUser
                    : (selUser is Map
                          ? Map<String, dynamic>.from(selUser)
                          : null);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClinovaCircleAvatar(
                      radius: 20,
                      initialsText: initial,
                      backgroundColor: isDoctorRole
                          ? const Color(0xFFEAF2FF)
                          : kClinovaFlatDoctorAvatarBackground,
                      foregroundColor: isDoctorRole
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF475569),
                      networkUrl: isDoctorRole && selectedDoctor != null
                          ? _doctorAvatarUrl(selectedDoctor!)
                          : null,
                      doctorUseFlatAssetOnly: !isDoctorRole,
                      doctorDisplayName: name,
                      doctorGender: !isDoctorRole
                          ? doctorGenderFromMap(selUserMap)
                          : null,
                    ),
                    if (peerOnline)
                      Positioned(
                        right: -0.5,
                        bottom: -0.5,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pageTitle),
                  if (selectedDoctor != null)
                    Text(
                      _doctorDisplayName(selectedDoctor!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Voice call',
            onPressed:
                (selectedDoctor == null || !isAuthed || activeRoomId.isEmpty)
                ? null
                : () => unawaited(_startWebRtcCall(video: false)),
            icon: const Icon(Icons.call_rounded),
          ),
          IconButton(
            tooltip: 'Video call',
            onPressed:
                (selectedDoctor == null || !isAuthed || activeRoomId.isEmpty)
                ? null
                : () => unawaited(_startWebRtcCall(video: true)),
            icon: const Icon(Icons.videocam_rounded),
          ),
          IconButton(
            tooltip: 'Таслах',
            onPressed:
                (!_rtcCallBarsVisible() || !isAuthed || activeRoomId.isEmpty)
                ? null
                : () => unawaited(_rtcSession!.hangup()),
            icon: const Icon(Icons.call_end_rounded),
          ),
          IconButton(
            tooltip: 'Care / Star',
            onPressed: selectedDoctor == null ? null : _showFeedbackDialog,
            icon: const Icon(Icons.stars_rounded),
          ),
        ],
      ),
      body: ClinovaBackdrop(
        child: Stack(
          clipBehavior: Clip.none,
          children: [body, _buildCallOverlay()],
        ),
      ),
    );
  }
}
