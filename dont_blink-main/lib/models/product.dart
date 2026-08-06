class Product {
  final String id;
  final String name;
  final String price;
  final String image;
  final String category;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.image,
    required this.category,
  });

  factory Product.fromFirestore(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      name: data['name'] ?? '',
      price: data['price'] ?? '',
      image: data['image'] ?? '',
      category: data['category'] ?? '',
    );
  }
}
