import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../health/api_health_card.dart';

class _Module {
  const _Module(this.title, this.icon, {this.route});

  final String title;
  final IconData icon;

  /// Henüz yapılmamış modüllerde null.
  final String? route;
}

const _modules = [
  _Module('Kampüs Haritası', Icons.map_outlined, route: '/map'),
  _Module('Ders Programı', Icons.calendar_view_week_outlined),
  _Module('Duyurular', Icons.campaign_outlined),
  _Module('Kulüpler ve Etkinlikler', Icons.groups_outlined),
  _Module('Yemekhane', Icons.restaurant_outlined),
  _Module('Akademik Takvim', Icons.event_note_outlined),
  _Module('Not Hesaplama', Icons.calculate_outlined),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AnküApp')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Telefonda 2, tablette 3-4 sütun
          final columns = (constraints.maxWidth / 200).floor().clamp(2, 4);

          return CustomScrollView(
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(child: ApiHealthCard()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Modüller',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 136,
                  ),
                  delegate: SliverChildListDelegate([
                    for (final module in _modules) _ModuleCard(module: module),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module});

  final _Module module;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = module.route != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? () => context.go(module.route!) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(module.icon, size: 32, color: theme.colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  module.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                if (!enabled)
                  Text('Yakında', style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
