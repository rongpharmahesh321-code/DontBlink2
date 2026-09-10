import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../services/order_service.dart';
import '../widgets/cached_product_image.dart';
import 'checkout_screen.dart';
import 'location_map_screen.dart';
import 'order_details_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();

  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  final ValueNotifier<String> _searchNotifier = ValueNotifier<String>('');
  String _filter = 'All';

  late final AnimationController _animationController;

  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
  }

  // ==========================================================
  // STATUS & FORMATTING HELPERS
  // ==========================================================

  bool _isActive(String status) {
    final value = status.trim().toLowerCase();
    return value != 'delivered' && value != 'cancelled';
  }

  bool _isTrackable(String status) {
    return status.trim().toLowerCase() == 'out for delivery';
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '₹${value.toInt()}';
    }
    return '₹${value.toStringAsFixed(2)}';
  }

  String _formatDateShort(DateTime? date) {
    if (date == null) return 'Recently';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final day = date.day.toString().padLeft(2, '0');
    final monthName = months[date.month - 1];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'pm' : 'am';

    return '$day $monthName, $hour:$minute $period';
  }

  Future<void> _reorder(OrderModel order) async {
    final cart = context.read<CartProvider>();
    int addedCount = 0;

    for (final item in order.items) {
      final id = (item['id'] ?? item['productId'] ?? '').toString();
      final name = (item['name'] ?? 'Product').toString();
      final price = (item['price'] ?? 0).toString();
      final image = (item['image'] ?? item['imageUrl'] ?? '').toString();
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;

      if (id.isNotEmpty) {
        final product = Product(
          id: id,
          name: name,
          price: price,
          image: image,
          description: '',
          category: '',
          stock: 99,
          isAvailable: true,
        );

        for (int i = 0; i < quantity; i++) {
          cart.add(product);
        }
        addedCount++;
      }
    }

    if (!mounted) return;

    if (addedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$addedCount ${addedCount == 1 ? 'item' : 'items'} added to cart! Proceeding to checkout...'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CheckoutScreen()),
      );
    } else {
      _showMessage('Unable to reorder items from this order.', error: true);
    }
  }

  // ==========================================================
  // SUMMARY
  // ==========================================================

  Map<String, int> _summary(List<OrderModel> orders) {
    int active = 0;
    int delivered = 0;
    int cancelled = 0;

    for (final order in orders) {
      final status = order.status.trim().toLowerCase();

      if (status == 'delivered') {
        delivered++;
      } else if (status == 'cancelled') {
        cancelled++;
      } else {
        active++;
      }
    }

    return {
      'all': orders.length,
      'active': active,
      'delivered': delivered,
      'cancelled': cancelled,
    };
  }

  // ==========================================================
  // FILTER
  // ==========================================================

  List<OrderModel> _filteredOrders(List<OrderModel> orders) {
    final query = _search.trim().toLowerCase();

    return orders.where((order) {
      final status = order.status.trim().toLowerCase();

      bool matchesFilter;

      switch (_filter) {
        case 'Active':
          matchesFilter = _isActive(order.status);
          break;

        case 'Delivered':
          matchesFilter = status == 'delivered';
          break;

        case 'Cancelled':
          matchesFilter = status == 'cancelled';
          break;

        default:
          matchesFilter = true;
      }

      if (!matchesFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final orderId = order.id.toLowerCase();

      final address = order.address.toLowerCase();

      final payment = order.paymentMethod.toLowerCase();

      final itemNames = order.items
          .map((item) => item['name']?.toString().toLowerCase() ?? '')
          .join(' ');

      return orderId.contains(query) ||
          address.contains(query) ||
          payment.contains(query) ||
          status.contains(query) ||
          itemNames.contains(query);
    }).toList();
  }

  // ==========================================================
  // TRACKING
  // ==========================================================

  Future<void> _openTracking(OrderModel order) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .get();

      if (!doc.exists) {
        if (!mounted) return;

        _showMessage('Order not found.', error: true);
        return;
      }

      final data = doc.data();

      if (data == null) {
        if (!mounted) return;

        _showMessage('Order data is unavailable.', error: true);
        return;
      }

      final latitude = data['customerLatitude'];

      final longitude = data['customerLongitude'];

      if (latitude is! num || longitude is! num) {
        if (!mounted) return;

        _showMessage(
          'Delivery location is unavailable for this order.',
          error: true,
        );
        return;
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LocationMapScreen(
            orderId: order.id,
            customerLatitude: latitude.toDouble(),
            customerLongitude: longitude.toDouble(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage('Unable to open live tracking.', error: true);
    }
  }

  // ==========================================================
  // DETAILS
  // ==========================================================

  void _openDetails(OrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)),
    );
  }

  // ==========================================
  // STATUS HELPERS FOR REDESIGN
  // ==========================================

  String _displayStatusTitle(String status) {
    switch (status.trim().toLowerCase()) {
      case 'delivered':
        return 'Order arrived';
      case 'cancelled':
        return 'Order cancelled';
      case 'out for delivery':
        return 'On the way';
      case 'packing':
      case 'packed':
        return 'Preparing order';
      case 'assigned to rider':
        return 'Rider assigned';
      case 'placed':
      case 'confirmed':
        return 'Order confirmed';
      default:
        return 'Order ${status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : ''}';
    }
  }

  Widget _buildStatusSquare(String status) {
    final s = status.trim().toLowerCase();
    final bool isDelivered = s == 'delivered';
    final bool isCancelled = s == 'cancelled';

    Color bgColor;
    Color iconColor;
    IconData icon;

    if (isDelivered) {
      bgColor = const Color(0xFFE8F5E9);
      iconColor = const Color(0xFF2E7D32);
      icon = Icons.check_rounded;
    } else if (isCancelled) {
      bgColor = const Color(0xFFFFECEC);
      iconColor = const Color(0xFFE53935);
      icon = Icons.close_rounded;
    } else {
      bgColor = const Color(0xFFFFF3E0);
      iconColor = const Color(0xFFEF6C00);
      icon = s == 'out for delivery'
          ? Icons.local_shipping_outlined
          : Icons.inventory_2_outlined;
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }

  // ==========================================================
  // SEARCH
  // ==========================================================

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ValueListenableBuilder<String>(
        valueListenable: _searchNotifier,
        builder: (context, searchValue, _) {
          return TextField(
            controller: _searchController,
            onChanged: (value) {
              _search = value;
              _searchNotifier.value = value;
            },
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              FocusScope.of(context).unfocus();
            },
            decoration: InputDecoration(
              hintText: 'Search your grocery orders',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 22),
              suffixIcon: searchValue.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _search = '';
                        _searchNotifier.value = '';
                        FocusScope.of(context).unfocus();
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // FAILED ORDERS BANNER
  // ==========================================================

  Widget _buildFailedOrdersBanner(int count) {
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade900,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your failed order ($count)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade900,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _filter = 'Cancelled';
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.orange.shade900,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // FILTERS
  // ==========================================================

  Widget _buildFilters(Map<String, int> summary) {
    final filters = [
      ('All', summary['all'] ?? 0),
      ('Active', summary['active'] ?? 0),
      ('Delivered', summary['delivered'] ?? 0),
      ('Cancelled', summary['cancelled'] ?? 0),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = filters[index];
          final selected = _filter == item.$1;

          return ChoiceChip(
            selected: selected,
            label: Text(
              '${item.$1} (${item.$2})',
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            selectedColor: AppColors.primary,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? AppColors.primary : Colors.grey.shade300,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onSelected: (_) {
              setState(() {
                _filter = item.$1;
              });
            },
          );
        },
      ),
    );
  }

  // ==========================================================
  // PRODUCT THUMBNAILS ROW
  // ==========================================================

  Widget _buildProductThumbnails(OrderModel order) {
    if (order.items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: order.items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final item = order.items[idx];
          final image = (item['image'] ?? item['imageUrl'] ?? '').toString();
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;

          return Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: image.isNotEmpty
                      ? CachedProductImage(
                          url: image,
                          width: 52,
                          height: 52,
                          fit: BoxFit.contain,
                        )
                      : Icon(
                          Icons.shopping_bag_outlined,
                          size: 26,
                          color: Colors.grey.shade400,
                        ),
                ),
                if (qty > 1)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '×$qty',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // RATING BANNER & DIALOG
  // ==========================================================

  Widget _buildRatingBanner(OrderModel order) {
    final hasRating = order.rating != null && order.rating! > 0;

    return InkWell(
      onTap: () => _showRatingDialog(order),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFA000), size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hasRating
                    ? 'Rating submitted. Thank you! • Edit'
                    : 'How was your order? Rate now',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(OrderModel order) {
    int selectedRating = order.rating ?? 5;
    final feedbackController =
        TextEditingController(text: order.ratingFeedback ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Rate your order',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Order #${order.id.toUpperCase()}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      return IconButton(
                        onPressed: () {
                          setModalState(() => selectedRating = star);
                        },
                        icon: Icon(
                          star <= selectedRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFFFA000),
                          size: 34,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: feedbackController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Add feedback (optional)',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await FirebaseFirestore.instance
                          .collection('orders')
                          .doc(order.id)
                          .update({
                        'rating': selectedRating,
                        'ratingFeedback': feedbackController.text.trim(),
                      });
                      _showMessage('Thank you for your rating!');
                    } catch (e) {
                      _showMessage('Could not save rating.', error: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // ORDER CARD
  // ==========================================================

  Widget _buildOrderCard(OrderModel order, int index) {
    final trackable = _isTrackable(order.status);
    final isDelivered = order.status.trim().toLowerCase() == 'delivered';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + (index * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetails(order),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Status Icon, Title & Date, More Options
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildStatusSquare(order.status),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayStatusTitle(order.status),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_formatPrice(order.grandTotal)} • ${_formatDateShort(order.createdAt)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (action) {
                        if (action == 'details') {
                          _openDetails(order);
                        } else if (action == 'track') {
                          _openTracking(order);
                        } else if (action == 'reorder') {
                          _reorder(order);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'details',
                          child: Text('View Details', style: TextStyle(fontSize: 13)),
                        ),
                        if (trackable)
                          const PopupMenuItem(
                            value: 'track',
                            child: Text('Track Order', style: TextStyle(fontSize: 13)),
                          ),
                        const PopupMenuItem(
                          value: 'reorder',
                          child: Text('Reorder Items', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),

                if (order.items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildProductThumbnails(order),
                ],

                if (isDelivered) ...[
                  const SizedBox(height: 10),
                  _buildRatingBanner(order),
                ],

                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 8),

                // Bottom Action: Reorder button (or Track + Reorder if active)
                if (trackable)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openTracking(order),
                          icon: const Icon(Icons.location_on_outlined, size: 16),
                          label: const Text(
                            'Track',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade800),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _reorder(order),
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          label: const Text(
                            'Reorder',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: AppColors.primary),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Center(
                    child: InkWell(
                      onTap: () => _reorder(order),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 16,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.refresh_rounded,
                              color: AppColors.primary,
                              size: 17,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Reorder',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
  // EMPTY
  // ==========================================================

  Widget _buildEmptyState() {
    String title;
    String message;

    switch (_filter) {
      case 'Active':
        title = 'No active orders';
        message = 'Orders currently being processed will appear here.';
        break;

      case 'Delivered':
        title = 'No delivered orders';
        message = 'Your completed deliveries will appear here.';
        break;

      case 'Cancelled':
        title = 'No cancelled orders';
        message = 'Cancelled orders will appear here.';
        break;

      default:
        title = 'No Orders Yet';
        message =
            'Your orders will appear here after you place your first order.';
    }

    if (_search.isNotEmpty) {
      title = 'No matching orders';
      message = 'Try a different order ID, item name or address.';
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 75),
          Container(
            width: 120,
            height: 120,
            margin: const EdgeInsets.symmetric(horizontal: 120),
            decoration: const BoxDecoration(
              color: AppColors.tintGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 58,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 38),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ERROR
  // ==========================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                color: Colors.red,
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Unable to load orders',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 17),
            OutlinedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('TRY AGAIN'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
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
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: const Text(
          'Order History',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.black87,
                  size: 19,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _orderService.getMyOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return _buildError();
          }

          final orders = (snapshot.data?.docs ?? [])
              .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
              .toList();

          final summary = _summary(orders);
          final failedCount = summary['cancelled'] ?? 0;

          return FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildSearchBar(),
                _buildFailedOrdersBanner(failedCount),
                _buildFilters(summary),
                const SizedBox(height: 6),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _searchNotifier,
                    builder: (context, _, _) {
                      final filtered = _filteredOrders(orders);

                      return filtered.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: () async {
                                await Future<void>.delayed(
                                  const Duration(milliseconds: 400),
                                );
                              },
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 30,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  return _buildOrderCard(
                                    filtered[index],
                                    index,
                                  );
                                },
                              ),
                            );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red : AppColors.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(14),
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchNotifier.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
