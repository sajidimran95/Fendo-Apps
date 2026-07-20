import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../models/notification_model.dart';
import 'auth_controller.dart';
import 'notifications_api.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController._();

  static final NotificationsController instance = NotificationsController._();

  NotificationsApi get _api => AuthController.instance.notificationsApi;

  final List<AppNotification> _items = [];
  int _unreadCount = 0;
  bool _seeded = false;

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _unreadCount;

  void _seedDemoIfNeeded() {
    if (_seeded) return;
    _seeded = true;
    final now = DateTime.now();
    _items.addAll([
      AppNotification(
        id: 1,
        title: 'New expense',
        body: 'Sam added Uber to Airport (\$60)',
        type: 'expense',
        read: false,
        createdAt: now.subtract(const Duration(hours: 1)).toIso8601String(),
      ),
      AppNotification(
        id: 2,
        title: 'Payment request',
        body: 'Maya requested \$30 for hotel',
        type: 'settlement_request',
        read: false,
        createdAt: now.subtract(const Duration(hours: 3)).toIso8601String(),
      ),
      AppNotification(
        id: 3,
        title: 'Bill reminder',
        body: 'Internet due today',
        type: 'bill',
        read: false,
        createdAt: now.subtract(const Duration(hours: 5)).toIso8601String(),
      ),
      AppNotification(
        id: 4,
        title: 'Settlement recorded',
        body: 'You paid Sam \$45',
        type: 'settlement',
        read: true,
        createdAt: now.subtract(const Duration(days: 1)).toIso8601String(),
      ),
    ]);
    _unreadCount = _items.where((n) => !n.read).length;
  }

  void _syncUnreadFromList() {
    _unreadCount = _items.where((n) => !n.read).length;
  }

  Future<List<AppNotification>> loadNotifications() async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      _syncUnreadFromList();
      notifyListeners();
      return items;
    }
    final list = await _api.listNotifications();
    _items
      ..clear()
      ..addAll(list);
    _syncUnreadFromList();
    notifyListeners();
    return items;
  }

  Future<int> loadUnreadCount() async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      _syncUnreadFromList();
      notifyListeners();
      return _unreadCount;
    }
    _unreadCount = await _api.unreadCount();
    notifyListeners();
    return _unreadCount;
  }

  Future<AppNotification> markRead(int id) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      final i = _items.indexWhere((n) => n.id == id);
      if (i < 0) return AppNotification(id: id, title: '', body: '', read: true);
      final updated = _items[i].copyWith(read: true);
      _items[i] = updated;
      _syncUnreadFromList();
      notifyListeners();
      return updated;
    }
    final updated = await _api.markRead(id);
    final i = _items.indexWhere((n) => n.id == id);
    if (i >= 0) {
      _items[i] = updated.id == id && updated.title.isNotEmpty
          ? updated
          : _items[i].copyWith(read: true);
    }
    await loadUnreadCount();
    notifyListeners();
    return updated;
  }

  Future<void> markAllRead() async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      for (var i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(read: true);
      }
      _unreadCount = 0;
      notifyListeners();
      return;
    }
    await _api.markAllRead();
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(read: true);
    }
    _unreadCount = 0;
    notifyListeners();
  }
}
