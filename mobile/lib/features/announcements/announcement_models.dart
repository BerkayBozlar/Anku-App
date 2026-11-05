/// `/api/announcements` kaydı (docs/api-sozlesmesi.md, 5. hafta).
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.sourceName,
    required this.sourceUrl,
    required this.publishedAt,
    this.summary,
    this.retrievedAt,
    this.isManual = false,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json['id'] as int,
    title: json['title'] as String,
    summary: json['summary'] as String?,
    sourceName: json['sourceName'] as String? ?? '',
    sourceUrl: json['sourceUrl'] as String? ?? '',
    publishedAt: DateTime.parse(json['publishedAt'] as String),
    retrievedAt: json['retrievedAt'] == null
        ? null
        : DateTime.parse(json['retrievedAt'] as String),
    isManual: json['isManual'] as bool? ?? false,
  );

  final int id;
  final String title;

  /// Resmî içeriğin düz metin özeti; tam metin kaynak bağlantısındadır.
  final String? summary;
  final String sourceName;
  final String sourceUrl;
  final DateTime publishedAt;

  /// Kaydın API'ye alındığı/kaydedildiği an.
  final DateTime? retrievedAt;

  /// Yönetici tarafından elle girildiyse `true`.
  final bool isManual;
}

class AnnouncementPage {
  const AnnouncementPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  factory AnnouncementPage.fromJson(Map<String, dynamic> json) =>
      AnnouncementPage(
        items: [
          for (final item in json['items'] as List<dynamic>? ?? const [])
            Announcement.fromJson(item as Map<String, dynamic>),
        ],
        page: json['page'] as int? ?? 1,
        pageSize: json['pageSize'] as int? ?? 20,
        totalCount: json['totalCount'] as int? ?? 0,
      );

  final List<Announcement> items;
  final int page;
  final int pageSize;
  final int totalCount;
}
