import 'package:flutter/foundation.dart';

import 'product.dart';

class Wishlist {
  static final List<Product> items = [];

  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static void toggle(Product product) {
    if (contains(product)) {
      items.removeWhere((item) => item.id == product.id);
    } else {
      items.add(product);
    }

    notifier.value++;
  }

  static bool contains(Product product) {
    return items.any((item) => item.id == product.id);
  }

  static void remove(Product product) {
    items.removeWhere((item) => item.id == product.id);
    notifier.value++;
  }

  static void clear() {
    items.clear();
    notifier.value++;
  }
}
