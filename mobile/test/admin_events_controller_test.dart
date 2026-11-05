import 'dart:async';

import 'package:anku_app/features/events/admin_events_controller.dart';
import 'package:anku_app/features/events/event_models.dart';
import 'package:anku_app/features/events/events_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Her `list` çağrısını test bitirene kadar bekleten sahte repository.
class _ControlledRepository implements EventsRepository {
  final calls = <(String?, Completer<EventPage>)>[];

  @override
  Future<EventPage> list({
    int page = 1,
    int pageSize = 20,
    String? search,
    int? clubId,
    DateTime? from,
    DateTime? to,
    bool descending = false,
  }) {
    final completer = Completer<EventPage>();
    calls.add((search, completer));
    return completer.future;
  }

  void complete(int call, List<String> titles) {
    calls[call].$2.complete(
      EventPage(
        items: [
          for (var i = 0; i < titles.length; i++)
            ClubEvent(
              id: i + 1,
              clubId: 1,
              title: titles[i],
              eventDate: DateTime.utc(2030, 1, 1 + i),
              status: EventStatus.published,
            ),
        ],
        page: 1,
        pageSize: 20,
        totalCount: titles.length,
      ),
    );
  }

  @override
  Future<ClubEvent> get(int id) => throw UnimplementedError();

  @override
  Future<ClubEvent> create(EventInput input) => throw UnimplementedError();

  @override
  Future<void> update(int id, EventInput input) => throw UnimplementedError();

  @override
  Future<void> delete(int id) => throw UnimplementedError();
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('geç biten yenileme yeni aramanın sonucunu ezmez', () async {
    final repo = _ControlledRepository();
    final container = ProviderContainer(
      overrides: [eventsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final provider = adminEventsProvider(EventTimeframe.upcoming);
    container.listen(provider, (_, _) {});

    await _settle();
    repo.complete(0, ['Kampüs Konseri', 'Bahar Şenliği']);
    await container.read(provider.future);

    // Yenileme sürerken arama değişir
    final refresh = container.read(provider.notifier).refresh();
    container.read(adminEventSearchProvider.notifier).set('Konser');
    await _settle();

    final searchCall = repo.calls.indexWhere((c) => c.$1 == 'Konser');
    expect(searchCall, isNot(-1));
    repo.complete(searchCall, ['Kampüs Konseri']);
    await _settle();

    // Eski aramayla başlayan yenileme en son biter
    repo.complete(1, ['Kampüs Konseri', 'Bahar Şenliği']);
    await refresh;
    await _settle();

    final state = container.read(provider).value!;
    expect(state.search, 'Konser');
    expect(state.items.map((e) => e.title), ['Kampüs Konseri']);
  });
}
