import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/network/api_exception.dart';
import '../../core/open_link.dart';
import '../discover/discovery_states.dart';
import 'announcements_repository.dart';

class AnnouncementDetailScreen extends ConsumerWidget {
  const AnnouncementDetailScreen({super.key, required this.announcementId});

  final int announcementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = announcementDetailsProvider(announcementId);
    final announcement = ref.watch(provider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Duyuru ayrıntısı')),
      body: announcement.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: DiscoveryMessage(
            icon: Icons.campaign_outlined,
            message: error.toString(),
            onRetry: () => ref.invalidate(provider),
          ),
        ),
        data: (value) {
          final summary = value.summary?.trim() ?? '';
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: RefreshIndicator(
                onRefresh: () async {
                  try {
                    ref.invalidate(provider);
                    await ref.read(provider.future);
                  } on ApiException {
                    // Hata, yukarıdaki yeniden deneme ekranında gösterilir.
                  }
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Text(value.title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.schedule),
                            title: const Text('Yayın tarihi'),
                            subtitle: Text(
                              formatDateTime(value.publishedAt.toLocal()),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.account_balance_outlined),
                            title: const Text('Kaynak'),
                            subtitle: Text(
                              value.sourceName.isEmpty
                                  ? 'Ankara Üniversitesi'
                                  : value.sourceName,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      summary.isNotEmpty
                          ? summary
                          : 'Bu duyuru için özet bulunmuyor. Ayrıntılar '
                                'kaynak sayfasındadır.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    if (value.sourceUrl.isNotEmpty)
                      FilledButton.icon(
                        onPressed: () =>
                            openExternalLink(context, value.sourceUrl),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Kaynakta aç'),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Tam metin ve ekler resmî kaynak sayfasındadır.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
