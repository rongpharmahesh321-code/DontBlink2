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
    };
  }
}
