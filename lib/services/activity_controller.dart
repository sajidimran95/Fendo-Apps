import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/activity_model.dart';
import 'activity_api.dart';
import 'auth_controller.dart';
import 'dashboard_controller.dart';

class ActivityController extends ChangeNotifier {
  ActivityController._();

  static final ActivityController instance = ActivityController._();

  ActivityApi get _api => AuthController.instance.activityApi;

  final List<ActivityItem> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  bool _silentBusy = false;
  Timer? _liveTimer;

  List<ActivityItem> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  int get page => _page;
  bool get loading => _loading;
  bool get isLive => _liveTimer != null;

  Future<List<ActivityItem>> loadActivity({bool refresh = true}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _loading = true;
      notifyListeners();
    }

    try {
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
    } finally {
      if (refresh) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Fetch page 1 and merge new events into the top without a full-screen reload.
  Future<void> silentRefresh() async {
    if (_silentBusy) return;
    if (!AuthController.instance.isAuthenticated) return;
    _silentBusy = true;
    try {
      final list = await _api.listActivity(page: 1);
      final changed = _mergeFirstPage(list);
      if (changed) {
        DashboardController.instance.patchRecentActivity(
          _items.take(5).toList(),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Activity silent refresh failed: $e');
    } finally {
      _silentBusy = false;
    }
  }

  /// True when [list] introduced different ids/order than current top.
  bool _mergeFirstPage(List<ActivityItem> list) {
    final newIds = list.map((e) => e.id).toList();
    final oldTop = _items.take(list.length).map((e) => e.id).toList();
    if (listEquals(newIds, oldTop) && list.isNotEmpty) {
      // Same events; refresh descriptions in place if needed.
      var anyDesc = false;
      for (var i = 0; i < list.length && i < _items.length; i++) {
        if (_items[i].description != list[i].description ||
            _items[i].createdAt != list[i].createdAt) {
          anyDesc = true;
          break;
        }
      }
      if (!anyDesc) return false;
      for (var i = 0; i < list.length && i < _items.length; i++) {
        _items[i] = list[i];
      }
      return true;
    }

    final pageIds = newIds.toSet();
    final rest = _items.where((e) => !pageIds.contains(e.id)).toList();
    _items
      ..clear()
      ..addAll(list)
      ..addAll(rest);
    _page = 1;
    _hasMore = list.isNotEmpty;
    return true;
  }

  Future<List<ActivityItem>> loadMore() async {
    if (!_hasMore) return items;
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
    return _api.listGroupActivity(groupId);
  }

  /// Poll while the app is open so new events appear without pull-to-refresh.
  void startLiveUpdates({
    Duration interval = const Duration(seconds: 12),
  }) {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(interval, (_) {
      // ignore: unawaited_futures
      silentRefresh();
    });
    // ignore: unawaited_futures
    silentRefresh();
  }

  void stopLiveUpdates() {
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  void clear() {
    stopLiveUpdates();
    _items.clear();
    _page = 1;
    _hasMore = true;
    _loading = false;
    notifyListeners();
  }
}
