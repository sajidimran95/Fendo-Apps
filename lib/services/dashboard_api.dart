import '../core/network/api_client.dart';
import '../models/dashboard_model.dart';

/// Dashboard endpoint 11.1 — GET /dashboard
class DashboardApi {
  DashboardApi(this._client);

  final ApiClient _client;

  Future<DashboardSummary> getDashboard() async {
    final res = await _client.get('/dashboard');
    return DashboardSummary.fromJson(unwrapMap(res.data));
  }
}
