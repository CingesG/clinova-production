class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.status,
    this.firstName,
    this.lastName,
    this.nickname,
    this.phone,
    this.avatarUrl,
    this.patientProfileId,
    this.doctorProfileId,
    this.branch,
  });

  final String id;
  final String email;
  final String role;
  final String? status;
  final String? firstName;
  final String? lastName;
  final String? nickname;
  final String? phone;
  final String? avatarUrl;
  final String? patientProfileId;
  final String? doctorProfileId;
  final Map<String, dynamic>? branch;

  String get displayName {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) {
      return nick;
    }
    final name = [firstName, lastName]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();
    return name.isEmpty ? email : name;
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'PATIENT',
      status: json['status']?.toString(),
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      nickname: json['nickname']?.toString(),
      phone: json['phone']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      patientProfileId: json['patientProfileId']?.toString(),
      doctorProfileId: json['doctorProfileId']?.toString(),
      branch: json['branch'] is Map<String, dynamic>
          ? json['branch'] as Map<String, dynamic>
          : null,
    );
  }
}