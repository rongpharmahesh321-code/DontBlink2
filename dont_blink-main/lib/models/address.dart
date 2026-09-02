class Address {
  final String id;
  final String fullName;
  final String phone;
  final String house;
  final String area;
  final String city;
  final String state;
  final String pincode;
  final bool isDefault;

  // Location
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
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });

  factory Address.fromFirestore(String id, Map<String, dynamic> data) {
    return Address(
      id: id,
      fullName: data["fullName"] ?? "",
      phone: data["phone"] ?? "",
      house: data["house"] ?? "",
      area: data["area"] ?? "",
      city: data["city"] ?? "",
      state: data["state"] ?? "",
      pincode: data["pincode"] ?? "",
      isDefault: data["isDefault"] ?? false,

      latitude: data["latitude"] != null
          ? (data["latitude"] as num).toDouble()
          : null,

      longitude: data["longitude"] != null
          ? (data["longitude"] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "fullName": fullName,
      "phone": phone,
      "house": house,
      "area": area,
      "city": city,
      "state": state,
      "pincode": pincode,
      "isDefault": isDefault,

      "latitude": latitude,
      "longitude": longitude,
    };
  }
}
