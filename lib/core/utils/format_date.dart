/// Human-readable dates for API strings (often full ISO with midnight time).
String formatDisplayDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final s = raw.trim();

  // Prefer yyyy-MM-dd calendar day so UTC midnight does not shift the local day.
  DateTime? day;
  if (s.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) {
    day = DateTime.tryParse(s.substring(0, 10));
  } else {
    final dt = DateTime.tryParse(s);
    if (dt != null) {
      final local = dt.toLocal();
      day = DateTime(local.year, local.month, local.day);
    }
  }
  if (day == null) return s.length >= 10 ? s.substring(0, 10) : s;

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[day.month - 1]} ${day.day}, ${day.year}';
}
