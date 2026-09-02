import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/category.dart';
import '../models/banner.dart';

import '../services/firestore_service.dart';
import '../services/category_service.dart';
import '../services/section_service.dart';
import '../services/banner_service.dart';

import '../widgets/product_card.dart';
import '../providers/cart_provider.dart';

import 'cart_screen.dart';
import 'address_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  final FirestoreService firestoreService = FirestoreService();

  final CategoryService categoryService = CategoryService();

  final SectionService sectionService = SectionService();

  final BannerService bannerService = BannerService();

  // ============================================================
  // PERSISTENT STREAMS
  //
  // These are created only once.
  //
  // IMPORTANT:
  // Popular Products uses its own persistent stream so scrolling
  // does not recreate the Firestore listener.
  // ============================================================

  late final Stream<List<Product>> _productsStream;

  late final Stream<List<Product>> _popularProductsStream;

  late final Stream<List<CategoryModel>> _categoriesStream;

  late final Stream<List<String>> _sectionsStream;

  late final Stream<List<BannerModel>> _bannersStream;

  // ============================================================
  // ADDRESS STREAM
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>>? _addressesStream;

  // ============================================================
  // SEARCH
  // ============================================================

  String search = '';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    debugPrint('🏠 HOME INIT');

    // ----------------------------------------------------------
    // ALL PRODUCTS
    // ----------------------------------------------------------

    _productsStream = firestoreService.getProducts();

    // ----------------------------------------------------------
    // POPULAR PRODUCTS
    //
    // CREATED ONCE.
    // ----------------------------------------------------------

    _popularProductsStream = firestoreService.getPopularProducts();

    // ----------------------------------------------------------
    // CATEGORIES
    // ----------------------------------------------------------

    _categoriesStream = categoryService.getCategories();

    // ----------------------------------------------------------
    // SECTIONS
    // ----------------------------------------------------------

    _sectionsStream = sectionService.getSections();

    // ----------------------------------------------------------
    // BANNERS
    // ----------------------------------------------------------

    _bannersStream = bannerService.getActiveBanners();

    // ----------------------------------------------------------
    // ADDRESS
    // ----------------------------------------------------------

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _addressesStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .snapshots();
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    debugPrint('❌ HOME DISPOSE');

    super.dispose();
  }

  // ============================================================
  // GREETING
  // ============================================================

  String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return '🌅 Good Morning';
    }

    if (hour >= 12 && hour < 17) {
      return '☀️ Good Afternoon';
    }

    if (hour >= 17 && hour < 21) {
      return '🌇 Good Evening';
    }

    return '🌙 Good Night';
  }

  // ============================================================
  // CHANGE ADDRESS
  // ============================================================

  Future<void> _changeAddress() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddressSelectionScreen()),
    );
  }

  // ============================================================
  // DELIVERY ADDRESS
  // ============================================================

  Widget _buildDeliveryAddress() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _addressesStream,

      builder: (context, snapshot) {
        String address = 'Select delivery location';

        // ------------------------------------------------------
        // READ SAVED ADDRESSES
        // ------------------------------------------------------

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final docs = snapshot.data!.docs;

          QueryDocumentSnapshot<Map<String, dynamic>>? selectedDoc;

          // ----------------------------------------------------
          // DEFAULT ADDRESS
          // ----------------------------------------------------

          for (final doc in docs) {
            final data = doc.data();

            if (data['isDefault'] == true) {
              selectedDoc = doc;
              break;
            }
          }

          // ----------------------------------------------------
          // FALLBACK
          // ----------------------------------------------------

          selectedDoc ??= docs.first;

          final data = selectedDoc.data();

          final house = data['house']?.toString().trim() ?? '';

          final area = data['area']?.toString().trim() ?? '';

          final city = data['city']?.toString().trim() ?? '';

          final state = data['state']?.toString().trim() ?? '';

          final pincode = data['pincode']?.toString().trim() ?? '';

          final parts = <String>[
            house,
            area,
            city,
            state,
            pincode,
          ].where((part) => part.isNotEmpty).toList();

          if (parts.isNotEmpty) {
            address = parts.join(', ');
          }
        }

        // ------------------------------------------------------
        // ADDRESS CARD
        // ------------------------------------------------------

        return GestureDetector(
          onTap: _changeAddress,

          child: Container(
            width: double.infinity,

            margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),

            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.circular(16),

              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),

            child: Row(
              children: [
                // ==============================================
                // LOCATION ICON
                // ==============================================
                Container(
                  width: 42,
                  height: 42,

                  decoration: BoxDecoration(
                    color: Colors.green.shade50,

                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: const Icon(
                    Icons.location_on,
                    color: Colors.green,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 12),

                // ==============================================
                // ADDRESS TEXT
                // ==============================================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'Deliver to',

                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        address,

                        maxLines: 2,

                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.green,
                  size: 25,
                ),
              ],
            ),
          ),
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
        // ------------------------------------------------------
        // LOADING
        // ------------------------------------------------------

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 175,

            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),

            decoration: BoxDecoration(
              color: Colors.grey.shade200,

              borderRadius: BorderRadius.circular(20),
            ),

            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.green,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        // ------------------------------------------------------
        // ERROR
        // ------------------------------------------------------

        if (snapshot.hasError) {
          debugPrint(
            '❌ Banner error: '
            '${snapshot.error}',
          );

          return const SizedBox.shrink();
        }

        // ------------------------------------------------------
        // DATA
        // ------------------------------------------------------

        final banners = snapshot.data ?? [];

        if (banners.isEmpty) {
          return const SizedBox.shrink();
        }

        return _BannerCarousel(banners: banners);
      },
    );
  }

  // ============================================================
  // CATEGORY POPUP
  // ============================================================

  void _openCategoryPopup(CategoryModel category) {
    showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (_) {
        return _CategoryProductsPopup(
          category: category,
          firestoreService: firestoreService,
        );
      },
    );
  }

  // ============================================================
  // CATEGORY PLACEHOLDER
  // ============================================================

  Widget _categoryPlaceholder() {
    return Container(
      width: 82,
      height: 82,

      decoration: BoxDecoration(
        color: const Color(0xffF1F7F3),

        borderRadius: BorderRadius.circular(16),
      ),

      child: const Icon(Icons.category, size: 34, color: Colors.green),
    );
  }

  // ============================================================
  // CATEGORY CARD
  // ============================================================

  Widget _buildCategoryCard(CategoryModel category) {
    return GestureDetector(
      onTap: () {
        _openCategoryPopup(category);
      },

      child: SizedBox(
        width: 100,

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),

              child: category.imageUrl.trim().isNotEmpty
                  ? Image.network(
                      category.imageUrl,

                      width: 82,
                      height: 82,

                      fit: BoxFit.cover,

                      errorBuilder: (_, __, ___) {
                        return _categoryPlaceholder();
                      },
                    )
                  : _categoryPlaceholder(),
            ),

            const SizedBox(height: 7),

            SizedBox(
              height: 38,

              child: Text(
                category.name,

                textAlign: TextAlign.center,

                maxLines: 2,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECTION
  // ============================================================

  Widget _buildSection(String sectionName, List<CategoryModel> categories) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),

            child: Text(
              sectionName,

              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 12),

          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),

              child: Text(
                'No categories yet',

                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            )
          else
            SizedBox(
              height: 135,

              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),

                scrollDirection: Axis.horizontal,

                itemCount: categories.length,

                separatorBuilder: (_, __) {
                  return const SizedBox(width: 14);
                },

                itemBuilder: (context, index) {
                  return _buildCategoryCard(categories[index]);
                },
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD SECTIONS
  // ============================================================

  Widget _buildSectionsFromCategories(
    List<CategoryModel> categories,
    List<String> firestoreSections,
  ) {
    final Map<String, List<CategoryModel>> grouped = {};

    final Map<String, String> displayNames = {};

    // ----------------------------------------------------------
    // GROUP CATEGORIES
    // ----------------------------------------------------------

    for (final category in categories) {
      final sectionName = category.section.trim();

      if (sectionName.isEmpty) {
        continue;
      }

      final key = sectionName.toLowerCase();

      displayNames[key] = sectionName;

      grouped.putIfAbsent(key, () => []).add(category);
    }

    // ----------------------------------------------------------
    // FIRESTORE SECTION ORDER
    // ----------------------------------------------------------

    final List<String> sections = [];

    for (final section in firestoreSections) {
      final name = section.trim();

      if (name.isEmpty) {
        continue;
      }

      final key = name.toLowerCase();

      if (!sections.any((existing) => existing.toLowerCase() == key)) {
        sections.add(displayNames[key] ?? name);
      }
    }

    // ----------------------------------------------------------
    // FALLBACK SECTIONS
    // ----------------------------------------------------------

    for (final category in categories) {
      final name = category.section.trim();

      if (name.isEmpty) {
        continue;
      }

      final key = name.toLowerCase();

      if (!sections.any((existing) => existing.toLowerCase() == key)) {
        sections.add(name);
      }
    }

    // ----------------------------------------------------------
    // EMPTY
    // ----------------------------------------------------------

    if (sections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20),

        child: Text(
          'No categories available yet.',

          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    // ----------------------------------------------------------
    // DISPLAY
    // ----------------------------------------------------------

    return Column(
      children: sections.map((section) {
        final key = section.toLowerCase();

        return _buildSection(section, grouped[key] ?? []);
      }).toList(),
    );
  }
  // ============================================================
  // POPULAR PRODUCTS
  //
  // IMPORTANT:
  //
  // Uses the persistent stream created in initState().
  //
  // This prevents the Popular Products section from creating
  // a new Firestore listener whenever HomeScreen rebuilds.
  // ============================================================

  Widget _buildPopularProducts() {
    return StreamBuilder<List<Product>>(
      stream: _popularProductsStream,

      builder: (context, snapshot) {
        // ------------------------------------------------------
        // LOADING
        // ------------------------------------------------------

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),

            child: Center(
              child: CircularProgressIndicator(color: Colors.green),
            ),
          );
        }

        // ------------------------------------------------------
        // ERROR
        // ------------------------------------------------------

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),

            child: Text(
              'Unable to load popular products.\n'
              '${snapshot.error}',

              textAlign: TextAlign.center,

              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        // ------------------------------------------------------
        // PRODUCTS
        // ------------------------------------------------------

        final products = snapshot.data ?? [];

        // ------------------------------------------------------
        // SEARCH
        // ------------------------------------------------------

        final searchText = search.trim().toLowerCase();

        final popularProducts = products.where((product) {
          if (searchText.isEmpty) {
            return true;
          }

          return product.name.toLowerCase().contains(searchText);
        }).toList();

        // ------------------------------------------------------
        // EMPTY
        // ------------------------------------------------------

        if (popularProducts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(30),

            child: Center(
              child: Text(
                'No Popular Products Found',

                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          );
        }

        // ------------------------------------------------------
        // PRODUCT GRID
        // ------------------------------------------------------

        return GridView.builder(
          shrinkWrap: true,

          physics: const NeverScrollableScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),

          itemCount: popularProducts.length,

          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,

            crossAxisSpacing: 12,

            mainAxisSpacing: 12,

            mainAxisExtent: 320,
          ),

          itemBuilder: (context, index) {
            return ProductCard(product: popularProducts[index]);
          },
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F8FA),

      // ========================================================
      // FLOATING CART
      // ========================================================
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.items.isEmpty) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },

            backgroundColor: Colors.green,

            elevation: 5,

            icon: const Icon(Icons.shopping_cart, color: Colors.white),

            label: Text(
              'View Cart (${cartProvider.items.length})',

              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),

          child: Column(
            children: [
              // ==================================================
              // HEADER
              // ==================================================
              Container(
                width: double.infinity,

                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),

                decoration: const BoxDecoration(
                  color: Colors.green,

                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),

                    bottomRight: Radius.circular(30),
                  ),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // --------------------------------------------
                    // GREETING
                    // --------------------------------------------
                    Text(
                      getGreeting(),

                      style: const TextStyle(
                        color: Colors.white70,

                        fontSize: 14,

                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 5),

                    // --------------------------------------------
                    // APP NAME
                    // --------------------------------------------
                    const Text(
                      'doorstepp',

                      style: TextStyle(
                        color: Colors.white,

                        fontSize: 30,

                        fontWeight: FontWeight.w800,

                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 3),

                    // --------------------------------------------
                    // TAGLINE
                    // --------------------------------------------
                    const Text(
                      'Groceries delivered in minutes',

                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // DELIVERY ADDRESS
              // ==================================================
              _buildDeliveryAddress(),

              // ==================================================
              // SEARCH
              // ==================================================
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),

                child: TextField(
                  textInputAction: TextInputAction.search,

                  onChanged: (value) {
                    setState(() {
                      search = value;
                    });
                  },

                  decoration: InputDecoration(
                    hintText: 'Search for groceries, snacks and more',

                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,

                      fontSize: 14,
                    ),

                    prefixIcon: const Icon(
                      Icons.search,

                      size: 27,

                      color: Colors.black87,
                    ),

                    suffixIcon: search.trim().isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              setState(() {
                                search = '';
                              });
                            },

                            icon: const Icon(Icons.close, size: 20),
                          )
                        : null,

                    filled: true,

                    fillColor: Colors.white,

                    contentPadding: const EdgeInsets.symmetric(vertical: 17),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(17),

                      borderSide: BorderSide.none,
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(17),

                      borderSide: BorderSide.none,
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(17),

                      borderSide: const BorderSide(
                        color: Colors.green,

                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              // ==================================================
              // BANNER SLIDER
              // ==================================================
              _buildBannerSlider(),

              const SizedBox(height: 10),

              // ==================================================
              // SECTIONS + CATEGORIES
              // ==================================================
              StreamBuilder<List<String>>(
                stream: _sectionsStream,

                builder: (context, sectionSnapshot) {
                  // ----------------------------------------------
                  // LOADING
                  // ----------------------------------------------

                  if (sectionSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20),

                      child: Center(
                        child: CircularProgressIndicator(color: Colors.green),
                      ),
                    );
                  }

                  // ----------------------------------------------
                  // ERROR
                  // ----------------------------------------------

                  if (sectionSnapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(20),

                      child: Text(
                        'Unable to load sections.\n'
                        '${sectionSnapshot.error}',

                        textAlign: TextAlign.center,

                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  // ----------------------------------------------
                  // CATEGORIES
                  // ----------------------------------------------

                  return StreamBuilder<List<CategoryModel>>(
                    stream: _categoriesStream,

                    builder: (context, categorySnapshot) {
                      // ------------------------------------------
                      // LOADING
                      // ------------------------------------------

                      if (categorySnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20),

                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.green,
                            ),
                          ),
                        );
                      }

                      // ------------------------------------------
                      // ERROR
                      // ------------------------------------------

                      if (categorySnapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(20),

                          child: Container(
                            width: double.infinity,

                            padding: const EdgeInsets.all(16),

                            decoration: BoxDecoration(
                              color: Colors.red.shade50,

                              borderRadius: BorderRadius.circular(14),
                            ),

                            child: Column(
                              children: [
                                const Icon(
                                  Icons.error_outline,

                                  color: Colors.red,

                                  size: 30,
                                ),

                                const SizedBox(height: 8),

                                const Text(
                                  'Unable to load categories',

                                  style: TextStyle(
                                    color: Colors.red,

                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 5),

                                Text(
                                  '${categorySnapshot.error}',

                                  textAlign: TextAlign.center,

                                  style: TextStyle(
                                    color: Colors.red.shade700,

                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final categories = categorySnapshot.data ?? [];

                      final firestoreSections = sectionSnapshot.data ?? [];

                      return _buildSectionsFromCategories(
                        categories,
                        firestoreSections,
                      );
                    },
                  );
                },
              ),

              // ==================================================
              // POPULAR PRODUCTS TITLE
              // ==================================================
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),

                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Popular Products',

                        style: TextStyle(
                          fontSize: 23,

                          fontWeight: FontWeight.w800,

                          letterSpacing: -0.3,
                        ),
                      ),
                    ),

                    if (search.trim().isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),

                        decoration: BoxDecoration(
                          color: Colors.green.shade50,

                          borderRadius: BorderRadius.circular(20),
                        ),

                        child: const Row(
                          children: [
                            Icon(
                              Icons.trending_up,

                              color: Colors.green,

                              size: 16,
                            ),

                            SizedBox(width: 4),

                            Text(
                              'Trending',

                              style: TextStyle(
                                color: Colors.green,

                                fontSize: 11,

                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 5),

              // ==================================================
              // POPULAR PRODUCTS
              // ==================================================
              _buildPopularProducts(),

              // ==================================================
              // BOTTOM SPACE
              // ==================================================
              const SizedBox(height: 35),
            ],
          ),
        ),
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

  Timer? _autoSlideTimer;

  int _currentPage = 0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _pageController = PageController(viewportFraction: 0.92);

    _startAutoSlide();
  }

  // ============================================================
  // AUTO SLIDE
  // ============================================================

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();

    // ----------------------------------------------------------
    // Don't create a timer when there is only one banner.
    // ----------------------------------------------------------

    if (widget.banners.length <= 1) {
      return;
    }

    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) {
        return;
      }

      if (!_pageController.hasClients) {
        return;
      }

      if (widget.banners.isEmpty) {
        return;
      }

      final nextPage = (_currentPage + 1) % widget.banners.length;

      _pageController.animateToPage(
        nextPage,

        duration: const Duration(milliseconds: 600),

        curve: Curves.easeInOut,
      );
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _autoSlideTimer?.cancel();

    _pageController.dispose();

    super.dispose();
  }

  // ============================================================
  // BANNER TAP
  // ============================================================

  void _openBanner(BannerModel banner) {
    debugPrint('Banner tapped: ${banner.id}');
  }

  // ============================================================
  // BANNER IMAGE
  // ============================================================

  Widget _buildBannerImage(BannerModel banner) {
    final imageUrl = banner.imageUrl.trim();

    if (imageUrl.isEmpty) {
      return Container(
        color: Colors.green.shade100,

        child: const Center(
          child: Icon(Icons.image_outlined, size: 50, color: Colors.green),
        ),
      );
    }

    return Image.network(
      imageUrl,

      width: double.infinity,

      height: double.infinity,

      fit: BoxFit.cover,

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
        return Container(
          color: Colors.green.shade50,

          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,

              size: 45,

              color: Colors.green,
            ),
          ),
        );
      },
    );
  }
  // ============================================================
  // BANNER BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ======================================================
        // SLIDER
        // ======================================================
        SizedBox(
          height: 175,

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
                padding: const EdgeInsets.only(
                  left: 4,
                  right: 4,
                  top: 8,
                  bottom: 4,
                ),

                child: GestureDetector(
                  onTap: () {
                    _openBanner(banner);
                  },

                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),

                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,

                          blurRadius: 8,

                          offset: Offset(0, 3),
                        ),
                      ],
                    ),

                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),

                      child: _buildBannerImage(banner),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ======================================================
        // DOT INDICATORS
        // ======================================================
        if (widget.banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 7),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,

              children: List.generate(widget.banners.length, (index) {
                final selected = index == _currentPage;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),

                  curve: Curves.easeOut,

                  margin: const EdgeInsets.symmetric(horizontal: 3),

                  width: selected ? 18 : 6,

                  height: 6,

                  decoration: BoxDecoration(
                    color: selected ? Colors.green : Colors.grey.shade300,

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

class _CategoryProductsPopup extends StatelessWidget {
  final CategoryModel category;

  final FirestoreService firestoreService;

  const _CategoryProductsPopup({
    required this.category,
    required this.firestoreService,
  });

  // ============================================================
  // PLACEHOLDER
  // ============================================================

  Widget _popupPlaceholder() {
    return Container(
      width: 58,
      height: 58,

      decoration: BoxDecoration(
        color: const Color(0xffF1F7F3),

        borderRadius: BorderRadius.circular(14),
      ),

      child: const Icon(Icons.category, color: Colors.green, size: 27),
    );
  }

  // ============================================================
  // PRODUCT IMAGE PLACEHOLDER
  // ============================================================

  Widget _productPlaceholder() {
    return Container(
      color: Colors.green.shade50,

      child: const Center(
        child: Icon(Icons.shopping_bag_outlined, color: Colors.green, size: 42),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,

      decoration: const BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),

      child: Column(
        children: [
          // ======================================================
          // HEADER
          // ======================================================
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),

            child: Row(
              children: [
                // ==================================================
                // CATEGORY IMAGE
                // ==================================================
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),

                  child: category.imageUrl.trim().isNotEmpty
                      ? Image.network(
                          category.imageUrl,

                          width: 58,
                          height: 58,

                          fit: BoxFit.cover,

                          errorBuilder: (_, __, ___) {
                            return _popupPlaceholder();
                          },
                        )
                      : _popupPlaceholder(),
                ),

                const SizedBox(width: 14),

                // ==================================================
                // CATEGORY NAME
                // ==================================================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        category.name,

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(
                          fontSize: 21,

                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        category.section,

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(
                          color: Colors.grey.shade600,

                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // ==================================================
                // CLOSE
                // ==================================================
                IconButton(
                  tooltip: 'Close',

                  onPressed: () {
                    Navigator.pop(context);
                  },

                  icon: const Icon(Icons.close, size: 28),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          // ======================================================
          // PRODUCTS
          // ======================================================
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: firestoreService.getProducts(),

              builder: (context, snapshot) {
                // =================================================
                // LOADING
                // =================================================

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  );
                }

                // =================================================
                // ERROR
                // =================================================

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),

                      child: Text(
                        'Unable to load products.\n'
                        '${snapshot.error}',

                        textAlign: TextAlign.center,

                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                // =================================================
                // PRODUCTS
                // =================================================

                final products = snapshot.data ?? [];

                // =================================================
                // CATEGORY FILTER
                // =================================================

                final filter = category.filter.trim().toLowerCase();

                final categoryName = category.name.trim().toLowerCase();

                final categoryProducts = products.where((product) {
                  final productCategory = product.category.trim().toLowerCase();

                  // ---------------------------------------------
                  // MATCH FILTER
                  // ---------------------------------------------

                  if (filter.isNotEmpty && productCategory == filter) {
                    return true;
                  }

                  // ---------------------------------------------
                  // MATCH CATEGORY NAME
                  // ---------------------------------------------

                  if (categoryName.isNotEmpty &&
                      productCategory == categoryName) {
                    return true;
                  }

                  return false;
                }).toList();

                // =================================================
                // EMPTY
                // =================================================

                if (categoryProducts.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,

                          size: 55,

                          color: Colors.grey,
                        ),

                        SizedBox(height: 12),

                        Text(
                          'No products available',

                          style: TextStyle(fontSize: 17, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // =================================================
                // PRODUCT GRID
                // =================================================

                return GridView.builder(
                  physics: const BouncingScrollPhysics(),

                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),

                  itemCount: categoryProducts.length,

                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,

                    crossAxisSpacing: 10,

                    mainAxisSpacing: 10,

                    mainAxisExtent: 320,
                  ),

                  itemBuilder: (context, index) {
                    return ProductCard(product: categoryProducts[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
