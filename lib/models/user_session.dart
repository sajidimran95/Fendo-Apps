class UserSession {
  const UserSession({
    required this.id,
    required this.name,
    this.createdAt,
    this.lastUsed,
    this.isCurrent = false,
  });

  final String id;
  final String name;
  final String? createdAt;
  final String? lastUsed;
  final bool isCurrent;

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Device').toString(),
      createdAt: json['created_at']?.toString(),
      lastUsed: json['last_used']?.toString(),
      isCurrent: json['is_current'] == true,
    );
  }
}
