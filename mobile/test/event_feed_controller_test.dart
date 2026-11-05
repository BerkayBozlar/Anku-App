import 'dart:async';

import 'package:anku_app/features/discover/event_feed_controller.dart';
import 'package:anku_app/features/events/event_models.dart';
import 'package:anku_app/features/events/events_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends EventsRepository {
  _Repository() : super(Dio());
  final calls = <({int page, Completer<EventPage> result})>[];

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
  }) {
    final result = Completer<EventPage>();
    calls.add((page: page, result: result));
    return result.future;
  }

  void complete(int call, List<int> ids, {int total = 21}) =>
      calls[call].result.complete(
        EventPage(
          items: [
            for (final id in ids)
              ClubEvent(
                id: id,
                clubId: 1,
                title: 'Etkinlik $id',
                eventDate: DateTime.utc(2030),
                status: EventStatus.published,
              ),
          ],
          page: calls[call].page,
          pageSize: 20,
          totalCount: total,
        ),
      );
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  const filter = (search: '', clubId: null, period: EventPeriod.upcoming);

  test('geç biten ikinci sayfa yenilenmiş listeyi ezmez', () async {
    final repo = _Repository();
    final container = ProviderContainer(
      overrides: [eventsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final provider = eventsFeedProvider(filter);
    container.listen(provider, (_, _) {});
    await _settle();
    repo.complete(0, [for (var i = 1; i <= 20; i++) i]);
    await container.read(provider.future);
    final notifier = container.read(provider.notifier);
    final more = notifier.loadMore();
    final refresh = notifier.refresh();
    repo.complete(2, [99], total: 1);
    await refresh;
    repo.complete(1, [21]);
    await more;
    expect(container.read(provider).value!.items.map((event) => event.id), [
      99,
    ]);
    expect(container.read(provider).value!.isLoadingMore, isFalse);
  });

  test('yenileme hatası sayfalama düğmesini kilitlemez', () async {
    final repo = _Repository();
    final container = ProviderContainer(
      overrides: [eventsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final provider = eventsFeedProvider(filter);
    container.listen(provider, (_, _) {});
    await _settle();
    repo.complete(0, [for (var i = 1; i <= 20; i++) i]);
    await container.read(provider.future);
    final notifier = container.read(provider.notifier);
    final oldMore = notifier.loadMore();
    final refresh = notifier.refresh();
    repo.calls[2].result.completeError(const EventsException('Ağ hatası'));
    await expectLater(refresh, throwsA(isA<EventsException>()));
    repo.complete(1, [21]);
    await oldMore;
    expect(container.read(provider).value!.isLoadingMore, isFalse);
    final retry = notifier.loadMore();
    repo.complete(3, [21]);
    await retry;
    expect(container.read(provider).value!.items.last.id, 21);
  });
}
