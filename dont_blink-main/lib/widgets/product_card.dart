import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'cached_product_image.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/wishlist.dart';
import '../providers/cart_provider.dart';
import '../screens/product_details_screen.dart';

/// Blinkit-style ProductCard with layered/lazy image loading.
///
/// Images are NOT precached by every card. A card only creates its network
/// image when it is close to the viewport. This prevents the whole catalogue
/// from downloading at HomeScreen startup.
class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback? onWishlistChanged;

  /// Kept for compatibility with existing category-popup callers.
  /// The grid itself is already lazy, so no per-card eager precache is needed.
  final bool eagerImage;

  const ProductCard({
    super.key,
    required this.product,
    this.onWishlistChanged,
    this.eagerImage = false,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  // Product grids are already lazy (SliverGrid/GridView.builder), so doing
  // viewport calculations and attaching a scroll listener to every card
  // creates more work than it saves. Images now load when Flutter builds the
  // visible card and are decoded to the card size.
  // ----------------------------------------------------------
  // DETAILS / WISHLIST / PRICE
  // ----------------------------------------------------------

  Future<void> _openProductDetails() async {
    FocusManager.instance.primaryFocus?.unfocus();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(product: widget.product),
      ),
    );

    if (!mounted) return;
    widget.onWishlistChanged?.call();
    context.read<CartProvider>().refresh();
  }

  void _toggleWishlist() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => Wishlist.toggle(widget.product));
    widget.onWishlistChanged?.call();
  }

  String _getPriceText() {
    final price = widget.product.price.trim();
    if (price.isEmpty) return '₹0';
    return price.startsWith('₹') ? price : '₹$price';
  }

  // ----------------------------------------------------------
  // IMAGE
  // ----------------------------------------------------------

  Widget _imagePlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.tintGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 52),
      ),
    );
  }

  Widget _buildProductImage() {
    final image = widget.product.image.trim();

    if (image.isEmpty) {
      return _imagePlaceholder();
    }

    return Hero(
      tag: widget.product.id,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedProductImage(
          url: image,
          fit: BoxFit.contain,
          cacheWidth: 360,
          cacheHeight: 360,
          placeholder: _imagePlaceholder(),
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // BADGES / CONTROLS
  // ----------------------------------------------------------

  Widget _buildDeliveryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.tintGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.tintGreenBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 14),
          const SizedBox(width: 3),
          Text(
            '${widget.product.deliveryTime} min',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistButton(bool isWishlisted) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black12,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _toggleWishlist,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              isWishlisted ? Icons.favorite : Icons.favorite_border,
              key: ValueKey(isWishlisted),
              color: isWishlisted ? Colors.red : Colors.grey.shade700,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 36,
      child: ElevatedButton(
        onPressed: () {
          FocusManager.instance.primaryFocus?.unfocus();
          context.read<CartProvider>().add(widget.product);
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.primary,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        child: const Text(
          'ADD',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityControl(
    BuildContext context,
    int quantity,
    bool canAddMore,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              context.read<CartProvider>().remove(widget.product);
            },
            borderRadius: BorderRadius.circular(10),
            child: const SizedBox(
              width: 28,
              height: 36,
              child: Center(
                child: Icon(Icons.remove, color: AppColors.primary, size: 17),
              ),
            ),
          ),
          SizedBox(
            width: 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Text(
                '$quantity',
                key: ValueKey(quantity),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: canAddMore
                ? () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    context.read<CartProvider>().add(widget.product);
                  }
                : null,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 28,
              height: 36,
              child: Center(
                child: Icon(
                  Icons.add,
                  color: canAddMore ? AppColors.primary : AppColors.tintGreenBorder,
                  size: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutOfStockButton() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          'OUT OF STOCK',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    final price = _getPriceText();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: animation,
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
      child: Text(
        price,
        key: ValueKey(price),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildLowStockLabel() {
    final stock = widget.product.stock;
    if (stock <= 0 || stock > 5) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        'Only $stock left',
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final quantity = context.select<CartProvider, int>(
      (provider) => provider.getQuantity(widget.product),
    );

    final bool outOfStock =
        widget.product.stock <= 0 || !widget.product.isAvailable;
    final bool canAddMore = quantity < widget.product.stock;
    final bool isWishlisted = Wishlist.contains(widget.product);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: _openProductDetails,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            color: Colors.white,
                            child: _buildProductImage(),
                          ),
                        ),
                      ),
                      Positioned(left: 6, top: 6, child: _buildDeliveryBadge()),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: _buildWishlistButton(isWishlisted),
                      ),
                    ],
                  ),

                  // Price + ADD/quantity stay exactly on the same row.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _buildPriceSection()),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: outOfStock
                            ? _buildOutOfStockButton()
                            : quantity == 0
                            ? _buildAddButton(context)
                            : _buildQuantityControl(
                                context,
                                quantity,
                                canAddMore,
                              ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    widget.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    widget.product.weight.trim().isNotEmpty
                        ? widget.product.weight
                        : '1 unit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11.5,
                      height: 1.15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  _buildLowStockLabel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
