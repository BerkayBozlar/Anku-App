import 'package:flutter/material.dart';

/// Yalnızca Yönetici rolüne açık. Etkinlik CRUD ekranları 3. haftada eklenecek.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yönetim')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.event_outlined),
              title: Text('Etkinlikler'),
              subtitle: Text('Ekleme, düzenleme ve silme'),
              trailing: Chip(label: Text('Yakında')),
            ),
          ),
        ],
      ),
    );
  }
}
