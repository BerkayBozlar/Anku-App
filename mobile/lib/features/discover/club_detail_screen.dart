import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../clubs/clubs_repository.dart';
import 'discovery_states.dart';
import 'event_feed_view.dart';

class ClubDetailScreen extends ConsumerWidget {
  const ClubDetailScreen({super.key, required this.clubId});

  final int clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = clubDetailsProvider(clubId);
    final club = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kulüp ayrıntısı'),
        actions: [
          IconButton(
            tooltip: 'Kulübü yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(provider),
          ),
        ],
      ),
      body: club.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: DiscoveryMessage(
            icon: Icons.groups_outlined,
            message: error is DioException && error.response?.statusCode == 404
                ? 'Kulüp bulunamadı. Kaldırılmış olabilir.'
                : describeApiError(error),
            onRetry: () => ref.invalidate(provider),
          ),
        ),
        data: (value) => EventFeedView(
          key: ValueKey(value.id),
          clubId: value.id,
          header: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.groups_outlined, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      value.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      value.description?.isNotEmpty == true
                          ? value.description!
                          : 'Bu kulüp için henüz açıklama eklenmemiş.',
                    ),
                    if (value.authorizedUserName?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Text('Kulüp yetkilisi: ${value.authorizedUserName}'),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
