import 'package:diplom_app/src/core/config/app_config.dart';

const kClinovaFlutterAssetPrefix = 'flutter-asset:';

/// Returns a Flutter [Image.asset] path when [raw] refers to a bundled doctor
/// portrait (`flutter-asset:...` or legacy `/uploads/image/doctor-NN.*`).
String? clinovaBundledAvatarAssetPath(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return null;
  if (t.startsWith(kClinovaFlutterAssetPrefix)) {
    return t.substring(kClinovaFlutterAssetPrefix.length);
  }
  if (t.startsWith('assets/images/doctors/')) {
    return t;
  }
  final lower = t.toLowerCase();
  final uploadsIdx = lower.indexOf('/uploads/image/doctor-');
  if (uploadsIdx >= 0) {
    final slice = t.substring(uploadsIdx);
    final m = RegExp(
      r'doctor-(\d+)\.(png|jpe?g|webp)',
      caseSensitive: false,
    ).firstMatch(slice);
    if (m != null) {
      final n = int.tryParse(m.group(1)!);
      if (n != null && n >= 1 && n <= 8) {
        return 'assets/images/doctors/doctor-${n.toString().padLeft(2, '0')}.jpg';
      }
    }
  }
  final tail = RegExp(
    r'(^|/)doctor-(\d+)\.(png|jpe?g|webp)$',
    caseSensitive: false,
  ).firstMatch(t);
  if (tail != null) {
    final n = int.tryParse(tail.group(2)!);
    if (n != null && n >= 1 && n <= 8) {
      return 'assets/images/doctors/doctor-${n.toString().padLeft(2, '0')}.jpg';
    }
  }
  return null;
}

/// Same rules as API client: absolute http(s), passthrough bundled references,
/// otherwise resolve relative paths against [AppConfig.apiBaseUrl].
String? clinovaAbsolutizeMediaUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith(kClinovaFlutterAssetPrefix)) return value;
  if (value.startsWith('assets/')) return value;
  final base = Uri.tryParse(AppConfig.apiBaseUrl);
  if (base == null) return value;
  final fixedPath = value.startsWith('/') ? value : '/$value';
  return base.resolve(fixedPath).toString();
}
