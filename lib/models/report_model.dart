class ReportBucket {
  const ReportBucket({required this.label, required this.amount});

  final String label;
  final double amount;

  factory ReportBucket.fromJson(Map<String, dynamic> json) {
    return ReportBucket(
      label: json['label']?.toString() ??
          json['name']?.toString() ??
          json['category']?.toString() ??
          json['month']?.toString() ??
          json['group']?.toString() ??
          json['member']?.toString() ??
          json['key']?.toString() ??
          '—',
      amount: _asDouble(
        json['amount'] ??
            json['total'] ??
            json['value'] ??
            json['net_balance'] ??
            json['spent'] ??
            0,
      ),
    );
  }

  static List<ReportBucket> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ReportBucket.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class PersonalReport {
  const PersonalReport({
    this.totalSpent = 0,
    this.totalOwed = 0,
    this.byCategory = const [],
    this.byMonth = const [],
    this.byGroup = const [],
    this.balanceTrend = const [],
    this.from,
    this.to,
  });

  final double totalSpent;
  final double totalOwed;
  final List<ReportBucket> byCategory;
  final List<ReportBucket> byMonth;
  final List<ReportBucket> byGroup;
  final List<ReportBucket> balanceTrend;
  final String? from;
  final String? to;

  factory PersonalReport.fromJson(Map<String, dynamic> json) {
    final data = json['report'] is Map
        ? Map<String, dynamic>.from(json['report'] as Map)
        : json;
    final period = data['period'] is Map
        ? Map<String, dynamic>.from(data['period'] as Map)
        : null;
    return PersonalReport(
      totalSpent: ReportBucket._asDouble(
        data['total_spent'] ?? data['totalSpent'] ?? 0,
      ),
      totalOwed: ReportBucket._asDouble(
        data['total_owed'] ?? data['totalOwed'] ?? 0,
      ),
      byCategory: ReportBucket.listFrom(data['by_category']),
      byMonth: ReportBucket.listFrom(data['by_month']),
      byGroup: ReportBucket.listFrom(data['by_group']),
      balanceTrend: ReportBucket.listFrom(data['balance_trend']),
      from: period?['from']?.toString() ?? data['from']?.toString(),
      to: period?['to']?.toString() ?? data['to']?.toString(),
    );
  }
}

class GroupReport {
  const GroupReport({
    required this.groupId,
    this.groupName,
    this.totalSpent = 0,
    this.totalOwed = 0,
    this.byCategory = const [],
    this.byMember = const [],
    this.byMonth = const [],
  });

  final int groupId;
  final String? groupName;
  final double totalSpent;
  final double totalOwed;
  final List<ReportBucket> byCategory;
  final List<ReportBucket> byMember;
  final List<ReportBucket> byMonth;

  factory GroupReport.fromJson(Map<String, dynamic> json, {int? fallbackId}) {
    final data = json['report'] is Map
        ? Map<String, dynamic>.from(json['report'] as Map)
        : json;
    final group = data['group'] is Map
        ? Map<String, dynamic>.from(data['group'] as Map)
        : null;
    return GroupReport(
      groupId: _asInt(data['group_id'] ?? group?['id'] ?? fallbackId ?? 0),
      groupName: group?['name']?.toString() ?? data['group_name']?.toString(),
      totalSpent: ReportBucket._asDouble(data['total_spent'] ?? 0),
      totalOwed: ReportBucket._asDouble(data['total_owed'] ?? 0),
      byCategory: ReportBucket.listFrom(data['by_category']),
      byMember: ReportBucket.listFrom(data['by_member'] ?? data['by_user']),
      byMonth: ReportBucket.listFrom(data['by_month']),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class ReportExport {
  const ReportExport({
    required this.format,
    required this.content,
    this.filename,
  });

  final String format;
  final String content;
  final String? filename;
}
