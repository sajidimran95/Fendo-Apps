class BillSplit {
  const BillSplit({
    required this.userId,
    required this.amountOwed,
    this.name,
  });

  final int userId;
  final double amountOwed;
  final String? name;

  factory BillSplit.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : null;
    return BillSplit(
      userId: _asInt(json['user_id'] ?? user?['id']),
      amountOwed: _asDouble(json['amount_owed'] ?? json['amount'] ?? 0),
      name: user?['name']?.toString() ?? json['name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'amount_owed': amountOwed,
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

class BillModel {
  const BillModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.groupId,
    this.groupName,
    this.notes,
    this.status = 'upcoming',
    this.reminderDays = const [],
    this.splits = const [],
    this.billType = 'one_time',
    this.frequency,
    this.recurrenceEndDate,
    this.amountPaid = 0,
    this.paymentMethod,
  });

  final int id;
  final String name;
  final double amount;
  final String dueDate;
  final int groupId;
  final String? groupName;
  final String? notes;
  final String status;
  final List<int> reminderDays;
  final List<BillSplit> splits;
  final String billType;
  final String? frequency;
  final String? recurrenceEndDate;
  final double amountPaid;
  final String? paymentMethod;

  double get remaining => (amount - amountPaid).clamp(0, amount);

  bool get isRecurring => billType == 'recurring';

  factory BillModel.fromJson(Map<String, dynamic> json) {
    final group = json['group'] is Map
        ? Map<String, dynamic>.from(json['group'] as Map)
        : null;
    final reminders = json['reminder_days'];
    final splitsRaw = json['splits'];

    return BillModel(
      id: BillSplit._asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      amount: BillSplit._asDouble(json['amount']),
      dueDate: (json['due_date'] ?? '').toString(),
      groupId: BillSplit._asInt(json['group_id'] ?? group?['id']),
      groupName: group?['name']?.toString() ?? json['group_name']?.toString(),
      notes: json['notes']?.toString(),
      status: (json['status'] ?? 'upcoming').toString(),
      reminderDays: reminders is List
          ? reminders.map((e) => BillSplit._asInt(e)).toList()
          : const [],
      splits: splitsRaw is List
          ? splitsRaw
              .whereType<Map>()
              .map((e) => BillSplit.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      billType: (json['bill_type'] ?? 'one_time').toString(),
      frequency: json['frequency']?.toString(),
      recurrenceEndDate: json['recurrence_end_date']?.toString(),
      amountPaid: BillSplit._asDouble(
        json['amount_paid'] ?? json['paid_amount'] ?? 0,
      ),
      paymentMethod: json['payment_method']?.toString(),
    );
  }

  BillModel copyWith({
    String? name,
    double? amount,
    String? dueDate,
    String? notes,
    String? status,
    List<int>? reminderDays,
    List<BillSplit>? splits,
    String? billType,
    String? frequency,
    String? recurrenceEndDate,
    double? amountPaid,
    String? paymentMethod,
    String? groupName,
  }) {
    return BillModel(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      groupId: groupId,
      groupName: groupName ?? this.groupName,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      reminderDays: reminderDays ?? this.reminderDays,
      splits: splits ?? this.splits,
      billType: billType ?? this.billType,
      frequency: frequency ?? this.frequency,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}
