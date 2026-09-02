class CategoryModel {
  final String id;
  final String name;
  final String section;
  final String imageUrl;
  final String filter;
  final int sortOrder;
  final bool isActive;

  CategoryModel({
    required this.id,
    required this.name,
    required this.section,
    required this.imageUrl,
    required this.filter,
    required this.sortOrder,
    required this.isActive,
  });

  // ==========================================================
  // FIRESTORE → CATEGORY MODEL
  // ==========================================================

  factory CategoryModel.fromFirestore(String id, Map<String, dynamic> data) {
    return CategoryModel(
      id: id,
      name: _toStringValue(data['name']),
      section: _toStringValue(data['section'], fallback: 'Grocery & Kitchen'),
      imageUrl: _toStringValue(data['imageUrl']),
      filter: _toStringValue(data['filter']),
      sortOrder: _toInt(data['sortOrder']),
      isActive: _toBool(data['isActive'], defaultValue: true),
    );
  }

  // ==========================================================
  // CATEGORY MODEL → FIRESTORE
  // ==========================================================

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'section': section,
      'imageUrl': imageUrl,
      'filter': filter,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }

  // ==========================================================
  // SAFE STRING CONVERSION
  // ==========================================================

  static String _toStringValue(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }

    final result = value.toString().trim();

    if (result.isEmpty) {
      return fallback;
    }

    return result;
  }

  // ==========================================================
  // SAFE INTEGER CONVERSION
  // ==========================================================

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  // ==========================================================
  // SAFE BOOLEAN CONVERSION
  // ==========================================================

  static bool _toBool(dynamic value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

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

  CategoryModel copyWith({
    String? id,
    String? name,
    String? section,
    String? imageUrl,
    String? filter,
    int? sortOrder,
    bool? isActive,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      section: section ?? this.section,
      imageUrl: imageUrl ?? this.imageUrl,
      filter: filter ?? this.filter,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }
}
