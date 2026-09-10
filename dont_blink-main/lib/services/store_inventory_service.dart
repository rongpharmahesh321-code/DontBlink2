import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/store_inventory.dart';

class StoreInventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> inventoryCollection(
    String storeId,
  ) {
    return _firestore.collection('stores').doc(storeId).collection('inventory');
  }

  Stream<List<StoreInventory>> streamInventory(String storeId) {
    return inventoryCollection(storeId).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => StoreInventory.fromFirestore(storeId, doc))
          .toList();
    });
  }

  Stream<StoreInventory?> streamProductInventory(
    String storeId,
    String productId,
  ) {
    return inventoryCollection(storeId).doc(productId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }

      return StoreInventory.fromFirestore(storeId, doc);
    });
  }

  Future<StoreInventory?> getInventory(String storeId, String productId) async {
    final doc = await inventoryCollection(storeId).doc(productId).get();

    if (!doc.exists) {
      return null;
    }

    return StoreInventory.fromFirestore(storeId, doc);
  }

  Future<void> saveInventory({
    required String storeId,
    required String productId,
    required int stock,
    required bool isAvailable,
    double? price,
  }) async {
    final data = <String, dynamic>{
      'stock': stock,
      'isAvailable': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (price != null) {
      data['price'] = price;
    } else {
      data['price'] = FieldValue.delete();
    }

    await inventoryCollection(
      storeId,
    ).doc(productId).set(data, SetOptions(merge: true));
  }

  Future<void> setStock({
    required String storeId,
    required String productId,
    required int stock,
  }) async {
    await inventoryCollection(storeId).doc(productId).set({
      'stock': stock,
      'isAvailable': stock > 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setAvailability({
    required String storeId,
    required String productId,
    required bool isAvailable,
  }) async {
    await inventoryCollection(storeId).doc(productId).set({
      'isAvailable': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeInventory({
    required String storeId,
    required String productId,
  }) async {
    await inventoryCollection(storeId).doc(productId).delete();
  }

  Future<void> batchSaveInventory({
    required String storeId,
    required Map<String, Map<String, dynamic>> products,
  }) async {
    final batch = _firestore.batch();

    for (final entry in products.entries) {
      final ref = inventoryCollection(storeId).doc(entry.key);

      batch.set(ref, {
        ...entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }
}
