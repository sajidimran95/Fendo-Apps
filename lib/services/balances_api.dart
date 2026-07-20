import '../core/network/api_client.dart';
import '../models/balances_model.dart';

/// Balances endpoints 5.1 – 5.2.
class BalancesApi {
  BalancesApi(this._client);

  final ApiClient _client;

  /// 5.1 GET /balances
  Future<OverallBalances> getBalances() async {
    final res = await _client.get('/balances');
    return OverallBalances.fromJson(unwrapMap(res.data));
  }

  /// 5.2 GET /balances/breakdown
  Future<BalanceBreakdown> getBreakdown() async {
    final res = await _client.get('/balances/breakdown');
    final body = res.data;
    if (body is List) {
      return BalanceBreakdown.fromJson({'people': body});
    }
    return BalanceBreakdown.fromJson(unwrapMap(body));
  }
}
