import 'package:anku_app/core/format.dart';
import 'package:anku_app/core/network/api_exception.dart';
import 'package:anku_app/features/announcements/announcements_repository.dart';
import 'package:anku_app/features/meals/meal_models.dart';
import 'package:anku_app/features/meals/meals_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

const _announcement = {
  'id': 7,
  'title': 'Kayıt yenileme tarihleri',
  'summary': 'Güz dönemi kayıt yenileme takvimi açıklandı.',
  'sourceName': 'Öğrenci İşleri Daire Başkanlığı',
  'sourceUrl': 'https://oidb.ankara.edu.tr/duyuru/kayit',
  'uniqueKey': 'ABC',
  'publishedAt': '2026-11-04T07:30:00.123Z',
  'retrievedAt': '2026-11-05T06:00:00Z',
  'isManual': false,
};

Map<String, Object?> _menu(int id, String date, {List<String>? dishes}) => {
  'id': id,
  'menuDate': date,
  'dishes': dishes ?? ['Mercimek Çorbası', 'Tavuk Sote', 'Pilav', 'Ayran'],
  'totalCalories': 1150,
  'sourceName': 'Ankara Üniversitesi SKS',
  'sourceUrl': 'https://sks.ankara.edu.tr/yemek-hizmetleri-2/',
  'retrievedAt': '2026-11-05T06:00:00Z',
  'isManual': false,
};

Dio _dio(RecordingAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = adapter;

Matcher _throwsMessage(String message) =>
    throwsA(isA<ApiException>().having((e) => e.message, 'message', message));

void main() {
  group('duyurular', () {
    test('liste sayfa ve kırpılmış aramayla istenir', () async {
      final adapter = RecordingAdapter(
        (_) => (
          200,
          {
            'items': [_announcement],
            'page': 1,
            'pageSize': 20,
            'totalCount': 1,
          },
        ),
      );

      final page = await AnnouncementsRepository(_dio(adapter))
          .list(search: '  kayıt ');

      final item = page.items.single;
      expect(item.title, 'Kayıt yenileme tarihleri');
      expect(item.publishedAt, DateTime.utc(2026, 11, 4, 7, 30, 0, 123));
      expect(item.sourceUrl, startsWith('https://oidb.ankara.edu.tr'));
      final request = adapter.requests.single;
      expect(request.path, '/api/announcements');
      expect(request.queryParameters, {
        'page': 1,
        'pageSize': 20,
        'search': 'kayıt',
      });
    });

    test('boş arama gönderilmez, null özet kabul edilir', () async {
      final adapter = RecordingAdapter(
        (_) => (
          200,
          {
            'items': [
              {..._announcement, 'summary': null},
            ],
            'page': 1,
            'pageSize': 20,
            'totalCount': 1,
          },
        ),
      );

      final page = await AnnouncementsRepository(_dio(adapter))
          .list(search: '   ');

      expect(page.items.single.summary, isNull);
      expect(
        adapter.requests.single.queryParameters.containsKey('search'),
        isFalse,
      );
    });

    test('ayrıntı 404 Türkçe mesaja çevrilir', () async {
      final repo = AnnouncementsRepository(
        _dio(RecordingAdapter((_) => (404, null))),
      );
      await expectLater(
        repo.get(9),
        _throwsMessage('Duyuru bulunamadı. Kaldırılmış olabilir.'),
      );
    });

    test('400 gövdesindeki API mesajı gösterilir', () async {
      final repo = AnnouncementsRepository(
        _dio(
          RecordingAdapter(
            (_) => (400, {'message': 'Sayfalama bilgileri geçersiz.'}),
          ),
        ),
      );
      await expectLater(
        repo.list(page: 0),
        _throwsMessage('Sayfalama bilgileri geçersiz.'),
      );
    });

    test('bozuk yanıt beklenmeyen yanıt hatası olur', () async {
      final repo = AnnouncementsRepository(
        _dio(
          RecordingAdapter(
            (_) => (
              200,
              {
                'items': [
                  {'id': 'x'},
                ],
              },
            ),
          ),
        ),
      );
      await expectLater(
        repo.list(),
        _throwsMessage('Sunucudan beklenmeyen bir yanıt alındı.'),
      );
    });
  });

  group('yemekhane', () {
    test('varsayılan aralıkta tarih parametresi gönderilmez', () async {
      final adapter = RecordingAdapter(
        (_) => (
          200,
          {
            'items': [_menu(1, '2026-11-05')],
            'from': '2026-11-05',
            'to': '2026-11-11',
          },
        ),
      );

      final range = await MealsRepository(_dio(adapter)).range();

      expect(adapter.requests.single.path, '/api/meal-menus');
      expect(adapter.requests.single.queryParameters, isEmpty);
      expect(range.from, DateTime(2026, 11, 5));
      expect(range.items.single.dishes, hasLength(4));
      expect(range.items.single.totalCalories, 1150);
    });

    test('tarihler gün düzeyinde yyyy-MM-dd gönderilir', () async {
      final adapter = RecordingAdapter(
        (_) => (200, {'items': [], 'from': '2026-11-02', 'to': '2026-11-08'}),
      );

      await MealsRepository(
        _dio(adapter),
      ).range(from: DateTime(2026, 11, 2, 23, 59), to: DateTime(2026, 11, 8));

      expect(adapter.requests.single.queryParameters, {
        'from': '2026-11-02',
        'to': '2026-11-08',
      });
    });

    test('günler aralıktaki her tarihi menüsüyle eşler', () {
      final range = MealMenuRange.fromJson({
        'items': [_menu(1, '2026-11-05'), _menu(2, '2026-11-07')],
        'from': '2026-11-05',
        'to': '2026-11-08',
      });

      final days = range.days;
      expect(days.map((d) => formatApiDate(d.$1)), [
        '2026-11-05',
        '2026-11-06',
        '2026-11-07',
        '2026-11-08',
      ]);
      expect(days.map((d) => d.$2?.id), [1, null, 2, null]);
    });

    test('aralık hatası API mesajıyla döner', () async {
      final repo = MealsRepository(
        _dio(
          RecordingAdapter(
            (_) => (
              400,
              {
                'message':
                    'En fazla 63 günlük geçerli bir tarih aralığı girin.',
              },
            ),
          ),
        ),
      );
      await expectLater(
        repo.range(from: DateTime(2026, 11, 8), to: DateTime(2026, 11, 1)),
        _throwsMessage('En fazla 63 günlük geçerli bir tarih aralığı girin.'),
      );
    });

    test('Türkçe gün adı', () {
      expect(weekdayName(DateTime(2026, 11, 5)), 'Perşembe');
      expect(weekdayName(DateTime(2026, 11, 8)), 'Pazar');
    });
  });
}
