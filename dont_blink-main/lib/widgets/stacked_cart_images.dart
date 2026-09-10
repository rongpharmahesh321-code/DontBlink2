import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import 'cached_product_image.dart';

class StackedCartImages extends StatelessWidget {
  final List<CartItem> items;
  final double size;
  final double overlap;
  final int maxVisible;

  const StackedCartImages({
    super.key,
    required this.items,
    this.size = 44,
    this.overlap = 18,
    this.maxVisible = 3,
  });

  @override
  Widget build(BuildContext context) {
    // Filter active items in the cart with valid quantities
    final validItems = items.where((item) => item.quantity > 0).toList();

    if (validItems.isEmpty) {
      return _buildFallback();
    }

    final int totalCount = validItems.length;
    final int displayCount = totalCount > maxVisible ? maxVisible : totalCount;
    // Show newest items on top/right by taking the last displayCount items
    final displayItems = validItems.length > maxVisible
        ? validItems.sublist(validItems.length - maxVisible)
        : validItems;
    final int remaining = totalCount - displayCount;

    final double stackWidth = size + ((displayCount - 1) * overlap);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: stackWidth,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = 0; i < displayItems.length; i++)
              Positioned(
                left: i * overlap,
                top: 0,
                child: _buildItemThumbnail(displayItems[i]),
              ),
            if (remaining > 0)
              Positioned(
                right: -4,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF168A43),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    '+$remaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemThumbnail(CartItem cartItem) {
    final product = cartItem.product;
    final imageUrl = product.image.trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(2),
              child: CachedProductImage(
                url: imageUrl,
                width: size - 4,
                height: size - 4,
                fit: BoxFit.contain,
                placeholder: _placeholder(),
                errorWidget: _placeholder(),
              ),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: Icon(
        Icons.shopping_bag_outlined,
        color: Colors.grey.shade400,
        size: size * 0.45,
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.shopping_bag_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}
