import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/activity_model.dart';

/// Activity endpoints 8.1 – 8.2.
class ActivityApi {
  ActivityApi(this._client);

  final ApiClient _client;

  List<ActivityItem> _parseActivityList(dynamic body) {
    final rows = unwrapList(body, key: 'activity');
    final out = <ActivityItem>[];
    for (final row in rows) {
      try {
        out.add(ActivityItem.fromJson(row));
      } catch (e) {
        debugPrint('Activity parse skip: $e');
      }
    }
    return out;
  }

  /// 8.1 GET /activity · ?page
  Future<List<ActivityItem>> listActivity({int page = 1}) async {
    final res = await _client.get(
      '/activity',
      queryParameters: {'page': page},
    );
    return _parseActivityList(res.data);
  }

  /// 8.2 GET /groups/{id}/activity
  Future<List<ActivityItem>> listGroupActivity(int groupId) async {
    final res = await _client.get('/groups/$groupId/activity');
    return _parseActivityList(res.data);
  }
}
