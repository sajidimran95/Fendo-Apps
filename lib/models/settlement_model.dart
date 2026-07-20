class SettlementModel {
  const SettlementModel({
    required this.id,
    required this.payeeId,
    required this.payerId,
    required this.groupId,
    required this.amount,
    this.currency = 'USD',
    this.paymentMethod,
    this.paymentReference,
    this.notes,
    this.settlementDate,
    this.payeeName,
    this.payerName,
    this.groupName,
  });

  final int id;
  final int payeeId;
  final int payerId;
  final int groupId;
  final double amount;
  final String currency;
  final String? paymentMethod;
  final String? paymentReference;
  final String? notes;
  final String? settlementDate;
  final String? payeeName;
  final String? payerName;
  final String? groupName;

  factory SettlementModel.fromJson(Map<String, dynamic> json) {
    final payee = json['payee'] is Map
        ? Map<String, dynamic>.from(json['payee'] as Map)
        : null;
    final payer = json['payer'] is Map
        ? Map<String, dynamic>.from(json['payer'] as Map)
        : null;
    final group = json['group'] is Map
        ? Map<String, dynamic>.from(json['group'] as Map)
        : null;

    return SettlementModel(
      id: _asInt(json['id']),
      payeeId: _asInt(json['payee_id'] ?? payee?['id']),
      payerId: _asInt(json['payer_id'] ?? payer?['id']),
      groupId: _asInt(json['group_id'] ?? group?['id']),
      amount: _asDouble(json['amount']),
      currency: json['currency']?.toString() ?? 'USD',
      paymentMethod: json['payment_method']?.toString(),
      paymentReference: json['payment_reference']?.toString(),
      notes: json['notes']?.toString(),
      settlementDate: json['settlement_date']?.toString(),
      payeeName: payee?['name']?.toString() ?? json['payee_name']?.toString(),
      payerName: payer?['name']?.toString() ?? json['payer_name']?.toString(),
      groupName: group?['name']?.toString() ?? json['group_name']?.toString(),
    );
  }

  SettlementModel copyWith({
    int? id,
    int? payeeId,
    int? payerId,
    int? groupId,
    double? amount,
    String? currency,
    String? paymentMethod,
    String? paymentReference,
    String? notes,
    String? settlementDate,
    String? payeeName,
    String? payerName,
    String? groupName,
  }) {
    return SettlementModel(
      id: id ?? this.id,
      payeeId: payeeId ?? this.payeeId,
      payerId: payerId ?? this.payerId,
      groupId: groupId ?? this.groupId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
      notes: notes ?? this.notes,
      settlementDate: settlementDate ?? this.settlementDate,
      payeeName: payeeName ?? this.payeeName,
      payerName: payerName ?? this.payerName,
      groupName: groupName ?? this.groupName,
    );
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

class SettlementRequest {
  const SettlementRequest({
    required this.id,
    required this.debtorId,
    required this.requesterId,
    required this.groupId,
    required this.amount,
    this.currency = 'USD',
    this.message,
    this.status = 'pending',
    this.debtorName,
    this.requesterName,
    this.groupName,
    this.createdAt,
  });

  final int id;
  final int debtorId;
  final int requesterId;
  final int groupId;
  final double amount;
  final String currency;
  final String? message;
  final String status;
  final String? debtorName;
  final String? requesterName;
  final String? groupName;
  final String? createdAt;

  bool get isPending => status == 'pending';

  factory SettlementRequest.fromJson(Map<String, dynamic> json) {
    final debtor = json['debtor'] is Map
        ? Map<String, dynamic>.from(json['debtor'] as Map)
        : null;
    final requester = json['requester'] is Map
        ? Map<String, dynamic>.from(json['requester'] as Map)
        : json['creditor'] is Map
            ? Map<String, dynamic>.from(json['creditor'] as Map)
            : null;
    final group = json['group'] is Map
        ? Map<String, dynamic>.from(json['group'] as Map)
        : null;

    return SettlementRequest(
      id: _asInt(json['id']),
      debtorId: _asInt(json['debtor_id'] ?? debtor?['id']),
      requesterId: _asInt(
        json['requester_id'] ?? json['creditor_id'] ?? requester?['id'],
      ),
      groupId: _asInt(json['group_id'] ?? group?['id']),
      amount: _asDouble(json['amount']),
      currency: json['currency']?.toString() ?? 'USD',
      message: json['message']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      debtorName:
          debtor?['name']?.toString() ?? json['debtor_name']?.toString(),
      requesterName: requester?['name']?.toString() ??
          json['requester_name']?.toString(),
      groupName: group?['name']?.toString() ?? json['group_name']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  SettlementRequest copyWith({
    int? id,
    int? debtorId,
    int? requesterId,
    int? groupId,
    double? amount,
    String? currency,
    String? message,
    String? status,
    String? debtorName,
    String? requesterName,
    String? groupName,
    String? createdAt,
  }) {
    return SettlementRequest(
      id: id ?? this.id,
      debtorId: debtorId ?? this.debtorId,
      requesterId: requesterId ?? this.requesterId,
      groupId: groupId ?? this.groupId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      message: message ?? this.message,
      status: status ?? this.status,
      debtorName: debtorName ?? this.debtorName,
      requesterName: requesterName ?? this.requesterName,
      groupName: groupName ?? this.groupName,
      createdAt: createdAt ?? this.createdAt,
    );
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

class SettlementDeepLink {
  const SettlementDeepLink({
    required this.url,
    this.payeeId,
    this.amount,
    this.note,
  });

  final String url;
  final int? payeeId;
  final double? amount;
  final String? note;

  factory SettlementDeepLink.fromJson(Map<String, dynamic> json) {
    return SettlementDeepLink(
      url: json['url']?.toString() ??
          json['deep_link']?.toString() ??
          json['link']?.toString() ??
          '',
      payeeId: json['payee_id'] == null ? null : _asInt(json['payee_id']),
      amount: json['amount'] == null ? null : _asDouble(json['amount']),
      note: json['note']?.toString(),
    );
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

const kSettlementPaymentMethods = [
  'cash',
  'bank_transfer',
  'venmo',
  'paypal',
  'zelle',
  'cashapp',
  'apple_pay',
  'other',
];

