import 'package:anku_app/features/events/event_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sözleşmedeki liste yanıtı okunur', () {
    final page = EventPage.fromJson({
      'items': [
        {
          'id': 45,
          'clubId': 12,
          'clubName': 'Müzik Topluluğu',
          'campusLocationId': 3,
          'title': 'Kampüs Konseri',
          'description': 'Öğrenci toplulukları konseri.',
          'eventDate': '2026-11-18T15:00:00Z',
          'capacity': 250,
          'status': 'Published',
        },
      ],
      'page': 1,
      'pageSize': 20,
      'totalCount': 1,
    });

    final event = page.items.single;
    expect(page.totalCount, 1);
    expect(event.clubName, 'Müzik Topluluğu');
    expect(event.campusLocationId, 3);
    expect(event.eventDate, DateTime.utc(2026, 11, 18, 15));
    expect(event.status, EventStatus.published);
  });

  test('bilinmeyen durum taslak sayılır, küçük harf de tanınır', () {
    expect(EventStatus.fromApi('cancelled'), EventStatus.cancelled);
    expect(EventStatus.fromApi('Archived'), EventStatus.draft);
    expect(EventStatus.fromApi(null), EventStatus.draft);
  });

  test('istek gövdesinde tarih UTC ve Z ile gider', () {
    final local = DateTime(2026, 12, 1, 19, 30);
    final json = EventInput(
      clubId: 12,
      title: 'Konser',
      eventDate: local,
      capacity: 40,
      status: EventStatus.draft,
    ).toJson();

    expect(json['eventDate'], local.toUtc().toIso8601String());
    expect(json['eventDate'], endsWith('Z'));
    expect(json['status'], 'Draft');
    expect(json['campusLocationId'], isNull);
  });
}
