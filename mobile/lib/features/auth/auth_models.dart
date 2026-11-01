/// API'deki roller (docs/api-sozlesmesi.md).
enum UserRole {
  yonetici('Yonetici', 'Yönetici'),
  kulupYetkilisi('KulupYetkilisi', 'Kulüp Yetkilisi'),
  ogrenci('Ogrenci', 'Öğrenci');

  const UserRole(this.apiName, this.label);

  final String apiName;
  final String label;

  /// Tanınmayan rol en az yetkili rol olarak ele alınır.
  static UserRole fromApi(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.apiName == value,
      orElse: () => UserRole.ogrenci,
    );
  }
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: UserRole.fromApi(json['role'] as String?),
    );
  }

  final String id;
  final String fullName;
  final String email;
  final UserRole role;

  String get firstName => fullName.trim().split(' ').first;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'role': role.apiName,
  };
}

/// `POST /api/auth/login` yanıtı; cihazda da aynı biçimde saklanır.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.expiresAt,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final DateTime expiresAt;
  final AuthUser user;

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt);

  bool get isExpired => isExpiredAt(DateTime.now());

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'expiresAt': expiresAt.toIso8601String(),
    'user': user.toJson(),
  };
}
