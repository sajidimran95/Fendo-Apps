import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../core/network/api_exception.dart';
import '../models/activity_model.dart';
import '../models/dashboard_model.dart';
import 'auth_controller.dart';
import 'balances_controller.dart';
import 'bills_controller.dart';
import 'dashboard_api.dart';
import 'spending_totals.dart';

class DashboardController extends ChangeNotifier {
  DashboardController._();

  static final DashboardController instance = DashboardController._();

  DashboardApi get _api => AuthController.instance.dashboardApi;

  DashboardSummary? _summary;
  bool _loading = false;
  String? _error;
  double _billsPaidThisMonth = 0;
  int _loadGen = 0;

  DashboardSummary? get summary => _summary;
  bool get loading => _loading;
  String? get error => _error;

  /// Expenses this month from dashboard API (before bills).
  double get expensesThisMonth =>
      _summary?.quickStats.expensesThisMonth ?? 0;

  double get billsPaidThisMonth => _billsPaidThisMonth;

  /// Expenses + bill payments for the current month.
  double get spendingThisMonth => expensesThisMonth + _billsPaidThisMonth;

  Future<void> load({bool force = false}) async {
    if (_summary != null && !force && !_loading) return;

    final gen = ++_loadGen;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      if (ApiConfig.demoAuth) {
        _summary = const DashboardSummary(
          balanceSummary: DashboardBalanceSummary(
            totalYouOwe: 120,
            totalYouAreOwed: 180.5,
            netBalance: 60.5,
          ),
          quickStats: DashboardQuickStats(
            groupsCount: 3,
            expensesThisMonth: 450,
            upcomingBillsCount: 2,
          ),
        );
        _billsPaidThisMonth = 45;
      } else {
        final dash = await _api.getDashboard();
        if (gen != _loadGen) return;

        // GET /balances is the source of truth for who owes whom.
        // Dashboard alone can stay stale or return zeros after a new expense.
        var balance = dash.balanceSummary;
        try {
          final overall = await BalancesController.instance.loadBalances();
          balance = DashboardBalanceSummary(
            totalYouOwe: overall.totalYouOwe,
            totalYouAreOwed: overall.totalYouAreOwed,
            netBalance: overall.netBalance,
          );
        } catch (e) {
          debugPrint('Dashboard balances fallback failed: $e');
        }

        if (gen != _loadGen) return;
        _summary = DashboardSummary(
          balanceSummary: balance,
          quickStats: dash.quickStats,
          upcomingBills: dash.upcomingBills,
          recentActivity: dash.recentActivity,
        );
        await _loadBillsPaidThisMonth();
      }
    } on ApiException catch (e) {
      if (gen == _loadGen) _error = e.displayMessage;
    } catch (e) {
      if (gen == _loadGen) _error = e.toString();
    } finally {
      if (gen == _loadGen) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadBillsPaidThisMonth() async {
    try {
      final now = DateTime.now();
      final bills = await BillsController.instance.loadBills();
      final paid = SpendingTotals.paidInRange(
        bills,
        from: DateTime(now.year, now.month, 1),
        to: now,
      );
      _billsPaidThisMonth = SpendingTotals.sumPaid(paid);
    } catch (_) {
      _billsPaidThisMonth = 0;
    }
  }

  /// Update recent activity strip without a full dashboard reload.
  void patchRecentActivity(List<ActivityItem> activity) {
    final current = _summary;
    if (current == null) return;
    final same = current.recentActivity.length == activity.length &&
        List.generate(
          activity.length,
          (i) =>
              current.recentActivity[i].id == activity[i].id &&
              current.recentActivity[i].description == activity[i].description,
        ).every((ok) => ok);
    if (same) return;
    _summary = DashboardSummary(
      balanceSummary: current.balanceSummary,
      quickStats: current.quickStats,
      upcomingBills: current.upcomingBills,
      recentActivity: List.unmodifiable(activity),
    );
    notifyListeners();
  }

  void clear() {
    _loadGen++;
    _summary = null;
    _error = null;
    _billsPaidThisMonth = 0;
    notifyListeners();
  }
}
