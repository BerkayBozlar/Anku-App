import 'package:anku_app/features/auth/auth_models.dart';
import 'package:anku_app/features/auth/auth_repository.dart';
import 'package:anku_app/features/auth/session_controller.dart';
import 'package:anku_app/features/auth/session_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(Dio());

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (password != 'dogru') {
      throw const AuthException('E-posta veya parola hatalı.');
    }
    return sessionFor(UserRole.yonetici);
  }
}

ProviderContainer _container(MemorySessionStorage storage) {
  final container = ProviderContainer(
    overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('kayıtlı oturum açılışta okunur', () async {
    final storage = MemorySessionStorage(sessionFor(UserRole.ogrenci));
    final container = _container(storage);

    final session = await container.read(sessionProvider.future);

    expect(session?.user.role, UserRole.ogrenci);
  });

  test('süresi dolmuş oturum silinir', () async {
    final storage = MemorySessionStorage(
      sessionFor(
        UserRole.ogrenci,
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      ),
    );
    final container = _container(storage);

    expect(await container.read(sessionProvider.future), isNull);
    expect(storage.session, isNull);
  });

  test('giriş oturumu saklar, çıkış siler', () async {
    final storage = MemorySessionStorage();
    final container = _container(storage);
    await container.read(sessionProvider.future);

    await container
        .read(sessionProvider.notifier)
        .login(email: 'a@b.c', password: 'dogru');

    expect(container.read(sessionProvider).value?.user.role, UserRole.yonetici);
    expect(storage.session, isNotNull);

    await container.read(sessionProvider.notifier).logout();

    expect(container.read(sessionProvider).value, isNull);
    expect(storage.session, isNull);
  });

  test('hatalı girişte durum değişmez, hata fırlatılır', () async {
    final storage = MemorySessionStorage();
    final container = _container(storage);
    await container.read(sessionProvider.future);

    await expectLater(
      container
          .read(sessionProvider.notifier)
          .login(email: 'a@b.c', password: 'yanlis'),
      throwsA(isA<AuthException>()),
    );
    expect(container.read(sessionProvider).value, isNull);
    expect(storage.session, isNull);
  });
}
