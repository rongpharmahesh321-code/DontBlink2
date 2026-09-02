import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/order.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================
  // ANIMATION
  // ==========================================================

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

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
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  // ==========================================================
  // STATUS COLOR
  // ==========================================================

  Color _statusColor(String status) {
    switch (status) {
      case 'Placed':
        return Colors.deepPurple;

      case 'Packed':
        return Colors.blue;

      case 'Assigned to Rider':
        return Colors.indigo;

      case 'Accepted':
        return Colors.blue;

      case 'Picked Up':
        return Colors.teal;

      case 'Out for Delivery':
        return Colors.orange;

      case 'Delivered':
        return Colors.green;

      case 'Cancelled':
        return Colors.red;

      default:
        return Colors.deepPurple;
    }
  }

  // ==========================================================
  // STATUS ICON
  // ==========================================================

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Placed':
        return Icons.shopping_bag;

      case 'Packed':
        return Icons.inventory_2;

      case 'Assigned to Rider':
        return Icons.person_pin_circle;

      case 'Accepted':
        return Icons.thumb_up;

      case 'Picked Up':
        return Icons.inventory;

      case 'Out for Delivery':
        return Icons.delivery_dining;

      case 'Delivered':
        return Icons.check_circle;

      case 'Cancelled':
        return Icons.cancel;

      default:
        return Icons.shopping_bag;
    }
  }

  // ==========================================================
  // STATUS MESSAGE
  // ==========================================================

  String _statusMessage(String status) {
    switch (status) {
      case 'Placed':
        return 'Your order has been received.';

      case 'Packed':
        return 'Your groceries are packed and ready.';

      case 'Assigned to Rider':
        return 'A rider has been assigned to your order.';

      case 'Accepted':
        return 'Your rider has accepted the delivery.';

      case 'Picked Up':
        return 'Your rider has picked up the order.';

      case 'Out for Delivery':
        return 'Your order is on the way.';

      case 'Delivered':
        return 'Your order has been delivered successfully.';

      case 'Cancelled':
        return 'This order has been cancelled.';

      default:
        return 'Your order is being processed.';
    }
  }

  // ==========================================================
  // STATUS INDEX
  // ==========================================================

  int _statusIndex(String status) {
    switch (status) {
      case 'Placed':
        return 0;

      case 'Packed':
        return 1;

      case 'Assigned to Rider':
        return 2;

      case 'Accepted':
        return 3;

      case 'Picked Up':
        return 4;

      case 'Out for Delivery':
        return 5;

      case 'Delivered':
        return 6;

      default:
        return 0;
    }
  }

  // ==========================================================
  // CHECK LIVE DELIVERY
  // ==========================================================

  bool _isOutForDelivery(String status) {
    return status
            .trim()
            .toLowerCase()
            .replaceAll('_', ' ')
            .replaceAll('-', ' ')
            .replaceAll(RegExp(r'\s+'), ' ') ==
        'out for delivery';
  }

  // ==========================================================
  // FORMAT PRICE
  // ==========================================================

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '₹${value.toInt()}';
    }

    return '₹${value.toStringAsFixed(2)}';
  }

  // ==========================================================
  // FORMAT DATE
  // ==========================================================

  String _formatDate(dynamic timestamp) {
    DateTime? date;

    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    }

    if (date == null) {
      return 'Recently';
    }

    final String day = date.day.toString().padLeft(2, '0');

    final String month = date.month.toString().padLeft(2, '0');

    final int hour = date.hour % 12 == 0 ? 12 : date.hour % 12;

    final String minute = date.minute.toString().padLeft(2, '0');

    final String period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/${date.year} • $hour:$minute $period';
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final OrderModel order = widget.order;

    return Scaffold(
      backgroundColor: const Color(0xffF7F8FA),

      // ========================================================
      // APP BAR
      // ========================================================
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

      // ========================================================
      // BODY
      // ========================================================
      body: FadeTransition(
        opacity: _fadeAnimation,

        child: SlideTransition(
          position: _slideAnimation,

          child: ListView(
            padding: const EdgeInsets.all(16),

            children: [
              // ==================================================
              // STATUS
              // ==================================================
              _buildStatusCard(order),

              // ==================================================
              // LIVE MAP
              // ==================================================
              if (_isOutForDelivery(order.status)) ...[
                const SizedBox(height: 16),

                _buildLiveMap(order),

                const SizedBox(height: 16),
              ],

              // ==================================================
              // ORDER PROGRESS
              // ==================================================
              _buildOrderTimeline(order.status),

              const SizedBox(height: 16),

              // ==================================================
              // ITEMS
              // ==================================================
              _buildProductsCard(order),

              const SizedBox(height: 16),

              // ==================================================
              // ADDRESS
              // ==================================================
              _buildAddressCard(order),

              const SizedBox(height: 16),

              // ==================================================
              // ORDER INFORMATION
              // ==================================================
              _buildOrderInfo(order),

              const SizedBox(height: 16),

              // ==================================================
              // BILL
              // ==================================================
              _buildBillCard(order),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // LIVE MAP
  // ==========================================================

  Widget _buildLiveMap(OrderModel order) {
    return _LiveCustomerMap(orderId: order.id);
  }

  // ==========================================================
  // COMMON CARD
  // ==========================================================

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: child,
    );
  }

  // ==========================================================
  // SECTION HEADER
  // ==========================================================

  Widget _sectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,

          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(11),
          ),

          child: Icon(icon, color: Colors.green, size: 21),
        ),

        const SizedBox(width: 10),

        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ==========================================================
  // STATUS CARD
  // ==========================================================

  Widget _buildStatusCard(OrderModel order) {
    final Color color = _statusColor(order.status);

    return _buildCard(
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,

            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),

            child: Icon(_statusIcon(order.status), color: color, size: 40),
          ),

          const SizedBox(height: 14),

          const Text(
            'Order Status',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),

          const SizedBox(height: 5),

          Text(
            order.status,
            textAlign: TextAlign.center,

            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            _statusMessage(order.status),
            textAlign: TextAlign.center,

            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),

            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),

            child: Text(
              '#${order.id.toUpperCase()}',

              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // ======================================================
          // LIVE DELIVERY BADGE
          // ======================================================
          if (_isOutForDelivery(order.status)) ...[
            const SizedBox(height: 14),

            Container(
              width: double.infinity,

              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),

              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Icon(Icons.circle, color: Colors.green, size: 8),

                  SizedBox(width: 6),

                  Text(
                    'LIVE DELIVERY TRACKING',
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
        ],
      ),
    );
  }

  // ==========================================================
  // ORDER TIMELINE
  // ==========================================================

  Widget _buildOrderTimeline(String status) {
    const List<String> stages = [
      'Placed',
      'Packed',
      'Assigned to Rider',
      'Accepted',
      'Picked Up',
      'Out for Delivery',
      'Delivered',
    ];

    final int currentIndex = _statusIndex(status);

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          _sectionHeader(icon: Icons.timeline, title: 'Order Progress'),

          const SizedBox(height: 18),

          ...List.generate(stages.length, (index) {
            final bool completed = currentIndex >= index;

            final bool active = currentIndex == index;

            final bool last = index == stages.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,

                      decoration: BoxDecoration(
                        shape: BoxShape.circle,

                        color: completed ? Colors.green : Colors.grey.shade200,

                        border: active
                            ? Border.all(color: Colors.green, width: 3)
                            : null,
                      ),

                      child: Icon(
                        completed ? Icons.check : Icons.circle,

                        size: completed ? 17 : 7,

                        color: completed ? Colors.white : Colors.grey,
                      ),
                    ),

                    if (!last)
                      Container(
                        width: 2,
                        height: 30,

                        color: currentIndex > index
                            ? Colors.green
                            : Colors.grey.shade200,
                      ),
                  ],
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          stages[index],

                          style: TextStyle(
                            color: completed ? Colors.green : Colors.grey,

                            fontWeight: active || completed
                                ? FontWeight.bold
                                : FontWeight.normal,

                            fontSize: 14,
                          ),
                        ),

                        if (active)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),

                            child: Text(
                              _statusMessage(status),

                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ==========================================================
  // PRODUCTS CARD
  // ==========================================================

  Widget _buildProductsCard(OrderModel order) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          _sectionHeader(icon: Icons.shopping_bag, title: 'Items'),

          const SizedBox(height: 14),

          if (order.items.isEmpty)
            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(14),

              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),

              child: const Text(
                'No items available.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...order.items.map((item) => _buildProductItem(item)),
        ],
      ),
    );
  }

  // ==========================================================
  // PRODUCT ITEM
  // ==========================================================

  Widget _buildProductItem(dynamic item) {
    String name = 'Product';
    String quantity = '1';
    double price = 0;
    String image = '';

    if (item is Map) {
      name = item['name']?.toString() ?? 'Product';

      quantity = item['quantity']?.toString() ?? '1';

      final dynamic priceValue = item['price'];

      if (priceValue is num) {
        price = priceValue.toDouble();
      } else {
        price = double.tryParse(priceValue?.toString() ?? '') ?? 0;
      }

      image = item['imageUrl']?.toString() ?? item['image']?.toString() ?? '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(9),

      decoration: BoxDecoration(
        color: Colors.grey.shade50,

        borderRadius: BorderRadius.circular(13),

        border: Border.all(color: Colors.grey.shade200),
      ),

      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),

            child: image.trim().isNotEmpty
                ? Image.network(
                    image,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,

                    errorBuilder: (_, __, ___) {
                      return _productPlaceholder();
                    },
                  )
                : _productPlaceholder(),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  name,

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Qty: $quantity',

                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Text(
            _formatPrice(price),

            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // PRODUCT PLACEHOLDER
  // ==========================================================

  Widget _productPlaceholder() {
    return Container(
      width: 58,
      height: 58,

      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),

      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey,
        size: 25,
      ),
    );
  }

  // ==========================================================
  // ADDRESS CARD
  // ==========================================================

  Widget _buildAddressCard(OrderModel order) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          _sectionHeader(icon: Icons.location_on, title: 'Delivery Address'),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,

            padding: const EdgeInsets.all(13),

            decoration: BoxDecoration(
              color: Colors.green.shade50,

              borderRadius: BorderRadius.circular(13),
            ),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Icon(Icons.location_on, color: Colors.green, size: 25),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    order.address.isNotEmpty
                        ? order.address
                        : 'Delivery address unavailable',

                    style: const TextStyle(fontSize: 14, height: 1.4),
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
  // ORDER INFORMATION
  // ==========================================================

  Widget _buildOrderInfo(OrderModel order) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          _sectionHeader(icon: Icons.receipt_long, title: 'Order Information'),

          const SizedBox(height: 15),

          _infoRow('Order ID', order.id),

          const SizedBox(height: 10),

          _infoRow('Status', order.status),

          const SizedBox(height: 10),

          _infoRow('Items', '${order.items.length}'),
        ],
      ),
    );
  }

  // ==========================================================
  // INFO ROW
  // ==========================================================

  Widget _infoRow(String title, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,

            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
        ),

        Flexible(
          child: Text(
            value,

            textAlign: TextAlign.end,

            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // BILL CARD
  // ==========================================================

  Widget _buildBillCard(OrderModel order) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          _sectionHeader(icon: Icons.receipt_long, title: 'Bill Details'),

          const SizedBox(height: 15),

          _billRow('Subtotal', _formatPrice(order.subtotal)),

          const SizedBox(height: 10),

          _billRow('Delivery Fee', _formatPrice(order.deliveryFee)),

          const SizedBox(height: 10),

          _billRow('Platform Fee', _formatPrice(order.platformFee)),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1),
          ),

          _billRow(
            'Grand Total',
            _formatPrice(order.grandTotal),
            bold: true,
            large: true,
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // BILL ROW
  // ==========================================================

  Widget _billRow(
    String title,
    String value, {
    bool bold = false,
    bool large = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,

            style: TextStyle(
              color: bold ? Colors.black : Colors.grey.shade700,

              fontSize: large ? 16 : 14,

              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),

        Text(
          value,

          style: TextStyle(
            color: large ? Colors.green : Colors.black87,

            fontSize: large ? 20 : 14,

            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
// =============================================================
// LIVE CUSTOMER MAP
// =============================================================

class _LiveCustomerMap extends StatefulWidget {
  final String orderId;

  const _LiveCustomerMap({required this.orderId});

  @override
  State<_LiveCustomerMap> createState() => _LiveCustomerMapState();
}

class _LiveCustomerMapState extends State<_LiveCustomerMap> {
  // ==========================================================
  // MAP
  // ==========================================================

  final MapController _mapController = MapController();

  // ==========================================================
  // LOCATIONS
  // ==========================================================

  LatLng? _customerLocation;

  LatLng? _riderLocation;

  // ==========================================================
  // ROUTE
  // ==========================================================

  List<LatLng> _routePoints = [];

  double _routeDistance = 0;

  double _routeDuration = 0;

  bool _loadingRoute = false;

  DateTime? _lastRouteRequest;

  // ==========================================================
  // STORE
  // ==========================================================

  static const LatLng _storeLocation = LatLng(25.8438, 93.4348);

  // ==========================================================
  // RIDER
  // ==========================================================

  String _riderName = 'Your Delivery Partner';

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .snapshots(),

      builder: (context, snapshot) {
        // ======================================================
        // ERROR
        // ======================================================

        if (snapshot.hasError) {
          return _mapUnavailable('Unable to load live delivery.');
        }

        // ======================================================
        // LOADING
        // ======================================================

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            height: 220,

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),

            child: const Center(
              child: CircularProgressIndicator(color: Colors.green),
            ),
          );
        }

        final Map<String, dynamic>? data = snapshot.data!.data();

        if (data == null) {
          return _mapUnavailable('Delivery information unavailable.');
        }

        // ======================================================
        // CUSTOMER LOCATION
        // ======================================================

        final dynamic customerLat = data['customerLatitude'];

        final dynamic customerLng = data['customerLongitude'];

        if (customerLat is! num || customerLng is! num) {
          return _mapUnavailable('Delivery location is unavailable.');
        }

        final LatLng customer = LatLng(
          customerLat.toDouble(),
          customerLng.toDouble(),
        );

        _customerLocation = customer;

        // ======================================================
        // RIDER NAME
        // ======================================================

        final dynamic riderName = data['riderName'];

        if (riderName != null && riderName.toString().trim().isNotEmpty) {
          _riderName = riderName.toString();
        }

        // ======================================================
        // RIDER LOCATION
        // ======================================================

        final dynamic riderLat = data['riderLatitude'];

        final dynamic riderLng = data['riderLongitude'];

        if (riderLat is num && riderLng is num) {
          final LatLng rider = LatLng(riderLat.toDouble(), riderLng.toDouble());

          final bool changed =
              _riderLocation == null ||
              _riderLocation!.latitude != rider.latitude ||
              _riderLocation!.longitude != rider.longitude;

          _riderLocation = rider;

          // ==================================================
          // REQUEST ROUTE AFTER BUILD
          // ==================================================

          if (changed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              _requestRoute(rider, customer);
            });
          }
        }

        // ======================================================
        // MAIN MAP CARD
        // ======================================================

        return Container(
          width: double.infinity,

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(20),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),

                blurRadius: 12,

                offset: const Offset(0, 4),
              ),
            ],
          ),

          clipBehavior: Clip.antiAlias,

          child: Column(
            children: [
              // ==================================================
              // MAP
              // ==================================================
              SizedBox(
                height: 270,

                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,

                      options: MapOptions(
                        initialCenter: _riderLocation ?? _customerLocation!,

                        initialZoom: 14,
                      ),

                      children: [
                        // ========================================
                        // OPEN STREET MAP
                        // ========================================
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                          userAgentPackageName: 'com.dontblink.app',
                        ),

                        // ========================================
                        // ROUTE
                        // ========================================
                        if (_routePoints.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints,

                                strokeWidth: 5,

                                color: Colors.green,
                              ),
                            ],
                          ),

                        // ========================================
                        // MARKERS
                        // ========================================
                        MarkerLayer(
                          markers: [
                            // ==================================
                            // STORE
                            // ==================================
                            Marker(
                              point: _storeLocation,

                              width: 55,

                              height: 55,

                              child: _mapMarker(Icons.store, Colors.green),
                            ),

                            // ==================================
                            // CUSTOMER
                            // ==================================
                            Marker(
                              point: _customerLocation!,

                              width: 55,

                              height: 55,

                              child: _mapMarker(Icons.location_on, Colors.red),
                            ),

                            // ==================================
                            // RIDER
                            // ==================================
                            if (_riderLocation != null)
                              Marker(
                                point: _riderLocation!,

                                width: 65,

                                height: 65,

                                child: _riderMarker(),
                              ),
                          ],
                        ),
                      ],
                    ),

                    // ==================================================
                    // LIVE BADGE
                    // ==================================================
                    if (_riderLocation != null)
                      Positioned(
                        top: 12,
                        right: 12,

                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),

                          decoration: BoxDecoration(
                            color: Colors.white,

                            borderRadius: BorderRadius.circular(20),

                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),

                                blurRadius: 8,
                              ),
                            ],
                          ),

                          child: const Row(
                            mainAxisSize: MainAxisSize.min,

                            children: [
                              Icon(Icons.circle, color: Colors.green, size: 8),

                              SizedBox(width: 5),

                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ==================================================
                    // CENTER RIDER BUTTON
                    // ==================================================
                    if (_riderLocation != null)
                      Positioned(
                        right: 12,
                        bottom: 12,

                        child: FloatingActionButton.small(
                          heroTag: 'customer_map_${widget.orderId}',

                          backgroundColor: Colors.white,

                          foregroundColor: Colors.green,

                          onPressed: () {
                            _mapController.move(_riderLocation!, 16);
                          },

                          child: const Icon(Icons.my_location),
                        ),
                      ),
                  ],
                ),
              ),

              // ==================================================
              // DELIVERY INFORMATION
              // ==================================================
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),

                child: Column(
                  children: [
                    // ==========================================
                    // ETA
                    // ==========================================
                    Row(
                      children: [
                        Container(
                          width: 43,
                          height: 43,

                          decoration: BoxDecoration(
                            color: Colors.green.shade50,

                            borderRadius: BorderRadius.circular(12),
                          ),

                          child: const Icon(
                            Icons.access_time,
                            color: Colors.green,
                          ),
                        ),

                        const SizedBox(width: 11),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Text(
                                _riderLocation != null
                                    ? 'Arriving in ${_etaMinutes()} min'
                                    : 'Waiting for rider',

                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 3),

                              Text(
                                _riderLocation != null
                                    ? '${_formatDistance()} away'
                                    : 'Live location will appear when delivery starts',

                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_loadingRoute)
                          const SizedBox(
                            width: 20,
                            height: 20,

                            child: CircularProgressIndicator(
                              strokeWidth: 2,

                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ==========================================
                    // DELIVERY PARTNER CARD
                    // ==========================================
                    Container(
                      width: double.infinity,

                      padding: const EdgeInsets.all(11),

                      decoration: BoxDecoration(
                        color: Colors.green.shade50,

                        borderRadius: BorderRadius.circular(13),
                      ),

                      child: Row(
                        children: [
                          Container(
                            width: 45,
                            height: 45,

                            decoration: const BoxDecoration(
                              color: Colors.green,

                              shape: BoxShape.circle,
                            ),

                            child: const Icon(
                              Icons.delivery_dining,

                              color: Colors.white,

                              size: 27,
                            ),
                          ),

                          const SizedBox(width: 11),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  _riderName,

                                  maxLines: 1,

                                  overflow: TextOverflow.ellipsis,

                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,

                                    fontSize: 14,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                Text(
                                  _riderLocation != null
                                      ? 'Your delivery partner is on the way'
                                      : 'Preparing your delivery',

                                  style: const TextStyle(
                                    color: Colors.grey,

                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (_riderLocation != null)
                            const Icon(
                              Icons.circle,
                              color: Colors.green,
                              size: 9,
                            ),
                        ],
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
  // REQUEST ROAD ROUTE
  // ==========================================================

  Future<void> _requestRoute(LatLng rider, LatLng customer) async {
    // ========================================================
    // DON'T REQUEST TOO OFTEN
    // ========================================================

    final DateTime now = DateTime.now();

    if (_lastRouteRequest != null &&
        now.difference(_lastRouteRequest!) < const Duration(seconds: 8)) {
      return;
    }

    _lastRouteRequest = now;

    if (mounted) {
      setState(() {
        _loadingRoute = true;
      });
    }

    try {
      // ======================================================
      // OSRM ROUTING
      // ======================================================

      final Uri url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${rider.longitude},${rider.latitude};'
        '${customer.longitude},${customer.latitude}'
        '?overview=full&geometries=geojson',
      );

      final http.Response response = await http.get(
        url,
        headers: const {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Routing server returned '
          '${response.statusCode}',
        );
      }

      final Map<String, dynamic> result = jsonDecode(response.body);

      if (result['code'] != 'Ok') {
        throw Exception('Route not found');
      }

      final dynamic routes = result['routes'];

      if (routes == null || routes.isEmpty) {
        throw Exception('No route available');
      }

      final Map<String, dynamic> route = routes[0];

      // ======================================================
      // ROUTE GEOMETRY
      // ======================================================

      final dynamic geometry = route['geometry'];

      final dynamic coordinates = geometry['coordinates'];

      final List<LatLng> points = [];

      for (final coordinate in coordinates) {
        points.add(
          LatLng(
            (coordinate[1] as num).toDouble(),

            (coordinate[0] as num).toDouble(),
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _routePoints = points;

        _routeDistance = (route['distance'] as num).toDouble();

        _routeDuration = (route['duration'] as num).toDouble();

        _loadingRoute = false;
      });
    } catch (e) {
      debugPrint('Customer route error: $e');

      if (!mounted) return;

      setState(() {
        _loadingRoute = false;
      });
    }
  }

  // ==========================================================
  // MAP MARKER
  // ==========================================================

  Widget _mapMarker(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,

        shape: BoxShape.circle,

        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.20), blurRadius: 7),
        ],
      ),

      child: Icon(icon, color: color, size: 32),
    );
  }

  // ==========================================================
  // RIDER MARKER
  // ==========================================================

  Widget _riderMarker() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green,

        shape: BoxShape.circle,

        border: Border.all(color: Colors.white, width: 3),

        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8),
        ],
      ),

      child: const Icon(Icons.delivery_dining, color: Colors.white, size: 32),
    );
  }

  // ==========================================================
  // ETA
  // ==========================================================

  int _etaMinutes() {
    if (_routeDuration <= 0) {
      return 1;
    }

    return math.max(1, (_routeDuration / 60).ceil());
  }

  // ==========================================================
  // DISTANCE
  // ==========================================================

  String _formatDistance() {
    if (_routeDistance <= 0) {
      return '--';
    }

    if (_routeDistance >= 1000) {
      return '${(_routeDistance / 1000).toStringAsFixed(1)} km';
    }

    return '${_routeDistance.toStringAsFixed(0)} m';
  }

  // ==========================================================
  // MAP UNAVAILABLE
  // ==========================================================

  Widget _mapUnavailable(String message) {
    return Container(
      width: double.infinity,

      height: 180,

      alignment: Alignment.center,

      decoration: BoxDecoration(
        color: Colors.grey.shade100,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          const Icon(Icons.location_off, color: Colors.grey, size: 40),

          const SizedBox(height: 8),

          Text(
            message,

            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
