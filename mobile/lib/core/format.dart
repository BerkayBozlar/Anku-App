String _two(int n) => n.toString().padLeft(2, '0');

/// `05.11.2026`
String formatDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

const _weekdays = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

/// `Perşembe`
String weekdayName(DateTime d) => _weekdays[d.weekday - 1];

/// API'nin gün düzeyindeki tarih biçimi: `2026-11-05`
String formatApiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// `05.11.2026 14:30`
String formatDateTime(DateTime d) =>
    '${formatDate(d)} ${_two(d.hour)}:${_two(d.minute)}';
