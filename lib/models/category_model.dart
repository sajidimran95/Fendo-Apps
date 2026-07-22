class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.isSystem = true,
  });

  final int id;
  final String name;
  final String? icon;
  final String? color;
  final bool isSystem;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      icon: json['icon']?.toString(),
      color: json['color']?.toString(),
      isSystem: json['is_system'] == true ||
          json['is_system'] == 1 ||
          json['system'] == true ||
          json['type']?.toString() == 'system',
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
