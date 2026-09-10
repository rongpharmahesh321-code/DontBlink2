import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/subcategory.dart';

class SubcategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _subcategoriesCollection =>
      _firestore.collection('subcategories');

  // ==========================================================
  // GET ACTIVE SUBCATEGORIES FOR A CATEGORY
  // ==========================================================

  Stream<List<SubcategoryModel>> getSubcategories(String categoryName) {
    final target = categoryName.trim().toLowerCase();

    return _subcategoriesCollection.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SubcategoryModel.fromFirestore(doc.id, doc.data()))
          .where((sub) {
            if (!sub.isActive) return false;
            if (target.isEmpty) return true;
            return sub.categoryName.trim().toLowerCase() == target;
          })
          .toList();

      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return list;
    });
  }

  // ==========================================================
  // GET ALL SUBCATEGORIES (ADMIN)
  // ==========================================================

  Stream<List<SubcategoryModel>> getAllSubcategories({String? categoryName}) {
    final target = categoryName?.trim().toLowerCase() ?? '';

    return _subcategoriesCollection.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SubcategoryModel.fromFirestore(doc.id, doc.data()))
          .where((sub) {
            if (target.isEmpty) return true;
            return sub.categoryName.trim().toLowerCase() == target;
          })
          .toList();

      list.sort((a, b) {
        final catCompare = a.categoryName.compareTo(b.categoryName);
        if (catCompare != 0) return catCompare;
        return a.sortOrder.compareTo(b.sortOrder);
      });

      return list;
    });
  }

  // ==========================================================
  // ADD SUBCATEGORY
  // ==========================================================

  Future<String> addSubcategory(SubcategoryModel subcategory) async {
    final docRef = await _subcategoriesCollection.add({
      ...subcategory.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // ==========================================================
  // UPDATE SUBCATEGORY
  // ==========================================================

  Future<void> updateSubcategory(SubcategoryModel subcategory) async {
    if (subcategory.id.isEmpty) {
      throw Exception('Subcategory ID cannot be empty');
    }

    await _subcategoriesCollection.doc(subcategory.id).update({
      ...subcategory.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================
  // TOGGLE ACTIVE STATUS
  // ==========================================================

  Future<void> toggleActive(String id, bool isActive) async {
    await _subcategoriesCollection.doc(id).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================
  // DELETE SUBCATEGORY
  // ==========================================================

  Future<void> deleteSubcategory(String id) async {
    if (id.isEmpty) return;
    await _subcategoriesCollection.doc(id).delete();
  }
}
