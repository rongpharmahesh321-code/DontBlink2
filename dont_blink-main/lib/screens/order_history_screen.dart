import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/order_service.dart';
import 'location_map_screen.dart';
import 'order_details_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final OrderService _orderService = OrderService();

  String _filter = 'All';
  String _search = '';

  final TextEditingController _searchController = TextEditingController();

  // ==========================================================
  // STATUS HELPERS
  // ==========================================================

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'placed':
        return Colors.deepPurple;

      case 'confirmed':
        return Colors.indigo;

      case 'packing':
      case 'packed':
        return Colors.orange;

      case 'assigned to rider':
        return Colors.indigo;

      case 'accepted':
        return Colors.blue;

      case 'picked up':
        return Colors.teal;

      case 'out for delivery':
        return Colors.deepOrange;

      case 'delivered':
        return Colors.green;

      case 'cancelled':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.trim().toLowerCase()) {
      case 'placed':
        return Icons.receipt_long_outlined;

      case 'confirmed':
        return Icons.check_circle_outline;

      case 'packing':
      case 'packed':
        return Icons.inventory_2_outlined;

      case 'assigned to rider':
        return Icons.person_pin_circle_outlined;

      case 'accepted':
        return Icons.thumb_up_outlined;

      case 'picked up':
        return Icons.inventory_outlined;

      case 'out for delivery':
        return Icons.delivery_dining_outlined;

      case 'delivered':
        return Icons.check_circle_outline;

      case 'cancelled':
        return Icons.cancel_outlined;

      default:
        return Icons.shopping_bag_outlined;
    }
  }

  String _statusDescription(String status) {
    switch (status.trim().toLowerCase()) {
      case 'placed':
        return 'Order received';

      case 'confirmed':
        return 'Order confirmed';

      case 'packing':
      case 'packed':
        return 'Your order is being prepared';

      case 'assigned to rider':
        return 'A delivery partner is assigned';

      case 'accepted':
        return 'Rider accepted the order';

      case 'picked up':
        return 'Rider picked up your order';

      case 'out for delivery':
        return 'Your order is on the way';

      case 'delivered':
        return 'Order delivered successfully';

      case 'cancelled':
        return 'Order has been cancelled';

      default:
        return 'Order is being processed';
    }
  }

  bool _isActive(String status) {
    final value = status.trim().toLowerCase();

    return value != 'delivered' && value != 'cancelled';
  }

  bool _isTrackable(String status) {
    return status.trim().toLowerCase() == 'out for delivery';
  }

  // ==========================================================
  // PRICE
  // ==========================================================

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '₹${value.toInt()}';
    }

    return '₹${value.toStringAsFixed(2)}';
  }

  // ==========================================================
  // DATE
  // ==========================================================

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Recently';
    }

    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/${date.year} • '
        '$hour:$minute $period';
  }

  // ==========================================================
  // ITEM COUNT
  // ==========================================================

  int _itemCount(OrderModel order) {
    int count = 0;

    for (final item in order.items) {
      final value = item['quantity'];

      if (value is num) {
        count += value.toInt();
      } else {
        count += int.tryParse(value?.toString() ?? '') ?? 0;
      }
    }

    return count;
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

      return orderId.contains(query) ||
          address.contains(query) ||
          payment.contains(query) ||
          status.contains(query);
    }).toList();
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
  // TRACKING
  // ==========================================================

  Future<void> _openTracking(BuildContext context, OrderModel order) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .get();

      if (!doc.exists) {
        if (!context.mounted) return;

        _showMessage('Order not found.', error: true);

        return;
      }

      final data = doc.data();

      if (data == null) {
        if (!context.mounted) return;

        _showMessage('Order data is unavailable.', error: true);

        return;
      }

      final latitude = data['customerLatitude'];

      final longitude = data['customerLongitude'];

      if (latitude is! num || longitude is! num) {
        if (!context.mounted) return;

        _showMessage(
          'Delivery location is unavailable for this order.',
          error: true,
        );

        return;
      }

      if (!context.mounted) return;

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
      if (!context.mounted) return;

      _showMessage('Unable to open live tracking.', error: true);
    }
  }

  // ==========================================================
  // VIEW DETAILS
  // ==========================================================

  void _openDetails(BuildContext context, OrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)),
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
          backgroundColor: error ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }

  // ==========================================================
  // SEARCH
  // ==========================================================

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _search = value;
          });
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search orders or order ID',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.green),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _search = '';
                    });
                  },
                  icon: const Icon(Icons.close),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
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
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = filters[index];

          final selected = _filter == item.$1;

          return ChoiceChip(
            selected: selected,
            label: Text(
              '${item.$1} ${item.$2}',
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            selectedColor: Colors.green,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? Colors.green : Colors.grey.shade200,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
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
  // HEADER SUMMARY
  // ==========================================================

  Widget _buildSummary(Map<String, int> summary) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _summaryItem('${summary['all'] ?? 0}', 'Orders'),
          _summaryDivider(),
          _summaryItem('${summary['active'] ?? 0}', 'Active'),
          _summaryDivider(),
          _summaryItem('${summary['delivered'] ?? 0}', 'Delivered'),
        ],
      ),
    );
  }

  Widget _summaryItem(String value, String title) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(width: 1, height: 32, color: Colors.white24);
  }

  // ==========================================================
  // ORDER CARD
  // ==========================================================

  Widget _buildOrderCard(OrderModel order, int index) {
    final color = _statusColor(order.status);

    final trackable = _isTrackable(order.status);

    final count = _itemCount(order);

    final itemPreview = order.items.isEmpty
        ? 'No item information'
        : order.items
              .take(2)
              .map((item) => item['name']?.toString() ?? 'Product')
              .join(', ');

    final extraItems = order.items.length > 2 ? order.items.length - 2 : 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index * 55)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 3),
              spreadRadius: -5,
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: () => _openDetails(context, order),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                // ----------------------------------------------
                // TOP
                // ----------------------------------------------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 47,
                      height: 47,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _statusIcon(order.status),
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.id.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(order.createdAt),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        order.status,
                        style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 13),

                // ----------------------------------------------
                // STATUS MESSAGE
                // ----------------------------------------------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: color, size: 17),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _statusDescription(order.status),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ----------------------------------------------
                // ITEMS + TOTAL
                // ----------------------------------------------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 39,
                      height: 39,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$count ${count == 1 ? 'item' : 'items'}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            extraItems > 0
                                ? '$itemPreview + $extraItems more'
                                : itemPreview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatPrice(order.grandTotal),
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 13),

                // ----------------------------------------------
                // ADDRESS
                // ----------------------------------------------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: Colors.grey.shade500,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ----------------------------------------------
                // ACTIONS
                // ----------------------------------------------
                if (trackable)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _openTracking(context, order),
                      icon: const Icon(Icons.location_on_outlined, size: 20),
                      label: const Text(
                        'TRACK MY ORDER',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _openDetails(context, order),
                      icon: const Icon(Icons.receipt_long_outlined, size: 19),
                      label: const Text(
                        'VIEW ORDER DETAILS',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
        message = 'Orders that are currently being processed will appear here.';
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

    return RefreshIndicator(
      color: Colors.green,
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 95),
          Container(
            width: 120,
            height: 120,
            margin: const EdgeInsets.symmetric(horizontal: 120),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 58,
              color: Colors.green,
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

  Widget _buildError(Object? error) {
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
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green),
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
      backgroundColor: const Color(0xffF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Order History',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _orderService.getMyOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (snapshot.hasError) {
            return _buildError(snapshot.error);
          }

          final orders = (snapshot.data?.docs ?? [])
              .map((doc) => OrderModel.fromFirestore(doc.id, doc.data()))
              .toList();

          final summary = _summary(orders);

          final filtered = _filteredOrders(orders);

          return Column(
            children: [
              _buildSearchBar(),
              _buildFilters(summary),
              _buildSummary(summary),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: Colors.green,
                        onRefresh: () async {
                          await Future<void>.delayed(
                            const Duration(milliseconds: 500),
                          );
                        },
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 2, bottom: 30),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _buildOrderCard(filtered[index], index);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
