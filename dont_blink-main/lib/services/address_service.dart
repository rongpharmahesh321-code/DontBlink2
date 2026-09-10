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
    await _removeOtherDefaults(exceptId: addressId);

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
  // SAVE GOOGLE MAP LOCATION
  //
  // Saves the selected Google Maps location as the
  // user's DEFAULT delivery address.
  // ==========================================================

  Future<void> saveSelectedLocation({
    required String address,
    required double latitude,
    required double longitude,
    String? house,
    String? area,
    String? city,
    String? state,
    String? pincode,
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
    //
    // Coordinates are treated as the source of truth.
    // A small coordinate difference is expected when the
    // customer moves the pin, so we don't rely heavily on
    // exact address-string matching.
    // --------------------------------------------------------

    final existing = await _addressCollection
        .where('latitude', isEqualTo: latitude)
        .where('longitude', isEqualTo: longitude)
        .limit(1)
        .get();

    // --------------------------------------------------------
    // REMOVE DEFAULT FROM OTHER ADDRESSES
    // --------------------------------------------------------

    await _removeOtherDefaults(
      exceptId: existing.docs.isNotEmpty ? existing.docs.first.id : null,
    );

    // --------------------------------------------------------
    // NORMALIZE ADDRESS FIELDS
    // --------------------------------------------------------

    final normalizedHouse = house?.trim().isNotEmpty == true
        ? house!.trim()
        : address.trim();

    final normalizedArea = area?.trim() ?? '';

    final normalizedCity = city?.trim() ?? '';

    final normalizedState = state?.trim() ?? '';

    final normalizedPincode = pincode?.trim() ?? '';

    // --------------------------------------------------------
    // FIRESTORE DATA
    // --------------------------------------------------------

    final data = {
      'fullName': fullName,
      'phone': phone,

      // Structured address.
      'house': normalizedHouse,
      'area': normalizedArea,
      'city': normalizedCity,
      'state': normalizedState,
      'pincode': normalizedPincode,

      // Complete formatted Google address.
      'formattedAddress': address.trim(),

      // Default delivery address.
      'isDefault': true,

      // Exact map location.
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
