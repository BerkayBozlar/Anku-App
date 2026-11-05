import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/network/api_client.dart';
import 'admin_events_controller.dart';
import 'event_models.dart';
import 'events_repository.dart';

/// Yalnızca Yönetici: etkinlik listesi, arama, ekleme, düzenleme ve silme.
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

  AdminEventsController get _controller =>
      ref.read(adminEventsProvider.notifier);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Form ekranı kaydedince bir mesajla döner; liste yenilenir.
  Future<void> _openForm([ClubEvent? event]) async {
    final message = await context.push<String>(
      event == null ? '/admin/events/new' : '/admin/events/${event.id}',
    );
    if (message == null || !mounted) return;
    _showMessage(message);
    await _refresh();
  }

  Future<void> _refresh() async {
    try {
      await _controller.refresh();
    } on EventsException catch (e) {
      if (mounted) _showMessage(e.message);
    }
  }

  Future<void> _loadMore() async {
    try {
      await _controller.loadMore();
    } on EventsException catch (e) {
      if (mounted) _showMessage(e.message);
    }
  }

  Future<void> _confirmDelete(ClubEvent event) async {
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
    if (confirmed != true || !mounted) return;

    try {
      await _controller.delete(event.id);
      if (mounted) _showMessage('Etkinlik silindi.');
    } on EventsException catch (e) {
      if (mounted) _showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(adminEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Etkinlik yönetimi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Etkinlik ekle'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                            _controller.search('');
                          },
                        ),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _controller.search,
            ),
          ),
          Expanded(
            child: switch (events) {
              AsyncData(:final value) => _EventList(
                state: value,
                onRefresh: _refresh,
                onLoadMore: _loadMore,
                onEdit: _openForm,
                onDelete: _confirmDelete,
                onAdd: () => _openForm(),
              ),
              AsyncError(:final error) => _ErrorView(
                message: error is EventsException
                    ? error.message
                    : describeApiError(error),
                onRetry: () => _controller.search(_search.text),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  final AdminEventsState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final ValueChanged<ClubEvent> onEdit;
  final ValueChanged<ClubEvent> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const Icon(Icons.event_busy_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              state.search.isEmpty
                  ? 'Henüz etkinlik yok.'
                  : '"${state.search}" için etkinlik bulunamadı.',
              textAlign: TextAlign.center,
            ),
            if (state.search.isEmpty) ...[
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: onAdd,
                  child: const Text('İlk etkinliği ekle'),
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
            onTap: () => onEdit(event),
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
    required this.onTap,
    required this.onDelete,
  });

  final ClubEvent event;
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
          _TileAction.edit => onTap(),
          _TileAction.delete => onDelete(),
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: _TileAction.edit,
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Düzenle'),
            ),
          ),
          PopupMenuItem(
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

enum _TileAction { edit, delete }

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
