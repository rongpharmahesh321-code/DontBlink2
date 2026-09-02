import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/order_service.dart';
import 'location_map_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderService orderService = OrderService();

  // ==========================================================
  // FORMAT PRICE
  // ==========================================================

  String _formatPrice(dynamic value) {
    double price = 0;

    if (value is num) {
      price = value.toDouble();
    } else {
      price = double.tryParse(value.toString()) ?? 0;
    }

    if (price % 1 == 0) {
      return '₹${price.toInt()}';
    }

    return '₹${price.toStringAsFixed(2)}';
  }

  // ==========================================================
  // FORMAT DATE
  // ==========================================================

  String _formatDate(dynamic timestamp) {
    if (timestamp is! Timestamp) {
      return 'Date unavailable';
    }

    final date = timestamp.toDate();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/${date.year} • $hour:$minute $period';
  }

  // ==========================================================
  // STATUS COLOR
  // ==========================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Colors.blue;

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
        return Colors.deepPurple;

      case 'delivered':
        return Colors.green;

      case 'cancelled':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  // ==========================================================
  // STATUS ICON
  // ==========================================================

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Icons.receipt_long;

      case 'confirmed':
        return Icons.check_circle_outline;

      case 'packing':
      case 'packed':
        return Icons.inventory_2;

      case 'assigned to rider':
        return Icons.person_pin_circle;

      case 'accepted':
        return Icons.thumb_up;

      case 'picked up':
        return Icons.inventory;

      case 'out for delivery':
        return Icons.delivery_dining;

      case 'delivered':
        return Icons.check_circle;

      case 'cancelled':
        return Icons.cancel;

      default:
        return Icons.info_outline;
    }
  }

  // ==========================================================
  // ITEM COUNT
  // ==========================================================

  int _itemCount(dynamic items) {
    if (items is! List) {
      return 0;
    }

    int count = 0;

    for (final item in items) {
      if (item is Map) {
        final quantity = item['quantity'];

        if (quantity is num) {
          count += quantity.toInt();
        } else {
          count += int.tryParse(quantity.toString()) ?? 0;
        }
      }
    }

    return count;
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
          'My Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: orderService.getMyOrders(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final orders = snapshot.data?.docs ?? [];

          if (orders.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            color: Colors.green,

            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
            },

            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),

              itemCount: orders.length,

              itemBuilder: (context, index) {
                final order = orders[index];

                final data = order.data();

                return _AnimatedOrderCard(
                  index: index,

                  child: _buildOrderCard(context, order.id, data),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // ORDER CARD
  // ==========================================================

  Widget _buildOrderCard(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
  ) {
    final status = data['status']?.toString() ?? 'Placed';

    final items = data['items'];

    final total = data['grandTotal'] ?? 0;

    final itemCount = _itemCount(items);

    final statusColor = _statusColor(status);

    final statusIcon = _statusIcon(status);

    return Card(
      elevation: 2,

      margin: const EdgeInsets.only(bottom: 15),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),

      child: InkWell(
        borderRadius: BorderRadius.circular(18),

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  OrderDetailsScreen(orderId: orderId, initialData: data),
            ),
          );
        },

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,

                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),

                    child: Icon(statusIcon, color: statusColor, size: 24),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'Order',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),

                        Text(
                          '#${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',

                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),

                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Text(
                      status,

                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              const Divider(height: 1),

              const SizedBox(height: 14),

              Row(
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: 19,
                    color: Colors.grey,
                  ),

                  const SizedBox(width: 7),

                  Text(
                    '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),

                  const SizedBox(width: 18),

                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 17,
                    color: Colors.grey,
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    child: Text(
                      _formatDate(data['createdAt']),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),

                  const SizedBox(width: 8),

                  Text(
                    _formatPrice(total),
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Spacer(),

                  const Text(
                    'View Details',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(width: 4),

                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // EMPTY
  // ==========================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Container(
              width: 110,
              height: 110,

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

            const SizedBox(height: 25),

            const Text(
              'No Orders Yet',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              'Your orders will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),

            const SizedBox(height: 25),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },

              icon: const Icon(Icons.shopping_cart),

              label: const Text('Start Shopping'),

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // ERROR
  // ==========================================================

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 65),

            const SizedBox(height: 15),

            const Text(
              'Unable to Load Orders',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: () {
                setState(() {});
              },

              icon: const Icon(Icons.refresh),

              label: const Text('Try Again'),

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// ANIMATED ORDER CARD
// =============================================================

class _AnimatedOrderCard extends StatefulWidget {
  final Widget child;
  final int index;

  const _AnimatedOrderCard({required this.child, required this.index});

  @override
  State<_AnimatedOrderCard> createState() => _AnimatedOrderCardState();
}

class _AnimatedOrderCardState extends State<_AnimatedOrderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _fadeAnimation;

  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350 + (widget.index * 60)),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
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
      opacity: _fadeAnimation,

      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

// =============================================================
// CUSTOMER ORDER DETAILS
// =============================================================

class OrderDetailsScreen extends StatelessWidget {
  final String orderId;

  final Map<String, dynamic> initialData;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.initialData,
  });

  // ==========================================================
  // PRICE
  // ==========================================================

  String _formatPrice(dynamic value) {
    double price = 0;

    if (value is num) {
      price = value.toDouble();
    } else {
      price = double.tryParse(value.toString()) ?? 0;
    }

    if (price % 1 == 0) {
      return '₹${price.toInt()}';
    }

    return '₹${price.toStringAsFixed(2)}';
  }

  // ==========================================================
  // DATE
  // ==========================================================

  String _formatDate(dynamic timestamp) {
    if (timestamp is! Timestamp) {
      return 'Date unavailable';
    }

    final date = timestamp.toDate();

    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/${date.year} • $hour:$minute $period';
  }

  // ==========================================================
  // STATUS COLOR
  // ==========================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;

      case 'cancelled':
        return Colors.red;

      case 'out for delivery':
        return Colors.deepPurple;

      case 'picked up':
        return Colors.teal;

      case 'accepted':
        return Colors.blue;

      case 'assigned to rider':
        return Colors.indigo;

      case 'packing':
      case 'packed':
        return Colors.orange;

      default:
        return Colors.blue;
    }
  }

  // ==========================================================
  // STATUS ICON
  // ==========================================================

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Icons.check_circle;

      case 'cancelled':
        return Icons.cancel;

      case 'out for delivery':
        return Icons.delivery_dining;

      case 'picked up':
        return Icons.inventory;

      case 'accepted':
        return Icons.thumb_up;

      case 'assigned to rider':
        return Icons.person_pin_circle;

      case 'packing':
      case 'packed':
        return Icons.inventory_2;

      default:
        return Icons.receipt_long;
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: OrderService().getOrder(orderId),

      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? initialData;

        final status = data['status']?.toString() ?? 'Placed';

        final items = data['items'] is List
            ? List.from(data['items'])
            : <dynamic>[];

        final statusColor = _statusColor(status);

        return Scaffold(
          backgroundColor: const Color(0xffF7F8FA),

          appBar: AppBar(
            title: const Text(
              'Order Details',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            centerTitle: true,

            backgroundColor: Colors.green,

            foregroundColor: Colors.white,

            elevation: 0,
          ),

          body: ListView(
            padding: const EdgeInsets.all(16),

            children: [
              // ==================================================
              // LIVE TRACKING — THIS IS THE IMPORTANT PART
              // ==================================================
              if (status.toLowerCase() == 'out for delivery')
                CustomerLiveTrackingCard(orderId: orderId, data: data),

              if (status.toLowerCase() == 'out for delivery')
                const SizedBox(height: 16),

              // ==================================================
              // STATUS
              // ==================================================
              Card(
                elevation: 2,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),

                child: Padding(
                  padding: const EdgeInsets.all(20),

                  child: Column(
                    children: [
                      Container(
                        width: 65,
                        height: 65,

                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.10),

                          shape: BoxShape.circle,
                        ),

                        child: Icon(
                          _statusIcon(status),
                          color: statusColor,
                          size: 35,
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Order Status',
                        style: TextStyle(color: Colors.grey),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        status,

                        textAlign: TextAlign.center,

                        style: TextStyle(
                          color: statusColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        '#${orderId.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ==================================================
              // ITEMS
              // ==================================================
              const Text(
                'Items',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              ...items.map((item) {
                if (item is! Map) {
                  return const SizedBox.shrink();
                }

                final name = item['name']?.toString() ?? 'Product';

                final image = item['image']?.toString() ?? '';

                final quantity = item['quantity'] ?? 1;

                final price = item['price'] ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),

                  child: ListTile(
                    contentPadding: const EdgeInsets.all(8),

                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),

                      child: image.trim().isEmpty
                          ? Container(
                              width: 58,
                              height: 58,
                              color: Colors.grey.shade300,
                              child: const Icon(
                                Icons.shopping_bag,
                                color: Colors.green,
                              ),
                            )
                          : Image.network(
                              image,
                              width: 58,
                              height: 58,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  width: 58,
                                  height: 58,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.image),
                                );
                              },
                            ),
                    ),

                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    subtitle: Text('Qty: $quantity'),

                    trailing: Text(
                      _formatPrice(price),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 15),

              // ==================================================
              // DELIVERY ADDRESS
              // ==================================================
              const Text(
                'Delivery Address',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.green),

                  title: Text(
                    data['customerName']?.toString() ?? 'Customer',

                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  subtitle: Text(
                    data['address']?.toString() ?? 'Address unavailable',
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // BILL
              // ==================================================
              const Text(
                'Bill Details',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),

                  child: Column(
                    children: [
                      _billRow('Subtotal', _formatPrice(data['subtotal'])),

                      const SizedBox(height: 10),

                      _billRow(
                        'Delivery Fee',
                        _formatPrice(data['deliveryFee']),
                      ),

                      const SizedBox(height: 10),

                      _billRow(
                        'Platform Fee',
                        _formatPrice(data['platformFee']),
                      ),

                      const Divider(height: 25),

                      _billRow(
                        'Grand Total',
                        _formatPrice(data['grandTotal']),
                        total: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // PAYMENT
              // ==================================================
              Card(
                child: ListTile(
                  leading: const Icon(Icons.payment, color: Colors.green),

                  title: const Text('Payment Method'),

                  subtitle: Text(
                    data['paymentMethod']?.toString() ?? 'Unknown',
                  ),
                ),
              ),

              const SizedBox(height: 15),

              Center(
                child: Text(
                  _formatDate(data['createdAt']),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // BILL ROW
  // ==========================================================

  Widget _billRow(String title, String value, {bool total = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,

      children: [
        Text(
          title,

          style: TextStyle(
            fontSize: total ? 17 : 14,
            fontWeight: total ? FontWeight.bold : FontWeight.normal,
          ),
        ),

        Text(
          value,

          style: TextStyle(
            color: total ? Colors.green : Colors.black,

            fontSize: total ? 20 : 15,

            fontWeight: total ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
// =============================================================
// CUSTOMER LIVE TRACKING CARD
// =============================================================

class CustomerLiveTrackingCard extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;

  const CustomerLiveTrackingCard({
    super.key,
    required this.orderId,
    required this.data,
  });

  @override
  State<CustomerLiveTrackingCard> createState() =>
      _CustomerLiveTrackingCardState();
}

class _CustomerLiveTrackingCardState extends State<CustomerLiveTrackingCard> {
  final MapController _mapController = MapController();

  static const double storeLatitude = 25.8438;
  static const double storeLongitude = 93.4348;

  LatLng? _riderLocation;

  // ==========================================================
  // CUSTOMER LOCATION
  // ==========================================================

  LatLng? get _customerLocation {
    final lat = widget.data['customerLatitude'];
    final lng = widget.data['customerLongitude'];

    if (lat is! num || lng is! num) {
      return null;
    }

    return LatLng(lat.toDouble(), lng.toDouble());
  }

  // ==========================================================
  // RIDER LOCATION
  // ==========================================================

  LatLng? _readRiderLocation(Map<String, dynamic> data) {
    final lat = data['riderLatitude'];
    final lng = data['riderLongitude'];

    if (lat is! num || lng is! num) {
      return null;
    }

    return LatLng(lat.toDouble(), lng.toDouble());
  }

  // ==========================================================
  // ETA
  // ==========================================================

  int _calculateEta(LatLng rider) {
    final customer = _customerLocation;

    if (customer == null) {
      return 0;
    }

    final meters = const Distance().as(LengthUnit.Meter, rider, customer);

    final km = meters / 1000;

    const speed = 25.0;

    if (km < 0.05) {
      return 1;
    }

    return math.max(1, ((km / speed) * 60).ceil());
  }

  // ==========================================================
  // DISTANCE
  // ==========================================================

  String _distanceText(LatLng rider) {
    final customer = _customerLocation;

    if (customer == null) {
      return '--';
    }

    final meters = const Distance().as(LengthUnit.Meter, rider, customer);

    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }

    return '${meters.toStringAsFixed(0)} m';
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final customer = _customerLocation;

    if (customer == null) {
      return _buildUnavailableCard();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .snapshots(),

      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? widget.data;

        final rider = _readRiderLocation(data);

        _riderLocation = rider;

        final eta = rider == null ? null : _calculateEta(rider);

        final distance = rider == null ? null : _distanceText(rider);

        return Card(
          elevation: 4,

          margin: EdgeInsets.zero,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          clipBehavior: Clip.antiAlias,

          child: Column(
            children: [
              // ==================================================
              // HEADER
              // ==================================================
              Container(
                width: double.infinity,

                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),

                color: Colors.green,

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.delivery_dining,
                          color: Colors.white,
                          size: 25,
                        ),

                        const SizedBox(width: 9),

                        const Expanded(
                          child: Text(
                            'Your delivery is on the way',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),

                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),

                            borderRadius: BorderRadius.circular(20),
                          ),

                          child: const Row(
                            mainAxisSize: MainAxisSize.min,

                            children: [
                              Icon(Icons.circle, color: Colors.white, size: 7),

                              SizedBox(width: 5),

                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      eta != null
                          ? 'Arriving in about $eta minutes'
                          : 'Waiting for rider location...',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // MAP
              // ==================================================
              SizedBox(
                height: 280,
                width: double.infinity,

                child: FlutterMap(
                  mapController: _mapController,

                  options: MapOptions(
                    initialCenter: rider ?? customer,
                    initialZoom: 14,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),

                  children: [
                    // ==========================================
                    // MAP TILES
                    // ==========================================
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                      userAgentPackageName: 'com.dontblink.app',
                    ),

                    // ==========================================
                    // RIDER → CUSTOMER
                    // ==========================================
                    if (rider != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [rider, customer],

                            strokeWidth: 4,

                            color: Colors.green,
                          ),
                        ],
                      ),

                    // ==========================================
                    // MARKERS
                    // ==========================================
                    MarkerLayer(
                      markers: [
                        // CUSTOMER
                        Marker(
                          point: customer,

                          width: 55,
                          height: 55,

                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),

                            child: const Icon(
                              Icons.home,
                              color: Colors.white,
                              size: 27,
                            ),
                          ),
                        ),

                        // RIDER
                        if (rider != null)
                          Marker(
                            point: rider,

                            width: 65,
                            height: 65,

                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.35),
                                    blurRadius: 15,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),

                              child: const Icon(
                                Icons.delivery_dining,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ==================================================
              // INFO
              // ==================================================
              Padding(
                padding: const EdgeInsets.all(15),

                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _infoBox(
                            icon: Icons.navigation,
                            title: 'Distance',
                            value: distance ?? '--',
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: _infoBox(
                            icon: Icons.access_time,
                            title: 'ETA',
                            value: eta != null ? '$eta min' : '--',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ==========================================
                    // RIDER STATUS
                    // ==========================================
                    Container(
                      width: double.infinity,

                      padding: const EdgeInsets.all(12),

                      decoration: BoxDecoration(
                        color: Colors.green.shade50,

                        borderRadius: BorderRadius.circular(12),
                      ),

                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,

                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),

                            child: const Icon(
                              Icons.delivery_dining,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  data['riderName']?.toString() ??
                                      'Your delivery rider',

                                  maxLines: 1,

                                  overflow: TextOverflow.ellipsis,

                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),

                                const SizedBox(height: 2),

                                Text(
                                  rider == null
                                      ? 'Waiting for live location'
                                      : 'Rider is moving towards you',

                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (rider != null)
                            const Icon(
                              Icons.circle,
                              color: Colors.green,
                              size: 9,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==========================================
                    // FULL MAP BUTTON
                    // ==========================================
                    SizedBox(
                      width: double.infinity,
                      height: 48,

                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.fullscreen),

                        label: const Text(
                          'VIEW FULL LIVE MAP',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),

                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,

                          side: const BorderSide(color: Colors.green),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),

                        onPressed: () {
                          Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (_) => LocationMapScreen(
                                orderId: widget.orderId,

                                customerLatitude: customer.latitude,

                                customerLongitude: customer.longitude,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // INFO BOX
  // ==========================================================

  Widget _infoBox({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: Colors.grey.shade50,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: Colors.grey.shade200),
      ),

      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 21),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),

                const SizedBox(height: 2),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
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
  // LOCATION UNAVAILABLE
  // ==========================================================

  Widget _buildUnavailableCard() {
    return Card(
      elevation: 2,

      margin: EdgeInsets.zero,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,

              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),

              child: const Icon(Icons.location_off, color: Colors.orange),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'Live tracking unavailable',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 3),

                  Text(
                    'Delivery location is not available for this order.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
