import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/address.dart';

class AddressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _addressCollection {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    return _firestore.collection("users").doc(user.uid).collection("addresses");
  }

  Future<void> addAddress(Address address) async {
    await _addressCollection.add(address.toMap());
  }

  Stream<List<Address>> getAddresses() {
    return _addressCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Address.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  Future<void> deleteAddress(String id) async {
    await _addressCollection.doc(id).delete();
  }

  Future<void> updateAddress(Address address) async {
    await _addressCollection.doc(address.id).update(address.toMap());
  }
}
