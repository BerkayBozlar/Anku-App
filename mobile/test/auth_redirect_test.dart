import 'package:anku_app/core/router/app_router.dart';
import 'package:anku_app/features/auth/auth_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  const loggedOut = AsyncData<AuthSession?>(null);
  final student = AsyncData<AuthSession?>(sessionFor(UserRole.ogrenci));
  final clubOfficer = AsyncData<AuthSession?>(
    sessionFor(UserRole.kulupYetkilisi),
  );
  final admin = AsyncData<AuthSession?>(sessionFor(UserRole.yonetici));

  test('oturum okunurken açılış ekranı gösterilir', () {
    const loading = AsyncLoading<AuthSession?>();
    expect(authRedirect(loading, '/'), '/splash');
    expect(authRedirect(loading, '/splash'), isNull);
  });

  test('giriş yapılmamışsa giriş ekranına gidilir', () {
    expect(authRedirect(loggedOut, '/'), '/login');
    expect(authRedirect(loggedOut, '/map'), '/login');
    expect(authRedirect(loggedOut, '/splash'), '/login');
    expect(authRedirect(loggedOut, '/login'), isNull);
    expect(authRedirect(loggedOut, '/register'), isNull);
  });

  test('giriş yapılmışsa giriş ve kayıt ekranları ana sayfaya döner', () {
    expect(authRedirect(student, '/login'), '/');
    expect(authRedirect(student, '/register'), '/');
    expect(authRedirect(student, '/splash'), '/');
    expect(authRedirect(student, '/map'), isNull);
    expect(authRedirect(student, '/profile'), isNull);
  });

  test('yönetim ekranı yalnızca yöneticiye açılır', () {
    expect(authRedirect(student, '/admin'), '/');
    expect(authRedirect(clubOfficer, '/admin'), '/');
    expect(authRedirect(admin, '/admin'), isNull);
  });

  test('oturum okunamazsa giriş ekranına gidilir', () {
    final failed = AsyncError<AuthSession?>(Exception(), StackTrace.empty);
    expect(authRedirect(failed, '/'), '/login');
  });
}
