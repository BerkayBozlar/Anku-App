import 'package:anku_app/features/auth/auth_models.dart';
import 'package:anku_app/features/auth/session_storage.dart';

class MemorySessionStorage implements SessionStorage {
  MemorySessionStorage([this.session]);

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}

AuthSession sessionFor(UserRole role, {DateTime? expiresAt}) {
  return AuthSession(
    accessToken: 'token-${role.apiName}',
    expiresAt:
        expiresAt ?? DateTime.now().toUtc().add(const Duration(hours: 1)),
    user: AuthUser(
      id: 'id-${role.apiName}',
      fullName: 'Deneme ${role.label}',
      email: '${role.apiName.toLowerCase()}@ankara.edu.tr',
      role: role,
    ),
  );
}
