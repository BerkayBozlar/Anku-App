import 'package:anku_app/features/auth/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sözleşmedeki giriş yanıtı ayrıştırılır', () {
    final session = AuthSession.fromJson({
      'accessToken': 'eyJhbGciOiJIUzI1NiIs...',
      'expiresAt': '2026-10-26T18:30:00Z',
      'user': {
        'id': '8c781f34-6a32-4ddb-b72d-62f68c17b964',
        'fullName': 'Örnek Öğrenci',
        'email': 'ogrenci@ankara.edu.tr',
        'role': 'Ogrenci',
      },
    });

    expect(session.user.role, UserRole.ogrenci);
    expect(session.user.firstName, 'Örnek');
    expect(session.expiresAt, DateTime.utc(2026, 10, 26, 18, 30));
  });

  test('roller API adlarından çözülür, bilinmeyen rol öğrenci sayılır', () {
    expect(UserRole.fromApi('Yonetici'), UserRole.yonetici);
    expect(UserRole.fromApi('KulupYetkilisi'), UserRole.kulupYetkilisi);
    expect(UserRole.fromApi('Admin'), UserRole.ogrenci);
    expect(UserRole.fromApi(null), UserRole.ogrenci);
  });

  test('oturum JSON olarak saklanıp geri okunur', () {
    final original = AuthSession(
      accessToken: 't',
      expiresAt: DateTime.utc(2026, 11, 1, 12),
      user: const AuthUser(
        id: '1',
        fullName: 'A B',
        email: 'a@b.c',
        role: UserRole.kulupYetkilisi,
      ),
    );

    final copy = AuthSession.fromJson(original.toJson());

    expect(copy.accessToken, 't');
    expect(copy.expiresAt, original.expiresAt);
    expect(copy.user.role, UserRole.kulupYetkilisi);
  });

  test('süre dolumu kontrol edilir', () {
    final session = AuthSession(
      accessToken: 't',
      expiresAt: DateTime.utc(2026, 11, 1, 12),
      user: const AuthUser(
        id: '1',
        fullName: '',
        email: '',
        role: UserRole.ogrenci,
      ),
    );

    expect(session.isExpiredAt(DateTime.utc(2026, 11, 1, 11, 59)), isFalse);
    expect(session.isExpiredAt(DateTime.utc(2026, 11, 1, 12)), isTrue);
  });
}
