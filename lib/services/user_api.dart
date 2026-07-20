import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/notification_settings.dart';
import '../models/user_model.dart';
import '../models/user_session.dart';

/// Profile endpoints 2.1 – 2.10 from API docs.
class UserApi {
  UserApi(this._client);

  final ApiClient _client;

  UserModel _parseUser(dynamic body) {
    final map = unwrapMap(body);
    final user = map['user'] ?? map['profile'] ?? map;
    if (user is! Map) {
      throw ApiException(message: 'Invalid profile response');
    }
    return UserModel.fromJson(Map<String, dynamic>.from(user));
  }

  /// 2.1 GET /user/profile
  Future<UserModel> getProfile() async {
    final res = await _client.get('/user/profile');
    return _parseUser(res.data);
  }

  /// 2.2 PUT /user/profile
  Future<UserModel> updateProfile({
    String? name,
    String? phone,
    String? timezone,
    String? currency,
    String? language,
    String? venmoHandle,
    String? paypalEmail,
    String? cashappTag,
  }) async {
    final res = await _client.put(
      '/user/profile',
      data: {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (timezone != null) 'timezone': timezone,
        if (currency != null) 'currency': currency,
        if (language != null) 'language': language,
        if (venmoHandle != null) 'venmo_handle': venmoHandle,
        if (paypalEmail != null) 'paypal_email': paypalEmail,
        if (cashappTag != null) 'cashapp_tag': cashappTag,
      },
    );
    return _parseUser(res.data);
  }

  /// 2.3 POST /user/avatar — multipart field `avatar`
  Future<UserModel> uploadAvatar({
    required String filePath,
    required String fileName,
  }) async {
    final form = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final res = await _client.postMultipart('/user/avatar', data: form);
    return _parseUser(res.data);
  }

  /// 2.4 PUT /user/password
  Future<String?> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    final res = await _client.put(
      '/user/password',
      data: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    final map = unwrapMap(res.data);
    return map['message']?.toString();
  }

  /// 2.5 PUT /user/fcm-token
  Future<void> updateFcmToken(String fcmToken) async {
    await _client.put(
      '/user/fcm-token',
      data: {'fcm_token': fcmToken},
    );
  }

  /// 2.6 GET /user/sessions
  Future<List<UserSession>> getSessions() async {
    final res = await _client.get('/user/sessions');
    return unwrapList(res.data, key: 'sessions')
        .map(UserSession.fromJson)
        .toList();
  }

  /// 2.7 DELETE /user/sessions/{id}
  Future<void> revokeSession(String id) async {
    await _client.delete('/user/sessions/$id');
  }

  /// 2.8 GET /user/notification-settings
  Future<NotificationSettings> getNotificationSettings() async {
    final res = await _client.get('/user/notification-settings');
    final map = unwrapMap(res.data);
    final settings = map['settings'] ?? map['notification_settings'] ?? map;
    if (settings is! Map) {
      throw ApiException(message: 'Invalid notification settings response');
    }
    return NotificationSettings.fromJson(Map<String, dynamic>.from(settings));
  }

  /// 2.9 PUT /user/notification-settings
  Future<NotificationSettings> updateNotificationSettings(
    NotificationSettings settings,
  ) async {
    final res = await _client.put(
      '/user/notification-settings',
      data: settings.toJson(),
    );
    final map = unwrapMap(res.data);
    final body = map['settings'] ?? map['notification_settings'] ?? map;
    if (body is Map) {
      return NotificationSettings.fromJson(Map<String, dynamic>.from(body));
    }
    return settings;
  }

  /// 2.10 DELETE /user/account
  Future<void> deleteAccount({
    required String confirmation,
    required String password,
  }) async {
    await _client.delete(
      '/user/account',
      data: {
        'confirmation': confirmation,
        'password': password,
      },
    );
  }
}
