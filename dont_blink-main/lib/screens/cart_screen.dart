import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // ==========================================================
  // PRICE PARSER
  // ==========================================================

  double _parsePrice(String price) {
    final cleaned = price.replaceAll(RegExp(r'[^0-9.]'), '').trim();

    return double.tryParse(cleaned) ?? 0;
  }

  // ==========================================================
  // FORMAT PRICE
  // ==========================================================

  String _formatPrice(double price) {
    if (price % 1 == 0) {
      return '₹${price.toInt()}';
    }

    return '₹${price.toStringAsFixed(2)}';
  }

  // ==========================================================
  // REMOVE ITEM
  // ==========================================================

  void _removeItem(BuildContext context, CartItem item) {
    context.read<CartProvider>().remove(item.product);
  }

  // ==========================================================
  // ADD ITEM
  // ==========================================================

  void _addItem(BuildContext context, CartItem item) {
    final currentQuantity = item.quantity;

    if (item.product.stock > 0 && currentQuantity >= item.product.stock) {
      _showMessage('You have reached the available stock.');

      return;
    }

    context.read<CartProvider>().add(item.product);
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),

          behavior: SnackBarBehavior.floating,

          duration: const Duration(seconds: 2),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ==========================================================
  // CLEAR CART
  // ==========================================================

  void _clearCart(BuildContext context) {
    showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),

              SizedBox(width: 10),

              Text('Clear Cart?'),
            ],
          ),

          content: const Text('Remove all items from your cart?'),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: const Text('CANCEL'),
            ),

            ElevatedButton(
              onPressed: () {
                context.read<CartProvider>().clear();

                Navigator.pop(dialogContext);
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,

                foregroundColor: Colors.white,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              child: const Text('CLEAR'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // EMPTY CART
  // ==========================================================

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Container(
              width: 120,
              height: 120,

              decoration: BoxDecoration(
                color: Colors.green.shade50,

                shape: BoxShape.circle,
              ),

              child: const Icon(
                Icons.shopping_cart_outlined,

                size: 58,

                color: Colors.green,
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Your cart is empty',

              textAlign: TextAlign.center,

              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 8),

            Text(
              'Add your favourite products\n'
              'and get them delivered quickly.',

              textAlign: TextAlign.center,

              style: TextStyle(
                color: Colors.grey.shade600,

                fontSize: 14,

                height: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

              decoration: BoxDecoration(
                color: Colors.green.shade50,

                borderRadius: BorderRadius.circular(20),
              ),

              child: const Row(
                mainAxisSize: MainAxisSize.min,

                children: [
                  Icon(Icons.bolt_rounded, color: Colors.green, size: 18),

                  SizedBox(width: 5),

                  Text(
                    'Fast delivery to your doorstep',

                    style: TextStyle(
                      color: Colors.green,

                      fontWeight: FontWeight.w600,

                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ==========================================================
  // CART ITEM CARD
  // ==========================================================

  Widget _buildCartItem(BuildContext context, CartItem item) {
    final product = item.product;

    final price = _parsePrice(product.price);

    final itemTotal = price * item.quantity;

    final canAddMore = product.stock > 0 && item.quantity < product.stock;

    final bool lowStock = product.stock > 0 && product.stock <= 5;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.grey.shade100),

        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
            spreadRadius: -4,
          ),
        ],
      ),

      child: Padding(
        padding: const EdgeInsets.all(12),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ==================================================
            // PRODUCT IMAGE
            // ==================================================
            Container(
              width: 88,
              height: 88,

              decoration: BoxDecoration(
                color: Colors.green.shade50,

                borderRadius: BorderRadius.circular(14),
              ),

              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),

                child: product.image.trim().isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.shopping_bag_outlined,

                          color: Colors.green,

                          size: 38,
                        ),
                      )
                    : Image.network(
                        product.image,

                        width: 88,
                        height: 88,

                        fit: BoxFit.contain,

                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }

                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.green,

                              strokeWidth: 2,
                            ),
                          );
                        },

                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,

                              color: Colors.grey,

                              size: 30,
                            ),
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(width: 13),

            // ==================================================
            // PRODUCT INFORMATION
            // ==================================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // ============================================
                  // PRODUCT NAME
                  // ============================================
                  Text(
                    product.name,

                    maxLines: 2,

                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      fontSize: 16,

                      fontWeight: FontWeight.w700,

                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // ============================================
                  // WEIGHT
                  // ============================================
                  if (product.weight.trim().isNotEmpty)
                    Text(
                      product.weight,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        color: Colors.grey.shade600,

                        fontSize: 12,

                        fontWeight: FontWeight.w500,
                      ),
                    ),

                  const SizedBox(height: 7),

                  // ============================================
                  // PRICE
                  // ============================================
                  Text(
                    _formatPrice(price),

                    style: const TextStyle(
                      color: Colors.green,

                      fontSize: 16,

                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 3),

                  // ============================================
                  // ITEM TOTAL
                  // ============================================
                  Text(
                    '₹${_formatPrice(itemTotal).replaceFirst('₹', '')} total',

                    style: TextStyle(
                      color: Colors.grey.shade600,

                      fontSize: 11,

                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // ============================================
                  // DELIVERY
                  // ============================================
                  Row(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      const Icon(
                        Icons.bolt_rounded,

                        color: Colors.green,

                        size: 14,
                      ),

                      const SizedBox(width: 3),

                      Text(
                        '${product.deliveryTime} min delivery',

                        style: TextStyle(
                          color: Colors.grey.shade600,

                          fontSize: 10,

                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // ============================================
                  // LOW STOCK
                  // ============================================
                  if (lowStock) ...[
                    const SizedBox(height: 4),

                    Text(
                      'Only ${product.stock} left',

                      style: const TextStyle(
                        color: Colors.orange,

                        fontSize: 10,

                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ==================================================
            // QUANTITY CONTROL
            // ==================================================
            Column(
              children: [
                Container(
                  height: 38,

                  decoration: BoxDecoration(
                    color: Colors.green,

                    borderRadius: BorderRadius.circular(11),
                  ),

                  child: Row(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      // ------------------------------------------
                      // MINUS
                      // ------------------------------------------
                      InkWell(
                        onTap: () {
                          _removeItem(context, item);
                        },

                        borderRadius: BorderRadius.circular(11),

                        child: const SizedBox(
                          width: 30,
                          height: 38,

                          child: Center(
                            child: Icon(
                              Icons.remove,

                              color: Colors.white,

                              size: 17,
                            ),
                          ),
                        ),
                      ),

                      // ------------------------------------------
                      // QUANTITY
                      // ------------------------------------------
                      SizedBox(
                        width: 22,

                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),

                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,

                              child: child,
                            );
                          },

                          child: Text(
                            '${item.quantity}',

                            key: ValueKey(item.quantity),

                            textAlign: TextAlign.center,

                            style: const TextStyle(
                              color: Colors.white,

                              fontSize: 13,

                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                      // ------------------------------------------
                      // PLUS
                      // ------------------------------------------
                      InkWell(
                        onTap: canAddMore
                            ? () {
                                _addItem(context, item);
                              }
                            : null,

                        borderRadius: BorderRadius.circular(11),

                        child: SizedBox(
                          width: 30,
                          height: 38,

                          child: Center(
                            child: Icon(
                              Icons.add,

                              color: canAddMore ? Colors.white : Colors.white38,

                              size: 17,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 5),

                // ==============================================
                // STOCK
                // ==============================================
                if (product.stock > 0)
                  Text(
                    '${product.stock} left',

                    style: TextStyle(
                      color: lowStock ? Colors.orange : Colors.grey.shade500,

                      fontSize: 9,

                      fontWeight: lowStock ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // CART HEADER
  // ==========================================================

  Widget _buildCartHeader(List<CartItem> items) {
    final itemCount = items.fold<int>(0, (sum, item) => sum + item.quantity);

    return Container(
      width: double.infinity,

      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),

      decoration: BoxDecoration(
        color: Colors.green.shade50,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: Colors.green.shade100),
      ),

      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,

            decoration: BoxDecoration(
              color: Colors.white,

              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.shopping_cart,
              color: Colors.green,
              size: 19,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  '$itemCount ${itemCount == 1 ? 'item' : 'items'}',

                  style: const TextStyle(
                    fontSize: 15,

                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  'Ready for checkout',

                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),

          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
        ],
      ),
    );
  }
  // ==========================================================
  // BILL SUMMARY
  // ==========================================================

  Widget _buildBillSummary({
    required double subtotal,
    required double savings,
    required int itemCount,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.grey.shade100),

        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
            spreadRadius: -4,
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            'Bill Summary',

            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 14),

          // ====================================================
          // ITEM TOTAL
          // ====================================================
          Row(
            children: [
              Expanded(
                child: Text(
                  'Item total',

                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
              ),

              Text(
                _formatPrice(subtotal),

                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ====================================================
          // DELIVERY FEE
          // ====================================================
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Delivery fee',

                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(width: 5),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(5),
                      ),

                      child: const Text(
                        'AT CHECKOUT',

                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                'Calculated later',

                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Divider(height: 1, color: Colors.grey.shade200),

          const SizedBox(height: 12),

          // ====================================================
          // SAVINGS
          // ====================================================
          if (savings > 0)
            Container(
              width: double.infinity,

              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),

              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),

              child: Row(
                children: [
                  const Icon(
                    Icons.local_offer_outlined,
                    color: Colors.green,
                    size: 18,
                  ),

                  const SizedBox(width: 7),

                  Expanded(
                    child: Text(
                      'You are saving ${_formatPrice(savings)} on this order',

                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (savings > 0) const SizedBox(height: 12),

          // ====================================================
          // TOTAL
          // ====================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,

            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Cart total',

                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      '$itemCount ${itemCount == 1 ? 'item' : 'items'}',

                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                _formatPrice(subtotal),

                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // CHECKOUT BUTTON
  // ==========================================================

  Widget _buildCheckoutButton({
    required BuildContext context,
    required List<CartItem> items,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),

      decoration: const BoxDecoration(
        color: Colors.white,

        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),

      child: SafeArea(
        top: false,

        child: SizedBox(
          width: double.infinity,
          height: 54,

          child: ElevatedButton(
            onPressed: items.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                    );
                  },

            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,

              disabledBackgroundColor: Colors.grey.shade300,

              disabledForegroundColor: Colors.grey.shade600,

              elevation: 0,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),

            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Icon(Icons.shopping_bag_outlined, size: 22),

                SizedBox(width: 8),

                Text(
                  'Proceed to Checkout',

                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),

                SizedBox(width: 5),

                Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // DELIVERY PROMISE
  // ==========================================================

  Widget _buildDeliveryPromise(List<CartItem> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    int fastestDelivery = items.first.product.deliveryTime;

    for (final item in items) {
      if (item.product.deliveryTime < fastestDelivery) {
        fastestDelivery = item.product.deliveryTime;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),

      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(13),

        border: Border.all(color: Colors.green.shade100),
      ),

      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,

            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.green,
              size: 19,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Fast delivery',

                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),

                const SizedBox(height: 2),

                Text(
                  'Estimated from $fastestDelivery minutes',

                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                ),
              ],
            ),
          ),

          const Icon(Icons.check_circle, color: Colors.green, size: 19),
        ],
      ),
    );
  }
  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final items = cartProvider.items;

        // ======================================================
        // CALCULATE SUBTOTAL
        // ======================================================

        double subtotal = 0;

        for (final item in items) {
          final price = _parsePrice(item.product.price);

          subtotal += price * item.quantity;
        }

        // ======================================================
        // CALCULATE SAVINGS
        // ======================================================

        double savings = 0;

        for (final item in items) {
          final discount = item.product.discount;

          if (discount > 0) {
            final price = _parsePrice(item.product.price);

            savings += (price * item.quantity * discount) / 100;
          }
        }

        // ======================================================
        // TOTAL ITEM QUANTITY
        // ======================================================

        final totalQuantity = items.fold<int>(
          0,
          (sum, item) => sum + item.quantity,
        );

        return Scaffold(
          backgroundColor: const Color(0xffF7F8FA),

          // ====================================================
          // APP BAR
          // ====================================================
          appBar: AppBar(
            backgroundColor: Colors.green,

            foregroundColor: Colors.white,

            elevation: 0,

            centerTitle: true,

            title: const Text(
              'My Cart',

              style: TextStyle(fontWeight: FontWeight.w700),
            ),

            actions: [
              if (items.isNotEmpty)
                IconButton(
                  tooltip: 'Clear cart',

                  onPressed: () {
                    _clearCart(context);
                  },

                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),

          // ====================================================
          // EMPTY / CART
          // ====================================================
          body: items.isEmpty
              ? _buildEmptyCart()
              : Column(
                  children: [
                    // ==========================================
                    // SCROLLABLE CONTENT
                    // ==========================================
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),

                        padding: const EdgeInsets.only(top: 2, bottom: 10),

                        children: [
                          // ====================================
                          // CART HEADER
                          // ====================================
                          _buildCartHeader(items),

                          // ====================================
                          // DELIVERY PROMISE
                          // ====================================
                          _buildDeliveryPromise(items),

                          const SizedBox(height: 6),

                          // ====================================
                          // CART ITEMS
                          // ====================================
                          ...items.map((item) {
                            return _buildCartItem(context, item);
                          }),

                          const SizedBox(height: 4),

                          // ====================================
                          // BILL SUMMARY
                          // ====================================
                          _buildBillSummary(
                            subtotal: subtotal,

                            savings: savings,

                            itemCount: totalQuantity,
                          ),

                          const SizedBox(height: 10),

                          // ====================================
                          // TRUST INFORMATION
                          // ====================================
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),

                            padding: const EdgeInsets.all(14),

                            decoration: BoxDecoration(
                              color: Colors.white,

                              borderRadius: BorderRadius.circular(16),

                              border: Border.all(color: Colors.grey.shade100),
                            ),

                            child: Row(
                              children: [
                                // ==================================
                                // SECURE
                                // ==================================
                                Expanded(
                                  child: _trustItem(
                                    Icons.verified_outlined,

                                    'Secure',
                                  ),
                                ),

                                Container(
                                  width: 1,
                                  height: 28,

                                  color: Colors.grey.shade200,
                                ),

                                // ==================================
                                // FRESH
                                // ==================================
                                Expanded(
                                  child: _trustItem(
                                    Icons.local_shipping_outlined,

                                    'Fast delivery',
                                  ),
                                ),

                                Container(
                                  width: 1,
                                  height: 28,

                                  color: Colors.grey.shade200,
                                ),

                                // ==================================
                                // SUPPORT
                                // ==================================
                                Expanded(
                                  child: _trustItem(
                                    Icons.support_agent_outlined,

                                    'Support',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ==========================================
                    // CHECKOUT BUTTON
                    // ==========================================
                    _buildCheckoutButton(context: context, items: items),
                  ],
                ),
        );
      },
    );
  }

  // ==========================================================
  // TRUST ITEM
  // ==========================================================

  Widget _trustItem(IconData icon, String title) {
    return Column(
      mainAxisSize: MainAxisSize.min,

      children: [
        Icon(icon, color: Colors.green, size: 21),

        const SizedBox(height: 4),

        Text(
          title,

          textAlign: TextAlign.center,

          maxLines: 1,

          overflow: TextOverflow.ellipsis,

          style: TextStyle(
            color: Colors.grey.shade700,

            fontSize: 10,

            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
