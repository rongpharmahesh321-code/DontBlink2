import 'product.dart';

class Wishlist {
  static List<Product> items = [];

  static void toggle(Product product) {
    if (items.any((item) => item.name == product.name)) {
      items.removeWhere((item) => item.name == product.name);
    } else {
      items.add(product);
    }
  }

  static bool contains(Product product) {
    return items.any((item) => item.name == product.name);
  }
}
