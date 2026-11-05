import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../events/event_models.dart';
import '../events/events_repository.dart';

enum EventPeriod { upcoming, past }

typedef EventFeedFilter = ({String search, int? clubId, EventPeriod period});

class EventFeedState {
  const EventFeedState({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.boundary,
    this.isLoadingMore = false,
  });

  final List<ClubEvent> items;
  final int totalCount;
  final int page;
  final DateTime boundary;
  final bool isLoadingMore;

  bool get hasMore => page * EventsFeedController.pageSize < totalCount;

  EventFeedState loadingMore(bool value) => EventFeedState(
    items: items,
    totalCount: totalCount,
    page: page,
    boundary: boundary,
    isLoadingMore: value,
  );
}

/// Öğrenci akışı yalnızca yayındaki etkinlikleri ister. Durum filtresi
/// sunucuda uygulanır; toplam sayı ve sayfalama da aynı filtreyi kullanır.
class EventsFeedController extends AsyncNotifier<EventFeedState> {
  EventsFeedController(this.filter);

  static const pageSize = 20;
  final EventFeedFilter filter;
  int _generation = 0;
  bool _isRefreshing = false;

  @override
  Future<EventFeedState> build() => _firstPage();

  Future<EventPage> _fetch(int page, DateTime boundary) {
    final past = filter.period == EventPeriod.past;
    return ref
        .read(eventsRepositoryProvider)
        .list(
          page: page,
          pageSize: pageSize,
          search: filter.search,
          clubId: filter.clubId,
          from: past ? null : boundary,
          to: past ? boundary : null,
          descending: past,
          status: EventStatus.published,
        );
  }

  Future<EventFeedState> _firstPage() async {
    final boundary = DateTime.now().toUtc();
    final page = await _fetch(1, boundary);
    return EventFeedState(
      items: page.items,
      totalCount: page.totalCount,
      page: page.page,
      boundary: boundary,
    );
  }

  Future<void> refresh() async {
    if (state.isLoading) return;
    final generation = ++_generation;
    _isRefreshing = true;
    final current = state.value;
    if (current != null) state = AsyncData(current.loadingMore(false));
    try {
      final fresh = await _firstPage();
      if (ref.mounted && generation == _generation) state = AsyncData(fresh);
    } on EventsException catch (error, stack) {
      if (!ref.mounted || generation != _generation) return;
      if (state.hasValue && !state.hasError) rethrow;
      state = AsyncError(error, stack);
    } finally {
      if (generation == _generation) _isRefreshing = false;
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (_isRefreshing ||
        current == null ||
        current.isLoadingMore ||
        !current.hasMore) {
      return;
    }
    final generation = _generation;
    state = AsyncData(current.loadingMore(true));
    try {
      final next = await _fetch(current.page + 1, current.boundary);
      if (!ref.mounted || generation != _generation) return;
      final items = {for (final event in current.items) event.id: event};
      for (final event in next.items) {
        items[event.id] = event;
      }
      state = AsyncData(
        EventFeedState(
          items: items.values.toList(),
          totalCount: next.totalCount,
          page: next.page,
          boundary: current.boundary,
        ),
      );
    } on EventsException {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(current);
      rethrow;
    }
  }
}

final eventsFeedProvider = AsyncNotifierProvider.autoDispose
    .family<EventsFeedController, EventFeedState, EventFeedFilter>(
      EventsFeedController.new,
      retry: (_, _) => null,
    );
