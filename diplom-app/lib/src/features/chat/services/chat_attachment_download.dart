import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/network/clinova_api.dart';

String _safeFileName(String name) {
  var s = name.trim();
  if (s.isEmpty) s = 'attachment';
  return s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

MimeType _mimeFromName(String name) {
  final ext = p.extension(name).toLowerCase().replaceFirst('.', '');
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return MimeType.jpeg;
    case 'png':
      return MimeType.png;
    case 'gif':
      return MimeType.gif;
    case 'pdf':
      return MimeType.pdf;
    case 'mp3':
      return MimeType.mp3;
    case 'webp':
      return MimeType.other;
    case 'wav':
      return MimeType.other;
    case 'webm':
      return MimeType.other;
    case 'mp4':
      return MimeType.mp4Video;
    default:
      return MimeType.other;
  }
}

Future<void> downloadChatAttachment({
  required ClinovaApi api,
  required String resolvedUrl,
  required String suggestedName,
}) async {
  final bytes = await api.downloadAttachmentBytes(resolvedUrl);
  final safe = _safeFileName(suggestedName);
  final ext = p.extension(safe).replaceFirst('.', '').toLowerCase();
  final base = safe.endsWith(ext) ? p.basenameWithoutExtension(safe) : p.basename(safe);

  if (kIsWeb) {
    await FileSaver.instance.saveFile(
      name: base,
      bytes: bytes,
      fileExtension: ext.isEmpty ? 'bin' : ext,
      mimeType: ext.isEmpty ? MimeType.other : _mimeFromName(safe),
    );
    return;
  }

  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          bytes,
          mimeType: _mimeString(safe),
          name: safe,
        ),
      ],
    ),
  );
}

String? _mimeString(String filename) {
  final ext = p.extension(filename).toLowerCase();
  switch (ext) {
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.pdf':
      return 'application/pdf';
    case '.mp3':
      return 'audio/mpeg';
    case '.wav':
      return 'audio/wav';
    case '.webm':
      return 'audio/webm';
    default:
      return null;
  }
}
