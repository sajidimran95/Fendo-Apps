import 'user_model.dart';

class AuthResponse {
  const AuthResponse({
    required this.user,
    required this.accessToken,
    this.tokenType = 'Bearer',
    this.isNewUser,
  });

  final UserModel user;
  final String accessToken;
  final String tokenType;
  final bool? isNewUser;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    if (userJson is! Map) {
      throw FormatException('Auth response missing user');
    }
    final token = json['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw FormatException('Auth response missing access_token');
    }

    return AuthResponse(
      user: UserModel.fromJson(Map<String, dynamic>.from(userJson)),
      accessToken: token,
      tokenType: (json['token_type'] ?? 'Bearer').toString(),
      isNewUser: json['is_new_user'] is bool ? json['is_new_user'] as bool : null,
    );
  }
}
