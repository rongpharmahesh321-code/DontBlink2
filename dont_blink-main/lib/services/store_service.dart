import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/store.dart';

class StoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _stores =>
      _firestore.collection('stores');

  Stream<List<StoreModel>> getStores() {
    return _stores.snapshots().map((snapshot) {
      final stores = snapshot.docs.map(StoreModel.fromFirestore).toList();

      stores.sort((a, b) {
        final priority = a.priority.compareTo(b.priority);

        if (priority != 0) return priority;

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return stores;
    });
  }

  Stream<List<StoreModel>> getActiveStores() {
    return _stores.where('isActive', isEqualTo: true).snapshots().map((
      snapshot,
    ) {
      final stores = snapshot.docs
          .map(StoreModel.fromFirestore)
          .where((store) => store.isActive)
          .toList();

      stores.sort((a, b) {
        final priority = a.priority.compareTo(b.priority);

        if (priority != 0) return priority;

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return stores;
    });
  }

  Future<StoreModel?> getStore(String storeId) async {
    final doc = await _stores.doc(storeId).get();

    if (!doc.exists) return null;

    return StoreModel.fromFirestore(doc);
  }

  Future<String> createStore(Map<String, dynamic> data) async {
    final ref = _stores.doc();

    await ref.set({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<void> updateStore(String storeId, Map<String, dynamic> data) async {
    await _stores.doc(storeId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteStore(String storeId) async {
    await _stores.doc(storeId).delete();
  }

  Future<void> setStoreStatus(String storeId, String status) async {
    await _stores.doc(storeId).update({
      'status': status.toUpperCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setStoreActive(String storeId, bool active) async {
    await _stores.doc(storeId).update({
      'isActive': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
