import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/cart.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================================
  // PLACE ORDER
  // ==========================================================

  Future<void> placeOrder({
    required String customerName,
    required String customerPhone,
    required String address,
    required String paymentMethod,
    required double customerLatitude,
    required double customerLongitude,
    required double deliveryFee,
    String? paymentStatus,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    // ========================================================
    // USER CHECK
    // ========================================================

    if (user == null) {
      throw Exception('User is not logged in');
    }

    // ========================================================
    // CART CHECK
    // ========================================================

    if (Cart.items.isEmpty) {
      throw Exception('Your cart is empty');
    }

    // ========================================================
    // CALCULATE SUBTOTAL
    // ========================================================

    double subtotal = 0;

    final List<Map<String, dynamic>> items = [];

    for (final item in Cart.items) {
      final cleanedPrice = item.product.price
          .replaceAll(RegExp(r'[^0-9.]'), '')
          .trim();

      final price = double.tryParse(cleanedPrice) ?? 0;

      subtotal += price * item.quantity;

      items.add({
        'productId': item.product.id,
        'name': item.product.name,
        'price': item.product.price,
        'image': item.product.image,
        'quantity': item.quantity,
      });
    }

    // ========================================================
    // PLATFORM FEE
    // ========================================================

    const double platformFee = 5;

    // ========================================================
    // GRAND TOTAL
    // ========================================================

    final double grandTotal = subtotal + deliveryFee + platformFee;

    // ========================================================
    // PAYMENT INFORMATION
    // ========================================================

    final String normalizedPaymentMethod = paymentMethod.trim().toLowerCase();

    // ========================================================
    // IMPORTANT
    //
    // COD must be TRUE only when the selected method
    // is actually Cash on Delivery.
    // ========================================================

    final bool isCashOnDelivery =
        normalizedPaymentMethod == 'cash on delivery' ||
        normalizedPaymentMethod == 'cod';

    final bool isPrepaid = !isCashOnDelivery;

    // ========================================================
    // PAYMENT STATUS
    //
    // COD:
    // Pending
    //
    // Cashfree / UPI:
    // Paid
    //
    // If the caller explicitly provides a status,
    // use that status.
    // ========================================================

    final String finalPaymentStatus = paymentStatus?.trim().isNotEmpty == true
        ? paymentStatus!.trim()
        : isCashOnDelivery
        ? 'Pending'
        : 'Paid';

    // ========================================================
    // AMOUNT TO COLLECT
    // ========================================================

    final double amountToCollect = isCashOnDelivery ? grandTotal : 0;

    // ========================================================
    // CREATE ORDER
    // ========================================================

    final orderRef = _firestore.collection('orders').doc();

    await orderRef.set({
      // ======================================================
      // ORDER ID
      // ======================================================
      'orderId': orderRef.id,

      // ======================================================
      // CUSTOMER
      // ======================================================
      'userId': user.uid,

      'customerName': customerName,

      'customerEmail': user.email ?? '',

      'customerPhone': customerPhone,

      // ======================================================
      // DELIVERY ADDRESS
      // ======================================================
      'address': address,

      'customerLatitude': customerLatitude,

      'customerLongitude': customerLongitude,

      // ======================================================
      // PAYMENT
      // ======================================================
      'paymentMethod': isCashOnDelivery ? 'Cash on Delivery' : paymentMethod,

      'isPrepaid': isPrepaid,

      'amountToCollect': amountToCollect,

      'paymentStatus': finalPaymentStatus,

      // ======================================================
      // PRODUCTS
      // ======================================================
      'items': items,

      // ======================================================
      // BILL
      // ======================================================
      'subtotal': subtotal,

      'deliveryFee': deliveryFee,

      'platformFee': platformFee,

      'grandTotal': grandTotal,

      // ======================================================
      // ORDER STATUS
      // ======================================================
      'status': 'Placed',

      // ======================================================
      // RIDER
      // ======================================================
      'riderId': null,

      'riderName': null,

      'riderEmail': null,

      // ======================================================
      // TIME
      // ======================================================
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================
  // GET MY ORDERS
  // ==========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> getMyOrders() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ==========================================================
  // GET SINGLE ORDER
  // ==========================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> getOrder(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots();
  }

  // ==========================================================
  // UPDATE ORDER STATUS
  // ==========================================================

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
