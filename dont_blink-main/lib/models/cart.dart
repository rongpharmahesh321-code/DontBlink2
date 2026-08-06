import 'product.dart';
import 'cart_item.dart';

class Cart {
  static List<CartItem> items = [];

  static void add(Product product) {
    for (var item in items) {
      if (item.product.name == product.name) {
        item.quantity++;
        return;
      }
    }

    items.add(CartItem(product: product));
  }

  static void remove(Product product) {
    for (int i = 0; i < items.length; i++) {
      if (items[i].product.name == product.name) {
        if (items[i].quantity > 1) {
          items[i].quantity--;
        } else {
          items.removeAt(i);
        }
        return;
      }
    }
  }

  static int getQuantity(Product product) {
    for (var item in items) {
      if (item.product.name == product.name) {
        return item.quantity;
      }
    }
    return 0;
  }
}
