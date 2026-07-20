import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/bill_model.dart';

/// Bills endpoints 6.1 – 6.5.
class BillsApi {
  BillsApi(this._client);

  final ApiClient _client;

  BillModel _parseBill(dynamic body) {
    final map = unwrapMap(body);
    final bill = map['bill'] ?? map;
    if (bill is! Map) {
      throw ApiException(message: 'Invalid bill response');
    }
    return BillModel.fromJson(Map<String, dynamic>.from(bill));
  }

  /// 6.1 GET /bills · ?status
  Future<List<BillModel>> listBills({String? status}) async {
    final res = await _client.get(
      '/bills',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return unwrapList(res.data, key: 'bills').map(BillModel.fromJson).toList();
  }

  /// 6.2 POST /bills
  Future<BillModel> createBill({
    required String name,
    required double amount,
    required String dueDate,
    required int groupId,
    String? notes,
    List<int> reminderDays = const [],
    List<BillSplit> splits = const [],
    String billType = 'one_time',
    String? frequency,
    String? recurrenceEndDate,
  }) async {
    final res = await _client.post(
      '/bills',
      data: {
        'name': name,
        'amount': amount,
        'due_date': dueDate,
        'group_id': groupId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'reminder_days': reminderDays,
        'splits': splits.map((e) => e.toJson()).toList(),
        if (billType == 'recurring') 'bill_type': 'recurring',
        if (billType == 'recurring' && frequency != null) 'frequency': frequency,
        if (billType == 'recurring' &&
            recurrenceEndDate != null &&
            recurrenceEndDate.isNotEmpty)
          'recurrence_end_date': recurrenceEndDate,
      },
    );
    return _parseBill(res.data);
  }

  /// 6.3 GET /bills/{id}
  Future<BillModel> getBill(int id) async {
    final res = await _client.get('/bills/$id');
    return _parseBill(res.data);
  }

  /// 6.3 PUT /bills/{id}
  Future<BillModel> updateBill(
    int id, {
    String? name,
    double? amount,
    String? dueDate,
    String? notes,
    List<int>? reminderDays,
    List<BillSplit>? splits,
    String? billType,
    String? frequency,
    String? recurrenceEndDate,
  }) async {
    final res = await _client.put(
      '/bills/$id',
      data: {
        if (name != null) 'name': name,
        if (amount != null) 'amount': amount,
        if (dueDate != null) 'due_date': dueDate,
        if (notes != null) 'notes': notes,
        if (reminderDays != null) 'reminder_days': reminderDays,
        if (splits != null) 'splits': splits.map((e) => e.toJson()).toList(),
        if (billType != null) 'bill_type': billType,
        if (frequency != null) 'frequency': frequency,
        if (recurrenceEndDate != null)
          'recurrence_end_date': recurrenceEndDate,
      },
    );
    return _parseBill(res.data);
  }

  /// 6.3 DELETE /bills/{id}
  Future<void> deleteBill(int id) async {
    await _client.delete('/bills/$id');
  }

  /// 6.4 POST /bills/{id}/pay
  Future<BillModel> payBill(int id, {String? paymentMethod}) async {
    final res = await _client.post(
      '/bills/$id/pay',
      data: {
        if (paymentMethod != null && paymentMethod.isNotEmpty)
          'payment_method': paymentMethod,
      },
    );
    return _parseBill(res.data);
  }

  /// 6.5 POST /bills/{id}/partial-pay
  Future<BillModel> partialPayBill(
    int id, {
    required double amount,
    String? paymentMethod,
  }) async {
    final res = await _client.post(
      '/bills/$id/partial-pay',
      data: {
        'amount': amount,
        if (paymentMethod != null && paymentMethod.isNotEmpty)
          'payment_method': paymentMethod,
      },
    );
    return _parseBill(res.data);
  }
}
