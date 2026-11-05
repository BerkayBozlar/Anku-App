import 'package:anku_app/app.dart';
import 'package:anku_app/core/network/api_client.dart';
import 'package:anku_app/features/auth/auth_models.dart';
import 'package:anku_app/features/auth/session_storage.dart';
import 'package:anku_app/features/health/api_health.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

Map<String, Object?> _event(
  int id,
  String title, {
  int clubId = 1,
  bool past = false,
  String status = 'Published',
}) => {
  'id': id,
  'clubId': clubId,
  'clubName': clubId == 1 ? 'Müzik Topluluğu' : 'İletişim Topluluğu',
  'title': title,
  'description': 'Öğrenciler için açık etkinlik açıklaması.',
  'eventDate': DateTime.now()
      .toUtc()
      .add(Duration(days: past ? -id : id))
      .toIso8601String(),
  'capacity': 100,
  'campusLocationName': 'Fen Fakültesi',
  'status': status,
};

class _Api {
  final events = <Map<String, Object?>>[
    _event(1, 'Kampüs Konseri'),
    _event(2, 'Geçmiş Konser', past: true),
    _event(3, 'Taslak Etkinlik', status: 'Draft'),
    _event(4, 'İptal Edilen Konser', status: 'Cancelled'),
  ];
  final clubs = [
    {
      'id': 1,
      'name': 'Müzik Topluluğu',
      'description': 'Birlikte müzik yapıyoruz.',
    },
    {
      'id': 2,
      'name': 'İletişim Topluluğu',
      'description': 'İletişim atölyeleri.',
    },
  ];
  bool failEvents = false;
  bool failClubs = false;
  late final adapter = RecordingAdapter(_respond);

  (int, Object?) _respond(RequestOptions options) {
    if (options.path == '/api/clubs') {
      return failClubs ? (503, null) : (200, clubs);
    }
    if (options.path.startsWith('/api/clubs/')) {
      final id = int.parse(options.path.split('/').last);
      final matches = clubs.where((club) => club['id'] == id);
      return matches.isEmpty ? (404, null) : (200, matches.single);
    }
    if (options.path.startsWith('/api/events/')) {
      final id = int.parse(options.path.split('/').last);
      final matches = events.where((event) => event['id'] == id);
      return matches.isEmpty ? (404, null) : (200, matches.single);
    }
    if (options.path == '/api/events') {
      if (failEvents) return (503, null);
      final q = options.queryParameters;
      final matching =
          events.where((event) {
            final date = DateTime.parse(event['eventDate']! as String);
            return (q['status'] == null || event['status'] == q['status']) &&
                (q['clubId'] == null || event['clubId'] == q['clubId']) &&
                (q['from'] == null ||
                    !date.isBefore(DateTime.parse(q['from'] as String))) &&
                (q['to'] == null ||
                    date.isBefore(DateTime.parse(q['to'] as String))) &&
                (q['search'] == null ||
                    (event['title'] as String).contains(q['search'] as String));
          }).toList()..sort(
            (a, b) =>
                (a['eventDate'] as String).compareTo(b['eventDate'] as String),
          );
      final ordered = q['order'] == 'desc'
          ? matching.reversed.toList()
          : matching;
      final page = q['page'] as int;
      final size = q['pageSize'] as int;
      return (
        200,
        {
          'items': ordered.skip((page - 1) * size).take(size).toList(),
          'page': page,
          'pageSize': size,
          'totalCount': ordered.length,
        },
      );
    }
    return (404, null);
  }
}

Finder _tab(String text) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(text));

Future<void> _open(
  WidgetTester tester,
  _Api api, {
  double width = 390,
  bool viaHome = false,
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
  if (viaHome) {
    await tester.scrollUntilVisible(find.text('Kulüpler ve Etkinlikler'), 250);
    await tester.tap(find.text('Kulüpler ve Etkinlikler'));
  } else {
    await tester.tap(_tab('Keşfet'));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('öğrenci yayındaki etkinlikten ayrıntıya ve kulübüne gider', (
    tester,
  ) async {
    final api = _Api();
    await _open(tester, api, viaHome: true);
    expect(_tab('Yönetim'), findsNothing);
    expect(find.text('Kampüs Konseri'), findsOneWidget);
    expect(find.text('Taslak Etkinlik'), findsNothing);
    expect(find.text('İptal Edilen Konser'), findsNothing);
    expect(find.text('1 etkinlik'), findsOneWidget);
    final query = api.adapter.requests
        .firstWhere((r) => r.path == '/api/events')
        .queryParameters;
    expect(query['status'], 'Published');
    expect(query['from'], isNotNull);

    await tester.tap(find.text('Kampüs Konseri'));
    await tester.pumpAndSettle();
    expect(find.text('Etkinlik ayrıntısı'), findsOneWidget);
    expect(find.text('Fen Fakültesi'), findsOneWidget);
    expect(
      find.text('Öğrenciler için açık etkinlik açıklaması.'),
      findsOneWidget,
    );
    expect(find.text('Kaydet'), findsNothing);

    await tester.tap(find.text('Müzik Topluluğu'));
    await tester.pumpAndSettle();
    expect(find.text('Kulüp ayrıntısı'), findsOneWidget);
    expect(find.text('Birlikte müzik yapıyoruz.'), findsOneWidget);
    expect(
      api.adapter.requests.any(
        (r) => r.path == '/api/events' && r.queryParameters['clubId'] == 1,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'kulüp araması Türkçe büyük harfle çalışır ve boş kulüp açıklanır',
    (tester) async {
      final api = _Api();
      await _open(tester, api);
      await tester.tap(find.text('Kulüpler'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Kulüp ara'),
        'İLETİŞİM',
      );
      await tester.pumpAndSettle();
      expect(find.text('Müzik Topluluğu'), findsNothing);
      await tester.tap(find.text('İletişim Topluluğu'));
      await tester.pumpAndSettle();
      expect(find.text('İletişim atölyeleri.'), findsOneWidget);
      expect(find.text('Henüz yaklaşan etkinlik yok.'), findsOneWidget);
      expect(api.adapter.requests.last.queryParameters['clubId'], 2);
    },
  );

  testWidgets('geçmiş sekmesi ve başlık araması filtreleri korur', (
    tester,
  ) async {
    final api = _Api();
    await _open(tester, api);
    await tester.tap(find.text('Geçmiş'));
    await tester.pumpAndSettle();
    expect(find.text('Geçmiş Konser'), findsOneWidget);
    expect(find.text('Kampüs Konseri'), findsNothing);
    final field = find.widgetWithText(TextField, 'Etkinlik ara');
    await tester.enterText(field, 'Bulunmayan');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Aramanıza uygun etkinlik bulunamadı.'), findsOneWidget);
    final query = api.adapter.requests.last.queryParameters;
    expect(query['to'], isNotNull);
    expect(query['order'], 'desc');
    expect(query['status'], 'Published');
    expect(query['search'], 'Bulunmayan');
    await tester.tap(find.byTooltip('Aramayı temizle'));
    await tester.pumpAndSettle();
    expect(find.text('Geçmiş Konser'), findsOneWidget);
  });

  testWidgets('etkinlik bağlantı hatası sonrası yeniden deneme çalışır', (
    tester,
  ) async {
    final api = _Api()..failEvents = true;
    await _open(tester, api);
    expect(find.textContaining('503'), findsOneWidget);
    api.failEvents = false;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Kampüs Konseri'), findsOneWidget);
  });

  testWidgets('kulüp bağlantı hatası sonrası yeniden deneme çalışır', (
    tester,
  ) async {
    final api = _Api()..failClubs = true;
    await _open(tester, api);
    await tester.tap(find.text('Kulüpler'));
    await tester.pumpAndSettle();
    expect(find.textContaining('503'), findsOneWidget);
    api.failClubs = false;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Müzik Topluluğu'), findsOneWidget);
  });

  testWidgets('sayfalama yayın filtresi ve tarih sınırını korur', (
    tester,
  ) async {
    final api = _Api();
    api.events
      ..clear()
      ..addAll([for (var id = 1; id <= 21; id++) _event(id, 'Etkinlik $id')]);
    await _open(tester, api);
    final listScroll = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Daha fazla göster'),
      500,
      scrollable: listScroll,
    );
    await tester.tap(find.text('Daha fazla göster'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Etkinlik 21'),
      300,
      scrollable: listScroll,
    );
    expect(find.text('Etkinlik 21'), findsOneWidget);
    final calls = api.adapter.requests
        .where((r) => r.path == '/api/events')
        .toList();
    expect(calls.last.queryParameters['page'], 2);
    expect(
      calls.last.queryParameters['from'],
      calls.first.queryParameters['from'],
    );
    expect(calls.last.queryParameters['status'], 'Published');
  });

  testWidgets('listelendikten sonra kaldırılan etkinlik açıklanır', (
    tester,
  ) async {
    final api = _Api();
    await _open(tester, api);
    api.events.removeWhere((event) => event['id'] == 1);
    await tester.tap(find.text('Kampüs Konseri'));
    await tester.pumpAndSettle();
    expect(
      find.text('Etkinlik bulunamadı veya yayından kaldırıldı.'),
      findsOneWidget,
    );
  });

  testWidgets('sonradan iptal edilen etkinliğin ayrıntısında uyarı görünür', (
    tester,
  ) async {
    final api = _Api();
    await _open(tester, api);
    api.events.first['status'] = 'Cancelled';
    await tester.tap(find.text('Kampüs Konseri'));
    await tester.pumpAndSettle();
    expect(find.text('Bu etkinlik iptal edildi.'), findsOneWidget);
  });

  testWidgets('dar telefonda akış ve ayrıntı taşmaz', (tester) async {
    final api = _Api();
    await _open(tester, api, width: 320);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Kampüs Konseri'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
