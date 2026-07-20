/// Static mock data for UI preview (no API).
class MockUser {
  const MockUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    this.currency = 'USD',
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final String currency;
}

class MockGroup {
  const MockGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.memberCount,
    required this.netBalance,
    required this.currency,
    this.color = 0xFF00B894,
  });

  final int id;
  final String name;
  final String type;
  final int memberCount;
  final double netBalance;
  final String currency;
  final int color;
}

class MockExpense {
  const MockExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.groupName,
    required this.paidBy,
    required this.date,
    required this.category,
  });

  final int id;
  final String title;
  final double amount;
  final String currency;
  final String groupName;
  final String paidBy;
  final String date;
  final String category;
}

class MockBill {
  const MockBill({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.groupName,
  });

  final int id;
  final String name;
  final double amount;
  final String dueDate;
  final String status;
  final String groupName;
}

class MockActivity {
  const MockActivity({
    required this.id,
    required this.description,
    required this.eventType,
    required this.timeAgo,
    required this.actorName,
    this.amount,
    this.groupName,
  });

  final int id;
  final String description;
  final String eventType;
  final String timeAgo;
  final String actorName;
  final double? amount;
  final String? groupName;
}

class MockBalanceRow {
  const MockBalanceRow({
    required this.name,
    required this.groupName,
    required this.amount,
    required this.youOwe,
  });

  final String name;
  final String groupName;
  final double amount;
  final bool youOwe;
}

class MockData {
  MockData._();

  static const currentUser = MockUser(
    id: 1,
    name: 'Alex Rivera',
    email: 'alex@fendo.app',
    phone: '+1 555 0102',
    currency: 'USD',
  );

  static const groups = <MockGroup>[
    MockGroup(
      id: 1,
      name: 'Bali Trip 2026',
      type: 'vacation',
      memberCount: 4,
      netBalance: 75,
      currency: 'USD',
      color: 0xFF00B894,
    ),
    MockGroup(
      id: 2,
      name: 'Apartment 4B',
      type: 'apartment',
      memberCount: 3,
      netBalance: -42.5,
      currency: 'USD',
      color: 0xFFF0A500,
    ),
    MockGroup(
      id: 3,
      name: 'Weekend Friends',
      type: 'friends',
      memberCount: 6,
      netBalance: 18,
      currency: 'USD',
      color: 0xFF5B8DEF,
    ),
  ];

  static const expenses = <MockExpense>[
    MockExpense(
      id: 1,
      title: 'Dinner at Nobu',
      amount: 120,
      currency: 'USD',
      groupName: 'Bali Trip 2026',
      paidBy: 'Alex',
      date: 'Jun 11',
      category: 'Food & Drink',
    ),
    MockExpense(
      id: 2,
      title: 'Uber to Airport',
      amount: 60,
      currency: 'USD',
      groupName: 'Bali Trip 2026',
      paidBy: 'Sam',
      date: 'Jun 10',
      category: 'Transport',
    ),
    MockExpense(
      id: 3,
      title: 'Groceries',
      amount: 89.4,
      currency: 'USD',
      groupName: 'Apartment 4B',
      paidBy: 'Alex',
      date: 'Jun 9',
      category: 'Groceries',
    ),
    MockExpense(
      id: 4,
      title: 'Netflix',
      amount: 22,
      currency: 'USD',
      groupName: 'Apartment 4B',
      paidBy: 'Jordan',
      date: 'Jun 8',
      category: 'Entertainment',
    ),
  ];

  static const bills = <MockBill>[
    MockBill(
      id: 1,
      name: 'Electricity April',
      amount: 150,
      dueDate: 'Jun 20',
      status: 'upcoming',
      groupName: 'Apartment 4B',
    ),
    MockBill(
      id: 2,
      name: 'Internet',
      amount: 65,
      dueDate: 'Jun 18',
      status: 'due_today',
      groupName: 'Apartment 4B',
    ),
    MockBill(
      id: 3,
      name: 'Netflix',
      amount: 22,
      dueDate: 'Jun 25',
      status: 'upcoming',
      groupName: 'Apartment 4B',
    ),
  ];

  static const activity = <MockActivity>[
    MockActivity(
      id: 1,
      description: "Alex added 'Dinner at Nobu'",
      eventType: 'expense_added',
      timeAgo: '2h ago',
      actorName: 'Alex',
      amount: 120,
      groupName: 'Bali Trip 2026',
    ),
    MockActivity(
      id: 2,
      description: 'Sam settled \$45 with you',
      eventType: 'settlement_recorded',
      timeAgo: '5h ago',
      actorName: 'Sam',
      amount: 45,
      groupName: 'Bali Trip 2026',
    ),
    MockActivity(
      id: 3,
      description: 'Jordan joined Apartment 4B',
      eventType: 'member_joined',
      timeAgo: '1d ago',
      actorName: 'Jordan',
      groupName: 'Apartment 4B',
    ),
    MockActivity(
      id: 4,
      description: "You created bill 'Electricity April'",
      eventType: 'bill_created',
      timeAgo: '2d ago',
      actorName: 'Alex',
      amount: 150,
      groupName: 'Apartment 4B',
    ),
  ];

  static const youOwe = <MockBalanceRow>[
    MockBalanceRow(
      name: 'Sam Chen',
      groupName: 'Bali Trip 2026',
      amount: 45,
      youOwe: true,
    ),
    MockBalanceRow(
      name: 'Jordan Lee',
      groupName: 'Apartment 4B',
      amount: 40.5,
      youOwe: true,
    ),
  ];

  static const youAreOwed = <MockBalanceRow>[
    MockBalanceRow(
      name: 'Maya Patel',
      groupName: 'Bali Trip 2026',
      amount: 120,
      youOwe: false,
    ),
    MockBalanceRow(
      name: 'Chris Wong',
      groupName: 'Weekend Friends',
      amount: 18,
      youOwe: false,
    ),
  ];

  static const notifications = <Map<String, String>>[
    {
      'title': 'New expense',
      'body': 'Sam added Uber to Airport (\$60)',
      'time': '1h',
    },
    {
      'title': 'Payment request',
      'body': 'Maya requested \$30 for hotel',
      'time': '3h',
    },
    {
      'title': 'Bill reminder',
      'body': 'Internet due today',
      'time': '5h',
    },
  ];

  static const double totalYouOwe = 85.5;
  static const double totalYouAreOwed = 210;
  static const double netBalance = 124.5;
  static const double expensesThisMonth = 450;
  static const int unreadCount = 3;
}
