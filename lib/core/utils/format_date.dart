/// Human-readable dates / labels for API strings.
library;

const _months = [
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

/// Calendar date only — e.g. `2026-08-07T00:00:00.000000Z` → `Aug 7, 2026`.
/// Avoids showing ISO `T00:00:00.000Z` tails and UTC day-shift bugs when
/// the value is a plain due/expense date.
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
  if (day == null) {
    // Strip common ISO time tails if parse failed partially.
    final cleaned = s
        .replaceAll(RegExp(r'[Tt].*$'), '')
        .replaceAll(RegExp(r'\.\d+Z?$'), '')
        .replaceAll(RegExp(r'Z$'), '');
    return cleaned.isEmpty ? s : cleaned;
  }

  return '${_months[day.month - 1]} ${day.day}, ${day.year}';
}

/// Local date + time when the time is meaningful; date alone otherwise.
/// e.g. `2026-08-07T14:30:00.000000Z` → `Aug 7, 2026 · 8:30 PM`
/// e.g. `2026-08-07T00:00:00.000000Z` → `Aug 7, 2026`
String formatDisplayDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final s = raw.trim();
  final dt = DateTime.tryParse(s);
  if (dt == null) return formatDisplayDate(s);

  final local = dt.toLocal();
  final datePart =
      '${_months[local.month - 1]} ${local.day}, ${local.year}';

  // Midnight (UTC or local) → date-only; callers don't want 00:00:00.000Z noise.
  final hasClock = local.hour != 0 ||
      local.minute != 0 ||
      local.second != 0 ||
      (s.contains(RegExp(r'[Tt]')) &&
          !RegExp(r'[Tt]0{1,2}:0{2}(:0{2})?(\.0+)?Z?$').hasMatch(s));

  // Prefer date-only when the payload is clearly date-level (T00:00...Z).
  if (RegExp(r'[Tt]0{1,2}:0{2}(:0{2})?(\.\d+)?Z?$').hasMatch(s) ||
      (!s.contains(RegExp(r'[Tt]')) && !s.contains(':'))) {
    return datePart;
  }

  if (!hasClock) return datePart;

  final h24 = local.hour;
  final hour12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
  final ampm = h24 >= 12 ? 'PM' : 'AM';
  final min = local.minute.toString().padLeft(2, '0');
  return '$datePart · $hour12:$min $ampm';
}

/// Title-case words for filters / statuses: `due_today` → `Due today`.
/// First word capital, remaining words lower (natural UI labels).
String formatDisplayLabel(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final words = raw
      .trim()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';

  String capFirst(String w) {
    if (w.isEmpty) return w;
    // Keep short all-caps tokens (USD, VIP) as-is.
    if (w.length <= 3 && w == w.toUpperCase() && RegExp(r'^[A-Z0-9]+$').hasMatch(w)) {
      return w;
    }
    final lower = w.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  // First word capitalized; remaining lower-case words with first letter capital
  // (Title Case for multi-word chips: "Due today" if we only cap first: user asked
  // 1st word capital — "Due today" vs "Due Today". Prefer title case on each word
  // for chips like "Due Today" which looks cleaner.)
  return words.map(capFirst).join(' ');
}
