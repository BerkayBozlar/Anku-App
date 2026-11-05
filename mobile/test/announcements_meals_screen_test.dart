import 'package:anku_app/app.dart';
import 'package:anku_app/core/format.dart';
import 'package:anku_app/core/network/api_client.dart';
import 'package:anku_app/features/auth/auth_models.dart';
import 'package:anku_app/features/auth/session_storage.dart';
import 'package:anku_app/features/announcements/announcements_screen.dart';
import 'package:anku_app/features/meals/meal_menu_screen.dart';
import 'package:anku_app/features/health/api_health.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

Map<String, Object?> _announcement(int id, String title, {String? summary}) => {
  'id': id,
  'title': title,
  'summary': summary ?? '$title için kısa özet.',
  'sourceName': 'Öğrenci İşleri Daire Başkanlığı',
  'sourceUrl': 'https://oidb.ankara.edu.tr/duyuru/$id',
  'uniqueKey': 'K$id',
  'publishedAt': DateTime.now()
      .toUtc()
      .subtract(Duration(hours: id))
      .toIso8601String(),
  'retrievedAt': DateTime.now().toUtc().toIso8601String(),
  'isManual': false,
};

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

class _Api {
  final announcements = [
    for (var i = 1; i <= 25; i++) _announcement(i, 'Duyuru $i'),
  ];

  /// Bugün ve 2 gün sonrası dolu; diğer günler menüsüz.
  late final menus = [
    _menu(1, _today(), ['Ezogelin Çorbası', 'Etli Nohut', 'Pilav', 'Cacık']),
    _menu(2, _addDays(_today(), 2), ['Domates Çorbası', 'Köfte', 'Makarna']),
  ];
  bool failMenus = false;
  late final adapter = RecordingAdapter(_respond);

  static Map<String, Object?> _menu(int id, DateTime day, List<String> d) => {
    'id': id,
    'menuDate': formatApiDate(day),
    'dishes': d,
    'totalCalories': id == 1 ? 1180 : null,
    'sourceName': 'Ankara Üniversitesi SKS',
    'sourceUrl': 'https://sks.ankara.edu.tr/yemek-hizmetleri-2/',
    'retrievedAt': DateTime.now().toUtc().toIso8601String(),
    'isManual': false,
  };

  (int, Object?) _respond(RequestOptions options) {
    final q = options.queryParameters;
    if (options.path == '/api/announcements') {
      final search = q['search'] as String?;
      final matching = announcements
          .where(
            (a) => search == null || (a['title']! as String).contains(search),
          )
          .toList();
      final page = q['page'] as int;
      final size = q['pageSize'] as int;
      return (
        200,
        {
          'items': matching.skip((page - 1) * size).take(size).toList(),
          'page': page,
          'pageSize': size,
          'totalCount': matching.length,
        },
      );
    }
    if (options.path.startsWith('/api/announcements/')) {
      final id = int.parse(options.path.split('/').last);
      final match = announcements.where((a) => a['id'] == id);
      return match.isEmpty ? (404, null) : (200, match.single);
    }
    if (options.path == '/api/meal-menus') {
      if (failMenus) {
        return (503, {'message': 'Menü kaynağına şu anda ulaşılamıyor.'});
      }
      final from = q['from'] == null
          ? _today()
          : DateTime.parse(q['from'] as String);
      final to = q['to'] == null
          ? _addDays(from, 6)
          : DateTime.parse(q['to'] as String);
      return (
        200,
        {
          'items': menus.where((m) {
            final day = DateTime.parse(m['menuDate']! as String);
            return !day.isBefore(from) && !day.isAfter(to);
          }).toList(),
          'from': formatApiDate(from),
          'to': formatApiDate(to),
        },
      );
    }
    return (404, null);
  }
}

/// Üstteki ekranın kaydırma alanı (ana sayfa alttaki yığında kalır).
Finder _scrollableOf(Type screen) => find
    .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
    .first;

Future<void> _openFromHome(
  WidgetTester tester,
  _Api api,
  String module, {
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = api.adapter;
  addTearDown(dio.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        sessionStorageProvider.overrideWithValue(
          MemorySessionStorage(sessionFor(UserRole.ogrenci)),
        ),
        apiHealthProvider.overrideWith(
          (ref) async => const ApiHealth(status: 'ok', application: 'test'),
        ),
      ],
      child: const AnkuApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text(module), 250);
  await tester.tap(find.text(module));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('öğrenci duyuruları listeler, sayfalar ve ayrıntıyı açar', (
    tester,
  ) async {
    final api = _Api();
    await _openFromHome(tester, api, 'Duyurular');

    expect(find.widgetWithText(AppBar, 'Duyurular'), findsOneWidget);
    expect(find.text('25 duyuru'), findsOneWidget);
    expect(find.text('Duyuru 1'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Daha fazla göster'),
      300,
      scrollable: _scrollableOf(AnnouncementsScreen),
    );
    await tester.tap(find.text('Daha fazla göster'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Duyuru 25'),
      300,
      scrollable: _scrollableOf(AnnouncementsScreen),
    );
    expect(find.text('Daha fazla göster'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Duyuru 1'),
      -300,
      scrollable: _scrollableOf(AnnouncementsScreen),
    );
    await tester.tap(find.text('Duyuru 1'));
    await tester.pumpAndSettle();

    expect(find.text('Duyuru ayrıntısı'), findsOneWidget);
    expect(find.text('Duyuru 1 için kısa özet.'), findsOneWidget);
    expect(find.text('Öğrenci İşleri Daire Başkanlığı'), findsOneWidget);
    expect(find.text('Kaynakta aç'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duyuru araması ve boş sonuç', (tester) async {
    final api = _Api();
    await _openFromHome(tester, api, 'Duyurular');

    await tester.enterText(find.byType(TextField), 'Duyuru 2');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    // "Duyuru 2" ve "Duyuru 20–25"
    expect(find.text('7 duyuru'), findsOneWidget);
    expect(api.adapter.requests.last.queryParameters['search'], 'Duyuru 2');

    await tester.enterText(find.byType(TextField), 'yok böyle');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Aramanıza uygun duyuru bulunamadı.'), findsOneWidget);
  });

  testWidgets('duyuru yokken anlaşılır boş durum', (tester) async {
    final api = _Api()..announcements.clear();
    await _openFromHome(tester, api, 'Duyurular');

    expect(find.textContaining('Henüz duyuru yok.'), findsOneWidget);
  });

  testWidgets(
    'yemekhane bugünden 7 günü, menüsüz günleri ve kaynağı gösterir',
    (tester) async {
      final api = _Api();
      await _openFromHome(tester, api, 'Yemekhane');

      final today = _today();
      expect(find.widgetWithText(AppBar, 'Yemekhane'), findsOneWidget);
      expect(
        find.text('${formatDate(today)} – ${formatDate(_addDays(today, 6))}'),
        findsOneWidget,
      );
      expect(find.text('Bugün'), findsOneWidget);
      expect(find.text('Ezogelin Çorbası'), findsOneWidget);
      expect(find.text('Toplam 1180 kcal'), findsOneWidget);
      expect(
        find.text(
          '${weekdayName(_addDays(today, 1))}, '
          '${formatDate(_addDays(today, 1))}',
        ),
        findsOneWidget,
      );
      expect(find.text('Bu gün için menü yayımlanmamış.'), findsWidgets);

      await tester.scrollUntilVisible(
        find.text('Resmî menü kaynağını aç'),
        300,
        scrollable: _scrollableOf(MealMenuScreen),
      );
      expect(
        find.textContaining('Kaynak: Ankara Üniversitesi SKS'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sonraki hafta tarih aralığıyla istenir ve bugüne dönülür', (
    tester,
  ) async {
    final api = _Api();
    await _openFromHome(tester, api, 'Yemekhane');

    await tester.tap(find.byTooltip('Sonraki 7 gün'));
    await tester.pumpAndSettle();

    final next = _addDays(_today(), 7);
    expect(api.adapter.requests.last.queryParameters, {
      'from': formatApiDate(next),
      'to': formatApiDate(_addDays(next, 6)),
    });
    expect(find.textContaining('yayımlanmış öğle menüsü yok'), findsOneWidget);

    await tester.tap(find.text('Bugüne dön'));
    await tester.pumpAndSettle();
    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Bugüne dön'), findsNothing);
  });

  testWidgets('menü hatası API mesajı ve tekrar dene ile gösterilir', (
    tester,
  ) async {
    final api = _Api()..failMenus = true;
    await _openFromHome(tester, api, 'Yemekhane');

    expect(find.text('Menü kaynağına şu anda ulaşılamıyor.'), findsOneWidget);

    api.failMenus = false;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Ezogelin Çorbası'), findsOneWidget);
  });

  for (final width in [320.0, 1024.0]) {
    for (final module in ['Duyurular', 'Yemekhane']) {
      testWidgets('$module ekranı ${width.toInt()} px genişlikte taşmaz', (
        tester,
      ) async {
        await _openFromHome(tester, _Api(), module, width: width);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
