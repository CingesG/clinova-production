/// Flat bundled doctor illustrations for missing / failed portraits.
const kDoctorMaleAsset = 'assets/images/avatars/doctor_male.png';
const kDoctorFemaleAsset = 'assets/images/avatars/doctor_female.png';

enum _ResolvedGender { male, female }

_ResolvedGender? _parseExplicitGender(String? raw) {
  final g = raw?.trim().toLowerCase();
  if (g == null || g.isEmpty) return null;
  const male = {'male', 'm', 'man', 'эрэгтэй'};
  const female = {'female', 'f', 'woman', 'эмэгтэй'};
  if (male.contains(g)) return _ResolvedGender.male;
  if (female.contains(g)) return _ResolvedGender.female;
  return null;
}

int _stableHash(String s) {
  var h = 0;
  for (final r in s.runes) {
    h = (h * 31 + r) & 0x7fffffff;
  }
  return h;
}

String _normalizeToken(String token) =>
    token.toLowerCase().replaceAll('-', '').replaceAll('—', '');

_ResolvedGender? _inferFromMongolianName(String doctorName) {
  final trimmed = doctorName.trim();
  if (trimmed.isEmpty) return null;
  final firstRaw = trimmed.split(RegExp(r'\s+')).first;
  final firstNorm = _normalizeToken(firstRaw);
  if (firstNorm.isEmpty) return null;

  const femaleSuffixes = [
    'чимэг',
    'заяа',
    'туяа',
    'дулам',
    'сувд',
    'сараа',
    'жаргал',
    'цэцэг',
  ];
  for (final s in femaleSuffixes) {
    if (firstRaw.toLowerCase().endsWith(s)) return _ResolvedGender.female;
  }

  const maleSuffixes = ['баяр', 'сүх', 'бат', 'оргил', 'гэсэр'];
  for (final s in maleSuffixes) {
    if (firstNorm.endsWith(s)) return _ResolvedGender.male;
  }

  const femaleNames = {'солонго', 'ариунзаяа', 'оюунчимэг', 'номин', 'энхжин'};
  if (femaleNames.contains(firstNorm)) return _ResolvedGender.female;

  const maleNames = {'энхбаяр', 'тэмүүлэн', 'баторгил', 'мөнхэрдэнэ', 'хүслэн'};
  if (maleNames.contains(firstNorm)) return _ResolvedGender.male;

  return null;
}

/// Returns a bundled male or female doctor avatar.
///
/// [gender] accepts e.g. `male` / `female` / `M` / `F` / Mongolian `эрэгтэй` / `эмэгтэй`.
/// When gender is absent, Cyrillic given-name heuristics are used, then a stable alternation by hash.
String resolveDoctorAvatar({
  required String doctorName,
  String? gender,
}) {
  final explicit = _parseExplicitGender(gender);
  if (explicit != null) {
    return explicit == _ResolvedGender.male ? kDoctorMaleAsset : kDoctorFemaleAsset;
  }
  final inferred = _inferFromMongolianName(doctorName);
  if (inferred != null) {
    return inferred == _ResolvedGender.male ? kDoctorMaleAsset : kDoctorFemaleAsset;
  }
  final h = _stableHash(doctorName);
  return (h & 1) == 0 ? kDoctorMaleAsset : kDoctorFemaleAsset;
}
