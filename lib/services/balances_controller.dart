import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../models/balances_model.dart';
import 'auth_controller.dart';
import 'balances_api.dart';

class BalancesController extends ChangeNotifier {
  BalancesController._();

  static final BalancesController instance = BalancesController._();

  BalancesApi get _api => AuthController.instance.balancesApi;

  OverallBalances? _overall;
  BalanceBreakdown? _breakdown;

  OverallBalances? get overall => _overall;
  BalanceBreakdown? get breakdown => _breakdown;

  Future<OverallBalances> loadBalances() async {
    if (ApiConfig.demoAuth) {
      _overall = const OverallBalances(
        totalYouOwe: 120,
        totalYouAreOwed: 180.5,
        netBalance: 60.5,
        youOwe: [
          BalanceEntry(
            name: 'Sam',
            amount: 45,
            groupName: 'Apartment 4B',
            userId: 2,
          ),
          BalanceEntry(
            name: 'Maya',
            amount: 75,
            groupName: 'Bali Trip',
            userId: 3,
          ),
        ],
        youAreOwed: [
          BalanceEntry(
            name: 'Jordan',
            amount: 100.5,
            groupName: 'Weekend Crew',
            userId: 4,
          ),
          BalanceEntry(
            name: 'Sam',
            amount: 80,
            groupName: 'Bali Trip',
            userId: 2,
          ),
        ],
      );
      notifyListeners();
      return _overall!;
    }
    _overall = await _api.getBalances();
    notifyListeners();
    return _overall!;
  }

  Future<BalanceBreakdown> loadBreakdown() async {
    if (ApiConfig.demoAuth) {
      _breakdown = const BalanceBreakdown(
        people: [
          BalanceBreakdownPerson(
            userId: 2,
            name: 'Sam',
            netBalance: 35,
            youOwe: 45,
            youAreOwed: 80,
            groups: [
              BalanceEntry(
                name: 'Sam',
                amount: -45,
                groupName: 'Apartment 4B',
              ),
              BalanceEntry(
                name: 'Sam',
                amount: 80,
                groupName: 'Bali Trip',
              ),
            ],
          ),
          BalanceBreakdownPerson(
            userId: 3,
            name: 'Maya',
            netBalance: -75,
            youOwe: 75,
            youAreOwed: 0,
            groups: [
              BalanceEntry(
                name: 'Maya',
                amount: -75,
                groupName: 'Bali Trip',
              ),
            ],
          ),
          BalanceBreakdownPerson(
            userId: 4,
            name: 'Jordan',
            netBalance: 100.5,
            youOwe: 0,
            youAreOwed: 100.5,
            groups: [
              BalanceEntry(
                name: 'Jordan',
                amount: 100.5,
                groupName: 'Weekend Crew',
              ),
            ],
          ),
        ],
      );
      notifyListeners();
      return _breakdown!;
    }
    _breakdown = await _api.getBreakdown();
    notifyListeners();
    return _breakdown!;
  }
}
