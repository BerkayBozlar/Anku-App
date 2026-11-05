import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/network/api_exception.dart';
import '../../core/open_link.dart';
import '../discover/discovery_states.dart';
import 'meal_models.dart';
import 'meals_repository.dart';

class MealMenuScreen extends ConsumerStatefulWidget {
  const MealMenuScreen({super.key});

  @override
  ConsumerState<MealMenuScreen> createState() => _MealMenuScreenState();
}

class _MealMenuScreenState extends ConsumerState<MealMenuScreen> {
  /// Gösterilen 7 günün ilki; `null` = API'ye göre bugün.
  DateTime? _from;

  void _shift(MealMenuRange current, int days) => setState(
    () => _from = DateTime(
      current.from.year,
      current.from.month,
      current.from.day + days,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final provider = mealMenuRangeProvider(_from);
    final range = ref.watch(provider);
    final current = range.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Yemekhane')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: () async {
              try {
                ref.invalidate(provider);
                await ref.read(provider.future);
              } on ApiException {
                // Hata, aşağıdaki yeniden deneme ekranında gösterilir.
              }
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _WeekBar(
                  range: current,
                  onPrevious: current == null || range.isLoading
                      ? null
                      : () => _shift(current, -7),
                  onNext: current == null || range.isLoading
                      ? null
                      : () => _shift(current, 7),
                  onToday: _from == null
                      ? null
                      : () => setState(() => _from = null),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kampüslerde sunulan ortak öğle menüsü.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                ...range.when(
                  loading: () => const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (error, _) => [
                    DiscoveryMessage(
                      icon: Icons.cloud_off_outlined,
                      message: error.toString(),
                      onRetry: () => ref.invalidate(provider),
                    ),
                  ],
                  data: (value) => _content(context, value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, MealMenuRange value) {
    if (value.items.isEmpty) {
      return const [
        DiscoveryMessage(
          icon: Icons.no_meals_outlined,
          message:
              'Bu tarihler için yayımlanmış öğle menüsü yok. '
              'SKS listesi yayımlandığında burada görünecek.',
        ),
      ];
    }

    final source = value.items.first;
    final updated = value.items
        .map((m) => m.retrievedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (latest, d) => latest == null || d.isAfter(latest) ? d : latest,
        );
    final theme = Theme.of(context);

    return [
      for (final (day, menu) in value.days) _DayCard(day: day, menu: menu),
      const SizedBox(height: 8),
      Text(
        [
          'Kaynak: ${source.sourceName.isEmpty ? 'Ankara Üniversitesi SKS' : source.sourceName}',
          if (updated != null)
            'Son güncelleme: ${formatDateTime(updated.toLocal())}',
        ].join('\n'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      if (source.sourceUrl.isNotEmpty)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => openExternalLink(context, source.sourceUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Resmî menü kaynağını aç'),
          ),
        ),
    ];
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.range,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final MealMenuRange? range;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    final range = this.range;
    return Row(
      children: [
        IconButton(
          tooltip: 'Önceki 7 gün',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                range == null
                    ? 'Menü'
                    : '${formatDate(range.from)} – ${formatDate(range.to)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (onToday != null)
                TextButton(onPressed: onToday, child: const Text('Bugüne dön')),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Sonraki 7 gün',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.menu});

  final DateTime day;
  final MealMenu? menu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final menu = this.menu;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isToday ? theme.colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${weekdayName(day)}, ${formatDate(day)}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (isToday)
                  Text(
                    'Bugün',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (menu == null || menu.dishes.isEmpty)
              Text(
                'Bu gün için menü yayımlanmamış.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              for (final dish in menu.dishes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2, right: 8),
                        child: Icon(Icons.restaurant, size: 16),
                      ),
                      Expanded(child: Text(dish)),
                    ],
                  ),
                ),
              if (menu.totalCalories != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Toplam ${menu.totalCalories} kcal',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
