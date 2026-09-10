import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/subcategory.dart';
import '../providers/cart_provider.dart';
import '../services/firestore_service.dart';
import '../services/subcategory_service.dart';
import '../theme/app_colors.dart';
import '../widgets/product_card.dart';
import '../widgets/stacked_cart_images.dart';
import 'checkout_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  final CategoryModel category;
  final String? initialSubcategory;

  const CategoryProductsScreen({
    super.key,
    required this.category,
    this.initialSubcategory,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final SubcategoryService _subcategoryService = SubcategoryService();

  late final Stream<List<Product>> _productsStream;
  late final Stream<List<SubcategoryModel>> _subcategoriesStream;

  String? _selectedSubcategory;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectedSubcategory = widget.initialSubcategory;
    _productsStream = _firestoreService.getProducts();
    _subcategoriesStream =
        _subcategoryService.getSubcategories(widget.category.name);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  double _cartPrice(String price) {
    final cleaned = price.replaceAll(RegExp(r'[^0-9.]'), '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  int _cartCount(List<CartItem> items) {
    return items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  double _cartTotal(List<CartItem> items) {
    return items.fold<double>(
      0,
      (sum, item) => sum + (_cartPrice(item.product.price) * item.quantity),
    );
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '₹${value.toInt()}';
    }
    return '₹${value.toStringAsFixed(2)}';
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: _isSearching
          ? TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Search in ${widget.category.name}...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey.shade400),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (widget.category.section.isNotEmpty)
                  Text(
                    widget.category.section,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
      actions: [
        if (_isSearching)
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchQuery = '';
                _searchController.clear();
              });
            },
          )
        else
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              setState(() {
                _isSearching = true;
              });
            },
          ),
      ],
    );
  }

  // ============================================================
  // SUBCATEGORIES STRIP (TOP HORIZONTAL ROW)
  // ============================================================

  Widget _buildSubcategoriesRow(List<SubcategoryModel> subcategories) {
    if (subcategories.isEmpty) {
      return const SizedBox.shrink();
    }

    final isAllSelected =
        _selectedSubcategory == null || _selectedSubcategory!.isEmpty;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 98,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: subcategories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            // Index 0 is the "All" item
            if (index == 0) {
              return _buildAllSubcategoryItem(isAllSelected);
            }

            final sub = subcategories[index - 1];
            final isSelected = _selectedSubcategory != null &&
                _selectedSubcategory!.trim().toLowerCase() ==
                    sub.name.trim().toLowerCase();

            return _buildSubcategoryItem(sub, isSelected);
          },
        ),
      ),
    );
  }

  Widget _buildAllSubcategoryItem(bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSubcategory = null;
        });
      },
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.grey.shade100,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  Icons.grid_view_rounded,
                  color: isSelected ? AppColors.primary : Colors.grey.shade700,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'All',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? AppColors.primary : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubcategoryItem(SubcategoryModel sub, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSubcategory = isSelected ? null : sub.name;
        });
      },
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : Colors.grey.shade50,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: ClipOval(
                child: sub.imageUrl.trim().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: sub.imageUrl.trim(),
                        fit: BoxFit.cover,
                        memCacheWidth: 150,
                        maxWidthDiskCache: 150,
                        placeholder: (_, __) => Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Icon(
                          Icons.category_outlined,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade600,
                          size: 24,
                        ),
                      )
                    : Icon(
                        Icons.category_outlined,
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade600,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              sub.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.1,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? AppColors.primary : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SKELETON LOADING
  // ============================================================

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 275,
      ),
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 14,
              width: 90,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 14,
              width: 130,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  height: 18,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                Container(
                  height: 32,
                  width: 65,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FLOATING CART BAR
  // ============================================================

  Widget _buildFloatingCart(BuildContext context, List<CartItem> items) {
    final count = _cartCount(items);
    if (count <= 0) return const SizedBox.shrink();

    final total = _cartTotal(items);

    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: SafeArea(
        top: false,
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
                          fontSize: 10,
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
                  child: TextButton(
                    onPressed: _openCart,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View cart',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(Icons.arrow_forward_rounded, size: 17),
                      ],
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

  // ============================================================
  // BUILD SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _searchFocusNode.unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xffF6F7F9),
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            Column(
              children: [
                // Top Horizontal Subcategories Row
                StreamBuilder<List<SubcategoryModel>>(
                  stream: _subcategoriesStream,
                  builder: (context, subSnapshot) {
                    final subcategories = subSnapshot.data ?? [];
                    return _buildSubcategoriesRow(subcategories);
                  },
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xffEEEEEE)),

                // Products Grid
                Expanded(
                  child: StreamBuilder<List<Product>>(
                    stream: _productsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return _buildSkeletonGrid();
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Unable to load products.\n${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        );
                      }

                      final filter = widget.category.filter.trim().toLowerCase();
                      final categoryName =
                          widget.category.name.trim().toLowerCase();

                      // 1. Filter by category
                      var products = (snapshot.data ?? <Product>[]).where((p) {
                        if (!p.isAvailable || p.stock <= 0) return false;

                        final pCategory = p.category.trim().toLowerCase();
                        return (filter.isNotEmpty && pCategory == filter) ||
                            (categoryName.isNotEmpty &&
                                pCategory == categoryName);
                      }).toList();

                      // 2. Filter by subcategory if selected
                      if (_selectedSubcategory != null &&
                          _selectedSubcategory!.trim().isNotEmpty) {
                        final targetSub =
                            _selectedSubcategory!.trim().toLowerCase();
                        products = products.where((p) {
                          return p.subCategory.trim().toLowerCase() == targetSub;
                        }).toList();
                      }

                      // 3. Filter by search query if any
                      if (_searchQuery.isNotEmpty) {
                        products = products.where((p) {
                          return p.name.toLowerCase().contains(_searchQuery);
                        }).toList();
                      }

                      if (products.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(36),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.search_off_rounded,
                                    size: 40,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No products match "$_searchQuery"'
                                      : (_selectedSubcategory != null &&
                                              _selectedSubcategory!.isNotEmpty)
                                          ? 'No products in $_selectedSubcategory'
                                          : 'No products available in this category.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
                        physics: const BouncingScrollPhysics(),
                        itemCount: products.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: 275,
                        ),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return ProductCard(
                            key: ValueKey(product.id),
                            product: product,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            // Bottom Floating Cart Bar
            Consumer<CartProvider>(
              builder: (context, cartProvider, _) {
                return _buildFloatingCart(context, cartProvider.items);
              },
            ),
          ],
        ),
      ),
    );
  }
}
