class BalanceEntry {
  const BalanceEntry({
    required this.name,
    required this.amount,
    this.userId,
    this.groupName,
    this.groupId,
    this.avatar,
  });

  final int? userId;
  final String name;
  final double amount;
  final String? groupName;
  final int? groupId;
  final String? avatar;

  factory BalanceEntry.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : null;
    final group = json['group'] is Map
        ? Map<String, dynamic>.from(json['group'] as Map)
        : null;
    return BalanceEntry(
      userId: _asIntOrNull(json['user_id'] ?? user?['id']),
      name: (user?['name'] ?? json['name'] ?? '').toString(),
      amount: _asDouble(
        json['amount'] ?? json['balance'] ?? json['net_balance'] ?? 0,
      ),
      groupName: group?['name']?.toString() ?? json['group_name']?.toString(),
      groupId: _asIntOrNull(json['group_id'] ?? group?['id']),
      avatar: user?['avatar']?.toString() ?? json['avatar']?.toString(),
    );
  }

  static int? _asIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class OverallBalances {
  const OverallBalances({
    this.totalYouOwe = 0,
    this.totalYouAreOwed = 0,
    this.netBalance = 0,
    this.youOwe = const [],
    this.youAreOwed = const [],
  });

  final double totalYouOwe;
  final double totalYouAreOwed;
  final double netBalance;
  final List<BalanceEntry> youOwe;
  final List<BalanceEntry> youAreOwed;

  factory OverallBalances.fromJson(Map<String, dynamic> json) {
    List<BalanceEntry> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => BalanceEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return OverallBalances(
      totalYouOwe: BalanceEntry._asDouble(
        json['total_you_owe'] ?? json['you_owe_total'],
      ),
      totalYouAreOwed: BalanceEntry._asDouble(
        json['total_you_are_owed'] ?? json['you_are_owed_total'],
      ),
      netBalance: BalanceEntry._asDouble(json['net_balance']),
      youOwe: parseList(json['you_owe']),
      youAreOwed: parseList(json['you_are_owed']),
    );
  }
}

class BalanceBreakdownPerson {
  const BalanceBreakdownPerson({
    required this.name,
    this.userId,
    this.avatar,
    this.netBalance = 0,
    this.youOwe = 0,
    this.youAreOwed = 0,
    this.groups = const [],
  });

  final int? userId;
  final String name;
  final String? avatar;
  final double netBalance;
  final double youOwe;
  final double youAreOwed;
  final List<BalanceEntry> groups;

  factory BalanceBreakdownPerson.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : null;
    List<BalanceEntry> groups = const [];
    final rawGroups = json['groups'] ?? json['by_group'] ?? json['details'];
    if (rawGroups is List) {
      groups = rawGroups
          .whereType<Map>()
          .map((e) => BalanceEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return BalanceBreakdownPerson(
      userId: BalanceEntry._asIntOrNull(json['user_id'] ?? user?['id']),
      name: (user?['name'] ?? json['name'] ?? '').toString(),
      avatar: user?['avatar']?.toString() ?? json['avatar']?.toString(),
      netBalance: BalanceEntry._asDouble(
        json['net_balance'] ?? json['net'] ?? json['balance'],
      ),
      youOwe: BalanceEntry._asDouble(json['you_owe'] ?? json['owe']),
      youAreOwed: BalanceEntry._asDouble(
        json['you_are_owed'] ?? json['owed'],
      ),
      groups: groups,
    );
  }
}

class BalanceBreakdown {
  const BalanceBreakdown({this.people = const []});

  final List<BalanceBreakdownPerson> people;

  factory BalanceBreakdown.fromJson(Map<String, dynamic> json) {
    final raw = json['people'] ??
        json['breakdown'] ??
        json['users'] ??
        json['items'] ??
        (json is List ? json : null);

    List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else {
      list = const [];
    }

    return BalanceBreakdown(
      people: list
          .whereType<Map>()
          .map(
            (e) =>
                BalanceBreakdownPerson.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}
