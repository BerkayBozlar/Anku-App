import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import 'announcement_models.dart';
import 'announcements_repository.dart';

class AnnouncementFeedState {
  const AnnouncementFeedState({
    required this.items,
    required this.totalCount,
    required this.page,
    this.isLoadingMore = false,
  });

  final List<Announcement> items;
  final int totalCount;
  final int page;
  final bool isLoadingMore;

  bool get hasMore => page * AnnouncementsController.pageSize < totalCount;

  AnnouncementFeedState loadingMore(bool value) => AnnouncementFeedState(
    items: items,
    totalCount: totalCount,
    page: page,
    isLoadingMore: value,
  );
}

/// Duyuru akışı; aile anahtarı arama metnidir (boş = tümü).
class AnnouncementsController extends AsyncNotifier<AnnouncementFeedState> {
  AnnouncementsController(this.search);

  static const pageSize = 20;
  final String search;
  int _generation = 0;
  bool _isRefreshing = false;

  @override
  Future<AnnouncementFeedState> build() => _firstPage();

  Future<AnnouncementPage> _fetch(int page) => ref
      .read(announcementsRepositoryProvider)
      .list(page: page, pageSize: pageSize, search: search);

  Future<AnnouncementFeedState> _firstPage() async {
    final page = await _fetch(1);
    return AnnouncementFeedState(
      items: page.items,
      totalCount: page.totalCount,
      page: page.page,
    );
  }

  /// Aşağı çekip yenileme. Liste varken hata olursa liste korunur ve hata
  /// çağırana iletilir (ekran SnackBar gösterir).
  Future<void> refresh() async {
    if (state.isLoading) return;
    final generation = ++_generation;
    _isRefreshing = true;
    final current = state.value;
    if (current != null) state = AsyncData(current.loadingMore(false));
    try {
      final fresh = await _firstPage();
      if (ref.mounted && generation == _generation) state = AsyncData(fresh);
    } on ApiException catch (error, stack) {
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
      final next = await _fetch(current.page + 1);
      if (!ref.mounted || generation != _generation) return;
      // Yeni duyuru eklenince sayfalar kayabilir; aynı kayıt iki kez görünmesin
      final items = {for (final item in current.items) item.id: item};
      for (final item in next.items) {
        items[item.id] = item;
      }
      state = AsyncData(
        AnnouncementFeedState(
          items: items.values.toList(),
          totalCount: next.totalCount,
          page: next.page,
        ),
      );
    } on ApiException {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(current);
      rethrow;
    }
  }
}

final announcementsFeedProvider = AsyncNotifierProvider.autoDispose
    .family<AnnouncementsController, AnnouncementFeedState, String>(
      AnnouncementsController.new,
      retry: (_, _) => null,
    );
