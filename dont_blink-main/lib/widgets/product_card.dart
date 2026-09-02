import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/wishlist.dart';

import '../providers/cart_provider.dart';
import '../screens/product_details_screen.dart';

class ProductCard extends StatefulWidget {
  final Product product;

  final VoidCallback? onWishlistChanged;

  const ProductCard({super.key, required this.product, this.onWishlistChanged});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with SingleTickerProviderStateMixin {
  // ==========================================================
  // ANIMATION
  // ==========================================================

  late final AnimationController _pressController;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _pressController = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 100),

      lowerBound: 0.0,

      upperBound: 0.03,
    );
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _pressController.dispose();

    super.dispose();
  }

  // ==========================================================
  // OPEN PRODUCT DETAILS
  // ==========================================================

  Future<void> _openProductDetails() async {
    await Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(product: widget.product),
      ),
    );

    if (!mounted) {
      return;
    }

    widget.onWishlistChanged?.call();

    // Refresh cart UI after returning.
    context.read<CartProvider>().refresh();
  }

  // ==========================================================
  // WISHLIST
  // ==========================================================

  void _toggleWishlist() {
    setState(() {
      Wishlist.toggle(widget.product);
    });

    widget.onWishlistChanged?.call();
  }

  // ==========================================================
  // PRICE
  // ==========================================================

  String _getPriceText() {
    final price = widget.product.price.trim();

    if (price.isEmpty) {
      return '₹0';
    }

    if (price.startsWith('₹')) {
      return price;
    }

    return '₹$price';
  }

  // ==========================================================
  // IMAGE PLACEHOLDER
  // ==========================================================

  Widget _imagePlaceholder() {
    return Container(
      width: double.infinity,

      height: double.infinity,

      decoration: BoxDecoration(
        color: Colors.green.shade50,

        borderRadius: BorderRadius.circular(16),
      ),

      child: const Center(
        child: Icon(Icons.shopping_bag_outlined, color: Colors.green, size: 52),
      ),
    );
  }

  // ==========================================================
  // PRODUCT IMAGE
  // ==========================================================

  Widget _buildProductImage() {
    final image = widget.product.image.trim();

    return Hero(
      tag: widget.product.id,

      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),

        child: image.isEmpty
            ? _imagePlaceholder()
            : Image.network(
                image,

                width: double.infinity,

                height: double.infinity,

                fit: BoxFit.contain,

                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return Container(
                    color: Colors.green.shade50,

                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.green,

                        strokeWidth: 2,
                      ),
                    ),
                  );
                },

                errorBuilder: (context, error, stackTrace) {
                  return _imagePlaceholder();
                },
              ),
      ),
    );
  }

  // ==========================================================
  // DELIVERY BADGE
  // ==========================================================

  Widget _buildDeliveryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),

      decoration: BoxDecoration(
        color: Colors.green.shade50,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.green.shade100),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          const Icon(Icons.bolt_rounded, color: Colors.green, size: 14),

          const SizedBox(width: 3),

          Text(
            '${widget.product.deliveryTime} min',

            style: const TextStyle(
              color: Colors.green,

              fontSize: 10,

              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // WISHLIST BUTTON
  // ==========================================================

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

            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,

                child: FadeTransition(opacity: animation, child: child),
              );
            },

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
  // ==========================================================
  // DISCOUNT BADGE
  // ==========================================================

  Widget _buildDiscountBadge() {
    final discount = widget.product.discount;

    if (discount <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      decoration: BoxDecoration(
        color: Colors.red.shade600,

        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(7),
          topRight: Radius.circular(7),
          bottomRight: Radius.circular(7),
        ),
      ),

      child: Text(
        '$discount% OFF',

        style: const TextStyle(
          color: Colors.white,

          fontSize: 9,

          fontWeight: FontWeight.w800,

          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ==========================================================
  // ADD BUTTON
  // ==========================================================

  Widget _buildAddButton(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 36,

      child: ElevatedButton(
        onPressed: () {
          context.read<CartProvider>().add(widget.product);
        },

        style: ElevatedButton.styleFrom(
          elevation: 0,

          backgroundColor: Colors.green,

          foregroundColor: Colors.white,

          padding: EdgeInsets.zero,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),

        child: const Text(
          'ADD',

          style: TextStyle(
            fontSize: 12,

            fontWeight: FontWeight.w800,

            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // QUANTITY CONTROL
  // ==========================================================

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
        color: Colors.green,

        borderRadius: BorderRadius.circular(10),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          // ====================================================
          // MINUS
          // ====================================================
          InkWell(
            onTap: () {
              context.read<CartProvider>().remove(widget.product);
            },

            borderRadius: BorderRadius.circular(10),

            child: const SizedBox(
              width: 28,
              height: 36,

              child: Center(
                child: Icon(Icons.remove, color: Colors.white, size: 17),
              ),
            ),
          ),

          // ====================================================
          // QUANTITY
          // ====================================================
          SizedBox(
            width: 20,

            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),

              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },

              child: Text(
                '$quantity',

                key: ValueKey(quantity),

                textAlign: TextAlign.center,

                style: const TextStyle(
                  color: Colors.white,

                  fontSize: 12,

                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          // ====================================================
          // PLUS
          // ====================================================
          InkWell(
            onTap: canAddMore
                ? () {
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

                  color: canAddMore ? Colors.white : Colors.white38,

                  size: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // OUT OF STOCK BUTTON
  // ==========================================================

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

  // ==========================================================
  // PRICE SECTION
  // ==========================================================

  Widget _buildPriceSection() {
    final price = _getPriceText();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),

      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,

          child: ScaleTransition(
            scale: animation,

            alignment: Alignment.centerLeft,

            child: child,
          ),
        );
      },

      child: Text(
        price,

        key: ValueKey(price),

        maxLines: 1,

        overflow: TextOverflow.ellipsis,

        style: const TextStyle(
          color: Colors.green,

          fontSize: 19,

          fontWeight: FontWeight.w800,

          letterSpacing: -0.2,
        ),
      ),
    );
  }

  // ==========================================================
  // STOCK LABEL
  // ==========================================================

  Widget _buildLowStockLabel() {
    final stock = widget.product.stock;

    if (stock <= 0 || stock > 5) {
      return const SizedBox.shrink();
    }

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

  // ==========================================================
  // PRESS SCALE
  // ==========================================================

  Widget _buildPressScale(Widget child) {
    return AnimatedBuilder(
      animation: _pressController,

      builder: (context, child) {
        final scale = 1 - _pressController.value;

        return Transform.scale(scale: scale, child: child);
      },

      child: child,
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();

    final quantity = cartProvider.getQuantity(widget.product);

    final bool outOfStock =
        widget.product.stock <= 0 || !widget.product.isAvailable;

    final bool canAddMore = quantity < widget.product.stock;

    final bool isWishlisted = Wishlist.contains(widget.product);

    return _buildPressScale(
      GestureDetector(
        onTap: _openProductDetails,

        onTapDown: (_) {
          _pressController.forward();
        },

        onTapUp: (_) {
          _pressController.reverse();
        },

        onTapCancel: () {
          _pressController.reverse();
        },

        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(18),

            border: Border.all(color: Colors.grey.shade100, width: 1),

            boxShadow: const [
              BoxShadow(
                color: Colors.black12,

                blurRadius: 10,

                offset: Offset(0, 4),

                spreadRadius: -4,
              ),
            ],
          ),

          child: Padding(
            padding: const EdgeInsets.all(10),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // =================================================
                // IMAGE AREA
                // =================================================
                SizedBox(
                  height: 138,

                  child: Stack(
                    children: [
                      // -------------------------------------------
                      // IMAGE BACKGROUND
                      // -------------------------------------------
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,

                            borderRadius: BorderRadius.circular(16),
                          ),

                          child: _buildProductImage(),
                        ),
                      ),

                      // -------------------------------------------
                      // DELIVERY BADGE
                      // -------------------------------------------
                      Positioned(left: 7, top: 7, child: _buildDeliveryBadge()),

                      // -------------------------------------------
                      // WISHLIST
                      // -------------------------------------------
                      Positioned(
                        right: 7,
                        top: 7,

                        child: _buildWishlistButton(isWishlisted),
                      ),

                      // -------------------------------------------
                      // DISCOUNT
                      // -------------------------------------------
                      if (widget.product.discount > 0)
                        Positioned(
                          left: 0,
                          bottom: 0,

                          child: _buildDiscountBadge(),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // =================================================
                // PRODUCT NAME
                // =================================================
                Text(
                  widget.product.name,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 15,

                    fontWeight: FontWeight.w700,

                    letterSpacing: -0.1,
                  ),
                ),

                const SizedBox(height: 3),

                // =================================================
                // WEIGHT / UNIT
                // =================================================
                Text(
                  widget.product.weight.trim().isNotEmpty
                      ? widget.product.weight
                      : '1 unit',

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    color: Colors.grey.shade600,

                    fontSize: 12,

                    fontWeight: FontWeight.w500,
                  ),
                ),

                // =================================================
                // LOW STOCK
                // =================================================
                _buildLowStockLabel(),

                const Spacer(),

                // =================================================
                // PRICE + CART
                // =================================================
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,

                  children: [
                    // ---------------------------------------------
                    // PRICE
                    // ---------------------------------------------
                    Expanded(child: _buildPriceSection()),

                    const SizedBox(width: 6),

                    // ---------------------------------------------
                    // CART CONTROL
                    // ---------------------------------------------
                    if (outOfStock)
                      _buildOutOfStockButton()
                    else if (quantity == 0)
                      _buildAddButton(context)
                    else
                      _buildQuantityControl(context, quantity, canAddMore),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
