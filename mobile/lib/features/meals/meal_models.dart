/// `yyyy-MM-dd` biçimindeki gün düzeyindeki tarih; saat dilimine çevrilmez.
DateTime _parseDay(String value) {
  final parsed = DateTime.parse(value);
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// SKS ortak öğle menüsü (docs/api-sozlesmesi.md, 5. hafta).
class MealMenu {
  const MealMenu({
    required this.id,
    required this.menuDate,
    required this.dishes,
    required this.sourceName,
    required this.sourceUrl,
    this.totalCalories,
    this.retrievedAt,
    this.isManual = false,
  });

  factory MealMenu.fromJson(Map<String, dynamic> json) => MealMenu(
    id: json['id'] as int,
    menuDate: _parseDay(json['menuDate'] as String),
    dishes: [
      for (final dish in json['dishes'] as List<dynamic>? ?? const [])
        dish as String,
    ],
    totalCalories: json['totalCalories'] as int?,
    sourceName: json['sourceName'] as String? ?? '',
    sourceUrl: json['sourceUrl'] as String? ?? '',
    retrievedAt: json['retrievedAt'] == null
        ? null
        : DateTime.parse(json['retrievedAt'] as String),
    isManual: json['isManual'] as bool? ?? false,
  );

  final int id;

  /// Menünün günü (yerel gece yarısı).
  final DateTime menuDate;
  final List<String> dishes;
  final int? totalCalories;
  final String sourceName;
  final String sourceUrl;

  /// Son indirme/kaydetme anı; menünün tarihi değildir.
  final DateTime? retrievedAt;
  final bool isManual;
}

/// `GET /api/meal-menus?from&to` yanıtı. Menüsü olmayan günler listede yer almaz.
class MealMenuRange {
  const MealMenuRange({
    required this.items,
    required this.from,
    required this.to,
  });

  factory MealMenuRange.fromJson(Map<String, dynamic> json) => MealMenuRange(
    items: [
      for (final item in json['items'] as List<dynamic>? ?? const [])
        MealMenu.fromJson(item as Map<String, dynamic>),
    ],
    from: _parseDay(json['from'] as String),
    to: _parseDay(json['to'] as String),
  );

  final List<MealMenu> items;
  final DateTime from;
  final DateTime to;

  /// Aralıktaki her gün ve varsa o günün menüsü.
  List<(DateTime, MealMenu?)> get days {
    final byDay = {
      for (final menu in items)
        DateTime(menu.menuDate.year, menu.menuDate.month, menu.menuDate.day):
            menu,
    };
    return [
      for (
        var day = from;
        !day.isAfter(to);
        day = DateTime(day.year, day.month, day.day + 1)
      )
        (day, byDay[day]),
    ];
  }
}
