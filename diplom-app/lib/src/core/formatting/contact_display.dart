/// Parse nested or flat JSON that may expose `phoneNumber` or legacy `phone`.
String? pickPhoneNumberFromJson(Map<String, dynamic>? json) {
  if (json == null) return null;
  final a = json['phoneNumber']?.toString().trim();
  if (a != null && a.isNotEmpty) return a;
  final b = json['phone']?.toString().trim();
  if (b != null && b.isNotEmpty) return b;
  return null;
}

/// Human label for Mongolian UX when phone is absent.
String displayMnRegisteredPhone(Map<String, dynamic>? data) {
  final p = pickPhoneNumberFromJson(data);
  if (p == null || p.isEmpty) return 'Бүртгээгүй';
  return p;
}
