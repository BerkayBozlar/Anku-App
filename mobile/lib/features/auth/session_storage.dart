import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_models.dart';

/// Oturumu (JWT dahil) cihazın güvenli deposunda tutar
/// (Android'de Keystore ile şifrelenir).
class SessionStorage {
  SessionStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth_session';

  final FlutterSecureStorage _storage;

  Future<AuthSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      // Bozuk ya da eski biçimde kayıt: yeniden giriş istenir
      await clear();
      return null;
    }
  }

  Future<void> write(AuthSession session) {
    return _storage.write(key: _key, value: jsonEncode(session.toJson()));
  }

  Future<void> clear() => _storage.delete(key: _key);
}

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SessionStorage(),
);
