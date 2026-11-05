import 'package:anku_app/app.dart';
import 'package:anku_app/features/auth/auth_models.dart';
import 'package:anku_app/features/auth/session_storage.dart';
import 'package:anku_app/features/clubs/club_models.dart';
import 'package:anku_app/features/clubs/clubs_repository.dart';
import 'package:anku_app/features/events/event_models.dart';
import 'package:anku_app/features/events/events_repository.dart';
import 'package:anku_app/features/health/api_health.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

class _FakeClubsRepository implements ClubsRepository {
  @override
  Future<Club> get(int id) async =>
      (await list()).firstWhere((club) => club.id == id);

  @override
  Future<List<Club>> list() async => const [
    Club(id: 1, name: 'Müzik Topluluğu'),
    Club(id: 2, name: 'Satranç Kulübü'),
  ];
}

class _FakeEventsRepository implements EventsRepository {
  _FakeEventsRepository(this.events);

  final List<ClubEvent> events;
  EventsException? listError;
  EventsException? deleteError;
  final updates = <(int, EventInput)>[];
  final listCalls = <({DateTime? from, DateTime? to, bool descending})>[];

  @override
  Future<EventPage> list({
    int page = 1,
    int pageSize = 20,
    String? search,
    int? clubId,
    DateTime? from,
    DateTime? to,
    bool descending = false,
    EventStatus? status,
  }) async {
    listCalls.add((from: from, to: to, descending: descending));
    if (listError != null) throw listError!;
    final matching =
        events
            .where((e) => search == null || e.title.contains(search))
            .where((e) => from == null || !e.eventDate.isBefore(from))
            .where((e) => to == null || e.eventDate.isBefore(to))
            .toList()
          ..sort(
            (a, b) => descending
                ? b.eventDate.compareTo(a.eventDate)
                : a.eventDate.compareTo(b.eventDate),
          );
    return EventPage(
      items: matching.skip((page - 1) * pageSize).take(pageSize).toList(),
      page: page,
      pageSize: pageSize,
      totalCount: matching.length,
    );
  }

  @override
  Future<ClubEvent> get(int id) async => events.firstWhere((e) => e.id == id);

  @override
  Future<ClubEvent> create(EventInput input) => throw UnimplementedError();

  @override
  Future<void> update(int id, EventInput input) async {
    updates.add((id, input));
    final index = events.indexWhere((e) => e.id == id);
    events[index] = _event(id, input.title, campusLocationId: 3);
  }

  @override
  Future<void> delete(int id) async {
    if (deleteError != null) throw deleteError!;
    events.removeWhere((e) => e.id == id);
  }
}

/// [daysFromNow] eksi ise geçmiş etkinlik.
ClubEvent _event(
  int id,
  String title, {
  int? campusLocationId,
  int daysFromNow = 10,
}) => ClubEvent(
  id: id,
  clubId: 1,
  clubName: 'Müzik Topluluğu',
  campusLocationId: campusLocationId,
  title: title,
  eventDate: DateTime.now().toUtc().add(
    Duration(days: daysFromNow, minutes: id),
  ),
  capacity: 100,
  status: EventStatus.published,
);

Future<void> _openEventsAsAdmin(
  WidgetTester tester,
  _FakeEventsRepository events,
) async {
  // Telefon boyu: formun tamamı ekrana sığsın
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(
          MemorySessionStorage(sessionFor(UserRole.yonetici)),
        ),
        apiHealthProvider.overrideWith(
          (ref) async => const ApiHealth(status: 'ok', application: 'test'),
        ),
        eventsRepositoryProvider.overrideWithValue(events),
        clubsRepositoryProvider.overrideWithValue(_FakeClubsRepository()),
      ],
      child: const AnkuApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Yönetim'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Etkinlikler'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('etkinlikler kulüp ve durumla listelenir', (tester) async {
    await _openEventsAsAdmin(
      tester,
      _FakeEventsRepository([_event(1, 'Kampüs Konseri')]),
    );

    expect(find.text('Etkinlik yönetimi'), findsOneWidget);
    expect(find.text('Kampüs Konseri'), findsOneWidget);
    expect(find.textContaining('Müzik Topluluğu'), findsOneWidget);
    expect(find.text('Yayında'), findsOneWidget);
  });

  testWidgets('etkinlik yoksa boş durum gösterilir', (tester) async {
    await _openEventsAsAdmin(tester, _FakeEventsRepository([]));

    expect(find.text('Yaklaşan etkinlik yok.'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Etkinlik ekle'),
      findsOneWidget,
    );
  });

  testWidgets('geçmiş etkinlikler ayrı sekmede, en yeni önce', (tester) async {
    final repo = _FakeEventsRepository([
      _event(1, 'Kampüs Konseri'),
      _event(2, 'Eylül Buluşması', daysFromNow: -60),
      _event(3, 'Ekim Söyleşisi', daysFromNow: -30),
    ]);
    await _openEventsAsAdmin(tester, repo);

    expect(find.text('Kampüs Konseri'), findsOneWidget);
    expect(find.text('Ekim Söyleşisi'), findsNothing);

    await tester.tap(find.text('Geçmiş'));
    await tester.pumpAndSettle();

    expect(find.text('Kampüs Konseri'), findsNothing);
    final newer = tester.getTopLeft(find.text('Ekim Söyleşisi')).dy;
    final older = tester.getTopLeft(find.text('Eylül Buluşması')).dy;
    expect(newer, lessThan(older));

    // Yaklaşan: from=şimdi artan; geçmiş: to=şimdi azalan
    expect(repo.listCalls.first.from, isNotNull);
    expect(repo.listCalls.first.descending, isFalse);
    expect(repo.listCalls.last.to, isNotNull);
    expect(repo.listCalls.last.descending, isTrue);
  });

  testWidgets('geçmiş etkinlik düzenlenmez, ayrıntısı açılır', (tester) async {
    await _openEventsAsAdmin(
      tester,
      _FakeEventsRepository([_event(2, 'Ekim Söyleşisi', daysFromNow: -30)]),
    );
    await tester.tap(find.text('Geçmiş'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('İşlemler'));
    await tester.pumpAndSettle();
    expect(find.text('Düzenle'), findsNothing);
    expect(find.text('Ayrıntı'), findsOneWidget);
    expect(find.text('Sil'), findsOneWidget);

    await tester.tap(find.text('Ayrıntı'));
    await tester.pumpAndSettle();

    expect(find.text('Tarihi geçti, düzenlenemez'), findsOneWidget);
    expect(find.text('Etkinliği düzenle'), findsNothing);
  });

  testWidgets('arama iki sekmeye de uygulanır', (tester) async {
    await _openEventsAsAdmin(
      tester,
      _FakeEventsRepository([
        _event(1, 'Kampüs Konseri'),
        _event(2, 'Bahar Şenliği'),
        _event(3, 'Eski Konser', daysFromNow: -30),
        _event(4, 'Eski Şenlik', daysFromNow: -20),
      ]),
    );

    await tester.enterText(find.byType(TextField), 'Konser');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Kampüs Konseri'), findsOneWidget);
    expect(find.text('Bahar Şenliği'), findsNothing);

    await tester.tap(find.text('Geçmiş'));
    await tester.pumpAndSettle();
    expect(find.text('Eski Konser'), findsOneWidget);
    expect(find.text('Eski Şenlik'), findsNothing);
  });

  testWidgets('yükleme hatası ve tekrar deneme', (tester) async {
    final repo = _FakeEventsRepository([_event(1, 'Kampüs Konseri')])
      ..listError = const EventsException('Sunucuya bağlanılamadı.');
    await _openEventsAsAdmin(tester, repo);

    expect(find.text('Sunucuya bağlanılamadı.'), findsOneWidget);

    repo.listError = null;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(find.text('Kampüs Konseri'), findsOneWidget);
  });

  testWidgets('daha fazla göster sonraki sayfayı ekler', (tester) async {
    await _openEventsAsAdmin(
      tester,
      _FakeEventsRepository([
        for (var i = 1; i <= 21; i++) _event(i, 'Etkinlik $i'),
      ]),
    );

    final list = find.descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    );
    expect(find.text('Etkinlik 21'), findsNothing);
    // Listenin sonuna in: alttaki boşluk sayesinde düğme "Etkinlik ekle"nin üstünde kalır
    await tester.fling(list, const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daha fazla göster'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Etkinlik 21'),
      300,
      scrollable: list,
    );

    expect(find.text('Etkinlik 21'), findsOneWidget);
    expect(find.text('Daha fazla göster'), findsNothing);
  });

  testWidgets('boş form doğrulama mesajlarını gösterir', (tester) async {
    await _openEventsAsAdmin(tester, _FakeEventsRepository([]));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Kulüp seçin.'), findsOneWidget);
    expect(find.text('Başlık zorunludur.'), findsOneWidget);
    expect(find.text('Tarih ve saat seçin.'), findsOneWidget);
    expect(find.text('Kontenjan zorunludur.'), findsOneWidget);
  });

  testWidgets('düzenleme kaydedilir, konum korunur, liste yenilenir', (
    tester,
  ) async {
    final repo = _FakeEventsRepository([
      _event(7, 'Kampüs Konseri', campusLocationId: 3),
    ]);
    await _openEventsAsAdmin(tester, repo);

    await tester.tap(find.text('Kampüs Konseri'));
    await tester.pumpAndSettle();
    expect(find.text('Etkinliği düzenle'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kampüs Konseri'),
      'Bahar Konseri',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();

    final (id, input) = repo.updates.single;
    expect(id, 7);
    expect(input.title, 'Bahar Konseri');
    expect(input.campusLocationId, 3);
    expect(input.clubId, 1);
    expect(find.text('Etkinlik güncellendi.'), findsOneWidget);
    expect(find.text('Bahar Konseri'), findsOneWidget);
  });

  testWidgets('silme onaylanınca etkinlik listeden kalkar', (tester) async {
    await _openEventsAsAdmin(
      tester,
      _FakeEventsRepository([_event(1, 'Kampüs Konseri')]),
    );

    await tester.tap(find.byTooltip('İşlemler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(find.text('Etkinlik silinsin mi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();

    expect(find.text('Etkinlik silindi.'), findsOneWidget);
    expect(find.text('Kampüs Konseri'), findsNothing);
  });

  testWidgets('silme sonrası "Daha fazla göster" etkinlik atlamaz', (
    tester,
  ) async {
    final repo = _FakeEventsRepository([
      for (var i = 1; i <= 21; i++) _event(i, 'Etkinlik $i'),
    ]);
    await _openEventsAsAdmin(tester, repo);

    await tester.tap(find.byTooltip('İşlemler').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();

    // İlk sayfa yeniden istendi: 20 etkinlik kaldı, hepsi tek sayfada
    expect(find.text('Etkinlik silindi.'), findsOneWidget);
    final list = find.descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    );
    await tester.fling(list, const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();
    expect(find.text('Etkinlik 21'), findsOneWidget);
    expect(find.text('Daha fazla göster'), findsNothing);
  });

  testWidgets('başvurulu etkinlik: iptal önerisi yalnız yaklaşanlarda', (
    tester,
  ) async {
    const conflict = EventsException(
      'Etkinliğe yapılmış başvurular olduğu için silinemiyor.',
      statusCode: 409,
    );
    final repo = _FakeEventsRepository([
      _event(1, 'Kampüs Konseri'),
      _event(2, 'Ekim Söyleşisi', daysFromNow: -30),
    ])..deleteError = conflict;
    await _openEventsAsAdmin(tester, repo);

    Future<void> deleteFirst() async {
      await tester.tap(find.byTooltip('İşlemler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
      await tester.pumpAndSettle();
    }

    await deleteFirst();
    expect(
      find.text(
        'Etkinliğe yapılmış başvurular olduğu için silinemiyor. '
        'Bunun yerine durumunu "İptal edildi" yapabilirsiniz.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Geçmiş'));
    await tester.pumpAndSettle();
    await deleteFirst();
    expect(find.text(conflict.message), findsOneWidget);
    expect(find.textContaining('İptal edildi'), findsNothing);
  });

  testWidgets('silinemeyen etkinlikte API mesajı gösterilir', (tester) async {
    final repo = _FakeEventsRepository([_event(1, 'Kampüs Konseri')])
      ..deleteError = const EventsException('Etkinliğe başvurular var.');
    await _openEventsAsAdmin(tester, repo);

    await tester.tap(find.byTooltip('İşlemler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();

    expect(find.text('Etkinliğe başvurular var.'), findsOneWidget);
    expect(find.text('Kampüs Konseri'), findsOneWidget);
  });
}
