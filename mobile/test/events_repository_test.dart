import 'package:anku_app/features/events/event_models.dart';
import 'package:anku_app/features/events/events_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

const _event = {
  'id': 45,
  'clubId': 12,
  'title': 'Kampüs Konseri',
  'eventDate': '2026-11-18T15:00:00Z',
  'capacity': 250,
  'status': 'Published',
};

EventsRepository _repo(RecordingAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = adapter;
  return EventsRepository(dio);
}

final _input = EventInput(
  clubId: 12,
  title: 'Kampüs Konseri',
  eventDate: DateTime.utc(2026, 11, 18, 15),
  capacity: 250,
  status: EventStatus.published,
);

Matcher _throwsMessage(String message) => throwsA(
  isA<EventsException>().having((e) => e.message, 'message', message),
);

void main() {
  test('liste sayfa ve arama parametreleriyle istenir', () async {
    final adapter = RecordingAdapter(
      (_) => (
        200,
        {
          'items': [_event],
          'page': 2,
          'pageSize': 20,
          'totalCount': 21,
        },
      ),
    );

    final page = await _repo(adapter).list(page: 2, search: '  konser ');

    expect(page.items.single.title, 'Kampüs Konseri');
    final request = adapter.requests.single;
    expect(request.path, '/api/events');
    expect(request.queryParameters, {
      'page': 2,
      'pageSize': 20,
      'search': 'konser',
    });
  });

  test(
    'geçmiş sorgusu to ve order=desc ile, UTC saniye hassasiyetinde',
    () async {
      final adapter = RecordingAdapter((_) => (200, {'items': []}));
      final repo = _repo(adapter);
      // Türkiye saati 12:30:15.789 -> UTC 09:30:15
      final now = DateTime.utc(2026, 11, 5, 9, 30, 15, 789).toLocal();

      await repo.list(to: now, descending: true);
      await repo.list(from: now);

      expect(adapter.requests[0].queryParameters, {
        'page': 1,
        'pageSize': 20,
        'to': '2026-11-05T09:30:15Z',
        'order': 'desc',
      });
      expect(adapter.requests[1].queryParameters, {
        'page': 1,
        'pageSize': 20,
        'from': '2026-11-05T09:30:15Z',
      });
    },
  );

  test('ekleme ve güncelleme doğru uç noktaya gider', () async {
    final adapter = RecordingAdapter(
      (options) => options.method == 'POST' ? (201, _event) : (204, null),
    );
    final repo = _repo(adapter);

    final created = await repo.create(_input);
    await repo.update(45, _input);
    await repo.delete(45);

    expect(created.id, 45);
    expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
      'POST /api/events',
      'PUT /api/events/45',
      'DELETE /api/events/45',
    ]);
    expect(adapter.requests.first.data, _input.toJson());
  });

  test('doğrulama hatası alan adına göre Türkçe gösterilir', () async {
    final repo = _repo(
      RecordingAdapter(
        (_) => (
          400,
          {
            'title': 'One or more validation errors occurred.',
            'status': 400,
            'errors': {
              'EventDate': ['Event date cannot be in the past.'],
            },
          },
        ),
      ),
    );

    await expectLater(
      repo.create(_input),
      _throwsMessage('Etkinlik tarihi geçmişte olamaz.'),
    );
  });

  test('tanınmayan alan hatasında API mesajı gösterilir', () async {
    final repo = _repo(
      RecordingAdapter(
        (_) => (
          400,
          {
            'errors': {
              'Other': ['Kulüp pasif.'],
            },
          },
        ),
      ),
    );

    await expectLater(repo.create(_input), _throwsMessage('Kulüp pasif.'));
  });

  test('beklenmeyen JSON biçimi anlaşılır hataya çevrilir', () async {
    final repo = _repo(
      RecordingAdapter(
        (_) => (
          200,
          {
            'items': [
              {'id': 'kırk beş', 'title': 'Bozuk'},
            ],
          },
        ),
      ),
    );

    await expectLater(
      repo.list(),
      _throwsMessage('Sunucudan beklenmeyen bir yanıt alındı.'),
    );
  });

  test('çakışmada durum kodu korunur, varsayılan mesaj tarafsızdır', () async {
    final repo = _repo(RecordingAdapter((_) => (409, null)));

    await expectLater(
      repo.delete(45),
      throwsA(
        isA<EventsException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having(
              (e) => e.message,
              'message',
              'Etkinliğe yapılmış başvurular olduğu için silinemiyor.',
            ),
      ),
    );
  });

  test('yetki, bulunamadı ve çakışma durumları', () async {
    Future<void> expectStatus(int status, Object? body, String message) {
      final repo = _repo(RecordingAdapter((_) => (status, body)));
      return expectLater(repo.delete(45), _throwsMessage(message));
    }

    await expectStatus(403, null, 'Bu işlem için yetkiniz yok.');
    await expectStatus(404, null, 'Etkinlik bulunamadı. Silinmiş olabilir.');
    await expectStatus(409, {
      'message': 'Etkinliğe başvurular var.',
    }, 'Etkinliğe başvurular var.');
  });
}
