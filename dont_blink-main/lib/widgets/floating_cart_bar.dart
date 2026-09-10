import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../screens/checkout_screen.dart';
import '../theme/app_colors.dart';
import 'stacked_cart_images.dart';

class FloatingCartBar extends StatelessWidget {
  final double bottomPadding;
  final EdgeInsetsGeometry? margin;

  const FloatingCartBar({
    super.key,
    this.bottomPadding = 12,
    this.margin,
  });

  double _parsePrice(String price) {
    final cleaned = price.replaceAll(RegExp(r'[^0-9.]'), '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  double _cartTotal(List<CartItem> items) {
    return items.fold<double>(
      0,
      (sum, item) => sum + (_parsePrice(item.product.price) * item.quantity),
    );
  }

  int _cartCount(List<CartItem> items) {
    return items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '₹${value.toInt()}';
    }
    return '₹${value.toStringAsFixed(2)}';
  }

  void _openCheckout(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<CartProvider>().items;
    final count = _cartCount(items);

    if (count <= 0) {
      return const SizedBox.shrink();
    }

    final total = _cartTotal(items);

    return SafeArea(
      top: false,
      child: Padding(
        padding: margin ?? EdgeInsets.fromLTRB(14, 0, 14, bottomPadding),
        child: Material(
          color: Colors.transparent,
          child: Container(
            height: 62,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openCheckout(context),
              child: Row(
                children: [
                  StackedCartImages(
                    items: items,
                    size: 48,
                    overlap: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$count ${count == 1 ? 'Item' : 'Items'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatPrice(total),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View cart',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.primary,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
