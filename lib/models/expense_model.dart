class ExpensePayer {
  const ExpensePayer({
    required this.userId,
    required this.amountPaid,
    this.name,
  });

  final int userId;
  final double amountPaid;
  final String? name;

  factory ExpensePayer.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : null;
    return ExpensePayer(
      userId: _asInt(json['user_id'] ?? user?['id'] ?? json['id']),
      amountPaid: _asDouble(json['amount_paid'] ?? json['amount'] ?? 0),
      name: user?['name']?.toString() ?? json['name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'amount_paid': amountPaid,
      };

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

class ExpenseParticipant {
  const ExpenseParticipant({
    required this.userId,
    this.name,
    this.percentage,
    this.shares,
    this.amount,
  });

  final int userId;
  final String? name;
  final double? percentage;
  final double? shares;
  final double? amount;

  factory ExpenseParticipant.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : null;
    final owed = json['amount'] ?? json['amount_owed'];
    return ExpenseParticipant(
      userId: ExpensePayer._asInt(json['user_id'] ?? user?['id'] ?? json['id']),
      name: user?['name']?.toString() ?? json['name']?.toString(),
      percentage: json['percentage'] == null
          ? null
          : ExpensePayer._asDouble(json['percentage']),
      shares: json['shares'] == null
          ? null
          : ExpensePayer._asDouble(json['shares']),
      amount: owed == null ? null : ExpensePayer._asDouble(owed),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        if (percentage != null) 'percentage': percentage,
        if (shares != null) 'shares': shares,
        if (amount != null) 'amount': amount,
      };
}

class ExpenseItem {
  const ExpenseItem({
    required this.name,
    required this.amount,
    this.assignedTo = const [],
  });

  final String name;
  final double amount;
  final List<int> assignedTo;

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    final assigned = json['assigned_to'];
    return ExpenseItem(
      name: (json['name'] ?? '').toString(),
      amount: ExpensePayer._asDouble(json['amount']),
      assignedTo: assigned is List
          ? assigned.map((e) => ExpensePayer._asInt(e)).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'assigned_to': assignedTo,
      };
}

class ExpenseModel {
  const ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.expenseDate,
    required this.groupId,
    this.groupName,
    this.categoryId,
    this.categoryName,
    this.splitMethod = 'equal',
    this.payers = const [],
    this.participants = const [],
    this.items = const [],
    this.isMultiPayer = false,
    this.merchantName,
    this.receiptUrl,
    this.createdAt,
  });

  final int id;
  final String title;
  final double amount;
  final String currency;
  final String expenseDate;
  final int groupId;
  final String? groupName;
  final int? categoryId;
  final String? categoryName;
  final String splitMethod;
  final List<ExpensePayer> payers;
  final List<ExpenseParticipant> participants;
  final List<ExpenseItem> items;
  final bool isMultiPayer;
  final String? merchantName;
  final String? receiptUrl;
  final String? createdAt;

  String get paidByLabel {
    if (payers.isEmpty) return 'Unknown';
    if (payers.length == 1) {
      return payers.first.name ?? 'User ${payers.first.userId}';
    }
    return '${payers.length} payers';
  }

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    final group = json['group'] is Map
        ? Map<String, dynamic>.from(json['group'] as Map)
        : null;
    final category = json['category'] is Map
        ? Map<String, dynamic>.from(json['category'] as Map)
        : null;

    List<ExpensePayer> parsePayers(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => ExpensePayer.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    List<ExpenseParticipant> parseParts(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) => ExpenseParticipant.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    }

    List<ExpenseItem> parseItems(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => ExpenseItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return ExpenseModel(
      id: ExpensePayer._asInt(json['id']),
      title: (json['title'] ?? '').toString(),
      amount: ExpensePayer._asDouble(json['amount']),
      currency: (json['currency'] ?? 'USD').toString(),
      expenseDate: (json['expense_date'] ?? json['date'] ?? '').toString(),
      groupId: ExpensePayer._asInt(json['group_id'] ?? group?['id']),
      groupName: group?['name']?.toString() ?? json['group_name']?.toString(),
      categoryId: json['category_id'] == null && category?['id'] == null
          ? null
          : ExpensePayer._asInt(json['category_id'] ?? category?['id']),
      categoryName:
          category?['name']?.toString() ?? json['category_name']?.toString(),
      splitMethod: (json['split_method'] ?? 'equal').toString(),
      payers: parsePayers(json['payers']),
      participants: parseParts(
        json['participants'] ?? json['splits'] ?? json['expense_splits'],
      ),
      items: parseItems(json['items']),
      isMultiPayer: json['is_multi_payer'] == true,
      merchantName: json['merchant_name']?.toString(),
      receiptUrl: json['receipt_url']?.toString() ?? json['receipt']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  ExpenseModel copyWith({
    String? title,
    double? amount,
    String? currency,
    String? expenseDate,
    int? categoryId,
    String? categoryName,
    String? splitMethod,
    List<ExpensePayer>? payers,
    List<ExpenseParticipant>? participants,
    List<ExpenseItem>? items,
    bool? isMultiPayer,
    String? merchantName,
    String? groupName,
  }) {
    return ExpenseModel(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      expenseDate: expenseDate ?? this.expenseDate,
      groupId: groupId,
      groupName: groupName ?? this.groupName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      splitMethod: splitMethod ?? this.splitMethod,
      payers: payers ?? this.payers,
      participants: participants ?? this.participants,
      items: items ?? this.items,
      isMultiPayer: isMultiPayer ?? this.isMultiPayer,
      merchantName: merchantName ?? this.merchantName,
      receiptUrl: receiptUrl,
      createdAt: createdAt,
    );
  }
}

class ScanReceiptResult {
  const ScanReceiptResult({
    this.title,
    this.amount,
    this.merchantName,
    this.expenseDate,
    this.currency,
    this.items = const [],
    this.raw,
  });

  final String? title;
  final double? amount;
  final String? merchantName;
  final String? expenseDate;
  final String? currency;
  final List<ExpenseItem> items;
  final Map<String, dynamic>? raw;

  factory ScanReceiptResult.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    return ScanReceiptResult(
      title: json['title']?.toString() ?? json['merchant_name']?.toString(),
      amount: json['amount'] == null
          ? null
          : ExpensePayer._asDouble(json['amount']),
      merchantName: json['merchant_name']?.toString(),
      expenseDate: json['expense_date']?.toString() ?? json['date']?.toString(),
      currency: json['currency']?.toString(),
      items: itemsRaw is List
          ? itemsRaw
              .whereType<Map>()
              .map((e) => ExpenseItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      raw: json,
    );
  }
}
