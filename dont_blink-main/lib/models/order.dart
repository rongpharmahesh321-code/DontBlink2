class OrderModel {
  final String id;

  final String customerName;
  final String address;
  final String paymentMethod;
  final String status;

  final double subtotal;
  final double deliveryFee;
  final double handlingFee;
  final double platformFee;
  final double grandTotal;

  final List<Map<String, dynamic>> items;

  final DateTime? createdAt;

  // ==========================================
  // CUSTOMER LOCATION & RATING
  // ==========================================

  final double? customerLatitude;
  final double? customerLongitude;
  final int? rating;
  final String? ratingFeedback;

  OrderModel({
    required this.id,
    required this.customerName,
    required this.address,
    required this.paymentMethod,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    this.handlingFee = 0.0,
    required this.platformFee,
    required this.grandTotal,
    required this.items,
    this.createdAt,
    this.customerLatitude,
    this.customerLongitude,
    this.rating,
    this.ratingFeedback,
  });

  // ==========================================
  // FIRESTORE → ORDER MODEL
  // ==========================================

  factory OrderModel.fromFirestore(String id, Map<String, dynamic> data) {
    return OrderModel(
      id: id,

      customerName: data["customerName"] ?? "",

      address: data["address"] ?? "",

      paymentMethod: data["paymentMethod"] ?? "",

      status: data["status"] ?? "Placed",

      subtotal: (data["subtotal"] ?? 0).toDouble(),

      deliveryFee: (data["deliveryFee"] ?? 0).toDouble(),

      handlingFee: (data["handlingFee"] ?? 0).toDouble(),

      platformFee: (data["platformFee"] ?? 0).toDouble(),

      grandTotal: (data["grandTotal"] ?? 0).toDouble(),

      items: List<Map<String, dynamic>>.from(data["items"] ?? []),

      createdAt: data["createdAt"]?.toDate(),

      // ========================================
      // CUSTOMER GPS
      // ========================================
      customerLatitude: data["customerLatitude"] != null
          ? (data["customerLatitude"] as num).toDouble()
          : null,

      customerLongitude: data["customerLongitude"] != null
          ? (data["customerLongitude"] as num).toDouble()
          : null,

      rating: data["rating"] != null ? (data["rating"] as num).toInt() : null,

      ratingFeedback: data["ratingFeedback"] as String?,
    );
  }

  // ==========================================
  // ORDER MODEL → FIRESTORE
  // ==========================================

  Map<String, dynamic> toMap() {
    return {
      "customerName": customerName,

      "address": address,

      "paymentMethod": paymentMethod,

      "status": status,

      "subtotal": subtotal,

      "deliveryFee": deliveryFee,

      "handlingFee": handlingFee,

      "platformFee": platformFee,

      "grandTotal": grandTotal,

      "items": items,

      "createdAt": createdAt,

      // ========================================
      // CUSTOMER GPS
      // ========================================
      "customerLatitude": customerLatitude,

      "customerLongitude": customerLongitude,

      "rating": rating,

      "ratingFeedback": ratingFeedback,
    };
  }
}
