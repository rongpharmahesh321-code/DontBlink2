import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/address.dart';

class AddressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==========================================================
  // ADDRESS COLLECTION
  // ==========================================================

  CollectionReference<Map<String, dynamic>> get _addressCollection {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    return _firestore.collection('users').doc(user.uid).collection('addresses');
  }

  // ==========================================================
  // ADD ADDRESS
  // ==========================================================

  Future<void> addAddress(Address address) async {
    // --------------------------------------------------------
    // If this address is default, remove default from
    // all other addresses first.
    // --------------------------------------------------------

    if (address.isDefault) {
      await _removeOtherDefaults();
    }

    await _addressCollection.add(address.toMap());
  }

  // ==========================================================
  // GET ADDRESSES
  // ==========================================================

  Stream<List<Address>> getAddresses() {
    return _addressCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Address.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  // ==========================================================
  // GET DEFAULT ADDRESS
  // ==========================================================

  Stream<Address?> getDefaultAddress() {
    return _addressCollection
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }

          final doc = snapshot.docs.first;

          return Address.fromFirestore(doc.id, doc.data());
        });
  }

  // ==========================================================
  // DELETE ADDRESS
  // ==========================================================

  Future<void> deleteAddress(String id) async {
    await _addressCollection.doc(id).delete();
  }

  // ==========================================================
  // UPDATE ADDRESS
  // ==========================================================

  Future<void> updateAddress(Address address) async {
    if (address.isDefault) {
      await _removeOtherDefaults(exceptId: address.id);
    }

    await _addressCollection.doc(address.id).update(address.toMap());
  }

  // ==========================================================
  // SELECT EXISTING ADDRESS AS DEFAULT
  // ==========================================================

  Future<void> selectAddress(String addressId) async {
    // --------------------------------------------------------
    // Remove default from every other address.
    // --------------------------------------------------------

    await _removeOtherDefaults(exceptId: addressId);

    // --------------------------------------------------------
    // Make selected address default.
    // --------------------------------------------------------

    await _addressCollection.doc(addressId).update({
      'isDefault': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================
  // REMOVE OTHER DEFAULT ADDRESSES
  // ==========================================================

  Future<void> _removeOtherDefaults({String? exceptId}) async {
    final snapshot = await _addressCollection.get();

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      if (doc.id == exceptId) {
        continue;
      }

      final data = doc.data();

      if (data['isDefault'] == true) {
        batch.update(doc.reference, {
          'isDefault': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  // ==========================================================
  // SAVE MAP / CURRENT LOCATION
  //
  // This creates or updates the selected location and makes
  // it the DEFAULT delivery address.
  // ==========================================================

  Future<void> saveSelectedLocation({
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    // --------------------------------------------------------
    // USER INFORMATION
    // --------------------------------------------------------

    final fullName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : 'Delivery Address';

    final phone = user.phoneNumber ?? '';

    // --------------------------------------------------------
    // CHECK FOR EXISTING LOCATION
    // --------------------------------------------------------

    final existing = await _addressCollection
        .where('latitude', isEqualTo: latitude)
        .where('longitude', isEqualTo: longitude)
        .limit(1)
        .get();

    // --------------------------------------------------------
    // FIRST REMOVE DEFAULT FROM OTHER ADDRESSES
    // --------------------------------------------------------

    await _removeOtherDefaults(
      exceptId: existing.docs.isNotEmpty ? existing.docs.first.id : null,
    );

    // --------------------------------------------------------
    // ADDRESS DATA
    // --------------------------------------------------------

    final data = {
      'fullName': fullName,

      'phone': phone,

      // Complete reverse-geocoded address.
      'house': address,

      'area': '',

      'city': '',

      'state': '',

      'pincode': '',

      // THIS IS THE IMPORTANT PART.
      'isDefault': true,

      'latitude': latitude,

      'longitude': longitude,

      'updatedAt': FieldValue.serverTimestamp(),
    };

    // --------------------------------------------------------
    // UPDATE EXISTING LOCATION
    // --------------------------------------------------------

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.set(data, SetOptions(merge: true));

      return;
    }

    // --------------------------------------------------------
    // CREATE NEW LOCATION
    // --------------------------------------------------------

    await _addressCollection.add(data);
  }
}
