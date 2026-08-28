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
  bool get hasValidUserId => userId > 0;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final nestedUser = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : null;

    // Live GET /groups/{id}/members returns flat users:
    //   { "id": 15, "name": "...", "email": "...", "role": "admin" }
    // where `id` IS the app user id.
    //
    // GET /groups/{id} embeds pivots:
    //   { "id": 7, "user_id": 15, "user": { "id": 15, "name": "..." } }
    // where pivot `id` is membership id — never send that on expenses.
    final explicitUserId = _asInt(
      json['user_id'] ?? nestedUser?['id'] ?? json['member_user_id'],
    );

    final userId = explicitUserId > 0
        ? explicitUserId
        : _asInt(
            // Flat member/user rows (Postman / live members list).
            (nestedUser == null &&
                    (json['email'] != null ||
                        json['name'] != null ||
                        json['role'] != null)
                ? json['id']
                : null),
          );

    final nameSource = nestedUser ?? json;
    return GroupMember(
      userId: userId,
      name: (nameSource['name'] ?? json['name'] ?? '').toString(),
      email: (nameSource['email'] ?? json['email'] ?? '').toString(),
      avatar:
          nestedUser?['avatar']?.toString() ?? json['avatar']?.toString(),
      role: (json['role'] ?? nestedUser?['role'] ?? 'member').toString(),
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
