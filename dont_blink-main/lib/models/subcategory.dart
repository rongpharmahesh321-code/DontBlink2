class SubcategoryModel {
  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final String imageUrl;
  final String imagePath;
  final int sortOrder;
  final bool isActive;

  SubcategoryModel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.imageUrl,
    this.imagePath = '',
    required this.sortOrder,
    required this.isActive,
  });

  // ==========================================================
  // FIRESTORE -> SUBCATEGORY MODEL
  // ==========================================================

  factory SubcategoryModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return SubcategoryModel(
      id: id,
      name: _toStringValue(data['name']),
      categoryId: _toStringValue(data['categoryId']),
      categoryName: _toStringValue(data['categoryName']),
      imageUrl: _toStringValue(
        data['imageUrl'],
        fallback: _toStringValue(data['image']),
      ),
      imagePath: _toStringValue(data['imagePath']),
      sortOrder: _toInt(data['sortOrder']),
      isActive: _toBool(data['isActive'], defaultValue: true),
    );
  }

  // ==========================================================
  // SUBCATEGORY MODEL -> FIRESTORE
  // ==========================================================

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }

  // ==========================================================
  // SAFE CONVERSIONS
  // ==========================================================

  static String _toStringValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final result = value.toString().trim();
    return result.isEmpty ? fallback : result;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  static bool _toBool(dynamic value, {bool defaultValue = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return defaultValue;
  }

  // ==========================================================
  // COPY WITH
  // ==========================================================

  SubcategoryModel copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? categoryName,
    String? imageUrl,
    String? imagePath,
    int? sortOrder,
    bool? isActive,
  }) {
    return SubcategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }
}
