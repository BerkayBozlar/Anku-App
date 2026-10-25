import 'package:anku_app/core/network/api_client.dart';
import 'package:anku_app/features/health/api_health.dart';
import 'package:anku_app/features/home/home_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Override healthOverride) {
  return ProviderScope(
    overrides: [healthOverride],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  testWidgets('API çalışıyorsa bağlantı kuruldu yazar', (tester) async {
    await tester.pumpWidget(
      _wrap(
        apiHealthProvider.overrideWith(
          (ref) async =>
              const ApiHealth(status: 'ok', application: 'AnkuApp.Api'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('API bağlantısı kuruldu'), findsOneWidget);
    expect(find.text('AnkuApp.Api'), findsOneWidget);
  });

  testWidgets('API kapalıysa hata gösterir', (tester) async {
    await tester.pumpWidget(
      _wrap(
        apiHealthProvider.overrideWith(
          (ref) async => throw DioException.connectionError(
            requestOptions: RequestOptions(path: '/api/health'),
            reason: 'test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('API bağlantısı yok'), findsOneWidget);
    expect(find.textContaining('Sunucuya bağlanılamadı'), findsOneWidget);
  });

  testWidgets('yedi modül kartı listelenir', (tester) async {
    await tester.pumpWidget(
      _wrap(
        apiHealthProvider.overrideWith(
          (ref) async => const ApiHealth(status: 'ok', application: ''),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final title in [
      'Kampüs Haritası',
      'Ders Programı',
      'Duyurular',
      'Kulüpler ve Etkinlikler',
      'Yemekhane',
      'Akademik Takvim',
      'Not Hesaplama',
    ]) {
      await tester.scrollUntilVisible(find.text(title), 100);
      expect(find.text(title), findsOneWidget);
    }
    expect(describeApiError(Exception()), isNotEmpty);
  });
}
