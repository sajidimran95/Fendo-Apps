import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/settlement_model.dart';

/// Settlements endpoints 7.1 – 7.7 + deep link.
class SettlementsApi {
  SettlementsApi(this._client);

  final ApiClient _client;

  SettlementModel _parseSettlement(dynamic body) {
    final map = unwrapMap(body);
    final item = map['settlement'] ?? map;
    if (item is! Map) {
      throw ApiException(message: 'Invalid settlement response');
    }
    return SettlementModel.fromJson(Map<String, dynamic>.from(item));
  }

  SettlementRequest _parseRequest(dynamic body) {
    final map = unwrapMap(body);
    final item = map['request'] ?? map['settlement_request'] ?? map;
    if (item is! Map) {
      throw ApiException(message: 'Invalid payment request response');
    }
    return SettlementRequest.fromJson(Map<String, dynamic>.from(item));
  }

  /// 7.1 GET /settlements
  Future<List<SettlementModel>> listSettlements() async {
    final res = await _client.get('/settlements');
    return unwrapList(res.data, key: 'settlements')
        .map(SettlementModel.fromJson)
        .toList();
  }

  /// 7.2 POST /settlements
  Future<SettlementModel> createSettlement({
    required int payeeId,
    required int groupId,
    required double amount,
    String currency = 'USD',
    required String paymentMethod,
    String? paymentReference,
    String? notes,
    String? settlementDate,
  }) async {
    final res = await _client.post(
      '/settlements',
      data: {
        'payee_id': payeeId,
        'group_id': groupId,
        'amount': amount,
        'currency': currency,
        'payment_method': paymentMethod,
        if (paymentReference != null && paymentReference.isNotEmpty)
          'payment_reference': paymentReference,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (settlementDate != null && settlementDate.isNotEmpty)
          'settlement_date': settlementDate,
      },
    );
    return _parseSettlement(res.data);
  }

  /// 7.3 GET /settlements/{id}
  Future<SettlementModel> getSettlement(int id) async {
    final res = await _client.get('/settlements/$id');
    return _parseSettlement(res.data);
  }

  /// 7.4 GET /settlements/requests
  Future<List<SettlementRequest>> listRequests() async {
    final res = await _client.get('/settlements/requests');
    return unwrapList(res.data, key: 'requests')
        .map(SettlementRequest.fromJson)
        .toList();
  }

  /// 7.5 POST /settlements/requests
  Future<SettlementRequest> createRequest({
    required int debtorId,
    required int groupId,
    required double amount,
    String currency = 'USD',
    String? message,
  }) async {
    final res = await _client.post(
      '/settlements/requests',
      data: {
        'debtor_id': debtorId,
        'group_id': groupId,
        'amount': amount,
        'currency': currency,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
    return _parseRequest(res.data);
  }

  /// 7.6 PUT /settlements/requests/{id}/accept
  Future<SettlementRequest> acceptRequest(
    int id, {
    String? paymentMethod,
    String? paymentReference,
  }) async {
    final res = await _client.put(
      '/settlements/requests/$id/accept',
      data: {
        if (paymentMethod != null && paymentMethod.isNotEmpty)
          'payment_method': paymentMethod,
        if (paymentReference != null && paymentReference.isNotEmpty)
          'payment_reference': paymentReference,
      },
    );
    return _parseRequest(res.data);
  }

  /// 7.7 PUT /settlements/requests/{id}/decline
  Future<SettlementRequest> declineRequest(int id) async {
    final res = await _client.put('/settlements/requests/$id/decline');
    return _parseRequest(res.data);
  }

  /// Deep link: GET /settlements/deeplink?payee_id&amount&note
  Future<SettlementDeepLink> getDeepLink({
    required int payeeId,
    required double amount,
    String? note,
  }) async {
    final res = await _client.get(
      '/settlements/deeplink',
      queryParameters: {
        'payee_id': payeeId,
        'amount': amount,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    final map = unwrapMap(res.data);
    return SettlementDeepLink.fromJson(map);
  }
}
