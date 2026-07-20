import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/report_model.dart';

/// Reports endpoints 10.1 – 10.3.
class ReportsApi {
  ReportsApi(this._client);

  final ApiClient _client;

  /// 10.1 GET /reports/personal · ?from · ?to
  Future<PersonalReport> personalReport({String? from, String? to}) async {
    final res = await _client.get(
      '/reports/personal',
      queryParameters: {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );
    final map = unwrapMap(res.data);
    return PersonalReport.fromJson(map);
  }

  /// 10.2 GET /reports/group/{id}
  Future<GroupReport> groupReport(int groupId) async {
    final res = await _client.get('/reports/group/$groupId');
    final map = unwrapMap(res.data);
    return GroupReport.fromJson(map, fallbackId: groupId);
  }

  /// 10.3 GET /reports/export · ?format=csv|json
  Future<ReportExport> exportReport({String format = 'csv'}) async {
    final res = await _client.get(
      '/reports/export',
      queryParameters: {'format': format},
    );
    final data = res.data;
    if (data is String) {
      return ReportExport(
        format: format,
        content: data,
        filename: 'fendo-report.$format',
      );
    }
    final map = unwrapMap(data);
    final content = map['content']?.toString() ??
        map['data']?.toString() ??
        map['export']?.toString();
    if (content == null || content.isEmpty) {
      // Pretty-print JSON body as export when API returns structured data.
      if (format == 'json') {
        return ReportExport(
          format: format,
          content: data.toString(),
          filename: map['filename']?.toString() ?? 'fendo-report.json',
        );
      }
      throw ApiException(message: 'Empty export response');
    }
    return ReportExport(
      format: format,
      content: content,
      filename: map['filename']?.toString() ?? 'fendo-report.$format',
    );
  }
}
