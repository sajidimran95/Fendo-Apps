class GroupModel {
  const GroupModel({
    required this.id,
    required this.name,
    required this.type,
    this.currency = 'USD',
    this.simplifyDebts = true,
    this.memberCount = 0,
    this.photo,
    this.archived = false,
    this.muted = false,
    this.netBalance = 0,
    this.role,
    this.createdAt,
  });

  final int id;
  final String name;
  final String type;
  final String currency;
  final bool simplifyDebts;
  final int memberCount;
  final String? photo;
  final bool archived;
  final bool muted;
  final double netBalance;
  final String? role;
  final String? createdAt;

  bool get isAdmin => role == 'admin';

  int get accentColor {
    const colors = [
      0xFF00B894,
      0xFF0984E3,
      0xFFE17055,
      0xFF6C5CE7,
      0xFFFD79A8,
      0xFFF0A500,
    ];
    return colors[id.abs() % colors.length];
  }

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? 'other').toString(),
      currency: (json['currency'] ?? 'USD').toString(),
      simplifyDebts: json['simplify_debts'] == true ||
          json['simplify_debts'] == 1 ||
          json['simplify_debts'] == '1',
      memberCount: _asInt(json['member_count'] ?? json['members_count'] ?? 0),
      photo: json['photo']?.toString() ?? json['avatar']?.toString(),
      archived: json['archived'] == true || json['is_archived'] == true,
      muted: json['muted'] == true || json['notifications_muted'] == true,
      netBalance: _asDouble(
        json['net_balance'] ?? json['your_balance'] ?? json['balance'] ?? 0,
      ),
      role: json['role']?.toString() ?? json['my_role']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  GroupModel copyWith({
    int? id,
    String? name,
    String? type,
    String? currency,
    bool? simplifyDebts,
    int? memberCount,
    String? photo,
    bool? archived,
    bool? muted,
    double? netBalance,
    String? role,
    String? createdAt,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      simplifyDebts: simplifyDebts ?? this.simplifyDebts,
      memberCount: memberCount ?? this.memberCount,
      photo: photo ?? this.photo,
      archived: archived ?? this.archived,
      muted: muted ?? this.muted,
      netBalance: netBalance ?? this.netBalance,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'currency': currency,
        'simplify_debts': simplifyDebts,
        'member_count': memberCount,
        'photo': photo,
        'archived': archived,
        'muted': muted,
        'net_balance': netBalance,
        'role': role,
        'created_at': createdAt,
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
