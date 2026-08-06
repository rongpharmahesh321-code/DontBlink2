class OrderModel {
  final String id;
  final String customerName;
  final String address;
  final String paymentMethod;
  final String status;
  final double subtotal;
  final double deliveryFee;
  final double platformFee;
  final double grandTotal;
  final List<Map<String, dynamic>> items;
  final DateTime? createdAt;

  OrderModel({
    required this.id,
    required this.customerName,
    required this.address,
    required this.paymentMethod,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.platformFee,
    required this.grandTotal,
    required this.items,
    this.createdAt,
  });

  factory OrderModel.fromFirestore(String id, Map<String, dynamic> data) {
    return OrderModel(
      id: id,
      customerName: data["customerName"] ?? "",
      address: data["address"] ?? "",
      paymentMethod: data["paymentMethod"] ?? "",
      status: data["status"] ?? "Placed",
      subtotal: (data["subtotal"] ?? 0).toDouble(),
      deliveryFee: (data["deliveryFee"] ?? 0).toDouble(),
      platformFee: (data["platformFee"] ?? 0).toDouble(),
      grandTotal: (data["grandTotal"] ?? 0).toDouble(),
      items: List<Map<String, dynamic>>.from(data["items"] ?? []),
      createdAt: data["createdAt"] != null ? data["createdAt"].toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "customerName": customerName,
      "address": address,
      "paymentMethod": paymentMethod,
      "status": status,
      "subtotal": subtotal,
      "deliveryFee": deliveryFee,
      "platformFee": platformFee,
      "grandTotal": grandTotal,
      "items": items,
      "createdAt": createdAt,
    };
  }
}
