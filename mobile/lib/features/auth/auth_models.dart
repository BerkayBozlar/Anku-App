/// API'deki roller. API rol adlarını "Yönetici", "Kulüp Yetkilisi" gibi Türkçe
/// karakterli ya da "Yonetici" gibi sade yazımla döndürebilir; ikisi de tanınır.
enum UserRole {
  yonetici('Yonetici', 'Yönetici'),
  kulupYetkilisi('KulupYetkilisi', 'Kulüp Yetkilisi'),
  ogrenci('Ogrenci', 'Öğrenci');

  const UserRole(this.apiName, this.label);

  /// Cihazda saklanan sade ad.
  final String apiName;
  final String label;

  /// Tanınmayan rol en az yetkili rol olarak ele alınır.
  static UserRole fromApi(String? value) =>
      _tryParse(value) ?? UserRole.ogrenci;

  /// Birden çok rol varsa en yetkili olanı seçer (enum sırası yetki sırasıdır).
  static UserRole fromApiList(Iterable<Object?> values) {
    final known = values.map((v) => _tryParse(v?.toString())).toSet();
    return UserRole.values.firstWhere(
      known.contains,
      orElse: () => UserRole.ogrenci,
    );
  }

  static UserRole? _tryParse(String? value) {
    if (value == null) return null;
    final key = _simplify(value);
    for (final role in UserRole.values) {
      if (_simplify(role.apiName) == key || _simplify(role.label) == key) {
        return role;
      }
    }
    return null;
  }

  static const _turkish = {
    'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', //
    'Ç': 'c', 'Ğ': 'g', 'İ': 'i', 'Ö': 'o', 'Ş': 's', 'Ü': 'u',
  };

  // "Kulüp Yetkilisi" -> "kulupyetkilisi"
  static String _simplify(String value) => value
      .split('')
      .where((c) => c.trim().isNotEmpty)
      .map((c) => _turkish[c] ?? c.toLowerCase())
      .join();
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  /// Giriş yanıtındaki `user` nesnesi (`roles` dizisi) ya da cihazda saklanan biçim (`role`).
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final roles = json['roles'];
    return AuthUser(
      id: json['id'] as String,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: roles is List
          ? UserRole.fromApiList(roles)
          : UserRole.fromApi(json['role'] as String?),
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
