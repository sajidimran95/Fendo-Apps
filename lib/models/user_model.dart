import '../utils/media_url.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    this.currency = 'USD',
    this.timezone,
    this.language,
    this.venmoHandle,
    this.paypalEmail,
    this.cashappTag,
    this.notificationSettings,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final String currency;
  final String? timezone;
  final String? language;
  final String? venmoHandle;
  final String? paypalEmail;
  final String? cashappTag;
  final Map<String, dynamic>? notificationSettings;

  /// Absolute URL for [avatar], or null.
  String? get avatarUrl => resolveMediaUrl(avatar);

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: json['phone']?.toString(),
      avatar: (json['avatar'] ?? json['avatar_url'] ?? json['photo'])
          ?.toString(),
      currency: (json['currency'] ?? 'USD').toString(),
      timezone: json['timezone']?.toString(),
      language: json['language']?.toString(),
      venmoHandle: json['venmo_handle']?.toString(),
      paypalEmail: json['paypal_email']?.toString(),
      cashappTag: json['cashapp_tag']?.toString(),
      notificationSettings: json['notification_settings'] is Map
          ? Map<String, dynamic>.from(json['notification_settings'] as Map)
          : null,
    );
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? avatar,
    String? currency,
    String? timezone,
    String? language,
    String? venmoHandle,
    String? paypalEmail,
    String? cashappTag,
    Map<String, dynamic>? notificationSettings,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      currency: currency ?? this.currency,
      timezone: timezone ?? this.timezone,
      language: language ?? this.language,
      venmoHandle: venmoHandle ?? this.venmoHandle,
      paypalEmail: paypalEmail ?? this.paypalEmail,
      cashappTag: cashappTag ?? this.cashappTag,
      notificationSettings: notificationSettings ?? this.notificationSettings,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatar': avatar,
        'currency': currency,
        'timezone': timezone,
        'language': language,
        'venmo_handle': venmoHandle,
        'paypal_email': paypalEmail,
        'cashapp_tag': cashappTag,
        'notification_settings': notificationSettings,
      };

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
