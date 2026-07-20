import 'package:dio/dio.dart';

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
          ),
        );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readAccessToken();
          if (token != null && token.isNotEmpty) {
            final type = await _tokenStorage.readTokenType() ?? 'Bearer';
            options.headers['Authorization'] = '$type $token';
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
  }) {
    return _guard(() => _dio.post(path, data: data));
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  ApiException _mapDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    String message = e.message ?? 'Something went wrong';
    Map<String, List<String>>? errors;

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      message = (map['message'] ?? map['error'] ?? message).toString();

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
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      message = 'Connection timed out. Check your network.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'Cannot reach server. Check API URL and network.';
    }

    return ApiException(
      message: message,
      statusCode: status,
      errors: errors,
    );
  }
}

/// Supports both `{ ... }` and `{ "data": { ... } }` payloads.
Map<String, dynamic> unwrapMap(dynamic body) {
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
