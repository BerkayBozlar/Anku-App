import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Yalnızca Yönetici rolüne açık.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yönetim')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Etkinlikler'),
              subtitle: const Text('Ekleme, düzenleme ve silme'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/admin/events'),
            ),
          ),
        ],
      ),
    );
  }
}
