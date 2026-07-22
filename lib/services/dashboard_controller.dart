import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../core/network/api_exception.dart';
import '../models/dashboard_model.dart';
import 'auth_controller.dart';
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
    if (_loading) return;
    if (_summary != null && !force) return;

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
        _summary = await _api.getDashboard();
        await _loadBillsPaidThisMonth();
      }
    } on ApiException catch (e) {
      _error = e.displayMessage;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
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

  void clear() {
    _summary = null;
    _error = null;
    _billsPaidThisMonth = 0;
    notifyListeners();
  }
}
