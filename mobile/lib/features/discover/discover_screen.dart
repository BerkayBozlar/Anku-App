import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../clubs/club_models.dart';
import '../clubs/clubs_repository.dart';
import 'discovery_states.dart';
import 'event_feed_view.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Kulüpler ve Etkinlikler'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Etkinlikler'),
            Tab(text: 'Kulüpler'),
          ],
        ),
      ),
      body: const TabBarView(children: [EventFeedView(), _ClubsList()]),
    ),
  );
}

class _ClubsList extends ConsumerStatefulWidget {
  const _ClubsList();

  @override
  ConsumerState<_ClubsList> createState() => _ClubsListState();
}

class _ClubsListState extends ConsumerState<_ClubsList> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final clubs = ref.watch(clubsProvider);
    final matching = clubs.value
        ?.where((club) => _fold(club.name).contains(_fold(_search)))
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        try {
          ref.invalidate(clubsProvider);
          await ref.read(clubsProvider.future);
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(describeApiError(error))));
          }
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Kulüp ara',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _search = value.trim()),
          ),
          const SizedBox(height: 16),
          if (clubs.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (clubs.hasError)
            DiscoveryMessage(
              icon: Icons.cloud_off_outlined,
              message: describeApiError(clubs.error!),
              onRetry: () => ref.invalidate(clubsProvider),
            )
          else if (matching != null && matching.isEmpty)
            DiscoveryMessage(
              icon: Icons.groups_outlined,
              message: _search.isEmpty
                  ? 'Henüz kulüp eklenmemiş.'
                  : 'Aramanıza uygun kulüp bulunamadı.',
            )
          else if (matching != null)
            for (final club in matching) _ClubCard(club: club),
        ],
      ),
    );
  }

  // Türkçe I/İ çiftleri de büyük-küçük harf farkından bağımsız aranır.
  String _fold(String value) =>
      value.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
}

class _ClubCard extends StatelessWidget {
  const _ClubCard({required this.club});

  final Club club;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: const Icon(Icons.groups_outlined),
      title: Text(club.name),
      subtitle: club.description?.isNotEmpty == true
          ? Text(
              club.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/discover/clubs/${club.id}'),
    ),
  );
}
