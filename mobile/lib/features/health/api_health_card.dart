import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import 'api_health.dart';

class ApiHealthCard extends ConsumerWidget {
  const ApiHealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(apiHealthProvider);
    final colors = Theme.of(context).colorScheme;

    final (
      IconData icon,
      Color color,
      String title,
      String subtitle,
    ) = switch (health) {
      AsyncData(:final value) when value.isOk => (
        Icons.cloud_done,
        Colors.green,
        'API bağlantısı kuruldu',
        value.application,
      ),
      AsyncData(:final value) => (
        Icons.cloud_off,
        colors.error,
        'API beklenmeyen durum döndürdü',
        'status: ${value.status}',
      ),
      AsyncError(:final error) => (
        Icons.cloud_off,
        colors.error,
        'API bağlantısı yok',
        describeApiError(error),
      ),
      _ => (
        Icons.cloud_sync,
        colors.outline,
        'API kontrol ediliyor…',
        AppConfig.apiBaseUrl,
      ),
    };

    return Card(
      child: ListTile(
        leading: health.isLoading
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: IconButton(
          tooltip: 'Yeniden dene',
          icon: const Icon(Icons.refresh),
          onPressed: health.isLoading
              ? null
              : () => ref.invalidate(apiHealthProvider),
        ),
      ),
    );
  }
}
