import 'package:anku_app/app.dart';
import 'package:anku_app/features/auth/auth_models.dart';
import 'package:anku_app/features/auth/session_storage.dart';
import 'package:anku_app/features/health/api_health.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

Future<void> _pumpApp(WidgetTester tester, {AuthSession? session}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage(session)),
        apiHealthProvider.overrideWith(
          (ref) async => const ApiHealth(status: 'ok', application: 'test'),
        ),
      ],
      child: const AnkuApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('giriş yapılmamışsa giriş ekranı açılır', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Giriş yap'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('öğrenci yönetim sekmesini görmez', (tester) async {
    await _pumpApp(tester, session: sessionFor(UserRole.ogrenci));

    expect(find.text('Merhaba, Deneme'), findsOneWidget);
    expect(_tab('Ana Sayfa'), findsOneWidget);
    expect(_tab('Profil'), findsOneWidget);
    expect(_tab('Yönetim'), findsNothing);
  });

  testWidgets('kulüp yetkilisi yönetim sekmesini görmez', (tester) async {
    await _pumpApp(tester, session: sessionFor(UserRole.kulupYetkilisi));

    expect(_tab('Yönetim'), findsNothing);
  });

  testWidgets('yönetici yönetim sekmesini görür ve açar', (tester) async {
    await _pumpApp(tester, session: sessionFor(UserRole.yonetici));

    await tester.tap(_tab('Yönetim'));
    await tester.pumpAndSettle();

    expect(find.text('Etkinlikler'), findsOneWidget);
  });

  testWidgets('profilden çıkış yapılınca giriş ekranına dönülür', (
    tester,
  ) async {
    await _pumpApp(tester, session: sessionFor(UserRole.ogrenci));

    await tester.tap(_tab('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Öğrenci'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Çıkış yap'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Çıkış yap'));
    await tester.pumpAndSettle();

    expect(find.text('Giriş yap'), findsOneWidget);
  });
}
