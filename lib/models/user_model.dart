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
  final Map<String, dynamic>? notificationSettings;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: json['phone']?.toString(),
      avatar: json['avatar']?.toString(),
      currency: (json['currency'] ?? 'USD').toString(),
      timezone: json['timezone']?.toString(),
      language: json['language']?.toString(),
      venmoHandle: json['venmo_handle']?.toString(),
      paypalEmail: json['paypal_email']?.toString(),
      notificationSettings: json['notification_settings'] is Map
          ? Map<String, dynamic>.from(json['notification_settings'] as Map)
          : null,
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
        'notification_settings': notificationSettings,
      };

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
