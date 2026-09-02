import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/banner.dart';

class BannerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================================
  // BANNERS COLLECTION
  // ==========================================================

  CollectionReference<Map<String, dynamic>> get _banners {
    return _firestore.collection('banners');
  }

  // ==========================================================
  // GET ACTIVE BANNERS
  //
  // Used by HomeScreen.
  // ==========================================================

  Stream<List<BannerModel>> getActiveBanners() {
    return _banners.where('isActive', isEqualTo: true).snapshots().map((
      snapshot,
    ) {
      final banners = snapshot.docs.map((doc) {
        return BannerModel.fromFirestore(doc.id, doc.data());
      }).toList();

      banners.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      return banners;
    });
  }

  // ==========================================================
  // GET ALL BANNERS
  //
  // Used by Admin Dashboard.
  // ==========================================================

  Stream<List<BannerModel>> getAllBanners() {
    return _banners.snapshots().map((snapshot) {
      final banners = snapshot.docs.map((doc) {
        return BannerModel.fromFirestore(doc.id, doc.data());
      }).toList();

      banners.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      return banners;
    });
  }

  // ==========================================================
  // GET SINGLE BANNER
  // ==========================================================

  Future<BannerModel?> getBanner(String bannerId) async {
    if (bannerId.trim().isEmpty) {
      return null;
    }

    final doc = await _banners.doc(bannerId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return BannerModel.fromFirestore(doc.id, doc.data()!);
  }

  // ==========================================================
  // ADD BANNER
  // ==========================================================

  Future<String> addBanner(BannerModel banner) async {
    final doc = await _banners.add({
      ...banner.toMap(),

      'createdAt': FieldValue.serverTimestamp(),

      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  // ==========================================================
  // UPDATE BANNER
  // ==========================================================

  Future<void> updateBanner(BannerModel banner) async {
    if (banner.id.trim().isEmpty) {
      throw Exception('Banner ID cannot be empty.');
    }

    await _banners.doc(banner.id).update({
      ...banner.toMap(),

      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================
  // DELETE BANNER
  // ==========================================================

  Future<void> deleteBanner(String bannerId) async {
    if (bannerId.trim().isEmpty) {
      throw Exception('Banner ID cannot be empty.');
    }

    await _banners.doc(bannerId).delete();
  }

  // ==========================================================
  // TOGGLE ACTIVE
  // ==========================================================

  Future<void> toggleBanner(String bannerId, bool isActive) async {
    if (bannerId.trim().isEmpty) {
      throw Exception('Banner ID cannot be empty.');
    }

    await _banners.doc(bannerId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
