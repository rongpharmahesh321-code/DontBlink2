import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/cart.dart';
import '../models/wishlist.dart';

import 'cart_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================
  // ANIMATION
  // ==========================================================

  late final AnimationController _animationController;

  late final Animation<double> _fadeAnimation;

  late final Animation<Offset> _slideAnimation;

  late final Animation<double> _imageScaleAnimation;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _imageScaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ==========================================================
  // PRICE
  // ==========================================================

  double _parsePrice(String price) {
    final cleaned = price.replaceAll(RegExp(r'[^0-9.]'), '').trim();

    return double.tryParse(cleaned) ?? 0;
  }

  String _formatPrice(double price) {
    if (price % 1 == 0) {
      return '₹${price.toInt()}';
    }

    return '₹${price.toStringAsFixed(2)}';
  }

  // ==========================================================
  // ADD TO CART
  // ==========================================================

  void _addToCart() {
    if (widget.product.stock <= 0 || !widget.product.isAvailable) {
      return;
    }

    final currentQuantity = Cart.getQuantity(widget.product);

    if (currentQuantity >= widget.product.stock) {
      _showMessage('You have reached the available stock.');

      return;
    }

    setState(() {
      Cart.add(widget.product);
    });

    _showMessage('${widget.product.name} added to cart');
  }

  // ==========================================================
  // REMOVE FROM CART
  // ==========================================================

  void _removeFromCart() {
    final currentQuantity = Cart.getQuantity(widget.product);

    if (currentQuantity <= 0) {
      return;
    }

    setState(() {
      Cart.remove(widget.product);
    });
  }

  // ==========================================================
  // OPEN CART
  // ==========================================================

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  // ==========================================================
  // WISHLIST
  // ==========================================================

  void _toggleWishlist() {
    setState(() {
      Wishlist.toggle(widget.product);
    });

    _showMessage(
      Wishlist.contains(widget.product)
          ? 'Added to wishlist'
          : 'Removed from wishlist',
    );
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
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ==========================================================
  // IMAGE PLACEHOLDER
  // ==========================================================

  Widget _imagePlaceholder() {
    return const Center(
      child: Icon(Icons.shopping_bag, size: 120, color: Colors.white),
    );
  }

  // ==========================================================
  // PRODUCT IMAGE
  // ==========================================================

  Widget _buildProductImage() {
    final imageUrl = widget.product.image.trim();

    return Container(
      width: double.infinity,

      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff34C759), Color(0xff16A34A)],
        ),
      ),

      padding: const EdgeInsets.symmetric(vertical: 30),

      child: Hero(
        tag: widget.product.id,

        child: imageUrl.isEmpty
            ? SizedBox(height: 240, child: _imagePlaceholder())
            : Image.network(
                imageUrl,

                height: 240,

                fit: BoxFit.contain,

                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return const SizedBox(
                    height: 240,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },

                errorBuilder: (context, error, stackTrace) {
                  return SizedBox(height: 240, child: _imagePlaceholder());
                },
              ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final quantity = Cart.getQuantity(widget.product);

    final bool outOfStock =
        widget.product.stock <= 0 || !widget.product.isAvailable;

    final bool canAddMore = quantity < widget.product.stock;

    final double price = _parsePrice(widget.product.price);

    final String formattedPrice = _formatPrice(price);

    final bool isWishlisted = Wishlist.contains(widget.product);

    return PopScope(
      canPop: false,

      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        Navigator.of(context).pop();
      },

      child: Scaffold(
        backgroundColor: Colors.grey.shade100,

        // ====================================================
        // APP BAR
        // ====================================================
        appBar: AppBar(
          backgroundColor: Colors.green,
          elevation: 0,
          foregroundColor: Colors.white,

          title: Text(
            widget.product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          actions: [
            // ================================================
            // CART
            // ================================================
            Stack(
              clipBehavior: Clip.none,

              children: [
                IconButton(
                  onPressed: _openCart,

                  icon: const Icon(
                    Icons.shopping_cart_outlined,
                    color: Colors.white,
                  ),
                ),

                if (quantity > 0)
                  Positioned(
                    right: 4,
                    top: 4,

                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),

                      child: Text(
                        '$quantity',

                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ================================================
            // WISHLIST
            // ================================================
            Padding(
              padding: const EdgeInsets.only(right: 8),

              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),

                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },

                  child: IconButton(
                    key: ValueKey(isWishlisted),

                    onPressed: _toggleWishlist,

                    icon: Icon(
                      isWishlisted ? Icons.favorite : Icons.favorite_border,

                      color: isWishlisted ? Colors.red : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // ====================================================
        // BODY
        // ====================================================
        body: Column(
          children: [
            // ================================================
            // PRODUCT IMAGE
            // ================================================
            AnimatedBuilder(
              animation: _animationController,

              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,

                  child: ScaleTransition(
                    scale: _imageScaleAnimation,

                    child: child,
                  ),
                );
              },

              child: _buildProductImage(),
            ),

            // ================================================
            // CONTENT
            // ================================================
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,

                child: SlideTransition(
                  position: _slideAnimation,

                  child: Container(
                    padding: const EdgeInsets.all(20),

                    decoration: const BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),

                    child: ListView(
                      children: [
                        // ======================================
                        // PRODUCT NAME
                        // ======================================
                        Text(
                          widget.product.name,

                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ======================================
                        // DELIVERY TIME
                        // ======================================
                        Align(
                          alignment: Alignment.centerLeft,

                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),

                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,

                              borderRadius: BorderRadius.circular(20),
                            ),

                            child: Row(
                              mainAxisSize: MainAxisSize.min,

                              children: [
                                const Icon(
                                  Icons.flash_on,
                                  color: Colors.orange,
                                  size: 18,
                                ),

                                const SizedBox(width: 4),

                                Text(
                                  '${widget.product.deliveryTime} min',

                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ======================================
                        // PRICE
                        // ======================================
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,

                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),

                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,

                                  child: ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                                );
                              },

                              child: Text(
                                formattedPrice,

                                key: ValueKey(formattedPrice),

                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),

                            const SizedBox(width: 15),

                            if (widget.product.discount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),

                                decoration: BoxDecoration(
                                  color: Colors.red,

                                  borderRadius: BorderRadius.circular(20),
                                ),

                                child: Text(
                                  '${widget.product.discount}% OFF',

                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 25),

                        // ======================================
                        // STOCK
                        // ======================================
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),

                          padding: const EdgeInsets.all(14),

                          decoration: BoxDecoration(
                            color: outOfStock
                                ? Colors.red.shade50
                                : Colors.green.shade50,

                            borderRadius: BorderRadius.circular(14),
                          ),

                          child: Row(
                            children: [
                              Icon(
                                outOfStock ? Icons.cancel : Icons.inventory_2,

                                color: outOfStock ? Colors.red : Colors.green,
                              ),

                              const SizedBox(width: 10),

                              Text(
                                outOfStock
                                    ? 'Out of Stock'
                                    : '${widget.product.stock} available',

                                style: TextStyle(
                                  color: outOfStock ? Colors.red : Colors.green,

                                  fontWeight: FontWeight.bold,

                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 15),

                        // ======================================
                        // DELIVERY INFORMATION
                        // ======================================
                        _InfoTile(
                          icon: Icons.delivery_dining,
                          iconColor: Colors.green,
                          title: 'Delivery',
                          subtitle: '${widget.product.deliveryTime} minutes',
                        ),

                        // ======================================
                        // CATEGORY
                        // ======================================
                        _InfoTile(
                          icon: Icons.category_outlined,
                          iconColor: Colors.blue,
                          title: 'Category',
                          subtitle: widget.product.category,
                        ),

                        // ======================================
                        // UNIT / WEIGHT
                        // ======================================
                        _InfoTile(
                          icon: Icons.scale_outlined,
                          iconColor: Colors.orange,
                          title: 'Unit',
                          subtitle: widget.product.weight,
                        ),

                        const SizedBox(height: 18),

                        // ======================================
                        // DESCRIPTION TITLE
                        // ======================================
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ======================================
                        // DESCRIPTION
                        // ======================================
                        Text(
                          widget.product.description.isNotEmpty
                              ? widget.product.description
                              : 'Fresh premium quality product sourced '
                                    'directly from trusted farms. Carefully '
                                    'packed to ensure maximum freshness and '
                                    'delivered to your doorstep in minutes.',
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 25),

                        // ======================================
                        // QUICK DELIVERY PROMISE
                        // ======================================
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xffF1F8F3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.flash_on,
                                  color: Colors.green,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Fast delivery to your doorstep',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    const SizedBox(height: 3),

                                    Text(
                                      'Estimated delivery in '
                                      '${widget.product.deliveryTime} minutes',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ======================================
                        // STOCK NOTICE
                        // ======================================
                        if (!outOfStock && widget.product.stock <= 5)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                ),

                                const SizedBox(width: 10),

                                Expanded(
                                  child: Text(
                                    'Only ${widget.product.stock} left in stock. '
                                    'Order soon!',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // ======================================================
        // BOTTOM CART BAR
        // ======================================================
        bottomNavigationBar: SafeArea(
          top: false,
          child: _buildBottomCartBar(
            quantity: quantity,
            outOfStock: outOfStock,
            canAddMore: canAddMore,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // BOTTOM CART BAR
  // ==========================================================

  Widget _buildBottomCartBar({
    required int quantity,
    required bool outOfStock,
    required bool canAddMore,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          );
        },
        child: outOfStock
            ? _buildOutOfStockBar()
            : quantity == 0
            ? _buildAddToCartBar()
            : _buildQuantityBar(quantity: quantity, canAddMore: canAddMore),
      ),
    );
  }

  // ==========================================================
  // OUT OF STOCK BAR
  // ==========================================================

  Widget _buildOutOfStockBar() {
    return Container(
      key: const ValueKey('out_of_stock'),
      height: 55,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Text(
          'OUT OF STOCK',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // ADD TO CART BAR
  // ==========================================================

  Widget _buildAddToCartBar() {
    return SizedBox(
      key: const ValueKey('add_to_cart'),
      height: 55,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _addToCart,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart, size: 22),
            SizedBox(width: 8),
            Text(
              'ADD TO CART',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // QUANTITY BAR
  // ==========================================================

  Widget _buildQuantityBar({required int quantity, required bool canAddMore}) {
    return Container(
      key: const ValueKey('quantity_cart'),
      height: 55,
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // ====================================================
          // MINUS
          // ====================================================
          IconButton(
            onPressed: _removeFromCart,
            icon: const Icon(
              Icons.remove_circle,
              size: 36,
              color: Colors.white,
            ),
          ),

          // ====================================================
          // QUANTITY
          // ====================================================
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Text(
                    '$quantity',
                    key: ValueKey(quantity),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Text(
                  'of ${widget.product.stock}',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),

          // ====================================================
          // PLUS
          // ====================================================
          IconButton(
            onPressed: canAddMore ? _addToCart : null,
            icon: Icon(
              Icons.add_circle,
              size: 36,
              color: canAddMore ? Colors.white : Colors.white38,
            ),
          ),

          // ====================================================
          // DIVIDER
          // ====================================================
          Container(width: 1, height: 35, color: Colors.white38),

          const SizedBox(width: 4),

          // ====================================================
          // CART BUTTON
          // ====================================================
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openCart,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.shopping_cart, color: Colors.white, size: 21),

                    SizedBox(width: 5),

                    Text(
                      'CART',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ============================================================
  // END OF PRODUCT DETAILS STATE
  // ============================================================
}

// ============================================================================
// PRODUCT INFORMATION TILE
// ============================================================================

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),

      child: ListTile(
        contentPadding: EdgeInsets.zero,

        leading: Container(
          width: 44,
          height: 44,

          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),

            borderRadius: BorderRadius.circular(12),
          ),

          child: Icon(icon, color: iconColor, size: 23),
        ),

        title: Text(
          title,

          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),

        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),

          child: Text(
            subtitle.isNotEmpty ? subtitle : 'Not specified',

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}
