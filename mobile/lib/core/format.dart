String _two(int n) => n.toString().padLeft(2, '0');

/// `05.11.2026`
String formatDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

/// `05.11.2026 14:30`
String formatDateTime(DateTime d) =>
    '${formatDate(d)} ${_two(d.hour)}:${_two(d.minute)}';
