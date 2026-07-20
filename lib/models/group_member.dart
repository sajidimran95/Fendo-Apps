class GroupMember {
  const GroupMember({
    required this.userId,
    required this.name,
    required this.email,
    this.avatar,
    this.role = 'member',
    this.balance = 0,
  });

  final int userId;
  final String name;
  final String email;
  final String? avatar;
  final String role;
  final double balance;

  bool get isAdmin => role == 'admin';

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : json;
    return GroupMember(
      userId: _asInt(json['user_id'] ?? user['id'] ?? json['id']),
      name: (user['name'] ?? json['name'] ?? '').toString(),
      email: (user['email'] ?? json['email'] ?? '').toString(),
      avatar: user['avatar']?.toString() ?? json['avatar']?.toString(),
      role: (json['role'] ?? 'member').toString(),
      balance: _asDouble(json['balance'] ?? json['net_balance'] ?? 0),
    );
  }

  GroupMember copyWith({String? role}) {
    return GroupMember(
      userId: userId,
      name: name,
      email: email,
      avatar: avatar,
      role: role ?? this.role,
      balance: balance,
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
