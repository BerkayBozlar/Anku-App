import 'dart:convert';
import 'dart:typed_data';

import 'package:anku_app/features/auth/auth_models.dart';
import 'package:anku_app/features/auth/session_storage.dart';
import 'package:dio/dio.dart';

/// İstekleri kaydeden ve her birine [respond] ile yanıt veren sahte adaptör.
class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.respond);

  /// `(durum kodu, JSON gövde)` döndürür.
  final (int, Object?) Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = respond(options);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class MemorySessionStorage implements SessionStorage {
  MemorySessionStorage([this.session]);

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}

AuthSession sessionFor(UserRole role, {DateTime? expiresAt}) {
  return AuthSession(
    accessToken: 'token-${role.apiName}',
    expiresAt:
        expiresAt ?? DateTime.now().toUtc().add(const Duration(hours: 1)),
    user: AuthUser(
      id: 'id-${role.apiName}',
      fullName: 'Deneme ${role.label}',
      email: '${role.apiName.toLowerCase()}@ankara.edu.tr',
      role: role,
    ),
  );
}
