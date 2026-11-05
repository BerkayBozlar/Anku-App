import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/network/api_client.dart';
import 'admin_events_controller.dart';
import 'event_models.dart';
import 'events_repository.dart';

/// Yalnızca Yönetici: yaklaşan ve geçmiş etkinlik sekmeleri, arama, ekleme,
/// düzenleme ve silme. Geçmiş etkinlikler salt okunurdur.
class AdminEventsScreen extends ConsumerStatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  ConsumerState<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends ConsumerState<AdminEventsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applySearch(String value) =>
      ref.read(adminEventSearchProvider.notifier).set(value);

  /// Form ekranı kaydedince bir mesajla döner; iki sekme de yenilenir
  /// (düzenlenen etkinlik sekme değiştirmiş olabilir).
  Future<void> _openForm([ClubEvent? event]) async {
    final message = await context.push<String>(
      event == null ? '/admin/events/new' : '/admin/events/${event.id}',
    );
    if (message == null || !mounted) return;
    _showMessage(context, message);
    ref.invalidate(adminEventsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Etkinlik yönetimi'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Yaklaşan'),
              Tab(text: 'Geçmiş'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Etkinlik ekle'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Başlıkta ara',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: ListenableBuilder(
                    listenable: _search,
                    builder: (context, _) => _search.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            tooltip: 'Aramayı temizle',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _search.clear();
                              _applySearch('');
                            },
                          ),
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _applySearch,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _EventsTab(
                    timeframe: EventTimeframe.upcoming,
                    onEdit: _openForm,
                    onAdd: () => _openForm(),
                  ),
                  _EventsTab(
                    timeframe: EventTimeframe.past,
                    onEdit: _openForm,
                    onAdd: () => _openForm(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Bir sekmenin listesi; yükleme, hata ve boş durumlarıyla.
class _EventsTab extends ConsumerWidget {
  const _EventsTab({
    required this.timeframe,
    required this.onEdit,
    required this.onAdd,
  });

  final EventTimeframe timeframe;
  final ValueChanged<ClubEvent> onEdit;
  final VoidCallback onAdd;

  bool get _isPast => timeframe == EventTimeframe.past;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on EventsException catch (e) {
      if (context.mounted) _showMessage(context, e.message);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ClubEvent event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Etkinlik silinsin mi?'),
        content: Text('"${event.title}" silinecek. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(adminEventsProvider(timeframe).notifier).delete(event.id);
      if (context.mounted) _showMessage(context, 'Etkinlik silindi.');
    } on EventsException catch (e) {
      if (!context.mounted) return;
      // Geçmiş etkinlik düzenlenemediği için iptal önerisi yalnız yaklaşanlarda
      final hint = e.statusCode == 409 && !_isPast
          ? ' Bunun yerine durumunu "İptal edildi" yapabilirsiniz.'
          : '';
      _showMessage(context, e.message + hint);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = adminEventsProvider(timeframe);
    final events = ref.watch(provider);

    return switch (events) {
      AsyncData(:final value) => _EventList(
        state: value,
        isPast: _isPast,
        onRefresh: () => _run(context, ref.read(provider.notifier).refresh),
        onLoadMore: () => _run(context, ref.read(provider.notifier).loadMore),
        onOpen: _isPast ? (e) => _showDetails(context, e) : onEdit,
        onDelete: (e) => _confirmDelete(context, ref, e),
        onAdd: onAdd,
      ),
      AsyncError(:final error) => _ErrorView(
        message: error is EventsException
            ? error.message
            : describeApiError(error),
        onRetry: () => ref.invalidate(provider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _EventList extends StatelessWidget {
  const _EventList({
    required this.state,
    required this.isPast,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onOpen,
    required this.onDelete,
    required this.onAdd,
  });

  final AdminEventsState state;
  final bool isPast;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final ValueChanged<ClubEvent> onOpen;
  final ValueChanged<ClubEvent> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      final String message;
      if (state.search.isNotEmpty) {
        message = '"${state.search}" için etkinlik bulunamadı.';
      } else if (isPast) {
        message = 'Tarihi geçmiş etkinlik yok.';
      } else {
        message = 'Yaklaşan etkinlik yok.';
      }

      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            Icon(
              isPast ? Icons.history_outlined : Icons.event_busy_outlined,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (state.search.isEmpty && !isPast) ...[
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: onAdd,
                  child: const Text('Etkinlik ekle'),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        // Alttaki "Etkinlik ekle" düğmesi son öğeyi örtmesin
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: state.isLoadingMore
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: onLoadMore,
                        child: const Text('Daha fazla göster'),
                      ),
              ),
            );
          }
          final event = state.items[index];
          return _EventTile(
            event: event,
            isPast: isPast,
            onTap: () => onOpen(event),
            onDelete: () => onDelete(event),
          );
        },
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.isPast,
    required this.onTap,
    required this.onDelete,
  });

  final ClubEvent event;
  final bool isPast;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (event.clubName != null) event.clubName!,
      formatDateTime(event.eventDate.toLocal()),
      if (event.capacity != null) '${event.capacity} kişi',
    ].join(' · ');

    return ListTile(
      onTap: onTap,
      title: Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(details),
            const SizedBox(height: 4),
            EventStatusChip(status: event.status),
          ],
        ),
      ),
      trailing: PopupMenuButton<_TileAction>(
        tooltip: 'İşlemler',
        onSelected: (action) => switch (action) {
          _TileAction.open => onTap(),
          _TileAction.delete => onDelete(),
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _TileAction.open,
            child: ListTile(
              leading: Icon(isPast ? Icons.info_outline : Icons.edit_outlined),
              title: Text(isPast ? 'Ayrıntı' : 'Düzenle'),
            ),
          ),
          const PopupMenuItem(
            value: _TileAction.delete,
            child: ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('Sil'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TileAction { open, delete }

/// Geçmiş etkinliğin salt okunur ayrıntısı.
void _showDetails(BuildContext context, ClubEvent event) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      Widget row(IconData icon, String label, String value) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
        dense: true,
      );

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(event.title, style: theme.textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Wrap(
                  spacing: 8,
                  children: [
                    EventStatusChip(status: event.status),
                    Text(
                      'Tarihi geçti, düzenlenemez',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              row(Icons.groups_outlined, 'Kulüp', event.clubName ?? '-'),
              row(
                Icons.schedule,
                'Tarih',
                formatDateTime(event.eventDate.toLocal()),
              ),
              row(
                Icons.people_outline,
                'Kontenjan',
                event.capacity?.toString() ?? '-',
              ),
              if (event.campusLocationName != null)
                row(Icons.place_outlined, 'Konum', event.campusLocationName!),
              if (event.description?.isNotEmpty ?? false)
                row(Icons.notes, 'Açıklama', event.description!),
            ],
          ),
        ),
      );
    },
  );
}

class EventStatusChip extends StatelessWidget {
  const EventStatusChip({super.key, required this.status});

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      EventStatus.published => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      EventStatus.cancelled => (scheme.errorContainer, scheme.onErrorContainer),
      EventStatus.draft => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          status.label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: foreground),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
