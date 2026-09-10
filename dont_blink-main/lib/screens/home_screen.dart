import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/app_colors.dart';
import '../widgets/cached_product_image.dart';
import '../widgets/stacked_cart_images.dart';
import 'package:provider/provider.dart';

import '../models/banner.dart';
import '../models/cart_item.dart';
import '../models/category.dart';
import '../models/product.dart';

import '../providers/cart_provider.dart';

import '../services/banner_service.dart';
import '../services/store_selection_service.dart';
import '../services/category_service.dart';
import '../services/firestore_service.dart';
import '../services/section_service.dart';

import '../widgets/product_card.dart';

import 'address_selection_screen.dart';
import 'category_products_screen.dart';
import 'checkout_screen.dart';
import 'product_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final Set<String> _warmedCategoryImages = <String>{};

  void _warmVisibleCategoryImages(List<CategoryModel> categories) {
    if (!mounted) return;

    // Warm only the categories likely to be visible immediately.
    for (final category in categories.take(8)) {
      final url = category.imageUrl.trim();

      if (url.isEmpty || _warmedCategoryImages.contains(url)) {
        continue;
      }

      _warmedCategoryImages.add(url);

      precacheImage(
        CachedNetworkImageProvider(
          url,
          maxWidth: 168,
          maxHeight: 168,
        ),
        context,
        onError: (_, _) {
          _warmedCategoryImages.remove(url);
        },
      );
    }
  }

  final Set<String> _warmedProductImages = <String>{};

  void _warmVisibleProductImages(List<Product> products) {
    if (!mounted) return;

    // Warm only the first few products that are likely to be visible.
    // This avoids downloading the entire catalogue during startup.
    final visibleProducts = products.take(8);

    for (final product in visibleProducts) {
      final url = product.image.trim();

      if (url.isEmpty || _warmedProductImages.contains(url)) {
        continue;
      }

      _warmedProductImages.add(url);

      precacheImage(
        CachedProductImage.provider(url),
        context,
        onError: (_, _) {
          _warmedProductImages.remove(url);
        },
      );
    }
  }

  // ============================================================
  // SERVICES
  // ============================================================

  final FirestoreService _firestoreService = FirestoreService();

  final CategoryService _categoryService = CategoryService();

  final SectionService _sectionService = SectionService();

  final BannerService _bannerService = BannerService();

  // ============================================================
  // PERSISTENT STREAMS
  // ============================================================
  //
  // IMPORTANT:
  // These are created once so search/cart/address rebuilds don't
  // recreate the Firebase listeners and visually refresh the page.
  // ============================================================

  late final Stream<List<Product>> _popularProductsStream;

  // All products are loaded once and reused for live search suggestions.
  // This prevents a Firestore query from running on every keystroke.
  late final Stream<List<Product>> _productsStream;

  late final Stream<List<CategoryModel>> _categoriesStream;

  late final Stream<List<String>> _sectionsStream;

  late final Stream<List<BannerModel>> _bannersStream;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _addressesStream;

  // ============================================================
  // SEARCH STATE
  // ============================================================

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _search = '';
  bool _wasKeyboardOpen = false;

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchFocusNode.addListener(_onSearchFocusChanged);

    _popularProductsStream = _firestoreService.getPopularProducts();
    _productsStream = _firestoreService.getProducts();
    _categoriesStream = _categoryService.getCategories();
    _sectionsStream = _sectionService.getSections();
    _bannersStream = _bannerService.getActiveBanners();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _addressesStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .snapshots();
    }
  }

  void _onSearchFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
      if (view != null) {
        final double bottomInset = view.viewInsets.bottom;
        final bool isKeyboardVisible = bottomInset > 0;
        // Only unfocus when keyboard was open and is now closed (e.g. back button / IME hide)
        if (_wasKeyboardOpen && !isKeyboardVisible) {
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
            if (mounted) {
              setState(() {});
            }
          }
        }
        _wasKeyboardOpen = isKeyboardVisible;
      }
    } catch (_) {}
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ============================================================
  // ADDRESS
  // ============================================================

  Future<void> _changeAddress() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddressSelectionScreen()),
    );
  }

  Widget _buildDeliveryAddress() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _addressesStream,
      builder: (context, snapshot) {
        String address = 'Select delivery location';

        double? latitude;
        double? longitude;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final docs = snapshot.data!.docs;

          QueryDocumentSnapshot<Map<String, dynamic>>? selected;

          for (final doc in docs) {
            final data = doc.data();

            if (data['isDefault'] == true) {
              selected = doc;
              break;
            }
          }

          selected ??= docs.first;

          final data = selected.data();

          final parts = <String>[
            data['house']?.toString().trim() ?? '',
            data['area']?.toString().trim() ?? '',
            data['city']?.toString().trim() ?? '',
            data['state']?.toString().trim() ?? '',
            data['pincode']?.toString().trim() ?? '',
          ].where((part) => part.isNotEmpty).toList();

          if (parts.isNotEmpty) {
            address = parts.join(', ');
          }

          latitude = _toDouble(data['latitude']);
          longitude = _toDouble(data['longitude']);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _changeAddress,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppColors.tintGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DELIVER TO',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),

            // Only show the delivery-radius status after an address
            // has actually been selected.
            if (address != 'Select delivery location')
              _HomeDeliveryAvailability(
                key: ValueKey('$latitude-$longitude'),
                latitude: latitude,
                longitude: longitude,
              ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearch(String value) {
    setState(() {
      _search = value;
    });
  }

  List<Product> _searchSuggestions(List<Product> products) {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) {
      return const <Product>[];
    }

    final matches = products.where((product) {
      if (!product.isAvailable || product.stock <= 0) {
        return false;
      }

      return product.name.trim().toLowerCase().contains(query);
    }).toList();

    // Put names that START with the query first, then the rest.
    matches.sort((a, b) {
      final aName = a.name.trim().toLowerCase();
      final bName = b.name.trim().toLowerCase();

      final aStarts = aName.startsWith(query);
      final bStarts = bName.startsWith(query);

      if (aStarts != bStarts) {
        return aStarts ? -1 : 1;
      }

      return aName.compareTo(bName);
    });

    // Keep the search panel compact like Blinkit.
    return matches.take(6).toList();
  }

  TextSpan _highlightSearchMatch(String name, String query) {
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty) {
      return TextSpan(
        text: name,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final lowerName = name.toLowerCase();
    final lowerQuery = cleanQuery.toLowerCase();
    final index = lowerName.indexOf(lowerQuery);

    if (index < 0) {
      return TextSpan(
        text: name,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final end = index + cleanQuery.length;

    return TextSpan(
      children: [
        TextSpan(
          text: name.substring(0, index),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(
          text: name.substring(index, end),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        TextSpan(
          text: name.substring(end),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _searchProductImage(Product product) {
    final image = product.image.trim();

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: image.isEmpty
          ? const Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.primary,
              size: 22,
            )
          : CachedProductImage(
              url: image,
              fit: BoxFit.contain,
              cacheWidth: 120,
              cacheHeight: 120,
              placeholder: const Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
    );
  }

  Future<void> _selectSearchSuggestion(Product product) async {
    if (!mounted) return;

    _searchController.text = product.name;
    _searchController.selection = TextSelection.collapsed(
      offset: _searchController.text.length,
    );

    setState(() {
      _search = product.name;
    });

    FocusScope.of(context).unfocus();

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)),
    );
  }

  Widget _buildSearchSuggestions(List<Product> products) {
    final query = _search.trim();

    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    final suggestions = _searchSuggestions(products);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: suggestions.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 17),
              child: Row(
                children: [
                  Icon(Icons.search_off_rounded, color: Colors.grey, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'No products found',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int index = 0; index < suggestions.length; index++)
                  Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          _selectSearchSuggestion(suggestions[index]);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              _searchProductImage(suggestions[index]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: RichText(
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  text: _highlightSearchMatch(
                                    suggestions[index].name,
                                    query,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.north_west_rounded,
                                size: 17,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (index != suggestions.length - 1)
                        Divider(
                          height: 1,
                          indent: 66,
                          endIndent: 12,
                          color: Colors.grey.shade100,
                        ),
                    ],
                  ),
              ],
            ),
    );
  }

  // ============================================================
  // CART
  // ============================================================

  int _cartCount(List<CartItem> items) {
    return items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  double _cartTotal(List<CartItem> items) {
    return items.fold<double>(0, (sum, item) {
      final cleaned = item.product.price.replaceAll(RegExp(r'[^0-9.]'), '');

      final price = double.tryParse(cleaned) ?? 0;

      return sum + (price * item.quantity);
    });
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
  // CART POPUP
  // ============================================================

  Widget _buildCartPopup(List<CartItem> items) {
    final count = _cartCount(items);

    if (count <= 0) {
      return const SizedBox.shrink();
    }

    final total = _cartTotal(items);

    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: SafeArea(
        top: false,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 18 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
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
                    color: Colors.black.withValues(alpha: 0.20),
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
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(int cartCount) {
    return Column(
      children: [
        _buildDeliveryAddress(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'doorstepp',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _openCart,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  if (cartCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            cartCount > 99 ? '99+' : '$cartCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        _buildSearchBar(),
      ],
    );
  }

  void _focusSearch() {
    if (!mounted) return;
    if (!_searchFocusNode.hasFocus) {
      _searchFocusNode.requestFocus();
    }
  }

  void _submitSearch() {
    if (!mounted) return;

    final query = _searchController.text.trim();

    // If there is no query, the search button simply opens the keyboard.
    if (query.isEmpty) {
      _focusSearch();
      return;
    }

    // Keep the search query as the source of truth and close the keyboard.
    // The HomeScreen product stream filters from this value.
    setState(() {
      _search = query;
    });

    _searchFocusNode.unfocus();
  }

  Widget _buildSearchBar() {
    return StreamBuilder<List<Product>>(
      stream: _productsStream,
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <Product>[];

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 3, 16, 8),
              child: Container(
                height: 53,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: _searchFocusNode.hasFocus
                        ? AppColors.primary
                        : Colors.grey.shade200,
                    width: _searchFocusNode.hasFocus ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onTapOutside: (_) {
                    if (_searchFocusNode.hasFocus) {
                      _searchFocusNode.unfocus();
                    }
                  },
                  onChanged: _onSearch,
                  onSubmitted: (_) => _submitSearch(),
                  textInputAction: TextInputAction.search,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.none,
                  decoration: InputDecoration(
                    hintText: 'Search for groceries, snacks and more',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                    prefixIcon: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: _submitSearch,
                        child: const SizedBox(
                          width: 52,
                          height: 52,
                          child: Center(
                            child: Icon(
                              Icons.search_rounded,
                              color: Colors.black87,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                    suffixIcon: (_search.trim().isEmpty && !_searchFocusNode.hasFocus)
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _search = '';
                              });
                              _searchFocusNode.unfocus();
                            },
                            icon: const Icon(Icons.close, size: 19),
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
            _buildSearchSuggestions(products),
          ],
        );
      },
    );
  }

  // ============================================================
  // BANNER SLIDER
  // ============================================================

  Widget _buildBannerSlider() {
    return StreamBuilder<List<BannerModel>>(
      stream: _bannersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _bannerSkeleton();
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final banners = snapshot.data ?? <BannerModel>[];

        if (banners.isEmpty) {
          return const SizedBox.shrink();
        }

        return _BlinkitFadeIn(
          key: ValueKey('banners_${banners.length}'),
          child: _BannerCarousel(banners: banners),
        );
      },
    );
  }

  Widget _bannerSkeleton() {
    return Container(
      height: 168,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(19),
      ),
    );
  }

  // ============================================================
  // SECTION / CATEGORY GROUPING
  // ============================================================

  Widget _buildSections(
    List<CategoryModel> categories,
    List<String> sectionNames,
  ) {
    final grouped = <String, List<CategoryModel>>{};

    final displayNames = <String, String>{};

    for (final category in categories) {
      final section = category.section.trim();

      if (section.isEmpty) {
        continue;
      }

      final key = section.toLowerCase();

      displayNames[key] = section;

      grouped.putIfAbsent(key, () => []).add(category);
    }

    final ordered = <String>[];

    for (final section in sectionNames) {
      final name = section.trim();

      if (name.isEmpty) {
        continue;
      }

      final key = name.toLowerCase();

      if (!ordered.any((item) => item.toLowerCase() == key)) {
        ordered.add(displayNames[key] ?? name);
      }
    }

    for (final category in categories) {
      final name = category.section.trim();

      if (name.isEmpty) {
        continue;
      }

      final key = name.toLowerCase();

      if (!ordered.any((item) => item.toLowerCase() == key)) {
        ordered.add(name);
      }
    }

    if (ordered.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: ordered.map((section) {
        final sectionCategories =
            grouped[section.toLowerCase()] ?? <CategoryModel>[];

        return _buildSection(section, sectionCategories);
      }).toList(),
    );
  }

  Widget _buildSection(String sectionName, List<CategoryModel> categories) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sectionName,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.primary,
                  size: 13,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 7,
                mainAxisSpacing: 15,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                return _buildCategoryTile(categories[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(CategoryModel category) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }
        FocusManager.instance.primaryFocus?.unfocus();
        _openCategoryPopup(category);
      },
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xffEEF7F4),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: category.imageUrl.trim().isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.category_outlined,
                          color: AppColors.primary,
                          size: 35,
                        ),
                      )
                    : _FadeInNetworkImage(
                        url: category.imageUrl,
                        fit: BoxFit.contain,
                        cacheWidth: 360,
                        placeholderColor: const Color(0xffEEF7F4),
                        errorIcon: Icons.image_not_supported_outlined,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            category.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CATEGORY POPUP
  // ============================================================

  void _openCategoryPopup(CategoryModel category) {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(category: category),
      ),
    );
  }

  // ============================================================
  // POPULAR PRODUCTS
  // ============================================================

  /// Builds the popular-products section directly as slivers.
  ///
  /// This is intentionally NOT a GridView inside a SliverToBoxAdapter.
  /// A shrink-wrapped GridView has to calculate the height of the whole
  /// product list, which makes large catalogues more expensive to build
  /// and can contribute to scroll jank.
  Widget _buildPopularProducts() {
    return StreamBuilder<List<Product>>(
      stream: _popularProductsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _popularProductsLoadingSliver();
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Text(
                'Unable to load popular products.',
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
          );
        }

        final searchText = _search.trim().toLowerCase();

        final products = (snapshot.data ?? <Product>[])
            .where((product) {
              if (!product.isAvailable || product.stock <= 0) {
                return false;
              }

              if (searchText.isEmpty) {
                return true;
              }

              return product.name.toLowerCase().contains(searchText);
            })
            .toList(growable: false);

        _warmVisibleProductImages(products);

        if (products.isEmpty) {
          if (searchText.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }

          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: Text(
                  'No products found.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          );
        }

        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        searchText.isEmpty
                            ? 'Popular Products'
                            : 'Search results',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (searchText.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tintGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.trending_up_rounded,
                              color: AppColors.primary,
                              size: 14,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Trending',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Real sliver grid: Flutter can now build/paint only the
            // product cards that are near the viewport.
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 115),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 320,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = products[index];

                    return ProductCard(
                      key: ValueKey(product.id),
                      product: product,
                    );
                  },
                  childCount: products.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  addSemanticIndexes: false,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _popularProductsLoadingSliver() {
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 10, 18, 10),
            child: _SkeletonBox(width: 170, height: 22, radius: 8),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 115),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 320,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, __) => const _ProductSkeletonCard(),
              childCount: 4,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              addSemanticIndexes: false,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_searchFocusNode.hasFocus && _search.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          }
          if (_search.isNotEmpty) {
            setState(() {
              _search = '';
              _searchController.clear();
            });
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    await Future<void>.delayed(const Duration(milliseconds: 250));
                  },
                  child: CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Consumer<CartProvider>(
                          builder: (context, cartProvider, _) {
                            return _buildHeader(_cartCount(cartProvider.items));
                          },
                        ),
                      ),
                      SliverToBoxAdapter(child: _buildBannerSlider()),
                      SliverToBoxAdapter(
                        child: StreamBuilder<List<String>>(
                          stream: _sectionsStream,
                          builder: (context, sectionSnapshot) {
                            if (sectionSnapshot.hasError) {
                              return const SizedBox.shrink();
                            }

                            if (sectionSnapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !sectionSnapshot.hasData) {
                              return _sectionsSkeleton();
                            }

                            final sectionNames = sectionSnapshot.data ?? <String>[];

                            return StreamBuilder<List<CategoryModel>>(
                              stream: _categoriesStream,
                              builder: (context, categorySnapshot) {
                                if (categorySnapshot.hasError) {
                                  return const SizedBox.shrink();
                                }

                                if (categorySnapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    !categorySnapshot.hasData) {
                                  return _sectionsSkeleton();
                                }

                                final categories =
                                    categorySnapshot.data ?? <CategoryModel>[];
                                _warmVisibleCategoryImages(categories);

                                if (categories.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return _BlinkitFadeIn(
                                  key: ValueKey(
                                    'categories_${categories.length}_${sectionNames.length}',
                                  ),
                                  child: _buildSections(categories, sectionNames),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      _buildPopularProducts(),
                    ],
                  ),
                ),
                Consumer<CartProvider>(
                  builder: (context, cartProvider, _) {
                    return _buildCartPopup(cartProvider.items);
                  },
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _sectionsSkeleton() {
    return _BlinkitFadeSkeleton(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 21),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 10, 18, 10),
              child: Row(
                children: [
                  _SkeletonBox(width: 150, height: 22, radius: 8),
                  Spacer(),
                  _SkeletonBox(width: 14, height: 14, radius: 7),
                ],
              ),
            ),
            SizedBox(
              height: 128,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 9),
                itemBuilder: (_, __) {
                  return const SizedBox(
                    width: 82,
                    child: Column(
                      children: [
                        _SkeletonBox(width: 82, height: 82, radius: 15),
                        SizedBox(height: 8),
                        _SkeletonBox(width: 65, height: 10, radius: 5),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _BlinkitFadeIn extends StatefulWidget {
  final Widget child;

  const _BlinkitFadeIn({super.key, required this.child});

  @override
  State<_BlinkitFadeIn> createState() => _BlinkitFadeInState();
}

class _BlinkitFadeInState extends State<_BlinkitFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _scale = Tween<double>(
      begin: 0.985,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.topCenter,
        child: widget.child,
      ),
    );
  }
}

class _BlinkitFadeSkeleton extends StatefulWidget {
  final Widget child;

  const _BlinkitFadeSkeleton({required this.child});

  @override
  State<_BlinkitFadeSkeleton> createState() => _BlinkitFadeSkeletonState();
}

class _BlinkitFadeSkeletonState extends State<_BlinkitFadeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.48,
        end: 0.9,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ProductSkeletonCard extends StatelessWidget {
  const _ProductSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.grey.shade100),
      ),
      padding: const EdgeInsets.all(10),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(width: double.infinity, height: 168, radius: 14),
          SizedBox(height: 10),
          _SkeletonBox(width: 92, height: 12, radius: 6),
          SizedBox(height: 8),
          _SkeletonBox(width: 135, height: 12, radius: 6),
          SizedBox(height: 8),
          _SkeletonBox(width: 70, height: 14, radius: 7),
        ],
      ),
    );
  }
}

class _FadeInNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final int? cacheWidth;
  final Color placeholderColor;
  final IconData errorIcon;

  const _FadeInNetworkImage({
    required this.url,
    required this.fit,
    required this.cacheWidth,
    required this.placeholderColor,
    required this.errorIcon,
  });

  @override
  State<_FadeInNetworkImage> createState() => _FadeInNetworkImageState();
}

class _FadeInNetworkImageState extends State<_FadeInNetworkImage> {
  @override
  Widget build(BuildContext context) {
    if (widget.url.trim().isEmpty) {
      return ColoredBox(
        color: widget.placeholderColor,
        child: Center(
          child: Icon(widget.errorIcon, color: Colors.grey, size: 31),
        ),
      );
    }

    return ColoredBox(
      color: widget.placeholderColor,
      child: CachedNetworkImage(
        imageUrl: widget.url,
        fit: widget.fit,
        memCacheWidth: widget.cacheWidth,
        maxWidthDiskCache: widget.cacheWidth,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => _BlinkitFadeSkeleton(
          child: ColoredBox(color: widget.placeholderColor),
        ),
        errorWidget: (context, url, error) =>
            Center(child: Icon(widget.errorIcon, color: Colors.grey, size: 31)),
      ),
    );
  }
}

// =================================================================
// HOME DELIVERY AVAILABILITY
// =================================================================
//
// Home checks LOCATION ONLY.
// It does NOT inspect the cart. This means:
//
//   inside an active store radius  -> Delivery available
//   outside every store radius    -> Not deliverable here
//
// Checkout remains responsible for checking whether the selected
// store can fulfill the customer's actual cart.
// =================================================================

class _HomeDeliveryAvailability extends StatefulWidget {
  final double? latitude;
  final double? longitude;

  const _HomeDeliveryAvailability({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<_HomeDeliveryAvailability> createState() =>
      _HomeDeliveryAvailabilityState();
}

class _HomeDeliveryAvailabilityState extends State<_HomeDeliveryAvailability> {
  final StoreSelectionService _service = StoreSelectionService();

  late Future<StoreSelectionResult?> _future;

  @override
  void initState() {
    super.initState();
    _future = _check();
  }

  @override
  void didUpdateWidget(covariant _HomeDeliveryAvailability oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _future = _check();
    }
  }

  Future<StoreSelectionResult?> _check() async {
    final latitude = widget.latitude;
    final longitude = widget.longitude;

    if (latitude == null || longitude == null) {
      return null;
    }

    return _service.selectBestStore(
      customerLatitude: latitude,
      customerLongitude: longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.latitude == null || widget.longitude == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<StoreSelectionResult?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final store = snapshot.data;

        if (store == null) {
          return _unavailable('This location is outside our delivery radius.');
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _unavailable(String message) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_outlined,
              color: Colors.red,
              size: 19,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Not deliverable here',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontSize: 8.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// BANNER CAROUSEL
// =================================================================

class _BannerCarousel extends StatefulWidget {
  final List<BannerModel> banners;

  const _BannerCarousel({required this.banners});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  late final PageController _pageController;

  Timer? _timer;

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(viewportFraction: 0.93);

    _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Do not compete with the first frame/initial product grid for CPU,
    // decoding and memory bandwidth. The banner widget itself will load the
    // currently visible image.
  }

  void _startTimer() {
    if (widget.banners.length <= 1) {
      return;
    }

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }

      final next = (_currentPage + 1) % widget.banners.length;

      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void didUpdateWidget(covariant _BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.banners.length != widget.banners.length) {
      _currentPage = 0;

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 174,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (index) {
              if (!mounted) {
                return;
              }

              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final banner = widget.banners[index];

              return Padding(
                padding: const EdgeInsets.fromLTRB(3, 7, 3, 5),
                child: GestureDetector(
                  onTap: () {},
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: AppColors.tintGreen),
                        _FadeInNetworkImage(
                          url: banner.imageUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 900,
                          placeholderColor: AppColors.tintGreen,
                          errorIcon: Icons.broken_image_outlined,
                        ),
                        if (banner.title.trim().isNotEmpty ||
                            banner.subtitle.trim().isNotEmpty)
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.42),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (banner.title.trim().isNotEmpty)
                                    Text(
                                      banner.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  if (banner.subtitle.trim().isNotEmpty)
                                    Text(
                                      banner.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 9,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 3, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.banners.length, (index) {
                final active = index == _currentPage;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 19 : 6,
                  height: 5,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// =================================================================
// CATEGORY PRODUCTS POPUP
// =================================================================

class _CategoryProductsPopup extends StatefulWidget {
  final CategoryModel category;
  final FirestoreService firestoreService;

  const _CategoryProductsPopup({
    required this.category,
    required this.firestoreService,
  });

  @override
  State<_CategoryProductsPopup> createState() => _CategoryProductsPopupState();
}

class _CategoryProductsFadeSkeleton extends StatelessWidget {
  const _CategoryProductsFadeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _BlinkitFadeSkeleton(
      child: GridView.builder(
        key: const ValueKey('category-products-skeleton-grid'),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 105),
        physics: const BouncingScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          // ProductCard contains a square image + compact info area.
          // A fixed 320px height caused a large empty/overflowed area on
          // wide category popups. Scale the card height with its width.
          childAspectRatio: 0.68,
        ),
        itemBuilder: (_, __) => const _ProductSkeletonCard(),
      ),
    );
  }
}

class _CategoryProductsPopupState extends State<_CategoryProductsPopup> {
  // Created once. Cart changes never recreate this Firebase listener.
  late final Stream<List<Product>> _productsStream;

  // Only the first visible cards are precached. This avoids downloading
  // an entire category before the user scrolls while making the first
  // screen of products appear much faster.
  final Set<String> _precacheStarted = <String>{};

  void _precacheFirstProducts(List<Product> products) {
    if (!mounted || products.isEmpty) return;

    final visibleCount = products.length < 2 ? products.length : 2;

    for (var i = 0; i < visibleCount; i++) {
      final product = products[i];
      final url = product.image.trim();

      if (url.isEmpty || !_precacheStarted.add(product.id)) {
        continue;
      }

      final provider = CachedProductImage.provider(url);

      precacheImage(provider, context).catchError((_) {});
    }
  }

  @override
  void initState() {
    super.initState();
    _productsStream = widget.firestoreService.getProducts();
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

  void _openCart(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }

  Widget _buildFloatingCart(BuildContext context, List<CartItem> items) {
    final count = _cartCount(items);

    if (count <= 0) {
      return const SizedBox.shrink();
    }

    final total = _cartTotal(items);

    return Positioned(
      left: 14,
      right: 14,
      bottom: 12,
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
                  color: Colors.black.withValues(alpha: 0.20),
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
                    onPressed: () => _openCart(context),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: widget.category.imageUrl.trim().isEmpty
                          ? Container(
                              width: 56,
                              height: 56,
                              color: AppColors.tintGreen,
                              child: const Icon(
                                Icons.category_outlined,
                                color: AppColors.primary,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: widget.category.imageUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              memCacheWidth: 168,
                              maxWidthDiskCache: 168,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              placeholder: (_, __) => Container(
                                width: 56,
                                height: 56,
                                color: AppColors.tintGreen,
                                child: const Icon(
                                  Icons.category_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 56,
                                height: 56,
                                color: AppColors.tintGreen,
                                child: const Icon(
                                  Icons.category_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.category.section,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: StreamBuilder<List<Product>>(
                  // Persistent stream: + / - never restarts the product stream.
                  stream: _productsStream,
                  builder: (context, snapshot) {
                    // Blinkit-style loading:
                    // Do not show a circular loading spinner inside the
                    // product grid. Show product-shaped skeleton cards first,
                    // then fade the real products in when Firestore responds.
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const _CategoryProductsFadeSkeleton(
                        key: ValueKey('category-products-loading'),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Unable to load products.'),
                      );
                    }

                    final filter = widget.category.filter.trim().toLowerCase();
                    final categoryName = widget.category.name
                        .trim()
                        .toLowerCase();

                    final products = (snapshot.data ?? <Product>[]).where((
                      product,
                    ) {
                      if (!product.isAvailable || product.stock <= 0) {
                        return false;
                      }

                      final productCategory = product.category
                          .trim()
                          .toLowerCase();

                      return (filter.isNotEmpty && productCategory == filter) ||
                          (categoryName.isNotEmpty &&
                              productCategory == categoryName);
                    }).toList();

                    _precacheFirstProducts(products);

                    if (products.isEmpty) {
                      return const Center(
                        child: Text(
                          'No products available in this category.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      );
                    }

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      reverseDuration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: GridView.builder(
                        key: const ValueKey('category-products-loaded'),
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 105),
                        physics: const BouncingScrollPhysics(),
                        itemCount: products.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              // The popup card content is compact. A 320px
                              // fixed row leaves a large white area below
                              // the name/weight. Keep the row close to the
                              // actual ProductCard content.
                              mainAxisExtent: 270,
                            ),
                        itemBuilder: (context, index) {
                          final product = products[index];

                          return ProductCard(
                            key: ValueKey(product.id),
                            product: product,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Only this small part listens to CartProvider.
          // The popup itself does not rebuild on + / -.
          Consumer<CartProvider>(
            builder: (context, cartProvider, _) {
              return _buildFloatingCart(context, cartProvider.items);
            },
          ),
        ],
      ),
    );
  }
}
