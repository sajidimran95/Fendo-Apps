class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.read = false,
    this.type,
    this.createdAt,
  });

  final int id;
  final String title;
  final String body;
  final bool read;
  final String? type;
  final String? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: _asInt(json['id']),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ??
          json['message']?.toString() ??
          json['content']?.toString() ??
          '',
      read: json['read'] == true ||
          json['is_read'] == true ||
          json['read_at'] != null,
      type: json['type']?.toString() ?? json['notification_type']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  AppNotification copyWith({
    int? id,
    String? title,
    String? body,
    bool? read,
    String? type,
    String? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      read: read ?? this.read,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get timeAgo {
    final raw = createdAt;
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
