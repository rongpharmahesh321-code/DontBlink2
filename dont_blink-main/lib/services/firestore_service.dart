import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../models/banner.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // PRODUCTS
  // ============================================================

  // ============================================================
  // GET ALL PRODUCTS
  // ============================================================

  Stream<List<Product>> getProducts() {
    return _firestore.collection('products').snapshots().map((snapshot) {
      final products = snapshot.docs.map((doc) {
        return Product.fromFirestore(doc.id, doc.data());
      }).toList();

      return products;
    });
  }

  // ============================================================
  // GET POPULAR PRODUCTS
  // ============================================================
  //
  // Only products where:
  //
  // isPopular == true
  //
  // are returned.
  //
  // This is controlled from the Admin Dashboard.
  // ============================================================

  Stream<List<Product>> getPopularProducts() {
    return _firestore
        .collection('products')
        .where('isPopular', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final products = snapshot.docs.map((doc) {
            return Product.fromFirestore(doc.id, doc.data());
          }).toList();

          return products;
        });
  }

  // ============================================================
  // GET SINGLE PRODUCT
  // ============================================================

  Future<Product?> getProduct(String productId) async {
    if (productId.trim().isEmpty) {
      return null;
    }

    final doc = await _firestore.collection('products').doc(productId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return Product.fromFirestore(doc.id, doc.data()!);
  }

  // ============================================================
  // ADD PRODUCT
  // ============================================================

  Future<String> addProduct(Product product) async {
    final docRef = await _firestore.collection('products').add({
      ...product.toMap(),

      // --------------------------------------------------------
      // DEFAULT POPULAR STATUS
      // --------------------------------------------------------
      //
      // New products are NOT popular by default.
      //
      // Admin can enable this later.
      // --------------------------------------------------------
      'isPopular': false,

      'createdAt': FieldValue.serverTimestamp(),

      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // ============================================================
  // UPDATE PRODUCT
  // ============================================================

  Future<void> updateProduct(Product product) async {
    if (product.id.trim().isEmpty) {
      throw Exception('Product ID cannot be empty.');
    }

    await _firestore.collection('products').doc(product.id).update({
      ...product.toMap(),

      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // DELETE PRODUCT
  // ============================================================

  Future<void> deleteProduct(String productId) async {
    if (productId.trim().isEmpty) {
      throw Exception('Product ID cannot be empty.');
    }

    await _firestore.collection('products').doc(productId).delete();
  }

  // ============================================================
  // UPDATE PRODUCT STOCK
  // ============================================================

  Future<void> updateStock({
    required String productId,
    required int stock,
  }) async {
    if (productId.trim().isEmpty) {
      throw Exception('Product ID cannot be empty.');
    }

    if (stock < 0) {
      throw Exception('Stock cannot be negative.');
    }

    await _firestore.collection('products').doc(productId).update({
      'stock': stock,

      'isAvailable': stock > 0,

      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // UPDATE PRODUCT AVAILABILITY
  // ============================================================

  Future<void> updateAvailability({
    required String productId,
    required bool isAvailable,
  }) async {
    if (productId.trim().isEmpty) {
      throw Exception('Product ID cannot be empty.');
    }

    await _firestore.collection('products').doc(productId).update({
      'isAvailable': isAvailable,

      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // UPDATE POPULAR STATUS
  // ============================================================
  //
  // true:
  // Product appears in Popular Products.
  //
  // false:
  // Product disappears from Popular Products.
  // ============================================================

  Future<void> updatePopularStatus({
    required String productId,
    required bool isPopular,
  }) async {
    if (productId.trim().isEmpty) {
      throw Exception('Product ID cannot be empty.');
    }

    await _firestore.collection('products').doc(productId).update({
      'isPopular': isPopular,

      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // ORDERS
  // ============================================================

  // ============================================================
  // GET ALL ORDERS
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> getOrders() {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ============================================================
  // BANNERS
  // ============================================================

  // ============================================================
  // GET ACTIVE BANNERS
  // ============================================================
  //
  // Customer HomeScreen uses this stream.
  //
  // Only:
  //
  // isActive == true
  //
  // banners are displayed.
  //
  // They are sorted using:
  //
  // sortOrder
  // ============================================================

  Stream<List<BannerModel>> getActiveBanners() {
    return _firestore
        .collection('banners')
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) {
          final banners = snapshot.docs.map((doc) {
            return BannerModel.fromFirestore(doc.id, doc.data());
          }).toList();

          return banners;
        });
  }

  // ============================================================
  // GET ALL BANNERS
  // ============================================================
  //
  // Admin Dashboard uses this.
  //
  // Both active and inactive banners are returned.
  // ============================================================

  Stream<List<BannerModel>> getAllBanners() {
    return _firestore
        .collection('banners')
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) {
          final banners = snapshot.docs.map((doc) {
            return BannerModel.fromFirestore(doc.id, doc.data());
          }).toList();

          return banners;
        });
  }

  // ============================================================
  // GET SINGLE BANNER
  // ============================================================

  Future<BannerModel?> getBanner(String bannerId) async {
    if (bannerId.trim().isEmpty) {
      return null;
    }

    final doc = await _firestore.collection('banners').doc(bannerId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return BannerModel.fromFirestore(doc.id, doc.data()!);
  }

  // ============================================================
  // ADD BANNER
  // ============================================================

  Future<String> addBanner(BannerModel banner) async {
    final docRef = await _firestore.collection('banners').add({
      ...banner.toMap(),

      'createdAt': FieldValue.serverTimestamp(),

      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // ============================================================
  // UPDATE BANNER
  // ============================================================

  Future<void> updateBanner(BannerModel banner) async {
    if (banner.id.trim().isEmpty) {
      throw Exception('Banner ID cannot be empty.');
    }

    await _firestore.collection('banners').doc(banner.id).update({
      ...banner.toMap(),

      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // DELETE BANNER
  // ============================================================

  Future<void> deleteBanner(String bannerId) async {
    if (bannerId.trim().isEmpty) {
      throw Exception('Banner ID cannot be empty.');
    }

    await _firestore.collection('banners').doc(bannerId).delete();
  }

  // ============================================================
  // UPDATE BANNER STATUS
  // ============================================================
  //
  // Admin can turn a banner ON/OFF without deleting it.
  // ============================================================

  Future<void> updateBannerStatus({
    required String bannerId,
    required bool isActive,
  }) async {
    if (bannerId.trim().isEmpty) {
      throw Exception('Banner ID cannot be empty.');
    }

    await _firestore.collection('banners').doc(bannerId).update({
      'isActive': isActive,

      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // UPDATE BANNER ORDER
  // ============================================================
  //
  // Used later when we allow the Admin to control the
  // order of banners.
  // ============================================================

  Future<void> updateBannerOrder({
    required String bannerId,
    required int sortOrder,
  }) async {
    if (bannerId.trim().isEmpty) {
      throw Exception('Banner ID cannot be empty.');
    }

    await _firestore.collection('banners').doc(bannerId).update({
      'sortOrder': sortOrder,

      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // UPDATE MULTIPLE BANNER ORDERS
  // ============================================================
  //
  // Useful when we build drag-and-drop banner ordering
  // in the Admin Dashboard.
  // ============================================================

  Future<void> updateBannerOrders(List<String> bannerIds) async {
    final batch = _firestore.batch();

    for (int i = 0; i < bannerIds.length; i++) {
      final bannerId = bannerIds[i].trim();

      if (bannerId.isEmpty) {
        continue;
      }

      final ref = _firestore.collection('banners').doc(bannerId);

      batch.update(ref, {
        'sortOrder': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
