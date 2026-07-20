import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../models/activity_model.dart';
import 'activity_api.dart';
import 'auth_controller.dart';

class ActivityController extends ChangeNotifier {
  ActivityController._();

  static final ActivityController instance = ActivityController._();

  ActivityApi get _api => AuthController.instance.activityApi;

  final List<ActivityItem> _items = [];
  bool _seeded = false;
  int _page = 1;
  bool _hasMore = true;

  List<ActivityItem> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  int get page => _page;

  void _seedDemoIfNeeded() {
    if (_seeded) return;
    _seeded = true;
    final now = DateTime.now();
    _items.addAll([
      ActivityItem(
        id: 1,
        eventType: 'expense_added',
        description: "Alex added 'Dinner at Nobu'",
        amount: 120,
        currency: 'USD',
        actorId: 1,
        actorName: 'Alex',
        groupId: 1,
        groupName: 'Bali Trip 2026',
        createdAt: now.subtract(const Duration(hours: 2)).toIso8601String(),
      ),
      ActivityItem(
        id: 2,
        eventType: 'settlement_recorded',
        description: 'Sam settled \$45 with you',
        amount: 45,
        currency: 'USD',
        actorId: 2,
        actorName: 'Sam',
        groupId: 1,
        groupName: 'Bali Trip 2026',
        createdAt: now.subtract(const Duration(hours: 5)).toIso8601String(),
      ),
      ActivityItem(
        id: 3,
        eventType: 'member_joined',
        description: 'Jordan joined Apartment 4B',
        actorId: 4,
        actorName: 'Jordan',
        groupId: 2,
        groupName: 'Apartment 4B',
        createdAt: now.subtract(const Duration(days: 1)).toIso8601String(),
      ),
      ActivityItem(
        id: 4,
        eventType: 'bill_created',
        description: "You created bill 'Electricity'",
        amount: 150,
        currency: 'USD',
        actorId: 1,
        actorName: 'Alex',
        groupId: 2,
        groupName: 'Apartment 4B',
        createdAt: now.subtract(const Duration(days: 2)).toIso8601String(),
      ),
      ActivityItem(
        id: 5,
        eventType: 'expense_added',
        description: "Maya added 'Groceries'",
        amount: 64.5,
        currency: 'USD',
        actorId: 3,
        actorName: 'Maya',
        groupId: 2,
        groupName: 'Apartment 4B',
        createdAt: now.subtract(const Duration(days: 3)).toIso8601String(),
      ),
      ActivityItem(
        id: 6,
        eventType: 'settlement_recorded',
        description: 'You paid Maya \$30',
        amount: 30,
        currency: 'USD',
        actorId: 1,
        actorName: 'Alex',
        groupId: 1,
        groupName: 'Bali Trip 2026',
        createdAt: now.subtract(const Duration(days: 4)).toIso8601String(),
      ),
    ]);
  }

  Future<List<ActivityItem>> loadActivity({bool refresh = true}) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      if (refresh) {
        _page = 1;
        _hasMore = false;
      }
      notifyListeners();
      return items;
    }

    if (refresh) {
      _page = 1;
      _hasMore = true;
    }

    final list = await _api.listActivity(page: _page);
    if (refresh) {
      _items
        ..clear()
        ..addAll(list);
    } else {
      _items.addAll(list);
    }
    _hasMore = list.isNotEmpty;
    notifyListeners();
    return items;
  }

  Future<List<ActivityItem>> loadMore() async {
    if (!_hasMore) return items;
    if (ApiConfig.demoAuth) {
      _hasMore = false;
      notifyListeners();
      return items;
    }
    _page += 1;
    final list = await _api.listActivity(page: _page);
    if (list.isEmpty) {
      _hasMore = false;
      _page -= 1;
    } else {
      _items.addAll(list);
    }
    notifyListeners();
    return items;
  }

  Future<List<ActivityItem>> loadGroupActivity(int groupId) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      return _items.where((a) => a.groupId == groupId).toList();
    }
    return _api.listGroupActivity(groupId);
  }
}
