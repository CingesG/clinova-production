/// Normalize Mongolian mobiles to API format `+976` + 8 digits.
/// Mirrors backend `mongolia-phone.util.ts`.
String? normalizeMnPhoneForApi(String raw) {
  final s = raw.trim().replaceAll(RegExp(r'\s+'), '');
  if (s.isEmpty) return null;

  String digits;
  if (s.startsWith('+976')) {
    digits = s.substring(4).replaceAll(RegExp(r'\D'), '');
  } else if (s.startsWith('976')) {
    digits = s.substring(3).replaceAll(RegExp(r'\D'), '');
  } else {
    digits = s.replaceAll(RegExp(r'\D'), '');
  }
  if (digits.length != 8) return null;
  if (!RegExp(r'^\d{8}$').hasMatch(digits)) return null;
  return '+976$digits';
}
