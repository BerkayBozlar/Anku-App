import 'dart:typed_data';

import 'package:anku_app/core/network/api_client.dart';
import 'package:anku_app/features/auth/auth_models.dart';
import 'package:anku_app/features/auth/session_controller.dart';
import 'package:anku_app/features/auth/session_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.status);

  final int status;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(ProviderContainer, _RecordingAdapter, MemorySessionStorage)> _setup(
  int status,
) async {
  final storage = MemorySessionStorage(sessionFor(UserRole.ogrenci));
  final container = ProviderContainer(
    overrides: [sessionStorageProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);
  await container.read(sessionProvider.future);

  final adapter = _RecordingAdapter(status);
  container.read(dioProvider).httpClientAdapter = adapter;
  return (container, adapter, storage);
}

void main() {
  test('oturum varsa isteğe Bearer token eklenir', () async {
    final (container, adapter, _) = await _setup(200);

    await container.read(dioProvider).get<Object>('/api/events');

    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer token-Ogrenci',
    );
  });

  test('401 yanıtında oturum kapatılır', () async {
    final (container, _, storage) = await _setup(401);

    await expectLater(
      container.read(dioProvider).get<Object>('/api/events'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(sessionProvider).value, isNull);
    expect(storage.session, isNull);
  });

  test('giriş isteğindeki 401 oturumu kapatmaz', () async {
    final (container, _, storage) = await _setup(401);

    await expectLater(
      container.read(dioProvider).post<Object>('/api/auth/login'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(sessionProvider).value, isNotNull);
    expect(storage.session, isNotNull);
  });
}
