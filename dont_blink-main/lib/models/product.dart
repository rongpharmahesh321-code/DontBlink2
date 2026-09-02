class Product {
  final String id;
  final String name;
  final String price;
  final String image;
  final String category;
  final String description;

  // ==========================================================
  // SELLING UNIT
  // ==========================================================
  //
  // Examples:
  // kg
  // 250 g
  // 500 g
  // litre
  // 250 ml
  // piece
  // pack
  // packet
  // bottle
  // box
  // dozen
  //
  final String sellingUnit;

  // ==========================================================
  // EXISTING PRODUCT INFORMATION
  // ==========================================================

  final double rating;
  final int deliveryTime;
  final int discount;

  // ==========================================================
  // STOCK
  // ==========================================================

  final int stock;
  final bool isAvailable;

  // ==========================================================
  // POPULAR PRODUCT
  // ==========================================================
  //
  // Controlled from the Admin Dashboard.
  //
  // true  = appears in Popular Products
  // false = does not appear in Popular Products
  //
  final bool isPopular;

  // ==========================================================
  // CONSTRUCTOR
  // ==========================================================

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.image,
    required this.category,

    this.description = '',

    this.sellingUnit = 'piece',

    this.rating = 4.8,

    this.deliveryTime = 10,

    this.discount = 0,

    this.stock = 0,

    this.isAvailable = true,

    this.isPopular = false,
  });

  // ==========================================================
  // FIRESTORE → PRODUCT
  // ==========================================================

  factory Product.fromFirestore(String id, Map<String, dynamic> data) {
    // --------------------------------------------------------
    // PRICE
    // --------------------------------------------------------

    final String price = _priceToString(data['price']);

    // --------------------------------------------------------
    // STOCK
    // --------------------------------------------------------

    final int stock = _toInt(data['stock'], defaultValue: 0);

    // --------------------------------------------------------
    // RATING
    // --------------------------------------------------------

    final double rating = _toDouble(data['rating'], defaultValue: 4.8);

    // --------------------------------------------------------
    // DELIVERY TIME
    // --------------------------------------------------------

    final int deliveryTime = _toInt(data['deliveryTime'], defaultValue: 10);

    // --------------------------------------------------------
    // DISCOUNT
    // --------------------------------------------------------

    final int discount = _toInt(data['discount'], defaultValue: 0);

    // --------------------------------------------------------
    // AVAILABILITY
    // --------------------------------------------------------

    final bool isAvailable = _toBool(
      data['isAvailable'],
      defaultValue: stock > 0,
    );

    // --------------------------------------------------------
    // POPULAR
    // --------------------------------------------------------

    final bool isPopular = _toBool(data['isPopular'], defaultValue: false);

    // --------------------------------------------------------
    // SELLING UNIT
    // --------------------------------------------------------

    final String sellingUnit = _toString(
      data['sellingUnit'],
      fallback: 'piece',
    );

    // --------------------------------------------------------
    // RETURN PRODUCT
    // --------------------------------------------------------

    return Product(
      id: id,

      name: _toString(data['name']),

      price: price,

      image: _toString(data['image']),

      category: _toString(data['category']),

      description: _toString(data['description']),

      sellingUnit: sellingUnit,

      rating: rating,

      deliveryTime: deliveryTime,

      discount: discount,

      stock: stock,

      isAvailable: isAvailable,

      isPopular: isPopular,
    );
  }

  // ==========================================================
  // BACKWARD COMPATIBILITY
  // ==========================================================
  //
  // Some existing screens use:
  //
  // product.weight
  //
  // Keep this getter so those screens continue working.
  //
  String get weight {
    if (sellingUnit.trim().isEmpty) {
      return 'piece';
    }

    return sellingUnit;
  }

  // ==========================================================
  // PRODUCT → FIRESTORE
  // ==========================================================

  Map<String, dynamic> toMap() {
    return {
      'name': name,

      'price': price,

      'image': image,

      'category': category,

      'description': description,

      'sellingUnit': sellingUnit,

      'rating': rating,

      'deliveryTime': deliveryTime,

      'discount': discount,

      'stock': stock,

      'isAvailable': isAvailable,

      // ------------------------------------------------------
      // ADMIN CONTROLLED POPULAR STATUS
      // ------------------------------------------------------
      'isPopular': isPopular,
    };
  }

  // ==========================================================
  // COPY WITH
  // ==========================================================

  Product copyWith({
    String? id,
    String? name,
    String? price,
    String? image,
    String? category,
    String? description,
    String? sellingUnit,
    double? rating,
    int? deliveryTime,
    int? discount,
    int? stock,
    bool? isAvailable,
    bool? isPopular,
  }) {
    return Product(
      id: id ?? this.id,

      name: name ?? this.name,

      price: price ?? this.price,

      image: image ?? this.image,

      category: category ?? this.category,

      description: description ?? this.description,

      sellingUnit: sellingUnit ?? this.sellingUnit,

      rating: rating ?? this.rating,

      deliveryTime: deliveryTime ?? this.deliveryTime,

      discount: discount ?? this.discount,

      stock: stock ?? this.stock,

      isAvailable: isAvailable ?? this.isAvailable,

      isPopular: isPopular ?? this.isPopular,
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
  // SAFE PRICE
  // ==========================================================

  static String _priceToString(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is num) {
      if (value % 1 == 0) {
        return value.toInt().toString();
      }

      return value.toString();
    }

    return value.toString().trim();
  }

  // ==========================================================
  // SAFE INTEGER
  // ==========================================================

  static int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) {
      return defaultValue;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString().trim()) ?? defaultValue;
  }

  // ==========================================================
  // SAFE DOUBLE
  // ==========================================================

  static double _toDouble(dynamic value, {double defaultValue = 0}) {
    if (value == null) {
      return defaultValue;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString().trim()) ?? defaultValue;
  }

  // ==========================================================
  // SAFE BOOLEAN
  // ==========================================================

  static bool _toBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) {
      return defaultValue;
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

    return defaultValue;
  }
}
