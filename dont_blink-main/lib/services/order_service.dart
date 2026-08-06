import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart.dart';
import '../models/address.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> placeOrder({
    required String customerName,
    required String address,
    required String paymentMethod,
  }) async {
    double total = 0;

    List<Map<String, dynamic>> items = [];

    for (var item in Cart.items) {
      final price = double.parse(
        item.product.price.replaceAll(RegExp(r'[^0-9.]'), ''),
      );

      total += price * item.quantity;

      items.add({
        "name": item.product.name,
        "price": item.product.price,
        "image": item.product.image,
        "quantity": item.quantity,
      });
    }

    await _firestore.collection("orders").add({
      "customerName": customerName,
      "address": address,
      "paymentMethod": paymentMethod,
      "items": items,
      "subtotal": total,
      "deliveryFee": 25,
      "platformFee": 5,
      "grandTotal": total + 30,
      "status": "Placed",
      "createdAt": FieldValue.serverTimestamp(),
    });
  }
}
