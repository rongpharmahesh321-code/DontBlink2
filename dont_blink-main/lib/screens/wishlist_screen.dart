import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/cached_product_image.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/wishlist.dart';
import '../providers/cart_provider.dart';
import '../screens/product_details_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  bool _addingAll = false;

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
  // MESSAGE
  // ==========================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }

  // ==========================================================
  // REMOVE
  // ==========================================================

  void _remove(Product product) {
    Wishlist.remove(product);
    _showMessage('${product.name} removed from wishlist.');
  }

  // ==========================================================
  // CLEAR
  // ==========================================================

  void _clearWishlist() {
    if (Wishlist.items.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.favorite_border_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text('Clear Wishlist?'),
            ],
          ),
          content: const Text(
            'All saved products will be removed from your wishlist.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Wishlist.clear();
                Navigator.pop(dialogContext);
                _showMessage('Wishlist cleared.');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('CLEAR'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // ADD TO CART
  // ==========================================================

  void _addToCart(Product product) {
    if (!product.isAvailable || (product.stock <= 0)) {
      _showMessage('${product.name} is currently unavailable.');
      return;
    }

    context.read<CartProvider>().add(product);

    _showMessage('${product.name} added to cart.');
  }

  // ==========================================================
  // ADD ALL
  // ==========================================================

  Future<void> _addAllToCart() async {
    if (_addingAll || Wishlist.items.isEmpty) {
      return;
    }

    setState(() {
      _addingAll = true;
    });

    int added = 0;

    for (final product in List<Product>.from(Wishlist.items)) {
      if (product.isAvailable && product.stock > 0) {
        context.read<CartProvider>().add(product);
        added++;
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    setState(() {
      _addingAll = false;
    });

    if (added == 0) {
      _showMessage('No available products can be added.');
    } else {
      _showMessage(
        '$added ${added == 1 ? 'product' : 'products'} added to cart.',
      );
    }
  }

  // ==========================================================
  // EMPTY STATE
  // ==========================================================

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.82, end: 1),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                width: 125,
                height: 125,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.red,
                  size: 60,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your wishlist is empty',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Save products you love and\n'
              'find them here whenever you need them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.tintGreen,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Tap ♥ on a product to save it',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
  // PRODUCT IMAGE
  // ==========================================================

  Widget _buildProductImage(Product product) {
    final image = product.image.trim();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.tintGreen,
        borderRadius: BorderRadius.circular(17),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: image.isEmpty
            ? const Center(
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                  size: 48,
                ),
              )
            : CachedProductImage(
                url: image,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
                cacheWidth: 360,
                cacheHeight: 360,
                placeholder: Center(
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    color: AppColors.tintGreenBorder,
                    size: 44,
                  ),
                ),
                errorWidget: const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.grey,
                    size: 35,
                  ),
                ),
              ),
      ),
    );
  }

  // ==========================================================
  // WISHLIST CARD
  // ==========================================================

  Widget _buildProductCard(Product product, int index) {
    final price = _parsePrice(product.price);

    final available = product.isAvailable && product.stock > 0;

    final lowStock = product.stock > 0 && product.stock <= 5;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 9,
              offset: Offset(0, 3),
              spreadRadius: -5,
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailsScreen(product: product),
              ),
            );

            if (mounted) {
              setState(() {});
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ----------------------------------------------
                // IMAGE
                // ----------------------------------------------
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildProductImage(product)),

                      // Discount
                      if (product.discount > 0)
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(10),
                                bottomRight: Radius.circular(9),
                              ),
                            ),
                            child: Text(
                              '${product.discount}% OFF',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),

                      // Remove
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 1,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _remove(product),
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(
                                Icons.favorite_rounded,
                                color: Colors.red,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Availability
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: available
                                ? Colors.white
                                : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            available
                                ? '${product.deliveryTime} min'
                                : 'Unavailable',
                            style: TextStyle(
                              color: available ? AppColors.primary : Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 9),

                // ----------------------------------------------
                // NAME
                // ----------------------------------------------
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                // ----------------------------------------------
                // UNIT
                // ----------------------------------------------
                Text(
                  product.weight.trim().isEmpty ? '1 unit' : product.weight,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),

                const SizedBox(height: 5),

                // ----------------------------------------------
                // PRICE
                // ----------------------------------------------
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatPrice(price),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (product.rating > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                if (lowStock) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Only ${product.stock} left',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],

                const SizedBox(height: 7),

                // ----------------------------------------------
                // ADD BUTTON
                // ----------------------------------------------
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: available ? () => _addToCart(product) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade200,
                      disabledForegroundColor: Colors.grey.shade500,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      available ? 'ADD TO CART' : 'UNAVAILABLE',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saved for later',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '$count ${count == 1 ? 'product' : 'products'} saved',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          if (count > 0)
            OutlinedButton.icon(
              onPressed: _addingAll ? null : _addAllToCart,
              icon: _addingAll
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_shopping_cart_outlined, size: 17),
              label: const Text('ADD ALL'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Wishlist',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: Wishlist.notifier,
            builder: (context, _, __) {
              if (Wishlist.items.isEmpty) {
                return const SizedBox.shrink();
              }

              return IconButton(
                tooltip: 'Clear wishlist',
                onPressed: _clearWishlist,
                icon: const Icon(Icons.delete_outline_rounded),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: Wishlist.notifier,
        builder: (context, _, __) {
          final items = List<Product>.from(Wishlist.items);

          if (items.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              _buildHeader(items.length),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    // The card now contains a full 1:1 image plus
                    // name, unit, price and the cart button. Give it
                    // enough vertical room so the bottom button never
                    // overflows.
                    childAspectRatio: 0.58,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return _buildProductCard(items[index], index);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
