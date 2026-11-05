import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bağlantıyı cihazın tarayıcısında açar; açılamazsa kullanıcıya bildirir.
Future<void> openExternalLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  var opened = false;
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      opened = false;
    }
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kaynak bağlantısı açılamadı.')),
    );
  }
}
