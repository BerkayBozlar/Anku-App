import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/network/api_exception.dart';
import '../discover/discovery_states.dart';
import 'announcement_models.dart';
import 'announcements_controller.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  final _searchText = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchText.dispose();
    super.dispose();
  }

  void _applySearch(String value) => setState(() => _search = value.trim());

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = announcementsFeedProvider(_search);
    final feed = ref.watch(provider);
    final current = feed.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Duyurular')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: () => _run(() => ref.read(provider.notifier).refresh()),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchText,
                          decoration: InputDecoration(
                            labelText: 'Duyuru ara',
                            hintText: 'Duyuru başlığı',
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
                          Text('${current.totalCount} duyuru'),
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
                      icon: Icons.campaign_outlined,
                      message: _search.isNotEmpty
                          ? 'Aramanıza uygun duyuru bulunamadı.'
                          : 'Henüz duyuru yok. Resmî kaynaktan alınan '
                                'duyurular burada listelenir.',
                    ),
                  )
                else if (current != null) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: current.items.length,
                      itemBuilder: (context, index) =>
                          _AnnouncementCard(item: current.items[index]),
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
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item});

  final Announcement item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = item.summary?.trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/announcements/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  formatDate(item.publishedAt.toLocal()),
                  if (item.sourceName.isNotEmpty) item.sourceName,
                ].join(' · '),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(item.title, style: theme.textTheme.titleMedium),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
