import 'dart:convert';
import 'dart:typed_data';

import 'package:anku_app/features/auth/auth_models.dart';
import 'package:anku_app/features/auth/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Her isteğe sabit bir yanıt dönen sahte adaptör.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body);

  final int status;
  final Object body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AuthRepository _repo(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = adapter;
  return AuthRepository(dio);
}

void main() {
  test('başarılı giriş oturum döndürür', () async {
    final adapter = _StubAdapter(200, {
      'accessToken': 'abc',
      'expiresAt': '2026-11-01T18:00:00Z',
      'user': {
        'id': '1',
        'fullName': 'Deneme Yönetici',
        'email': 'yonetici@ankara.edu.tr',
        'role': 'Yonetici',
      },
    });

    final session = await _repo(adapter)
        .login(email: 'yonetici@ankara.edu.tr', password: 'x');

    expect(session.accessToken, 'abc');
    expect(session.user.role, UserRole.yonetici);
    expect(adapter.lastRequest?.path, '/api/auth/login');
    expect(adapter.lastRequest?.data, {
      'email': 'yonetici@ankara.edu.tr',
      'password': 'x',
    });
  });

  test('401 anlaşılır mesaja çevrilir', () async {
    final repo = _repo(_StubAdapter(401, {'title': 'Yetkisiz', 'status': 401}));

    await expectLater(
      repo.login(email: 'a@b.c', password: 'x'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'E-posta veya parola hatalı.',
        ),
      ),
    );
  });

  test('400 ProblemDetails içindeki ilk alan hatası gösterilir', () async {
    final repo = _repo(
      _StubAdapter(400, {
        'title': 'Doğrulama hatası',
        'status': 400,
        'detail': 'Gönderilen bilgiler geçerli değil.',
        'errors': {
          'password': ['Parola en az 8 karakter olmalıdır.'],
        },
      }),
    );

    await expectLater(
      repo.register(fullName: 'A', email: 'a@b.c', password: '1'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Parola en az 8 karakter olmalıdır.',
        ),
      ),
    );
  });

  test('409 kayıtta e-posta çakışması olarak gösterilir', () async {
    final repo = _repo(_StubAdapter(409, {'title': 'Çakışma', 'status': 409}));

    await expectLater(
      repo.register(fullName: 'A', email: 'a@b.c', password: '12345678'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Bu e-posta adresi zaten kayıtlı.',
        ),
      ),
    );
  });
}
