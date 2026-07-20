import '../core/network/api_client.dart';
import '../models/notification_model.dart';

/// Notifications endpoints 9.1 – 9.4.
class NotificationsApi {
  NotificationsApi(this._client);

  final ApiClient _client;

  /// 9.1 GET /notifications
  Future<List<AppNotification>> listNotifications() async {
    final res = await _client.get('/notifications');
    return unwrapList(res.data, key: 'notifications')
        .map(AppNotification.fromJson)
        .toList();
  }

  /// 9.2 PUT /notifications/{id}/read
  Future<AppNotification> markRead(int id) async {
    final res = await _client.put('/notifications/$id/read');
    final map = unwrapMap(res.data);
    final item = map['notification'] ?? map;
    if (item is! Map) {
      return AppNotification(
        id: id,
        title: '',
        body: '',
        read: true,
      );
    }
    return AppNotification.fromJson(Map<String, dynamic>.from(item));
  }

  /// 9.3 POST /notifications/read-all
  Future<void> markAllRead() async {
    await _client.post('/notifications/read-all');
  }

  /// 9.4 GET /notifications/unread-count → count
  Future<int> unreadCount() async {
    final res = await _client.get('/notifications/unread-count');
    final map = unwrapMap(res.data);
    final count = map['count'] ?? map['unread_count'] ?? map['unread'];
    if (count is int) return count;
    return int.tryParse(count?.toString() ?? '') ?? 0;
  }
}
