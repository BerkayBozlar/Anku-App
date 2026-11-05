/// API'deki etkinlik durumları.
enum EventStatus {
  draft('Draft', 'Taslak'),
  published('Published', 'Yayında'),
  cancelled('Cancelled', 'İptal edildi');

  const EventStatus(this.apiName, this.label);

  final String apiName;
  final String label;

  /// Tanınmayan durum taslak sayılır.
  static EventStatus fromApi(String? value) => EventStatus.values.firstWhere(
    (s) => s.apiName.toLowerCase() == value?.toLowerCase(),
    orElse: () => EventStatus.draft,
  );
}

/// `GET /api/events` öğesi ve `GET /api/events/{id}` ayrıntısı.
class ClubEvent {
  const ClubEvent({
    required this.id,
    required this.clubId,
    required this.title,
    required this.eventDate,
    required this.status,
    this.clubName,
    this.campusLocationId,
    this.campusLocationName,
    this.description,
    this.capacity,
  });

  factory ClubEvent.fromJson(Map<String, dynamic> json) {
    return ClubEvent(
      id: json['id'] as int,
      clubId: json['clubId'] as int,
      clubName: json['clubName'] as String?,
      campusLocationId: json['campusLocationId'] as int?,
      campusLocationName: json['campusLocationName'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      eventDate: DateTime.parse(json['eventDate'] as String).toUtc(),
      capacity: json['capacity'] as int?,
      status: EventStatus.fromApi(json['status'] as String?),
    );
  }

  final int id;
  final int clubId;
  final String? clubName;
  final int? campusLocationId;
  final String? campusLocationName;
  final String title;
  final String? description;

  /// UTC; ekranda `toLocal()` ile gösterilir.
  final DateTime eventDate;
  final int? capacity;
  final EventStatus status;
}

/// Sayfalı liste yanıtı.
class EventPage {
  const EventPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  factory EventPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List? ?? const [];
    return EventPage(
      items: [
        for (final item in items)
          ClubEvent.fromJson(item as Map<String, dynamic>),
      ],
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? items.length,
      totalCount: json['totalCount'] as int? ?? items.length,
    );
  }

  final List<ClubEvent> items;
  final int page;
  final int pageSize;
  final int totalCount;
}

/// `POST` ve `PUT /api/events` gövdesi.
class EventInput {
  const EventInput({
    required this.clubId,
    required this.title,
    required this.eventDate,
    required this.capacity,
    required this.status,
    this.campusLocationId,
    this.description,
  });

  final int clubId;
  final int? campusLocationId;
  final String title;
  final String? description;
  final DateTime eventDate;
  final int capacity;
  final EventStatus status;

  Map<String, dynamic> toJson() => {
    'clubId': clubId,
    'campusLocationId': campusLocationId,
    'title': title,
    'description': description,
    // UTC ve "Z" ile; API tarihi UTC saklar
    'eventDate': eventDate.toUtc().toIso8601String(),
    'capacity': capacity,
    'status': status.apiName,
  };
}
