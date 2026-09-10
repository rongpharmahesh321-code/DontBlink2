import 'package:cloud_firestore/cloud_firestore.dart';

class StoreModel {
  final String id;
  final String name;
  final String code;
  final String address;
  final String city;
  final String phone;
  final double latitude;
  final double longitude;
  final double serviceRadiusKm;
  final int priority;
  final String status;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StoreModel({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.city,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.serviceRadiusKm,
    required this.priority,
    required this.status,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  bool get isOpen => isActive && status.toUpperCase() == 'OPEN';

  factory StoreModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    double number(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int integer(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime? date(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return StoreModel(
      id: doc.id,
      name: data['name']?.toString().trim() ?? '',
      code: data['code']?.toString().trim() ?? '',
      address: data['address']?.toString().trim() ?? '',
      city: data['city']?.toString().trim() ?? '',
      phone: data['phone']?.toString().trim() ?? '',
      latitude: number(data['latitude']),
      longitude: number(data['longitude']),
      serviceRadiusKm: number(data['serviceRadiusKm']) <= 0
          ? 5
          : number(data['serviceRadiusKm']),
      priority: integer(data['priority']),
      status: (data['status']?.toString().trim().isEmpty ?? true)
          ? 'OPEN'
          : data['status'].toString().trim().toUpperCase(),
      isActive: data['isActive'] != false,
      createdAt: date(data['createdAt']),
      updatedAt: date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool includeCreatedAt = false}) {
    final data = <String, dynamic>{
      'name': name,
      'code': code,
      'address': address,
      'city': city,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
      'serviceRadiusKm': serviceRadiusKm,
      'priority': priority,
      'status': status,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (includeCreatedAt) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    return data;
  }
}
