import '../../../core/formatting/contact_display.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.status,
    this.firstName,
    this.lastName,
    this.nickname,
    this.phoneNumber,
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
  /// E.164 Mongolian (+976…) when set from backend.
  final String? phoneNumber;
  final String? avatarUrl;
  final String? patientProfileId;
  final String? doctorProfileId;
  final Map<String, dynamic>? branch;

  /// Back-compat accessor for older widgets.
  String? get phone => phoneNumber;

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
      phoneNumber: pickPhoneNumberFromJson(json),
      avatarUrl: json['avatarUrl']?.toString(),
      patientProfileId: json['patientProfileId']?.toString(),
      doctorProfileId: json['doctorProfileId']?.toString(),
      branch: json['branch'] is Map<String, dynamic>
          ? json['branch'] as Map<String, dynamic>
          : null,
    );
  }
}
