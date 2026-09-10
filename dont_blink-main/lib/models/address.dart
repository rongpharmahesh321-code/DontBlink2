class Address {
  final String id;
  final String fullName;
  final String phone;

  final String house;
  final String area;
  final String city;
  final String state;
  final String pincode;

  // Complete address returned by Google.
  final String formattedAddress;

  final bool isDefault;

  // Exact delivery location.
  final double? latitude;
  final double? longitude;

  Address({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.house,
    required this.area,
    required this.city,
    required this.state,
    required this.pincode,
    this.formattedAddress = '',
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });

  // ==========================================================
  // FIRESTORE → ADDRESS
  // ==========================================================

  factory Address.fromFirestore(String id, Map<String, dynamic> data) {
    return Address(
      id: id,

      fullName: data['fullName']?.toString() ?? '',

      phone: data['phone']?.toString() ?? '',

      house: data['house']?.toString() ?? '',

      area: data['area']?.toString() ?? '',

      city: data['city']?.toString() ?? '',

      state: data['state']?.toString() ?? '',

      pincode: data['pincode']?.toString() ?? '',

      formattedAddress: data['formattedAddress']?.toString() ?? '',

      isDefault: data['isDefault'] == true,

      latitude: data['latitude'] is num
          ? (data['latitude'] as num).toDouble()
          : null,

      longitude: data['longitude'] is num
          ? (data['longitude'] as num).toDouble()
          : null,
    );
  }

  // ==========================================================
  // ADDRESS → FIRESTORE
  // ==========================================================

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phone': phone,

      'house': house,
      'area': area,
      'city': city,
      'state': state,
      'pincode': pincode,

      'formattedAddress': formattedAddress,

      'isDefault': isDefault,

      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
