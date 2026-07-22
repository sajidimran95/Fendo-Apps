class ContactMatchUser {
  const ContactMatchUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.phone,
  });

  final int id;
  final String name;
  final String email;
  final String? avatar;
  final String? phone;

  factory ContactMatchUser.fromJson(Map<String, dynamic> json) {
    return ContactMatchUser(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      avatar: json['avatar']?.toString(),
      phone: json['phone']?.toString(),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

/// One row from POST /contacts/match response.
class ContactMatchResult {
  const ContactMatchResult({
    required this.localId,
    required this.name,
    required this.isAppUser,
    this.user,
    this.phones = const [],
    this.emails = const [],
  });

  final String localId;
  final String name;
  final bool isAppUser;
  final ContactMatchUser? user;
  final List<String> phones;
  final List<String> emails;

  factory ContactMatchResult.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return ContactMatchResult(
      localId: (json['local_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      isAppUser: json['is_app_user'] == true || json['is_app_user'] == 1,
      user: user is Map
          ? ContactMatchUser.fromJson(Map<String, dynamic>.from(user))
          : null,
      phones: _stringList(json['phones']),
      emails: _stringList(json['emails']),
    );
  }

  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e.toString()).toList();
  }
}

/// Payload item for POST /contacts/match.
class ContactMatchInput {
  const ContactMatchInput({
    required this.localId,
    required this.name,
    this.phones = const [],
    this.emails = const [],
  });

  final String localId;
  final String name;
  final List<String> phones;
  final List<String> emails;

  Map<String, dynamic> toJson() => {
        'local_id': localId,
        'name': name,
        'phones': phones,
        'emails': emails,
      };
}

enum LoanDirection { give, take }

class MockLoan {
  const MockLoan({
    required this.id,
    required this.personName,
    required this.amount,
    required this.currency,
    required this.direction,
    required this.date,
    this.note,
    this.isAppUser = true,
    this.counterpartyUserId,
  });

  final int id;
  final String personName;
  final double amount;
  final String currency;
  final LoanDirection direction;
  final String date;
  final String? note;
  final bool isAppUser;
  final int? counterpartyUserId;

  bool get isGive => direction == LoanDirection.give;
}
