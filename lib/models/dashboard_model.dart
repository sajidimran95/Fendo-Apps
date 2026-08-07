import 'activity_model.dart';
import 'bill_model.dart';

class DashboardBalanceSummary {
  const DashboardBalanceSummary({
    required this.totalYouOwe,
    required this.totalYouAreOwed,
    required this.netBalance,
  });

  final double totalYouOwe;
  final double totalYouAreOwed;
  final double netBalance;

  factory DashboardBalanceSummary.fromJson(Map<String, dynamic> json) {
    return DashboardBalanceSummary(
      totalYouOwe: _asDouble(json['total_you_owe']),
      totalYouAreOwed: _asDouble(json['total_you_are_owed']),
      netBalance: _asDouble(json['net_balance']),
    );
  }

  static double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class DashboardQuickStats {
  const DashboardQuickStats({
    required this.groupsCount,
    required this.expensesThisMonth,
    required this.upcomingBillsCount,
  });

  final int groupsCount;
  final double expensesThisMonth;
  final int upcomingBillsCount;

  factory DashboardQuickStats.fromJson(Map<String, dynamic> json) {
    return DashboardQuickStats(
      groupsCount: _asInt(json['groups_count']),
      expensesThisMonth: DashboardBalanceSummary._asDouble(
        json['expenses_this_month'],
      ),
      upcomingBillsCount: _asInt(json['upcoming_bills_count']),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.balanceSummary,
    required this.quickStats,
    this.upcomingBills = const [],
    this.recentActivity = const [],
  });

  final DashboardBalanceSummary balanceSummary;
  final DashboardQuickStats quickStats;
  final List<BillModel> upcomingBills;
  final List<ActivityItem> recentActivity;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    // Prefer nested objects; also accept flat keys used by some backends.
    Map<String, dynamic>? asMap(dynamic v) {
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    final balance = asMap(json['balance_summary']) ??
        asMap(json['balances']) ??
        (json.containsKey('total_you_owe') ||
                json.containsKey('total_you_are_owed') ||
                json.containsKey('net_balance')
            ? json
            : null);
    final stats = asMap(json['quick_stats']) ??
        asMap(json['stats']) ??
        (json.containsKey('groups_count') ||
                json.containsKey('expenses_this_month')
            ? json
            : null);
    final bills = json['upcoming_bills'] ?? json['bills'];
    final activity = json['recent_activity'] ?? json['activity'];

    return DashboardSummary(
      balanceSummary: balance != null
          ? DashboardBalanceSummary.fromJson(balance)
          : const DashboardBalanceSummary(
              totalYouOwe: 0,
              totalYouAreOwed: 0,
              netBalance: 0,
            ),
      quickStats: stats != null
          ? DashboardQuickStats.fromJson(stats)
          : const DashboardQuickStats(
              groupsCount: 0,
              expensesThisMonth: 0,
              upcomingBillsCount: 0,
            ),
      upcomingBills: bills is List
          ? bills
              .whereType<Map>()
              .map((e) => BillModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      recentActivity: activity is List
          ? activity
              .whereType<Map>()
              .map((e) => ActivityItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}
