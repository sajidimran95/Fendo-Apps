import '../core/network/api_client.dart';
import '../models/activity_model.dart';

/// Activity endpoints 8.1 – 8.2.
class ActivityApi {
  ActivityApi(this._client);

  final ApiClient _client;

  /// 8.1 GET /activity · ?page
  Future<List<ActivityItem>> listActivity({int page = 1}) async {
    final res = await _client.get(
      '/activity',
      queryParameters: {'page': page},
    );
    return unwrapList(res.data, key: 'activity')
        .map(ActivityItem.fromJson)
        .toList();
  }

  /// 8.2 GET /groups/{id}/activity
  Future<List<ActivityItem>> listGroupActivity(int groupId) async {
    final res = await _client.get('/groups/$groupId/activity');
    return unwrapList(res.data, key: 'activity')
        .map(ActivityItem.fromJson)
        .toList();
  }
}
