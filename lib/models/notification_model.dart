class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.read = false,
    this.type,
    this.createdAt,
    this.groupId,
    this.requestId,
    this.expenseId,
    this.billId,
    this.settlementId,
    this.data = const {},
  });

  final int id;
  final String title;
  final String body;
  final bool read;
  final String? type;
  final String? createdAt;
  final int? groupId;
  final int? requestId;
  final int? expenseId;
  final int? billId;
  final int? settlementId;
  final Map<String, dynamic> data;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = const {};
    final rawData = json['data'] ?? json['payload'] ?? json['meta'];
    if (rawData is Map) {
      data = Map<String, dynamic>.from(rawData);
    }

    int? pickId(List<String> keys) {
      for (final k in keys) {
        final v = json[k] ?? data[k];
        if (v == null) continue;
        final n = _asInt(v);
        if (n > 0) return n;
      }
      return null;
    }

    final typeRaw = (json['type'] ??
            json['notification_type'] ??
            data['type'] ??
            data['notification_type'])
        ?.toString();
    final title =
        json['title']?.toString() ?? data['title']?.toString() ?? '';
    final body = json['body']?.toString() ??
        json['message']?.toString() ??
        json['content']?.toString() ??
        data['body']?.toString() ??
        '';
    final type = _normalizeType(typeRaw, title: title, body: body);

    return AppNotification(
      id: _asInt(json['id']),
      title: title,
      body: body,
      read: json['read'] == true ||
          json['is_read'] == true ||
          json['read_at'] != null,
      type: type,
      createdAt: json['created_at']?.toString() ?? data['created_at']?.toString(),
      groupId: pickId(['group_id', 'groupId']),
      requestId: pickId([
        'request_id',
        'settlement_request_id',
        'payment_request_id',
        'requestId',
      ]),
      expenseId: pickId(['expense_id', 'expenseId']),
      billId: pickId(['bill_id', 'billId']),
      settlementId: pickId(['settlement_id', 'settlementId']),
      data: data,
    );
  }

  /// Build a lightweight notification from FCM / local payload data.
  factory AppNotification.fromPushData(Map<String, dynamic> data) {
    return AppNotification.fromJson({
      'id': data['notification_id'] ?? data['id'] ?? 0,
      'title': data['title'] ?? 'Fendo',
      'body': data['body'] ?? data['message'] ?? '',
      'type': data['type'] ?? data['notification_type'],
      'data': data,
      'group_id': data['group_id'],
      'request_id': data['request_id'] ?? data['settlement_request_id'],
      'expense_id': data['expense_id'],
      'bill_id': data['bill_id'],
      'settlement_id': data['settlement_id'],
      'created_at': data['created_at'],
      'read': true,
    });
  }

  AppNotification copyWith({
    int? id,
    String? title,
    String? body,
    bool? read,
    String? type,
    String? createdAt,
    int? groupId,
    int? requestId,
    int? expenseId,
    int? billId,
    int? settlementId,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      read: read ?? this.read,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      groupId: groupId ?? this.groupId,
      requestId: requestId ?? this.requestId,
      expenseId: expenseId ?? this.expenseId,
      billId: billId ?? this.billId,
      settlementId: settlementId ?? this.settlementId,
      data: data ?? this.data,
    );
  }

  bool get isActionable {
    final t = (type ?? '').toLowerCase();
    return t.contains('settlement_request') ||
        t.contains('settlement_requested') ||
        t.contains('payment_request') ||
        t.contains('settlement') ||
        t.contains('expense') ||
        t.contains('bill') ||
        t.contains('group') ||
        requestId != null ||
        expenseId != null ||
        billId != null ||
        settlementId != null ||
        groupId != null;
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

  /// Normalize API / FCM type strings; infer from title when type is missing.
  static String? _normalizeType(
    String? type, {
    required String title,
    required String body,
  }) {
    final t = (type ?? '').trim().toLowerCase();
    if (t.isNotEmpty) return t;
    final blob = '${title.toLowerCase()} ${body.toLowerCase()}';
    if (blob.contains('payment request') ||
        blob.contains('requested \$') ||
        blob.contains('requested money') ||
        blob.contains('requested payment') ||
        (blob.contains('requested') && blob.contains('pay'))) {
      return 'settlement_requested';
    }
    if (blob.contains('settled') || blob.contains('paid you') || blob.contains('you paid')) {
      return 'settlement_recorded';
    }
    if (blob.contains('expense') || blob.contains('added')) {
      return 'expense_added';
    }
    if (blob.contains('bill') || blob.contains('due')) {
      return 'bill_created';
    }
    if (blob.contains('joined') || blob.contains('group')) {
      return 'group';
    }
    return type;
  }
}
