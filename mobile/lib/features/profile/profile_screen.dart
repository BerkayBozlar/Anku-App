import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış yapılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkış yap'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final theme = Theme.of(context);

    if (session == null) return const SizedBox.shrink();
    final user = session.user;
    final expires = session.expiresAt.toLocal();

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              child: Text(
                user.fullName.isEmpty ? '?' : user.fullName[0].toUpperCase(),
                style: theme.textTheme.headlineMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.fullName,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Center(child: Chip(label: Text(user.role.label))),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.alternate_email),
                  title: const Text('E-posta'),
                  subtitle: Text(user.email),
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Oturum bitişi'),
                  subtitle: Text(_formatDateTime(expires)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Çıkış yap'),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}
