import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'event_models.dart';
import 'events_repository.dart';

/// Yönetim ekranındaki sekmeler.
enum EventTimeframe {
  /// Tarihi gelmemiş etkinlikler, en yakın önce.
  upcoming,

  /// Tarihi geçmiş etkinlikler, en yeni önce; salt okunur.
  past,
}

/// İki sekmenin ortak arama metni.
class AdminEventSearch extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value.trim();
}

final adminEventSearchProvider =
    NotifierProvider.autoDispose<AdminEventSearch, String>(
      AdminEventSearch.new,
    );

class AdminEventsState {
  const AdminEventsState({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.boundary,
    this.search = '',
    this.isLoadingMore = false,
  });

  final List<ClubEvent> items;
  final int totalCount;

  /// Son yüklenen sayfa.
  final int page;

  /// Yaklaşan/geçmiş ayrımının yapıldığı an. Sonraki sayfalar da aynı anla
  /// istenir; aksi halde sayfalar arasında etkinlik kayabilir.
  final DateTime boundary;
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
      boundary: boundary,
      search: search,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Bir sekmenin sayfalı etkinlik listesi. Arama değişince baştan yüklenir.
class AdminEventsController extends AsyncNotifier<AdminEventsState> {
  AdminEventsController(this.timeframe);

  static const pageSize = 20;

  final EventTimeframe timeframe;

  @override
  Future<AdminEventsState> build() =>
      _firstPage(ref.watch(adminEventSearchProvider));

  Future<EventPage> _fetch(int page, String search, DateTime boundary) {
    final past = timeframe == EventTimeframe.past;
    return ref
        .read(eventsRepositoryProvider)
        .list(
          page: page,
          pageSize: pageSize,
          search: search,
          from: past ? null : boundary,
          to: past ? boundary : null,
          descending: past,
        );
  }

  Future<AdminEventsState> _firstPage(String search) async {
    final boundary = DateTime.now().toUtc();
    final page = await _fetch(1, search, boundary);
    return AdminEventsState(
      items: page.items,
      totalCount: page.totalCount,
      page: 1,
      boundary: boundary,
      search: search,
    );
  }

  /// Listeyi baştan yükler. Liste zaten gösteriliyorsa hata [EventsException]
  /// olarak fırlatılır ve mevcut liste korunur.
  Future<void> refresh() async {
    final search = ref.read(adminEventSearchProvider);
    final boundary = state.value?.boundary;
    try {
      final fresh = await _firstPage(search);
      if (!_isCurrent(search, boundary)) return;
      state = AsyncData(fresh);
    } on EventsException catch (e, st) {
      if (!_isCurrent(search, boundary)) return;
      if (state.hasValue && !state.hasError) rethrow;
      state = AsyncError(e, st);
    }
  }

  /// Sonraki sayfayı ekler; hata [EventsException] olarak fırlatılır.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _fetch(
        current.page + 1,
        current.search,
        current.boundary,
      );
      if (!_isCurrent(current.search, current.boundary)) return;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next.items],
          totalCount: next.totalCount,
          page: next.page,
          isLoadingMore: false,
        ),
      );
    } on EventsException {
      if (_isCurrent(current.search, current.boundary)) {
        state = AsyncData(current);
      }
      rethrow;
    }
  }

  /// Siler ve ilk sayfayı yeniden ister. Yerelden çıkarmak sunucudaki sayfa
  /// sınırlarını kaydırır ve "Daha fazla göster" bir etkinliği atlardı.
  Future<void> delete(int id) async {
    await ref.read(eventsRepositoryProvider).delete(id);
    if (!ref.mounted) return;
    try {
      await refresh();
    } on EventsException {
      // Silme başarılı; yenileme olmadı. Liste en azından silineni göstermesin.
      final current = state.value;
      if (!ref.mounted || current == null) return;
      state = AsyncData(
        current.copyWith(
          items: current.items.where((e) => e.id != id).toList(),
          totalCount: current.totalCount - 1,
        ),
      );
    }
  }

  /// Beklerken sekme kapanmadıysa, arama değişmediyse ve liste başka bir
  /// yoldan yeniden yüklenmediyse sonuç uygulanabilir.
  bool _isCurrent(String search, DateTime? boundary) =>
      ref.mounted &&
      !state.isLoading &&
      ref.read(adminEventSearchProvider) == search &&
      state.value?.boundary == boundary;
}

final adminEventsProvider = AsyncNotifierProvider.autoDispose
    .family<AdminEventsController, AdminEventsState, EventTimeframe>(
      AdminEventsController.new,
      retry: (_, _) => null,
    );
