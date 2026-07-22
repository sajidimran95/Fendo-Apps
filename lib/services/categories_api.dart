import '../core/network/api_client.dart';
import '../models/category_model.dart';

/// Categories API (list / create / update / delete).
class CategoriesApi {
  CategoriesApi(this._client);

  final ApiClient _client;

  /// GET /categories
  Future<List<CategoryModel>> listCategories() async {
    final res = await _client.get('/categories');
    return unwrapList(res.data, key: 'categories')
        .map(CategoryModel.fromJson)
        .toList();
  }

  /// POST /categories
  Future<CategoryModel> createCategory({
    required String name,
    String? icon,
    String? color,
  }) async {
    final res = await _client.post(
      '/categories',
      data: {
        'name': name,
        if (icon != null && icon.isNotEmpty) 'icon': icon,
        if (color != null && color.isNotEmpty) 'color': color,
      },
    );
    final map = unwrapMap(res.data);
    final cat = map['category'] ?? map;
    return CategoryModel.fromJson(Map<String, dynamic>.from(cat as Map));
  }

  /// PUT /categories/{id}
  Future<CategoryModel> updateCategory(
    int id, {
    String? name,
    String? icon,
    String? color,
  }) async {
    final res = await _client.put(
      '/categories/$id',
      data: {
        if (name != null) 'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
      },
    );
    final map = unwrapMap(res.data);
    final cat = map['category'] ?? map;
    return CategoryModel.fromJson(Map<String, dynamic>.from(cat as Map));
  }

  /// DELETE /categories/{id}
  Future<void> deleteCategory(int id) async {
    await _client.delete('/categories/$id');
  }
}
