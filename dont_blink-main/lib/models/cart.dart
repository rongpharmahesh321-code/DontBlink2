import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../widgets/cached_product_image.dart';
import 'product.dart';
import 'cart_item.dart';

class Cart {
  // ==========================================================
  // CART ITEMS
  // ==========================================================

  static List<CartItem> items = [];

  // ==========================================================
  // CART CHANGE LISTENER
  //
  // Every time the cart changes, this value changes.
  // HomeScreen can listen to it and rebuild automatically.
  // ==========================================================

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  // ==========================================================
  // NOTIFY CART CHANGE
  // ==========================================================

  static void _notifyChange() {
    changes.value++;
  }

  // ==========================================================
  // ADD TO CART
  // ==========================================================

  static bool add(Product product) {
    if (!product.isAvailable || product.stock <= 0) {
      return false;
    }

    final url = product.image.trim();
    if (url.isNotEmpty) {
      try {
        CachedProductImage.provider(url)
            .resolve(ImageConfiguration.empty)
            .addListener(ImageStreamListener((_, _) {}, onError: (_, _) {}));
      } catch (_) {}
    }

    for (final item in items) {
      if (item.product.id == product.id) {
        // The cart can never contain more units than current stock.
        if (item.quantity >= product.stock) {
          return false;
        }

        item.quantity++;
        _notifyChange();
        return true;
      }
    }

    items.add(CartItem(product: product));
    _notifyChange();
    return true;
  }

  // ==========================================================
  // REMOVE FROM CART
  // ==========================================================

  static void remove(Product product) {
    for (int i = 0; i < items.length; i++) {
      if (items[i].product.id == product.id) {
        if (items[i].quantity > 1) {
          items[i].quantity--;
        } else {
          items.removeAt(i);
        }

        _notifyChange();
        return;
      }
    }
  }

  // ==========================================================
  // GET PRODUCT QUANTITY
  // ==========================================================

  static int getQuantity(Product product) {
    for (var item in items) {
      if (item.product.id == product.id) {
        return item.quantity;
      }
    }

    return 0;
  }

  // ==========================================================
  // TOTAL ITEMS
  //
  // Example:
  // Milk × 2
  // Bread × 1
  //
  // totalItems = 3
  // ==========================================================

  static int get totalItems {
    int total = 0;

    for (var item in items) {
      total += item.quantity;
    }

    return total;
  }

  // ==========================================================
  // IS EMPTY
  // ==========================================================

  static bool get isEmpty {
    return items.isEmpty;
  }

  // ==========================================================
  // CLEAR CART
  // ==========================================================

  static void clear() {
    if (items.isEmpty) {
      return;
    }

    items.clear();

    _notifyChange();
  }

  // ==========================================================
  // TOTAL PRICE
  // ==========================================================

  static double get totalPrice {
    double total = 0;

    for (var item in items) {
      final cleanedPrice = item.product.price
          .replaceAll(RegExp(r'[^0-9.]'), '')
          .trim();

      final price = double.tryParse(cleanedPrice) ?? 0;

      total += price * item.quantity;
    }

    return total;
  }
}
