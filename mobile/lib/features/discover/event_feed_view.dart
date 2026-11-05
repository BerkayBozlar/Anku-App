import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../events/event_models.dart';
import '../events/events_repository.dart';
import 'discovery_states.dart';
import 'event_feed_controller.dart';

class EventFeedView extends ConsumerStatefulWidget {
  const EventFeedView({super.key, this.clubId, this.header});

  final int? clubId;
  final Widget? header;

  @override
  ConsumerState<EventFeedView> createState() => _EventFeedViewState();
}

class _EventFeedViewState extends ConsumerState<EventFeedView> {
  final _searchText = TextEditingController();
  String _search = '';
  EventPeriod _period = EventPeriod.upcoming;

  EventFeedFilter get _filter =>
      (search: _search, clubId: widget.clubId, period: _period);

  @override
  void dispose() {
    _searchText.dispose();
    super.dispose();
  }

  void _applySearch(String value) => setState(() => _search = value.trim());

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on EventsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = eventsFeedProvider(_filter);
    final feed = ref.watch(provider);
    final current = feed.value;

    return RefreshIndicator(
      onRefresh: () => _run(() => ref.read(provider.notifier).refresh()),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (widget.header != null) SliverToBoxAdapter(child: widget.header!),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<EventPeriod>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: EventPeriod.upcoming,
                        label: Text('Yaklaşan'),
                      ),
                      ButtonSegment(
                        value: EventPeriod.past,
                        label: Text('Geçmiş'),
                      ),
                    ],
                    selected: {_period},
                    onSelectionChanged: (value) =>
                        setState(() => _period = value.single),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchText,
                    decoration: InputDecoration(
                      labelText: 'Etkinlik ara',
                      hintText: 'Etkinlik başlığı',
                      border: const OutlineInputBorder(),
                      prefixIcon: IconButton(
                        tooltip: 'Ara',
                        icon: const Icon(Icons.search),
                        onPressed: () => _applySearch(_searchText.text),
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Aramayı temizle',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchText.clear();
                          _applySearch('');
                        },
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _applySearch,
                  ),
                  if (current != null && !feed.isLoading) ...[
                    const SizedBox(height: 16),
                    Text('${current.totalCount} etkinlik'),
                  ],
                ],
              ),
            ),
          ),
          if (feed.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (feed.hasError)
            SliverToBoxAdapter(
              child: DiscoveryMessage(
                icon: Icons.cloud_off_outlined,
                message: feed.error.toString(),
                onRetry: () => ref.invalidate(provider),
              ),
            )
          else if (current != null && current.items.isEmpty)
            SliverToBoxAdapter(
              child: DiscoveryMessage(
                message: _search.isNotEmpty
                    ? 'Aramanıza uygun etkinlik bulunamadı.'
                    : _period == EventPeriod.past
                    ? 'Henüz geçmiş etkinlik yok.'
                    : 'Henüz yaklaşan etkinlik yok.',
              ),
            )
          else if (current != null) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: current.items.length,
                itemBuilder: (context, index) =>
                    _EventCard(event: current.items[index]),
              ),
            ),
            if (current.hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton(
                    onPressed: current.isLoadingMore
                        ? null
                        : () => _run(
                            () => ref.read(provider.notifier).loadMore(),
                          ),
                    child: Text(
                      current.isLoadingMore
                          ? 'Yükleniyor…'
                          : 'Daha fazla göster',
                    ),
                  ),
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final ClubEvent event;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: const Icon(Icons.event_outlined),
      title: Text(event.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          [
            if (event.clubName?.isNotEmpty == true) event.clubName!,
            formatDateTime(event.eventDate.toLocal()),
          ].join('\n'),
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/discover/events/${event.id}'),
    ),
  );
}
