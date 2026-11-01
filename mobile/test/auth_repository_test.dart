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
    // API düz metin hatalarını text/plain olarak döndürür
    final text = body is String;
    return ResponseBody.fromString(
      text ? body as String : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [
          text ? 'text/plain; charset=utf-8' : 'application/json',
        ],
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
        'roles': ['Yönetici'],
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
    final repo = _repo(
      _StubAdapter(401, {'message': 'E-posta veya şifre hatalı.'}),
    );

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

  test('kayıt yanıtında kullanıcı nesnesi beklenmez', () async {
    final adapter = _StubAdapter(201, {
      'message': 'Kullanıcı oluşturuldu.',
      'userId': 'abc',
      'role': 'Öğrenci',
    });

    await _repo(adapter).register(
      fullName: 'Deneme Öğrenci',
      email: 'a@b.c',
      password: 'Test1234!',
    );

    expect(adapter.lastRequest?.path, '/api/auth/register');
  });

  test('kayıtlı e-posta için dönen düz metin gösterilir', () async {
    final repo = _repo(_StubAdapter(400, 'Bu e-posta zaten kayıtlı.'));

    await expectLater(
      repo.register(fullName: 'A', email: 'a@b.c', password: 'Test1234!'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Bu e-posta zaten kayıtlı.',
        ),
      ),
    );
  });

  test('Identity parola hatası Türkçeye çevrilir', () async {
    final repo = _repo(
      _StubAdapter(400, [
        {
          'code': 'PasswordRequiresUpper',
          'description':
              "Passwords must have at least one uppercase ('A'-'Z').",
        },
      ]),
    );

    await expectLater(
      repo.register(fullName: 'A', email: 'a@b.c', password: 'test1234!'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Parola en az bir büyük harf içermelidir.',
        ),
      ),
    );
  });

  test('ProblemDetails alan hatası Türkçe gösterilir', () async {
    final repo = _repo(
      _StubAdapter(400, {
        'title': 'One or more validation errors occurred.',
        'status': 400,
        'errors': {
          'Password': [
            "The field Password must be a string or array type with a minimum length of '8'.",
          ],
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
      repo.register(fullName: 'A', email: 'a@b.c', password: 'Test1234!'),
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
