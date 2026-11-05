import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'event_models.dart';
import 'events_repository.dart';

class AdminEventsState {
  const AdminEventsState({
    required this.items,
    required this.totalCount,
    required this.page,
    this.search = '',
    this.isLoadingMore = false,
  });

  final List<ClubEvent> items;
  final int totalCount;

  /// Son yüklenen sayfa.
  final int page;
  final String search;
  final bool isLoadingMore;

  bool get hasMore => items.length < totalCount;

  AdminEventsState copyWith({
    List<ClubEvent>? items,
    int? totalCount,
    int? page,
    bool? isLoadingMore,
  }) {
    return AdminEventsState(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      page: page ?? this.page,
      search: search,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Yönetim ekranındaki sayfalı etkinlik listesi.
class AdminEventsController extends AsyncNotifier<AdminEventsState> {
  static const pageSize = 20;

  String _search = '';

  @override
  Future<AdminEventsState> build() => _firstPage();

  Future<AdminEventsState> _firstPage() async {
    final search = _search;
    final page = await ref
        .read(eventsRepositoryProvider)
        .list(page: 1, pageSize: pageSize, search: search);
    return AdminEventsState(
      items: page.items,
      totalCount: page.totalCount,
      page: 1,
      search: search,
    );
  }

  /// Listeyi baştan yükler. Liste zaten gösteriliyorsa hata [EventsException]
  /// olarak fırlatılır ve mevcut liste korunur.
  Future<void> refresh() async {
    try {
      state = AsyncData(await _firstPage());
    } on EventsException catch (e, st) {
      if (state.hasValue && !state.hasError) rethrow;
      state = AsyncError(e, st);
    }
  }

  /// Aramayı uygular; aynı arama zaten gösteriliyorsa bir şey yapmaz,
  /// hata sonrası "Tekrar dene" için de kullanılır.
  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed == _search && state.hasValue && !state.hasError) return;
    _search = trimmed;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_firstPage);
  }

  /// Sonraki sayfayı ekler; hata [EventsException] olarak fırlatılır.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await ref
          .read(eventsRepositoryProvider)
          .list(
            page: current.page + 1,
            pageSize: pageSize,
            search: current.search,
          );
      // Bu arada arama değiştiyse eski sonuç eklenmez
      if (!ref.mounted || state.value?.search != current.search) return;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next.items],
          totalCount: next.totalCount,
          page: next.page,
          isLoadingMore: false,
        ),
      );
    } on EventsException {
      if (ref.mounted) state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> delete(int id) async {
    await ref.read(eventsRepositoryProvider).delete(id);
    final current = state.value;
    if (current == null || !ref.mounted) return;
    state = AsyncData(
      current.copyWith(
        items: current.items.where((e) => e.id != id).toList(),
        totalCount: current.totalCount - 1,
      ),
    );
  }
}

final adminEventsProvider =
    AsyncNotifierProvider.autoDispose<AdminEventsController, AdminEventsState>(
      AdminEventsController.new,
      retry: (_, _) => null,
    );
