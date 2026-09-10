import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/cart.dart';

class StoreSelectionResult {
  final String storeId;
  final Map<String, dynamic> storeData;
  final double distanceKm;
  final double score;
  final bool isRerouted;
  final String? originalNearestStoreId;
  final String? originalNearestStoreName;

  const StoreSelectionResult({
    required this.storeId,
    required this.storeData,
    required this.distanceKm,
    required this.score,
    this.isRerouted = false,
    this.originalNearestStoreId,
    this.originalNearestStoreName,
  });

  StoreSelectionResult copyWith({
    String? storeId,
    Map<String, dynamic>? storeData,
    double? distanceKm,
    double? score,
    bool? isRerouted,
    String? originalNearestStoreId,
    String? originalNearestStoreName,
  }) {
    return StoreSelectionResult(
      storeId: storeId ?? this.storeId,
      storeData: storeData ?? this.storeData,
      distanceKm: distanceKm ?? this.distanceKm,
      score: score ?? this.score,
      isRerouted: isRerouted ?? this.isRerouted,
      originalNearestStoreId:
          originalNearestStoreId ?? this.originalNearestStoreId,
      originalNearestStoreName:
          originalNearestStoreName ?? this.originalNearestStoreName,
    );
  }

  String get storeName {
    final v = storeData['name']?.toString().trim() ?? '';
    return v.isEmpty ? 'Selected Store' : v;
  }

  String get storeCode => storeData['code']?.toString().trim() ?? '';

  String get status =>
      (storeData['status'] ?? 'CLOSED').toString().trim().toUpperCase();

  double get serviceRadiusKm {
    final v = storeData['serviceRadiusKm'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  int get priority {
    final v = storeData['priority'];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 1;
  }

  double get latitude {
    final v = storeData['latitude'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  double get longitude {
    final v = storeData['longitude'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

/// Shared store-selection and multi-store auto-rerouting engine.
///
/// Multi-Tier Architecture:
/// 1. Tier 1: Check primary active stores within their service radius that
///    can fulfill all items in the cart.
/// 2. Tier 2 (Silent Failover): If the nearest store is out of stock for any
///    cart item, automatically check other active stores across the network
///    (up to extended failover radius) and silently route the order to the
///    closest fulfilling backup store without showing store switches to the customer.
class StoreSelectionService {
  StoreSelectionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<StoreSelectionResult?> selectBestStore({
    required double customerLatitude,
    required double customerLongitude,
    bool checkCartInventory = false,
  }) async {
    if (!_validCoordinate(customerLatitude, customerLongitude)) {
      return null;
    }

    final snapshot = await _firestore.collection('stores').get();
    final allActiveStores = <StoreSelectionResult>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      if (data['isActive'] == false) continue;

      final status =
          (data['status'] ?? 'CLOSED').toString().trim().toUpperCase();

      if (status != 'OPEN' && status != 'BUSY') continue;

      final latitude = _toDouble(data['latitude']);
      final longitude = _toDouble(data['longitude']);
      final radius = _toDouble(data['serviceRadiusKm']);

      if (latitude == null ||
          longitude == null ||
          radius == null ||
          radius <= 0 ||
          !_validCoordinate(latitude, longitude)) {
        continue;
      }

      final distance = _distanceKm(
        customerLatitude,
        customerLongitude,
        latitude,
        longitude,
      );

      final priority = (_toInt(data['priority']) ?? 1).clamp(1, 100);
      final score =
          distance * 100 + (status == 'BUSY' ? 20.0 : 0.0) + priority * 0.25;

      allActiveStores.add(
        StoreSelectionResult(
          storeId: doc.id,
          storeData: data,
          distanceKm: distance,
          score: score,
        ),
      );
    }

    if (allActiveStores.isEmpty) return null;

    // Sort strictly by distance to find the true closest store
    allActiveStores.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    final nearestStore = allActiveStores.first;

    // -------------------------------------------------------------
    // TIER 1: Primary Delivery Radius Check
    // -------------------------------------------------------------
    final primaryCandidates = <StoreSelectionResult>[];
    for (final store in allActiveStores) {
      if (store.distanceKm <= store.serviceRadiusKm) {
        if (!checkCartInventory || Cart.items.isEmpty) {
          primaryCandidates.add(store);
        } else {
          final canFulfill = await _canFulfillCart(store.storeId);
          if (canFulfill) {
            primaryCandidates.add(store);
          }
        }
      }
    }

    if (primaryCandidates.isNotEmpty) {
      primaryCandidates.sort(_compare);
      final best = primaryCandidates.first;

      // If the fulfilling store is not the absolute nearest store to customer,
      // mark it as rerouted because the nearest store could not fulfill the cart!
      if (best.storeId != nearestStore.storeId &&
          checkCartInventory &&
          Cart.items.isNotEmpty) {
        return best.copyWith(
          isRerouted: true,
          originalNearestStoreId: nearestStore.storeId,
          originalNearestStoreName: nearestStore.storeName,
        );
      }

      return best;
    }

    // -------------------------------------------------------------
    // TIER 2: SILENT AUTO-REROUTE / FAILOVER TO BACKUP STORE
    // When nearest store cannot fulfill the cart, look across other
    // active stores in the network that can fulfill the order.
    // -------------------------------------------------------------
    if (checkCartInventory && Cart.items.isNotEmpty) {
      const maxFailoverRadiusKm = 25.0;

      final failoverCandidates = <StoreSelectionResult>[];
      for (final store in allActiveStores) {
        if (store.distanceKm > maxFailoverRadiusKm) continue;

        final canFulfill = await _canFulfillCart(store.storeId);
        if (canFulfill) {
          failoverCandidates.add(
            store.copyWith(
              isRerouted: true,
              originalNearestStoreId: nearestStore.storeId,
              originalNearestStoreName: nearestStore.storeName,
            ),
          );
        }
      }

      if (failoverCandidates.isNotEmpty) {
        failoverCandidates.sort(_compare);
        return failoverCandidates.first;
      }
    }

    return null;
  }

  Future<List<StoreSelectionResult>> getEligibleStores({
    required double customerLatitude,
    required double customerLongitude,
    bool checkCartInventory = false,
  }) async {
    final best = await selectBestStore(
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
      checkCartInventory: checkCartInventory,
    );

    return best != null ? [best] : [];
  }

  int _compare(StoreSelectionResult a, StoreSelectionResult b) {
    final score = a.score.compareTo(b.score);
    if (score != 0) return score;

    final distance = a.distanceKm.compareTo(b.distanceKm);
    if (distance != 0) return distance;

    final priority = a.priority.compareTo(b.priority);
    if (priority != 0) return priority;

    return a.storeName.toLowerCase().compareTo(b.storeName.toLowerCase());
  }

  Future<bool> _canFulfillCart(String storeId) async {
    final snapshot = await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('inventory')
        .get();

    final byId = <String, _InventoryData>{};
    final byProductId = <String, _InventoryData>{};
    final byName = <String, _InventoryData>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final int stock = _toInt(data['stock']) ?? 0;
      final rawAvailable = data['isAvailable'];
      final bool isAvailable = (rawAvailable is bool)
          ? rawAvailable
          : (rawAvailable?.toString().trim().toLowerCase() != 'false');

      final record = _InventoryData(
        stock: stock,
        isAvailable: isAvailable && stock > 0,
      );

      final docId = doc.id.trim();
      if (docId.isNotEmpty) {
        byId[docId] = record;
        byId[docId.toLowerCase()] = record;
      }

      final productId =
          (data['productId'] ?? data['id'])?.toString().trim() ?? '';
      if (productId.isNotEmpty) {
        byProductId[productId] = record;
        byProductId[productId.toLowerCase()] = record;
      }

      final name = data['productName']?.toString().trim().toLowerCase() ?? '';
      if (name.isNotEmpty) {
        byName[name] = record;
      }
    }

    for (final item in Cart.items) {
      final productId = item.product.id.trim();
      final productName = item.product.name.trim().toLowerCase();

      if (productId.isEmpty) return false;

      final record =
          byId[productId] ??
          byId[productId.toLowerCase()] ??
          byProductId[productId] ??
          byProductId[productId.toLowerCase()] ??
          (productName.isEmpty ? null : byName[productName]);

      // Product MUST have an explicit inventory record in this store.
      // If the store hasn't enabled/added this product, it CANNOT fulfill it.
      if (record == null) {
        debugPrint(
          '[StoreSelection] Store $storeId CANNOT fulfill: "${item.product.name}" ($productId) is not enabled in this store inventory.',
        );
        return false;
      }

      // Must be available for sale in this store
      if (!record.isAvailable) {
        debugPrint(
          '[StoreSelection] Store $storeId CANNOT fulfill: "${item.product.name}" ($productId) is marked unavailable in this store.',
        );
        return false;
      }

      // Must have sufficient stock in this store
      if (record.stock < item.quantity) {
        debugPrint(
          '[StoreSelection] Store $storeId CANNOT fulfill: "${item.product.name}" ($productId) insufficient stock (stock=${record.stock}, required=${item.quantity}).',
        );
        return false;
      }
    }

    debugPrint(
      '[StoreSelection] Store $storeId CAN fulfill all items in cart.',
    );
    return true;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  bool _validCoordinate(double latitude, double longitude) {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        !(latitude == 0 && longitude == 0);
  }

  double _distanceKm(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const earthRadiusKm = 6371.0;

    final lat1 = _radians(latitude1);
    final lat2 = _radians(latitude2);
    final dLat = _radians(latitude2 - latitude1);
    final dLon = _radians(longitude2 - longitude1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final clamped = a.clamp(0.0, 1.0);
    final c = 2 * math.atan2(math.sqrt(clamped), math.sqrt(1 - clamped));

    return earthRadiusKm * c;
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}

class _InventoryData {
  final int stock;
  final bool isAvailable;

  const _InventoryData({required this.stock, required this.isAvailable});
}
