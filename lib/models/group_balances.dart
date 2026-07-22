class GroupBalanceSummary {
  const GroupBalanceSummary({
    this.youOwe = 0,
    this.youAreOwed = 0,
    this.netBalance = 0,
  });

  final double youOwe;
  final double youAreOwed;
  final double netBalance;

  factory GroupBalanceSummary.fromJson(Map<String, dynamic> json) {
    return GroupBalanceSummary(
      youOwe: _d(json['you_owe']),
      youAreOwed: _d(json['you_are_owed']),
      netBalance: _d(json['net_balance']),
    );
  }

  static double _d(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class GroupBalanceRow {
  const GroupBalanceRow({
    required this.userId,
    required this.name,
    required this.amount,
    this.avatar,
  });

  final int userId;
  final String name;
  final double amount;
  final String? avatar;

  factory GroupBalanceRow.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : json;
    return GroupBalanceRow(
      userId: _asInt(json['user_id'] ?? user['id'] ?? json['id']),
      name: (user['name'] ?? json['name'] ?? '').toString(),
      amount: GroupBalanceSummary._d(
        json['amount'] ?? json['balance'] ?? json['net_balance'],
      ),
      avatar: user['avatar']?.toString(),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class GroupBalances {
  const GroupBalances({
    required this.summary,
    this.balances = const [],
    this.simplified = const [],
  });

  final GroupBalanceSummary summary;
  final List<GroupBalanceRow> balances;
  final List<GroupBalanceRow> simplified;

  factory GroupBalances.fromJson(Map<String, dynamic> json) {
    final summaryRaw = json['summary'];
    final summary = summaryRaw is Map
        ? GroupBalanceSummary.fromJson(Map<String, dynamic>.from(summaryRaw))
        : GroupBalanceSummary.fromJson(json);

    List<GroupBalanceRow> parseRows(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => GroupBalanceRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return GroupBalances(
      summary: summary,
      balances: parseRows(json['balances']),
      simplified: parseRows(json['simplified']),
    );
  }
}

class InviteLinkResult {
  const InviteLinkResult({
    required this.inviteToken,
    required this.inviteLink,
    this.expiresAt,
  });

  final String inviteToken;
  final String inviteLink;
  final String? expiresAt;

  factory InviteLinkResult.fromJson(Map<String, dynamic> json) {
    return InviteLinkResult(
      inviteToken: (json['invite_token'] ?? json['token'] ?? '').toString(),
      inviteLink: (json['invite_link'] ?? json['link'] ?? '').toString(),
      expiresAt: json['expires_at']?.toString(),
    );
  }
}

/// Result of POST /groups/{id}/invite or /invite-phone.
class InviteMembersResult {
  const InviteMembersResult({
    this.added = const [],
    this.notFound = const [],
    this.alreadyMembers = const [],
    this.message,
  });

  final List<String> added;
  final List<String> notFound;
  final List<String> alreadyMembers;
  final String? message;

  int get addedCount => added.length;

  factory InviteMembersResult.fromJson(Map<String, dynamic> json) {
    List<String> asStrings(dynamic raw) {
      if (raw is! List) return const [];
      return raw.map((e) {
        if (e is Map) {
          return (e['email'] ?? e['phone'] ?? e['name'] ?? e['id'] ?? e)
              .toString();
        }
        return e.toString();
      }).toList();
    }

    return InviteMembersResult(
      added: asStrings(json['added']),
      notFound: asStrings(json['not_found']),
      alreadyMembers: asStrings(json['already_members']),
      message: json['message']?.toString(),
    );
  }

  InviteMembersResult merge(InviteMembersResult other) {
    return InviteMembersResult(
      added: [...added, ...other.added],
      notFound: [...notFound, ...other.notFound],
      alreadyMembers: [...alreadyMembers, ...other.alreadyMembers],
      message: other.message ?? message,
    );
  }
}
