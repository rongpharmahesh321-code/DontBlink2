import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'store_selection_service.dart';

/// Connects a customer's selected delivery location to the
/// intelligent dark-store selection engine.
///
/// This service deliberately does not modify the HomeScreen yet.
/// It gives us one clean place to:
/// - select the best store for an address
/// - remember the selected store for the signed-in customer
/// - clear the selection when the address changes
class CustomerStoreService {
  CustomerStoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    StoreSelectionService? storeSelectionService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storeSelectionService =
           storeSelectionService ?? StoreSelectionService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final StoreSelectionService _storeSelectionService;

  /// Selects the best dark store for the supplied delivery coordinates
  /// and saves the selected store ID on the customer's user document.
  ///
  /// Returns null when:
  /// - no customer is signed in, or
  /// - no eligible store can serve the location.
  Future<StoreSelectionResult?> selectStoreForAddress({
    required double latitude,
    required double longitude,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final result = await _storeSelectionService.selectBestStore(
      customerLatitude: latitude,
      customerLongitude: longitude,
    );

    if (result == null) {
      await clearSelectedStore();
      return null;
    }

    await _firestore.collection('users').doc(user.uid).set({
      'selectedStoreId': result.storeId,
      'selectedStoreName': result.storeName,
      'selectedStoreCode': result.storeCode,
      'selectedStoreDistanceKm': result.distanceKm,
      'selectedStoreUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return result;
  }

  /// Reads the customer's currently selected store ID.
  Future<String?> getSelectedStoreId() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final snapshot = await _firestore.collection('users').doc(user.uid).get();

    if (!snapshot.exists) {
      return null;
    }

    final value = snapshot.data()?['selectedStoreId'];

    if (value == null) {
      return null;
    }

    final storeId = value.toString().trim();

    return storeId.isEmpty ? null : storeId;
  }

  /// Reads the full currently selected store.
  ///
  /// Returns null if the customer has no selected store or if the store
  /// was deleted.
  Future<StoreSelectionResult?> getSelectedStore() async {
    final storeId = await getSelectedStoreId();

    if (storeId == null) {
      return null;
    }

    final snapshot = await _firestore.collection('stores').doc(storeId).get();

    if (!snapshot.exists) {
      await clearSelectedStore();
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      await clearSelectedStore();
      return null;
    }

    final latitude = _toDouble(data['latitude']);
    final longitude = _toDouble(data['longitude']);

    if (latitude == null || longitude == null) {
      return StoreSelectionResult(
        storeId: snapshot.id,
        storeData: data,
        distanceKm: 0,
        score: 0,
      );
    }

    final distance = 0.0;

    return StoreSelectionResult(
      storeId: snapshot.id,
      storeData: data,
      distanceKm: distance,
      score: 0,
    );
  }

  /// Clears the customer's remembered store.
  ///
  /// This is useful when the customer changes their delivery address
  /// before a new store has been selected.
  Future<void> clearSelectedStore() async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    await _firestore.collection('users').doc(user.uid).set({
      'selectedStoreId': FieldValue.delete(),
      'selectedStoreName': FieldValue.delete(),
      'selectedStoreCode': FieldValue.delete(),
      'selectedStoreDistanceKm': FieldValue.delete(),
      'selectedStoreUpdatedAt': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  /// Re-runs selection for a new address.
  ///
  /// Use this whenever the customer changes the active delivery address.
  Future<StoreSelectionResult?> updateStoreForNewAddress({
    required double latitude,
    required double longitude,
  }) {
    return selectStoreForAddress(latitude: latitude, longitude: longitude);
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}
