import 'package:anku_app/features/auth/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API giriş yanıtı ayrıştırılır (roles dizisi, Türkçe rol adı)', () {
    final session = AuthSession.fromJson({
      'accessToken': 'eyJhbGciOiJIUzI1NiIs...',
      'expiresAt': '2026-10-26T18:30:00.1234567Z',
      'user': {
        'id': '8c781f34-6a32-4ddb-b72d-62f68c17b964',
        'fullName': 'Örnek Öğrenci',
        'email': 'ogrenci@ankara.edu.tr',
        'roles': ['Öğrenci'],
      },
    });

    expect(session.user.role, UserRole.ogrenci);
    expect(session.user.firstName, 'Örnek');
    expect(session.expiresAt, DateTime.utc(2026, 10, 26, 18, 30, 0, 123, 456));
  });

  test(
    'roller Türkçe ve sade yazımdan çözülür, bilinmeyen rol öğrenci sayılır',
    () {
      expect(UserRole.fromApi('Yönetici'), UserRole.yonetici);
      expect(UserRole.fromApi('Kulüp Yetkilisi'), UserRole.kulupYetkilisi);
      expect(UserRole.fromApi('Öğrenci'), UserRole.ogrenci);
      expect(UserRole.fromApi('Yonetici'), UserRole.yonetici);
      expect(UserRole.fromApi('KulupYetkilisi'), UserRole.kulupYetkilisi);
      expect(UserRole.fromApi('Admin'), UserRole.ogrenci);
      expect(UserRole.fromApi(null), UserRole.ogrenci);
    },
  );

  test('birden çok rolde en yetkili olan seçilir', () {
    expect(
      UserRole.fromApiList(['Öğrenci', 'Kulüp Yetkilisi']),
      UserRole.kulupYetkilisi,
    );
    expect(
      UserRole.fromApiList(['Kulüp Yetkilisi', 'Yönetici']),
      UserRole.yonetici,
    );
    expect(UserRole.fromApiList([]), UserRole.ogrenci);
  });

  test('tekil role alanı da okunur', () {
    final user = AuthUser.fromJson({
      'id': '1',
      'fullName': 'A',
      'email': 'a@b.c',
      'role': 'KulupYetkilisi',
    });

    expect(user.role, UserRole.kulupYetkilisi);
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
