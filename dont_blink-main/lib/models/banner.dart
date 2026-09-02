class BannerModel {
  final String id;
  final String imageUrl;
  final String title;
  final String subtitle;
  final bool isActive;

  // Main Firestore ordering field.
  final int displayOrder;

  const BannerModel({
    required this.id,
    required this.imageUrl,
    this.title = '',
    this.subtitle = '',
    this.isActive = true,
    int? displayOrder,
    int? sortOrder,

    // Backward compatibility with Admin Banners screen.
  }) : displayOrder = sortOrder ?? displayOrder ?? 0;

  // ==========================================================
  // SORT ORDER
  // ==========================================================
  //
  // Existing admin screen uses:
  //
  // banner.sortOrder
  //
  // Keep it as an alias for displayOrder.
  // ==========================================================

  int get sortOrder => displayOrder;

  // ==========================================================
  // FIRESTORE → BANNER
  // ==========================================================

  factory BannerModel.fromFirestore(String id, Map<String, dynamic> data) {
    // --------------------------------------------------------
    // ORDER
    // --------------------------------------------------------

    int order = 0;

    if (data['displayOrder'] != null) {
      order = _toInt(data['displayOrder'], fallback: 0);
    } else if (data['sortOrder'] != null) {
      order = _toInt(data['sortOrder'], fallback: 0);
    }

    // --------------------------------------------------------
    // RETURN
    // --------------------------------------------------------

    return BannerModel(
      id: id,

      imageUrl: _toString(data['imageUrl'], fallback: ''),

      title: _toString(data['title'], fallback: ''),

      subtitle: _toString(data['subtitle'], fallback: ''),

      isActive: _toBool(data['isActive'], fallback: true),

      displayOrder: order,
    );
  }

  // ==========================================================
  // BANNER → FIRESTORE
  // ==========================================================

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'isActive': isActive,

      // Use one consistent Firestore field.
      'displayOrder': displayOrder,
    };
  }

  // ==========================================================
  // COPY WITH
  // ==========================================================

  BannerModel copyWith({
    String? id,
    String? imageUrl,
    String? title,
    String? subtitle,
    bool? isActive,
    int? displayOrder,
    int? sortOrder,
  }) {
    return BannerModel(
      id: id ?? this.id,

      imageUrl: imageUrl ?? this.imageUrl,

      title: title ?? this.title,

      subtitle: subtitle ?? this.subtitle,

      isActive: isActive ?? this.isActive,

      displayOrder: sortOrder ?? displayOrder ?? this.displayOrder,
    );
  }

  // ==========================================================
  // SAFE STRING
  // ==========================================================

  static String _toString(dynamic value, {String fallback = ''}) {
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
  // SAFE INTEGER
  // ==========================================================

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) {
      return fallback;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString().trim()) ?? fallback;
  }

  // ==========================================================
  // SAFE BOOLEAN
  // ==========================================================

  static bool _toBool(dynamic value, {bool fallback = false}) {
    if (value == null) {
      return fallback;
    }

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

    return fallback;
  }
}
