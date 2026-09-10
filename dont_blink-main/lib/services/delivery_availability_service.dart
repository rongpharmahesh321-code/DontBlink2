import 'package:flutter/foundation.dart';

import '../models/cart.dart';
import 'store_selection_service.dart';

class DeliveryAvailability {
  final bool isDeliverable;
  final StoreSelectionResult? store;
  final String message;

  const DeliveryAvailability({
    required this.isDeliverable,
    required this.store,
    required this.message,
  });

  double? get distanceKm => store?.distanceKm;
  double? get serviceRadiusKm => store?.serviceRadiusKm;
  String get storeName => store?.storeName ?? '';
  String get storeCode => store?.storeCode ?? '';

  bool get isRerouted => store?.isRerouted ?? false;

  String get distanceText {
    final distance = distanceKm;
    if (distance == null) return '';
    if (distance < 1) return '${(distance * 1000).round()} m away';
    return '${distance.toStringAsFixed(1)} km away';
  }
}

class DeliveryAvailabilityService {
  DeliveryAvailabilityService({StoreSelectionService? storeSelectionService})
    : _storeSelectionService = storeSelectionService ?? StoreSelectionService();

  final StoreSelectionService _storeSelectionService;

  Future<DeliveryAvailability> check({
    required double? latitude,
    required double? longitude,
  }) async {
    if (latitude == null || longitude == null) {
      return const DeliveryAvailability(
        isDeliverable: false,
        store: null,
        message: 'Delivery location is not available.',
      );
    }

    try {
      // Always check the CURRENT cart. This is also the same engine
      // used by OrderService, so Checkout and final ordering agree.
      final hasCart = Cart.items.isNotEmpty;

      final result = await _storeSelectionService.selectBestStore(
        customerLatitude: latitude,
        customerLongitude: longitude,
        checkCartInventory: hasCart,
      );

      if (result == null) {
        return DeliveryAvailability(
          isDeliverable: false,
          store: null,
          message: hasCart
              ? 'Some items in your cart are currently out of stock.'
              : 'Sorry, we don’t deliver to this location yet.',
        );
      }

      return DeliveryAvailability(
        isDeliverable: true,
        store: result,
        message: 'Delivery available.',
      );
    } catch (e) {
      debugPrint('Delivery availability check failed: $e');

      return const DeliveryAvailability(
        isDeliverable: false,
        store: null,
        message: 'We could not check delivery availability. Please try again.',
      );
    }
  }
}
