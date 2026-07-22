import 'package:flutter/foundation.dart';

import '../models/activity_model.dart';
import 'activity_api.dart';
import 'auth_controller.dart';

class ActivityController extends ChangeNotifier {
  ActivityController._();

  static final ActivityController instance = ActivityController._();

  ActivityApi get _api => AuthController.instance.activityApi;

  final List<ActivityItem> _items = [];
  int _page = 1;
  bool _hasMore = true;

  List<ActivityItem> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  int get page => _page;

  Future<List<ActivityItem>> loadActivity({bool refresh = true}) async {
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

  void clear() {
    _items.clear();
    _page = 1;
    _hasMore = true;
    notifyListeners();
  }
}
