import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/category.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ==========================================
  // CATEGORIES COLLECTION
  // ==========================================

  CollectionReference<Map<String, dynamic>> get _categoriesCollection =>
      _firestore.collection('categories');

  // ==========================================
  // GET ACTIVE CATEGORIES
  // ==========================================

  Stream<List<CategoryModel>> getCategories() {
    return _categoriesCollection.snapshots().map((snapshot) {
      final categories = snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc.id, doc.data()))
          .where((category) => category.isActive)
          .toList();

      categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      return categories;
    });
  }

  // ==========================================
  // GET ALL CATEGORIES
  // ==========================================

  Stream<List<CategoryModel>> getAllCategories() {
    return _categoriesCollection.snapshots().map((snapshot) {
      final categories = snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc.id, doc.data()))
          .toList();

      categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      return categories;
    });
  }

  // ==========================================
  // GET CATEGORIES BY SECTION
  // ==========================================

  Stream<List<CategoryModel>> getCategoriesBySection(String section) {
    return _categoriesCollection.snapshots().map((snapshot) {
      final wantedSection = section.trim().toLowerCase();

      final categories = snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc.id, doc.data()))
          .where(
            (category) =>
                category.isActive &&
                category.section.trim().toLowerCase() == wantedSection,
          )
          .toList();

      categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      return categories;
    });
  }

  // ==========================================
  // ADD CATEGORY
  // ==========================================

  Future<String> addCategory(CategoryModel category) async {
    final docRef = await _categoriesCollection.add(category.toMap());

    return docRef.id;
  }

  // ==========================================
  // UPDATE CATEGORY
  // ==========================================

  Future<void> updateCategory(CategoryModel category) async {
    if (category.id.isEmpty) {
      throw Exception('Category ID cannot be empty.');
    }

    await _categoriesCollection.doc(category.id).update(category.toMap());
  }

  // ==========================================
  // DELETE CATEGORY
  // ==========================================

  Future<void> deleteCategory(String categoryId) async {
    if (categoryId.isEmpty) {
      throw Exception('Category ID cannot be empty.');
    }

    await _categoriesCollection.doc(categoryId).delete();
  }

  // ==========================================
  // ENABLE / DISABLE CATEGORY
  // ==========================================

  Future<void> setCategoryActive({
    required String categoryId,
    required bool isActive,
  }) async {
    await _categoriesCollection.doc(categoryId).update({'isActive': isActive});
  }

  // ==========================================
  // UPDATE CATEGORY ORDER
  // ==========================================

  Future<void> updateSortOrder({
    required String categoryId,
    required int sortOrder,
  }) async {
    await _categoriesCollection.doc(categoryId).update({
      'sortOrder': sortOrder,
    });
  }

  // ==========================================
  // CHECK CATEGORY NAME
  // ==========================================

  Future<bool> categoryNameExists(String name, {String? excludeId}) async {
    final snapshot = await _categoriesCollection
        .where('name', isEqualTo: name.trim())
        .limit(10)
        .get();

    for (final doc in snapshot.docs) {
      if (excludeId != null && doc.id == excludeId) {
        continue;
      }

      return true;
    }

    return false;
  }

  // ==========================================================
  // UPLOAD CATEGORY IMAGE
  // ==========================================================

  Future<String> uploadCategoryImage({
    required String categoryId,
    required Uint8List imageBytes,
    required String fileExtension,
  }) async {
    if (categoryId.trim().isEmpty) {
      throw Exception('Category ID cannot be empty.');
    }

    if (imageBytes.isEmpty) {
      throw Exception('Image is empty.');
    }

    final extension = fileExtension.trim().toLowerCase();

    final safeExtension = extension.isEmpty ? 'jpg' : extension;

    final fileName =
        'category_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    final storagePath = 'categories/$categoryId/$fileName';

    final Reference reference = _storage.ref().child(storagePath);

    String contentType = 'image/jpeg';

    if (safeExtension == 'png') {
      contentType = 'image/png';
    } else if (safeExtension == 'webp') {
      contentType = 'image/webp';
    } else if (safeExtension == 'gif') {
      contentType = 'image/gif';
    }

    final metadata = SettableMetadata(
      contentType: contentType,
      cacheControl: 'public,max-age=86400',
    );

    await reference.putData(imageBytes, metadata);

    final downloadUrl = await reference.getDownloadURL();

    return downloadUrl;
  }

  // ==========================================================
  // DELETE CATEGORY IMAGE
  // ==========================================================

  Future<void> deleteCategoryImage(String imageUrl) async {
    if (imageUrl.trim().isEmpty) {
      return;
    }

    try {
      final reference = _storage.refFromURL(imageUrl);

      await reference.delete();
    } catch (e) {
      // Don't stop category deletion if the
      // old image is already missing.
      //
      // This also handles old/broken image URLs.
      //
      // We deliberately don't throw here.
    }
  }
}
