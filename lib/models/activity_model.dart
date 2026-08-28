import '../core/utils/app_currency.dart';

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.eventType,
    required this.description,
    this.amount,
    this.currency = AppCurrency.fallback,
    this.actorId,
    this.actorName,
    this.groupId,
    this.groupName,
    this.createdAt,
  });

  final int id;
  final String eventType;
  final String description;
  final double? amount;
  final String currency;
  final int? actorId;
  final String? actorName;
  final int? groupId;
  final String? groupName;
  final String? createdAt;

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] is Map
        ? Map<String, dynamic>.from(json['actor'] as Map)
        : null;
    final group = json['group'] is Map
        ? Map<String, dynamic>.from(json['group'] as Map)
        : null;

    final amount =
        json['amount'] == null ? null : _asDouble(json['amount']);

    // Prefer API currency → group currency → profile (never hard-code USD only).
    final rawCur = (json['currency'] ??
            group?['currency'] ??
            json['group_currency'])
        ?.toString()
        .trim();
    final currency = AppCurrency.normalize(
      (rawCur != null && rawCur.isNotEmpty) ? rawCur : AppCurrency.profileCode,
    );

    final rawDesc = json['description']?.toString() ?? '';
    final description = _localizeDescription(rawDesc, amount, currency);

    return ActivityItem(
      id: _asInt(json['id']),
      eventType: json['event_type']?.toString() ?? 'activity',
      description: description,
      amount: amount,
      currency: currency,
      actorId: actor == null && json['actor_id'] == null
          ? null
          : _asInt(json['actor_id'] ?? actor?['id']),
      actorName: actor?['name']?.toString() ??
          json['actor_name']?.toString() ??
          (json['actor'] is String ? json['actor'].toString() : null),
      groupId: group == null && json['group_id'] == null
          ? null
          : _asInt(json['group_id'] ?? group?['id']),
      groupName: group?['name']?.toString() ??
          json['group_name']?.toString() ??
          (json['group'] is String ? json['group'].toString() : null),
      createdAt: json['created_at']?.toString(),
    );
  }

  /// Server activity text hard-codes `$10.00` — swap to profile/group currency.
  static String _localizeDescription(
    String desc,
    double? amount,
    String currency,
  ) {
    if (desc.isEmpty) return desc;
    final money = amount != null
        ? AppCurrency.format(amount, code: currency)
        : null;

    var out = desc;
    // "( $10.00 )" / "($10.00)"
    out = out.replaceAllMapped(
      RegExp(r'\(\s*[$€£¥৳₹]?\s*[\d,]+\.?\d*\s*\)'),
      (m) => money != null ? '($money)' : m.group(0)!,
    );
    // bare $10.00 / ৳100
    out = out.replaceAllMapped(
      RegExp(r'[$€£¥৳₹]\s*[\d,]+\.?\d*'),
      (m) => money ?? m.group(0)!,
    );
    // "10.00 USD" trailing code when we know amount
    if (money != null) {
      final codes = AppCurrency.codes.join('|');
      out = out.replaceAllMapped(
        RegExp(
          '\\b[\\d,]+\\.?\\d*\\s*($codes)\\b',
          caseSensitive: false,
        ),
        (_) => money,
      );
    }
    return out;
  }

  String get timeAgo {
    final raw = createdAt;
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}
