import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/cart.dart';
import 'store_selection_service.dart';

/// Handles customer order creation and order retrieval.
///
/// Store selection is intentionally performed again when the order is placed.
/// This prevents an order from being created when the selected store can no
/// longer fulfill the complete cart.
class OrderService {
  OrderService({StoreSelectionService? storeSelectionService})
    : _storeSelectionService = storeSelectionService ?? StoreSelectionService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StoreSelectionService _storeSelectionService;

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

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    if (Cart.items.isEmpty) {
      throw Exception('Your cart is empty.');
    }

    if (!_isValidCoordinate(customerLatitude, customerLongitude)) {
      throw Exception('Please select a valid delivery address.');
    }

    if (deliveryFee < 0) {
      throw Exception('Invalid delivery fee.');
    }

    // Re-check the store immediately before creating the order.
    final selectedStore = await _selectBestStore(
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
    );

    double subtotal = 0;
    final List<Map<String, dynamic>> items = [];

    for (final item in Cart.items) {
      final cleanedPrice = item.product.price
          .replaceAll(RegExp(r'[^0-9.]'), '')
          .trim();

      final price = double.tryParse(cleanedPrice);

      if (price == null || price < 0) {
        throw Exception('Invalid price for product "${item.product.name}".');
      }

      if (item.quantity <= 0) {
        throw Exception('Invalid quantity for product "${item.product.name}".');
      }

      subtotal += price * item.quantity;

      items.add({
        'productId': item.product.id,
        'name': item.product.name,
        'price': item.product.price,
        'image': item.product.image,
        'quantity': item.quantity,
      });
    }

    const double handlingFee = 5.0;
    const double platformFee = 5.0;
    final double grandTotal = subtotal + deliveryFee + handlingFee + platformFee;

    final bool hasSurcharge = deliveryFee > 25.0;
    final double surchargeAmount = hasSurcharge ? (deliveryFee - 25.0) : 0.0;
    final double riderPayout = hasSurcharge ? 19.0 : 16.0;

    final normalizedPaymentMethod = paymentMethod.trim().toLowerCase();

    final bool isCashOnDelivery =
        normalizedPaymentMethod == 'cash on delivery' ||
        normalizedPaymentMethod == 'cod';

    if (isCashOnDelivery) {
      final hour = DateTime.now().hour;
      if (hour >= 22 || hour < 7) {
        throw Exception(
          'Cash on Delivery is unavailable between 10:00 PM and 7:00 AM. '
          'Please choose an online payment method.',
        );
      }
    }

    final bool isPrepaid = !isCashOnDelivery;

    final String finalPaymentStatus =
        paymentStatus != null && paymentStatus.trim().isNotEmpty
        ? paymentStatus.trim()
        : isCashOnDelivery
        ? 'Pending'
        : 'Paid';

    final double amountToCollect = isCashOnDelivery ? grandTotal : 0.0;

    final orderRef = _firestore.collection('orders').doc();

    await orderRef.set({
      // ======================================================
      // ORDER
      // ======================================================
      'orderId': orderRef.id,
      'status': 'Placed',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),

      // ======================================================
      // CUSTOMER
      // ======================================================
      'userId': user.uid,
      'customerName': customerName.trim(),
      'customerEmail': user.email ?? '',
      'customerPhone': customerPhone.trim(),

      // ======================================================
      // DELIVERY
      // ======================================================
      'address': address.trim(),
      'customerLatitude': customerLatitude,
      'customerLongitude': customerLongitude,

      // ======================================================
      // SELECTED STORE
      // ======================================================
      'storeId': selectedStore.storeId,
      'storeName': selectedStore.storeName,
      'storeCode': selectedStore.storeCode,
      'storeDistanceKm': selectedStore.distanceKm,
      'storeLatitude': selectedStore.latitude,
      'storeLongitude': selectedStore.longitude,
      'isRerouted': selectedStore.isRerouted,
      'originalNearestStoreId': selectedStore.originalNearestStoreId,
      'originalNearestStoreName': selectedStore.originalNearestStoreName,
      'storeSelectionReason': selectedStore.isRerouted
          ? 'Auto-rerouted to backup store (inventory failover)'
          : 'Closest store with complete cart inventory',

      // ======================================================
      // PAYMENT
      // ======================================================
      'paymentMethod': isCashOnDelivery
          ? 'Cash on Delivery'
          : paymentMethod.trim(),
      'isPrepaid': isPrepaid,
      'amountToCollect': amountToCollect,
      'paymentStatus': finalPaymentStatus,

      // ======================================================
      // ITEMS
      // ======================================================
      'items': items,

      // ======================================================
      // BILL
      // ======================================================
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'handlingFee': handlingFee,
      'platformFee': platformFee,
      'grandTotal': grandTotal,
      'hasSurcharge': hasSurcharge,
      'deliverySurcharge': surchargeAmount,
      'surchargeReason': hasSurcharge ? 'Rain / Weather Surcharge' : null,
      'riderPayout': riderPayout,
      'riderEarnings': riderPayout,

      // ======================================================
      // RIDER
      // ======================================================
      'riderId': null,
      'riderName': null,
      'riderEmail': null,
    });
  }

  // ==========================================================
  // SELECT BEST STORE
  // ==========================================================

  Future<StoreSelectionResult> _selectBestStore({
    required double customerLatitude,
    required double customerLongitude,
  }) async {
    final result = await _storeSelectionService.selectBestStore(
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
      checkCartInventory: true,
    );

    if (result == null) {
      throw Exception(
        'Sorry, some items in your cart are currently out of stock.',
      );
    }

    return result;
  }

  // ==========================================================
  // GET MY ORDERS
  // ==========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> getMyOrders() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
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
    final cleanOrderId = orderId.trim();
    final cleanStatus = status.trim();

    if (cleanOrderId.isEmpty) {
      throw Exception('Order ID is required.');
    }

    if (cleanStatus.isEmpty) {
      throw Exception('Order status is required.');
    }

    await _firestore.collection('orders').doc(cleanOrderId).update({
      'status': cleanStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================
  // COORDINATE VALIDATION
  // ==========================================================

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        !(latitude == 0 && longitude == 0);
  }
}
