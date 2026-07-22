import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../core/network/api_exception.dart';
import '../models/dashboard_model.dart';
import 'auth_controller.dart';
import 'dashboard_api.dart';

class DashboardController extends ChangeNotifier {
  DashboardController._();

  static final DashboardController instance = DashboardController._();

  DashboardApi get _api => AuthController.instance.dashboardApi;

  DashboardSummary? _summary;
  bool _loading = false;
  String? _error;

  DashboardSummary? get summary => _summary;
  bool get loading => _loading;
  String? get error => _error;

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
      } else {
        _summary = await _api.getDashboard();
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

  void clear() {
    _summary = null;
    _error = null;
    notifyListeners();
  }
}
