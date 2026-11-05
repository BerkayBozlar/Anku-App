import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../events/event_models.dart';
import '../events/events_repository.dart';
import 'discovery_states.dart';

final eventDetailsProvider = FutureProvider.autoDispose.family<ClubEvent, int>(
  (ref, id) => ref.watch(eventsRepositoryProvider).get(id),
  retry: (_, _) => null,
);

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final int eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = eventDetailsProvider(eventId);
    final event = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(title: const Text('Etkinlik ayrıntısı')),
      body: event.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: DiscoveryMessage(
            icon: Icons.event_busy_outlined,
            message: error is EventsException && error.statusCode == 404
                ? 'Etkinlik bulunamadı veya yayından kaldırıldı.'
                : error.toString(),
            onRetry: () => ref.invalidate(provider),
          ),
        ),
        data: (value) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: () async {
                try {
                  ref.invalidate(provider);
                  await ref.read(provider.future);
                } on EventsException {
                  // Provider hata durumunu aşağıdaki yeniden deneme ekranında sunar.
                }
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (value.status != EventStatus.published)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          value.status == EventStatus.cancelled
                              ? 'Bu etkinlik iptal edildi.'
                              : 'Bu etkinlik henüz yayında değil.',
                        ),
                      ),
                    ),
                  Text(
                    value.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.groups_outlined),
                          title: Text(value.clubName ?? 'Kulüp ayrıntıları'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push('/discover/clubs/${value.clubId}'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.schedule),
                          title: const Text('Tarih ve saat'),
                          subtitle: Text(
                            formatDateTime(value.eventDate.toLocal()),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: const Text('Konum'),
                          subtitle: Text(
                            value.campusLocationName ??
                                'Konum henüz belirtilmemiş.',
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.people_outline),
                          title: const Text('Kontenjan'),
                          subtitle: Text(
                            value.capacity == null
                                ? 'Kontenjan belirtilmemiş.'
                                : '${value.capacity} kişi',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Etkinlik hakkında',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value.description?.isNotEmpty == true
                        ? value.description!
                        : 'Bu etkinlik için henüz açıklama eklenmemiş.',
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
