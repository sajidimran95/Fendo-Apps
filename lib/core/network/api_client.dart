import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

typedef OnUnauthorized = Future<void> Function();

class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    OnUnauthorized? onUnauthorized,
    Dio? dio,
  })  : _tokenStorage = tokenStorage,
        _onUnauthorized = onUnauthorized {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: ApiConfig.connectTimeout,
            receiveTimeout: ApiConfig.receiveTimeout,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            // Let us convert 4xx into ApiException with server messages.
            validateStatus: (status) => status != null && status < 500,
          ),
        );

    // Shared-host SSL often misses intermediate certs; Android/Dart then
    // fails with CERTIFICATE_VERIFY_FAILED while browsers still work.
    // Allow only our configured API host until the server chain is fixed.
    if (!kIsWeb) {
      final apiHost = Uri.tryParse(ApiConfig.baseUrl)?.host;
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) {
            return apiHost != null && host == apiHost;
          };
          return client;
        },
      );
    }

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
          logPrint: (obj) => debugPrint(obj.toString()),
        ),
      );
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await _tokenStorage.readAccessToken();
            if (token != null && token.isNotEmpty) {
              final type = await _tokenStorage.readTokenType() ?? 'Bearer';
              options.headers['Authorization'] = '$type $token';
            }
          } catch (e) {
            debugPrint('Token read failed: $e');
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final cb = _onUnauthorized;
          if (error.response?.statusCode == 401 && cb != null) {
            await cb();
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final TokenStorage _tokenStorage;
  final OnUnauthorized? _onUnauthorized;

  Dio get dio => _dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _guard(() => _dio.get(path, queryParameters: queryParameters));
  }

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Options? options,
  }) {
    return _guard(() => _dio.post(path, data: data, options: options));
  }

  Future<Response<dynamic>> put(
    String path, {
    Object? data,
  }) {
    return _guard(() => _dio.put(path, data: data));
  }

  Future<Response<dynamic>> delete(
    String path, {
    Object? data,
  }) {
    return _guard(() => _dio.delete(path, data: data));
  }

  Future<Response<dynamic>> postMultipart(
    String path, {
    required FormData data,
  }) {
    return _guard(
      () => _dio.post(
        path,
        data: data,
        options: Options(contentType: 'multipart/form-data'),
      ),
    );
  }

  Future<Response<dynamic>> _guard(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final res = await request();
      final code = res.statusCode ?? 0;
      if (code >= 400) {
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
          message: 'HTTP $code',
        );
      }
      return res;
    } on DioException catch (e) {
      throw _mapDio(e);
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  ApiException _mapDio(DioException e) {
    final status = e.response?.statusCode;
    var data = e.response?.data;

    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          data = jsonDecode(trimmed);
        } catch (_) {
          // keep raw string
        }
      }
    }

    String message = 'Something went wrong';
    Map<String, List<String>>? errors;

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final rawMessage = map['message'] ?? map['error'];
      if (rawMessage != null && rawMessage.toString().trim().isNotEmpty) {
        message = rawMessage.toString();
      }

      final rawErrors = map['errors'];
      if (rawErrors is Map) {
        errors = rawErrors.map((key, value) {
          if (value is List) {
            return MapEntry(
              key.toString(),
              value.map((e) => e.toString()).toList(),
            );
          }
          return MapEntry(key.toString(), [value.toString()]);
        });
      }
    } else if (data is String && data.trim().isNotEmpty) {
      final trimmed = data.trim();
      message = trimmed.length > 180 ? '${trimmed.substring(0, 180)}…' : trimmed;
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      message = 'Connection timed out. Check your network.';
    } else if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.badCertificate ||
        e.error is HandshakeException ||
        (e.error?.toString().contains('CERTIFICATE_VERIFY_FAILED') ?? false) ||
        (e.message?.contains('CERTIFICATE_VERIFY_FAILED') ?? false)) {
      message =
          'Secure connection failed. Check API SSL certificate on server.';
    } else if (e.error != null) {
      message = e.error.toString();
    } else if (e.message != null && e.message!.trim().isNotEmpty) {
      message = e.message!;
    }

    message = _humanizeServerMessage(message);

    if (kDebugMode) {
      debugPrint(
        'API error status=$status type=${e.type} message=$message data=$data',
      );
    }

    return ApiException(
      message: message,
      statusCode: status,
      errors: errors,
    );
  }

  /// Soften Laravel stack-trace style messages for the UI.
  static String _humanizeServerMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('no query results') ||
        lower.contains('model not found') ||
        RegExp(r'app[/\\]models', caseSensitive: false).hasMatch(message)) {
      return 'That record was not found. Refresh and try again.';
    }
    if (lower.contains('query expression') ||
        lower.contains('could not be converted to string')) {
      return 'Server error while finishing the request. Please refresh.';
    }
    return message;
  }
}

/// Supports both `{ ... }` and `{ "data": { ... } }` payloads.
Map<String, dynamic> unwrapMap(dynamic body) {
  if (body is String) {
    final trimmed = body.trim();
    if (trimmed.startsWith('{')) {
      body = jsonDecode(trimmed);
    }
  }
  if (body is! Map) {
    throw ApiException(message: 'Invalid server response');
  }
  final map = Map<String, dynamic>.from(body);
  final data = map['data'];
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return map;
}

/// Supports list payloads at root, under `data`, named keys, or Laravel
/// pagination (`data: { data: [...], current_page, ... }`).
List<Map<String, dynamic>> unwrapList(
  dynamic body, {
  String? key,
}) {
  if (body is String) {
    final trimmed = body.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      body = jsonDecode(trimmed);
    }
  }

  List<dynamic>? list;
  if (body is List) {
    list = body;
  } else if (body is Map) {
    final map = Map<String, dynamic>.from(body);
    final data = map['data'];

    if (data is List) {
      list = data;
    } else if (data is Map) {
      final inner = Map<String, dynamic>.from(data);
      // Laravel paginator: { data: [...], current_page, ... }
      if (inner['data'] is List) {
        list = inner['data'] as List;
      } else if (key != null && inner[key] is List) {
        list = inner[key] as List;
      }
    }

    if (list == null && key != null && map[key] is List) {
      list = map[key] as List;
    }
  }

  // Empty / unexpected shape → empty list (new accounts have no rows yet).
  if (list == null) {
    if (body is Map) {
      final data = body['data'];
      if (data == null ||
          (data is Map && data.isEmpty) ||
          (data is Map && data['data'] == null)) {
        return const [];
      }
    }
    throw ApiException(message: 'Invalid list response');
  }

  return list
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}
