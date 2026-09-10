import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/cached_product_image.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/wishlist.dart';
import '../providers/cart_provider.dart';
import '../widgets/floating_cart_bar.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late Product _product;

  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  // ==========================================================
  // PRICE
  // ==========================================================

  double _parsePrice(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '').trim();

    return double.tryParse(cleaned) ?? 0;
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '₹${value.toInt()}';
    }

    return '₹${value.toStringAsFixed(2)}';
  }

  double _originalPrice() {
    final price = _parsePrice(_product.price);

    if (_product.discount <= 0 || _product.discount >= 100) {
      return price;
    }

    return price / (1 - (_product.discount / 100));
  }

  double _savings() {
    final original = _originalPrice();
    final current = _parsePrice(_product.price);

    if (_product.discount <= 0) {
      return 0;
    }

    return (original - current).clamp(0, double.infinity);
  }

  int _cartQuantity(BuildContext context) {
    return context.watch<CartProvider>().getQuantity(_product);
  }

  // ==========================================================
  // AVAILABILITY
  // ==========================================================

  bool get _available => _product.isAvailable && _product.stock > 0;

  bool get _lowStock => _product.stock > 0 && _product.stock <= 5;

  bool get _inWishlist => Wishlist.items.any((item) => item.id == _product.id);

  // ==========================================================
  // QUANTITY
  // ==========================================================

  void _increaseQuantity() {
    if (!_available) {
      return;
    }

    final cart = context.read<CartProvider>();
    final quantity = cart.getQuantity(_product);

    if (quantity >= _product.stock) {
      _showMessage('You have reached the available stock.');
      return;
    }

    cart.add(_product);
  }

  void _decreaseQuantity() {
    final cart = context.read<CartProvider>();
    final quantity = cart.getQuantity(_product);

    if (quantity <= 1) {
      return;
    }

    cart.remove(_product);
  }

  // ==========================================================
  // CART
  // ==========================================================

  Future<void> _addToCart() async {
    if (!_available) {
      _showMessage('${_product.name} is currently unavailable.');
      return;
    }

    if (_adding) {
      return;
    }

    final cart = context.read<CartProvider>();
    final quantity = cart.getQuantity(_product);

    if (quantity >= _product.stock) {
      _showMessage('You have reached the available stock.');
      return;
    }

    setState(() {
      _adding = true;
    });

    final added = cart.add(_product);

    await Future<void>.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    setState(() {
      _adding = false;
    });

    if (!added) {
      _showMessage('You have reached the available stock.');
      return;
    }

    _showMessage('${_product.name} added to cart.');
  }

  // ==========================================================
  // WISHLIST
  // ==========================================================

  void _toggleWishlist() {
    if (_inWishlist) {
      Wishlist.remove(_product);

      _showMessage('${_product.name} removed from wishlist.');
    } else {
      Wishlist.items.add(_product);

      _showMessage('${_product.name} added to wishlist.');
    }

    setState(() {});
  }

  // ==========================================================
  // SHARE
  // ==========================================================

  void _shareProduct() {
    // The project does not currently expose a verified
    // share service. Keep this action local instead of
    // introducing an additional package/API dependency.
    _showMessage('Product sharing will be available soon.');
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
  // IMAGE
  // ==========================================================

  Widget _buildImage() {
    final image = _product.image.trim();

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: image.isEmpty
            ? const Center(
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                  size: 90,
                ),
              )
            : CachedProductImage(
                url: image,
                fit: BoxFit.contain,
                cacheWidth: 800,
                cacheHeight: 800,
                placeholder: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
      ),
    );
  }

  // ==========================================================
  // TOP IMAGE AREA
  // ==========================================================

  Widget _buildImageArea() {
    return Stack(
      children: [
        _buildImage(),

        Positioned(
          top: 15,
          left: 15,
          child: _circleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
        ),

        Positioned(
          top: 15,
          right: 15,
          child: Row(
            children: [
              _circleButton(icon: Icons.share_outlined, onTap: _shareProduct),
              const SizedBox(width: 8),
              _circleButton(
                icon: _inWishlist
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                iconColor: _inWishlist ? Colors.red : Colors.black87,
                onTap: _toggleWishlist,
              ),
            ],
          ),
        ),

        if (_product.discount > 0)
          Positioned(
            left: 15,
            bottom: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '${_product.discount}% OFF',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),

        Positioned(
          right: 15,
          bottom: 15,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 7,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 17),
                const SizedBox(width: 4),
                Text(
                  '${_product.deliveryTime} min',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.black87,
  }) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: iconColor, size: 21),
        ),
      ),
    );
  }

  // ==========================================================
  // PRODUCT HEADER
  // ==========================================================

  Widget _buildProductHeader() {
    final price = _parsePrice(_product.price);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _product.name,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ),
            if (_product.rating > 0)
              Container(
                margin: const EdgeInsets.only(left: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 17,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _product.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            if (_product.weight.trim().isNotEmpty)
              Text(
                _product.weight,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            if (_product.weight.trim().isNotEmpty)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              _available ? 'In stock' : 'Unavailable',
              style: TextStyle(
                color: _available ? AppColors.primary : Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 13),

        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatPrice(price),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (_product.discount > 0) ...[
              const SizedBox(width: 9),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  _formatPrice(_originalPrice()),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
            ],
          ],
        ),

        if (_product.discount > 0) ...[
          const SizedBox(height: 5),
          Text(
            'You save ${_formatPrice(_savings())}',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================================
  // DELIVERY INFO
  // ==========================================================

  Widget _buildDeliveryInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tintGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.tintGreenBorder),
      ),
      child: Row(
        children: [
          _deliveryInfoItem(
            Icons.bolt_rounded,
            '${_product.deliveryTime} min',
            'Fast delivery',
          ),
          _verticalDivider(),
          _deliveryInfoItem(
            Icons.inventory_2_outlined,
            _product.stock > 0 ? '${_product.stock}' : '0',
            'Available',
          ),
          _verticalDivider(),
          _deliveryInfoItem(Icons.verified_outlined, 'Fresh', 'Quality'),
        ],
      ),
    );
  }

  Widget _deliveryInfoItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 21),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 38, color: AppColors.tintGreenBorder);
  }

  // ==========================================================
  // STOCK
  // ==========================================================

  Widget _buildStockNotice() {
    if (!_available) {
      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.remove_shopping_cart_outlined,
              color: Colors.red,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'This product is currently unavailable.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!_lowStock) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Only ${_product.stock} left in stock. Order soon.',
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // QUANTITY
  // ==========================================================

  Widget _buildQuantityCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quantity',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 3),
                Text(
                  'Choose how many you need',
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: _decreaseQuantity,
                  borderRadius: BorderRadius.circular(12),
                  child: const SizedBox(
                    width: 38,
                    height: 42,
                    child: Center(
                      child: Icon(Icons.remove, color: Colors.white, size: 18),
                    ),
                  ),
                ),
                SizedBox(
                  width: 31,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Text(
                      '${_cartQuantity(context)}',
                      key: ValueKey(_cartQuantity(context)),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: _increaseQuantity,
                  borderRadius: BorderRadius.circular(12),
                  child: const SizedBox(
                    width: 38,
                    height: 42,
                    child: Center(
                      child: Icon(Icons.add, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ABOUT PRODUCT
  // ==========================================================

  Widget _buildAboutProduct() {
    final description = _product.description.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About this product',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            description.isNotEmpty
                ? description
                : 'No product description is available.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // BOTTOM BAR
  // ==========================================================

  Widget _buildBottomBar(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.getQuantity(_product);
    final hasCartItems = cart.items.isNotEmpty;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (qty == 0) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _available && !_adding ? _addToCart : null,
                  icon: _adding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.shopping_cart_outlined, size: 20),
                  label: Text(
                    _adding
                        ? 'ADDING...'
                        : _available
                        ? 'ADD TO CART • ${_formatPrice(_parsePrice(_product.price))}'
                        : 'UNAVAILABLE',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              if (hasCartItems) const SizedBox(height: 8),
            ],
            if (hasCartItems)
              const FloatingCartBar(margin: EdgeInsets.zero),
          ],
        ),
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
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildImageArea()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 19, 16, 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildProductHeader(),

                const SizedBox(height: 16),

                _buildDeliveryInfo(),

                const SizedBox(height: 11),

                _buildStockNotice(),

                if (_available) ...[
                  const SizedBox(height: 11),
                  _buildQuantityCard(),
                ],

                const SizedBox(height: 13),

                _buildAboutProduct(),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }
}
