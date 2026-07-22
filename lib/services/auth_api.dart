import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';

/// Auth endpoints 1.1 – 1.10 from API docs.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  /// 1.1 POST /auth/register
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
  }) async {
    final res = await _client.post(
      '/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
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

  /// 1.2 POST /auth/verify-otp
  Future<AuthResponse> verifyOtp({
    required String email,
    required String otp,
    required String purpose,
  }) async {
    final res = await _client.post(
      '/auth/verify-otp',
      data: {
        'email': email,
        'otp': otp,
        'purpose': purpose,
      },
    );
    return AuthResponse.fromJson(unwrapMap(res.data));
  }

  /// 1.3 POST /auth/resend-otp
  Future<String?> resendOtp({
    required String email,
    required String purpose,
  }) async {
    final res = await _client.post(
      '/auth/resend-otp',
      data: {
        'email': email,
        'purpose': purpose,
      },
    );
    final map = unwrapMap(res.data);
    return map['message']?.toString();
  }

  /// 1.4 POST /auth/login
  Future<AuthResponse> login({
    required String email,
    required String password,
    String? deviceName,
  }) async {
    final res = await _client.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
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

  /// 1.7 POST /auth/forgot-password
  Future<String?> forgotPassword({required String email}) async {
    final res = await _client.post(
      '/auth/forgot-password',
      data: {'email': email},
    );
    final map = unwrapMap(res.data);
    return map['message']?.toString();
  }

  /// 1.8 POST /auth/reset-password
  Future<String?> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    final res = await _client.post(
      '/auth/reset-password',
      data: {
        'email': email,
        'otp': otp,
        'password': password,
        'password_confirmation': passwordConfirmation,
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
