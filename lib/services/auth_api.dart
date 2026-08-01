import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';

/// Auth endpoints — phone channel (Firebase SMS OTP) per API v1.0.4+.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  static const channelPhone = 'phone';

  /// 1.1 POST /auth/register (phone; email optional)
  Future<Map<String, dynamic>> register({
    required String name,
    required String password,
    required String passwordConfirmation,
    required String phone,
    String? email,
    String channel = channelPhone,
  }) async {
    final res = await _client.post(
      '/auth/register',
      data: {
        'name': name,
        'phone': phone,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'channel': channel,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    try {
      return unwrapMap(res.data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        message: 'Could not parse register response: $e',
        statusCode: res.statusCode,
      );
    }
  }

  /// 1.2 POST /auth/verify-otp (phone)
  Future<AuthResponse> verifyOtp({
    required String phone,
    required String otp,
    required String purpose,
    String channel = channelPhone,
  }) async {
    final res = await _client.post(
      '/auth/verify-otp',
      data: {
        'phone': phone,
        'otp': otp,
        'purpose': purpose,
        'channel': channel,
      },
    );
    return AuthResponse.fromJson(unwrapMap(res.data));
  }

  /// 1.3 POST /auth/resend-otp (phone) — returns map with `otp` for Firebase SMS.
  Future<Map<String, dynamic>> resendOtp({
    required String phone,
    required String purpose,
    String channel = channelPhone,
  }) async {
    final res = await _client.post(
      '/auth/resend-otp',
      data: {
        'phone': phone,
        'purpose': purpose,
        'channel': channel,
      },
    );
    return unwrapMap(res.data);
  }

  /// 1.4 POST /auth/login (phone)
  Future<AuthResponse> login({
    required String phone,
    required String password,
    String? deviceName,
    String channel = channelPhone,
  }) async {
    final res = await _client.post(
      '/auth/login',
      data: {
        'phone': phone,
        'password': password,
        'channel': channel,
        if (deviceName != null && deviceName.isNotEmpty)
          'device_name': deviceName,
      },
    );
    return AuthResponse.fromJson(unwrapMap(res.data));
  }

  /// 1.5 POST /auth/logout (auth)
  Future<void> logout() async {
    await _client.post('/auth/logout');
  }

  /// 1.6 GET /auth/me (auth)
  Future<UserModel> me() async {
    final res = await _client.get('/auth/me');
    final map = unwrapMap(res.data);
    final user = map['user'] ?? map;
    if (user is! Map) {
      throw ApiException(message: 'Invalid /auth/me response');
    }
    return UserModel.fromJson(Map<String, dynamic>.from(user));
  }

  /// 1.7 POST /auth/forgot-password (phone)
  Future<Map<String, dynamic>> forgotPassword({
    required String phone,
    String channel = channelPhone,
  }) async {
    final res = await _client.post(
      '/auth/forgot-password',
      data: {
        'phone': phone,
        'channel': channel,
      },
    );
    return unwrapMap(res.data);
  }

  /// 1.8 POST /auth/reset-password (phone)
  Future<String?> resetPassword({
    required String phone,
    required String otp,
    required String password,
    required String passwordConfirmation,
    String channel = channelPhone,
  }) async {
    final res = await _client.post(
      '/auth/reset-password',
      data: {
        'phone': phone,
        'otp': otp,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'channel': channel,
      },
    );
    final map = unwrapMap(res.data);
    return map['message']?.toString();
  }

  /// 1.9 POST /auth/social-login
  Future<AuthResponse> socialLogin({
    required String provider,
    required String providerId,
    required String email,
    required String name,
    String? avatar,
    String? deviceName,
  }) async {
    final res = await _client.post(
      '/auth/social-login',
      data: {
        'provider': provider,
        'provider_id': providerId,
        'email': email,
        'name': name,
        if (avatar != null) 'avatar': avatar,
        if (deviceName != null && deviceName.isNotEmpty)
          'device_name': deviceName,
      },
    );
    return AuthResponse.fromJson(unwrapMap(res.data));
  }

  /// 1.10 POST /auth/refresh (auth)
  Future<String> refreshToken() async {
    final res = await _client.post('/auth/refresh');
    final map = unwrapMap(res.data);
    final token = map['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException(message: 'Refresh response missing access_token');
    }
    return token;
  }
}
