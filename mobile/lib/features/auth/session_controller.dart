import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_models.dart';
import 'auth_repository.dart';
import 'session_storage.dart';

/// Oturum durumu: `null` ise giriş yapılmamıştır.
class SessionController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final storage = ref.read(sessionStorageProvider);
    final stored = await storage.read();
    if (stored == null) return null;
    if (stored.isExpired) {
      await storage.clear();
      return null;
    }
    return stored;
  }

  /// Hata durumunda [AuthException] fırlatır; mevcut durum değişmez.
  Future<void> login({required String email, required String password}) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    await ref.read(sessionStorageProvider).write(session);
    state = AsyncData(session);
  }

  Future<void> logout() async {
    await ref.read(sessionStorageProvider).clear();
    state = const AsyncData(null);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, AuthSession?>(
  SessionController.new,
);
