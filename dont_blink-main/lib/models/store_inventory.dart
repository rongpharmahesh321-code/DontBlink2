import 'package:cloud_firestore/cloud_firestore.dart';

class StoreInventory {
  final String storeId;
  final String productId;
  final int stock;
  final bool isAvailable;
  final double? price;
  final DateTime? updatedAt;

  const StoreInventory({
    required this.storeId,
    required this.productId,
    required this.stock,
    required this.isAvailable,
    this.price,
    this.updatedAt,
  });

  factory StoreInventory.fromFirestore(
    String storeId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    int toInt(dynamic value) {
      if (value is num) {
        return value.toInt();
      }

      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double? toDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      }

      final parsed = double.tryParse(value?.toString() ?? '');

      return parsed;
    }

    DateTime? toDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }

      return null;
    }

    return StoreInventory(
      storeId: storeId,
      productId: doc.id,
      stock: toInt(data['stock']),
      isAvailable: data['isAvailable'] != false,
      price: toDouble(data['price']),
      updatedAt: toDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'stock': stock,
      'isAvailable': isAvailable,
      if (price != null) 'price': price,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
