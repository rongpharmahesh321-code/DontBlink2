import 'package:flutter/material.dart';

import '../models/cart.dart';
import '../models/product.dart';
import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  // ==========================================================
  // LISTEN TO THE GLOBAL CART
  // ==========================================================

  CartProvider() {
    Cart.changes.addListener(_cartChanged);
  }

  // ==========================================================
  // CART CHANGE CALLBACK
  // ==========================================================

  void _cartChanged() {
    notifyListeners();
  }

  // ==========================================================
  // CART ITEMS
  // ==========================================================

  List<CartItem> get items => Cart.items;

  // ==========================================================
  // ADD
  // ==========================================================

  bool add(Product product) {
    return Cart.add(product);
  }

  // ==========================================================
  // REMOVE
  // ==========================================================

  void remove(Product product) {
    Cart.remove(product);
  }

  // ==========================================================
  // GET QUANTITY
  // ==========================================================

  int getQuantity(Product product) {
    return Cart.getQuantity(product);
  }

  // ==========================================================
  // CLEAR
  // ==========================================================

  void clear() {
    Cart.clear();
  }

  // ==========================================================
  // REFRESH
  // ==========================================================

  void refresh() {
    notifyListeners();
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    Cart.changes.removeListener(_cartChanged);
    super.dispose();
  }
}
