import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/order.dart';
import '../widgets/cached_product_image.dart';

// ==========================================================
// THEME COLORS (matching CheckoutScreen)
// ==========================================================
const Color _primaryGreen = Color(0xFF168A43);
const Color _bgScreen = Color(0xFFF7FAF8);
const Color _cardBorder = Color(0xFFE2EEE5);
const Color _tintGreen = Color(0xFFF0F9F2);
const Color _tintGreenBorder = Color(0xFFD5EDD9);

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel? order;
  final String? orderId;
  final Map<String, dynamic>? initialData;

  const OrderDetailsScreen({super.key, this.order, this.orderId, this.initialData})
      : assert(
         order != null || (orderId != null && initialData != null),
         'Provide either order or orderId + initialData.',
       );

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================
  // INITIAL / LIVE ORDER
  // ==========================================================

  OrderModel get _initialOrder {
    if (widget.order != null) {
      return widget.order!;
    }

    return OrderModel.fromFirestore(widget.orderId!, widget.initialData!);
  }

  OrderModel _orderFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    if (data == null) {
      return _initialOrder;
    }

    return OrderModel.fromFirestore(snapshot.id, data);
  }

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
        return _primaryGreen;

      case 'Packed':
        return const Color(0xFF0D9488);

      case 'Assigned to Rider':
      case 'Accepted':
        return const Color(0xFF0284C7);

      case 'Picked Up':
        return const Color(0xFF2563EB);

      case 'Out for Delivery':
        return const Color(0xFFEA580C);

      case 'Delivered':
        return _primaryGreen;

      case 'Cancelled':
        return const Color(0xFFDC2626);

      default:
        return _primaryGreen;
    }
  }

  // ==========================================================
  // STATUS ICON
  // ==========================================================

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Placed':
        return Icons.shopping_bag_outlined;

      case 'Packed':
        return Icons.inventory_2_outlined;

      case 'Assigned to Rider':
        return Icons.person_pin_circle_outlined;

      case 'Accepted':
        return Icons.thumb_up_alt_outlined;

      case 'Picked Up':
        return Icons.inventory_outlined;

      case 'Out for Delivery':
        return Icons.delivery_dining_rounded;

      case 'Delivered':
        return Icons.check_circle_rounded;

      case 'Cancelled':
        return Icons.cancel_outlined;

      default:
        return Icons.shopping_bag_outlined;
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
    final String liveOrderId = widget.order?.id ?? widget.orderId!;

    return Scaffold(
      backgroundColor: _bgScreen,
      appBar: AppBar(
        toolbarHeight: 70,
        title: const Text(
          'Order Details',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(liveOrderId)
            .snapshots(),
        builder: (context, snapshot) {
          final OrderModel order;

          if (snapshot.hasData && snapshot.data!.exists) {
            order = _orderFromSnapshot(snapshot.data!);
          } else {
            order = _initialOrder;
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: RefreshIndicator(
                color: _primaryGreen,
                onRefresh: () async {
                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(liveOrderId)
                      .get();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                  children: [
                    _buildStatusCard(order),
                    const SizedBox(height: 12),
                    _buildLiveMap(order),
                    const SizedBox(height: 12),
                    _buildOrderTimeline(order.status),
                    const SizedBox(height: 12),
                    _buildProductsCard(order),
                    const SizedBox(height: 12),
                    _buildAddressCard(order),
                    const SizedBox(height: 12),
                    _buildPaymentCard(order),
                    const SizedBox(height: 12),
                    _buildOrderInfo(order),
                    const SizedBox(height: 12),
                    _buildBillCard(order),
                    const SizedBox(height: 18),
                    _buildSupportCard(order),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // PAYMENT CARD
  // ==========================================================

  Widget _buildPaymentCard(OrderModel order) {
    final method = order.paymentMethod.trim().isEmpty
        ? 'Payment method unavailable'
        : order.paymentMethod;

    final isCod =
        method.toLowerCase().contains('cash') || method.toLowerCase() == 'cod';

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(icon: Icons.payment_outlined, title: 'Payment'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isCod ? Colors.orange.shade50 : _tintGreen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCod ? Colors.orange.shade200 : _tintGreenBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isCod ? Colors.orange : _primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCod
                        ? Icons.money_rounded
                        : Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isCod
                            ? 'Pay when your order arrives'
                            : 'Payment selected for this order',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
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
  }

  // ==========================================================
  // SUPPORT CARD
  // ==========================================================

  Widget _buildSupportCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _tintGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _tintGreenBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: _primaryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need help with this order?',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  'Keep your order ID #${order.id.toUpperCase()} handy.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: _primaryGreen.withValues(alpha: 0.04),
            blurRadius: 14,
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
            color: _tintGreen,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _tintGreenBorder),
          ),
          child: Icon(icon, color: _primaryGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  // ==========================================================
  // STATUS CARD
  // ==========================================================

  Widget _buildStatusCard(OrderModel order) {
    final Color color = _statusColor(order.status);
    final bool isOutForDel = _isOutForDelivery(order.status);

    return _buildCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(_statusIcon(order.status), color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORDER STATUS',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.status,
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOutForDel)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _tintGreen,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _tintGreenBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: _primaryGreen, size: 8),
                      SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: _primaryGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _bgScreen,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cardBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: color, size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _statusMessage(order.status),
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              Clipboard.setData(ClipboardData(text: order.id));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Order ID copied to clipboard'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: _primaryGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '#${order.id.toUpperCase()}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _primaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.copy_rounded,
                    color: Colors.grey,
                    size: 14,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatDate(order.createdAt),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
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
                        color: completed ? _primaryGreen : Colors.grey.shade100,
                        border: active
                            ? Border.all(color: _primaryGreen, width: 3)
                            : Border.all(
                                color: completed ? _primaryGreen : Colors.grey.shade300,
                                width: 1.5,
                              ),
                      ),
                      child: Icon(
                        completed ? Icons.check_rounded : Icons.circle,
                        size: completed ? 16 : 6,
                        color: completed ? Colors.white : Colors.grey.shade400,
                      ),
                    ),
                    if (!last)
                      Container(
                        width: 2,
                        height: 30,
                        color: currentIndex > index
                            ? _primaryGreen
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
                            color: completed ? _primaryGreen : Colors.grey.shade600,
                            fontWeight: active || completed
                                ? FontWeight.w800
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        if (active)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              _statusMessage(status),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11.5,
                                height: 1.3,
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
    final int count = order.items.fold<int>(0, (total, item) {
      final q = item['quantity'];
      return total +
          (q is num ? q.toInt() : int.tryParse(q?.toString() ?? '') ?? 0);
    });

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionHeader(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Items',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _tintGreen,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _tintGreenBorder),
                ),
                child: Text(
                  '$count ${count == 1 ? 'item' : 'items'}',
                  style: const TextStyle(
                    color: _primaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (order.items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _bgScreen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorder),
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
        final cleaned =
            priceValue?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '';
        price = double.tryParse(cleaned) ?? 0;
      }

      image = item['imageUrl']?.toString() ?? item['image']?.toString() ?? '';
    }

    final int qty = int.tryParse(quantity) ?? 1;
    final double lineTotal = price * qty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bgScreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedProductImage(
              url: image,
              width: 62,
              height: 62,
              cacheWidth: 186,
              cacheHeight: 186,
              fit: BoxFit.cover,
              placeholder: _productPlaceholder(),
              errorWidget: _productPlaceholder(),
            ),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Qty: $quantity × ${_formatPrice(price)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatPrice(lineTotal),
            style: const TextStyle(
              color: _primaryGreen,
              fontWeight: FontWeight.w800,
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
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey.shade400,
        size: 24,
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
          _sectionHeader(
            icon: Icons.location_on_outlined,
            title: 'Delivery Address',
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _tintGreen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _tintGreenBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: _primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    order.address.isNotEmpty
                        ? order.address
                        : 'Delivery address unavailable',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
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
  // ORDER INFORMATION
  // ==========================================================

  Widget _buildOrderInfo(OrderModel order) {
    final itemCount = order.items.fold<int>(0, (total, item) {
      final q = item['quantity'];
      return total +
          (q is num ? q.toInt() : int.tryParse(q?.toString() ?? '') ?? 0);
    });

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.receipt_long_outlined,
            title: 'Order Information',
          ),
          const SizedBox(height: 15),
          _infoRow('Order ID', '#${order.id.toUpperCase()}'),
          const SizedBox(height: 10),
          _infoRow('Placed on', _formatDate(order.createdAt)),
          const SizedBox(height: 10),
          _infoRow('Items', '$itemCount ${itemCount == 1 ? 'item' : 'items'}'),
          const SizedBox(height: 10),
          _infoRow(
            'Customer',
            order.customerName.isNotEmpty ? order.customerName : 'Customer',
          ),
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
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
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
          _sectionHeader(
            icon: Icons.receipt_long_outlined,
            title: 'Bill Details',
          ),
          const SizedBox(height: 15),
          _billRow('Subtotal', _formatPrice(order.subtotal)),
          const SizedBox(height: 10),
          _billRow('Delivery Fee', _formatPrice(order.deliveryFee)),
          if (order.handlingFee > 0) ...[
            const SizedBox(height: 10),
            _billRow('Handling Fee', _formatPrice(order.handlingFee)),
          ],
          const SizedBox(height: 10),
          _billRow('Platform Fee', _formatPrice(order.platformFee)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _tintGreen,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _tintGreenBorder),
            ),
            child: _billRow(
              'Grand Total',
              _formatPrice(order.grandTotal),
              bold: true,
              large: true,
            ),
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
              color: bold ? Colors.black87 : Colors.grey.shade700,
              fontSize: large ? 16 : 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: large ? _primaryGreen : Colors.black87,
            fontSize: large ? 20 : 13.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
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
// LIVE CUSTOMER MAP — Google Maps
//
// Architecture:
//   1. StreamBuilder listens to the ORDER document (rider GPS, status)
//   2. A separate stream listens to the STORE document (live admin location)
//   3. The GoogleMap widget only rebuilds when markers/polylines change
//   4. Route requests are debounced and only fire on actual changes
// =============================================================

class _LiveCustomerMap extends StatefulWidget {
  final String orderId;

  const _LiveCustomerMap({required this.orderId});

  @override
  State<_LiveCustomerMap> createState() => _LiveCustomerMapState();
}

class _LiveCustomerMapState extends State<_LiveCustomerMap> {
  // ==========================================================
  // MAP CONTROLLER
  // ==========================================================

  GoogleMapController? _mapController;
  bool _initialFitDone = false;
  double _currentBearing = 0.0;
  bool _isMapRotated = false;
  bool _userInteractedWithMap = false;

  // ==========================================================
  // ORDER DATA (updated from order stream)
  // ==========================================================

  LatLng? _customerLocation;
  LatLng? _riderLocation;
  String _riderName = 'Your Delivery Partner';

  // ==========================================================
  // STORE (live from stores collection)
  // ==========================================================

  LatLng? _storeLocation;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _storeSubscription;
  String _lastStoreId = '';

  // ==========================================================
  // ROUTE
  // ==========================================================

  List<LatLng> _routePoints = [];
  double _routeDistance = 0;
  double _routeDuration = 0;
  bool _loadingRoute = false;
  DateTime? _lastRouteRequest;
  LatLng? _lastRouteFrom;
  LatLng? _lastRouteTo;

  // ==========================================================
  // GOOGLE WEB API KEY
  // ==========================================================

  static const MethodChannel _googleConfigChannel = MethodChannel(
    'com.doorstepp.app/google_config',
  );

  String? _cachedRoutesApiKey;

  Future<String> _getRoutesApiKey() async {
    if (_cachedRoutesApiKey != null && _cachedRoutesApiKey!.isNotEmpty) {
      return _cachedRoutesApiKey!;
    }
    const envKey = String.fromEnvironment('GOOGLE_WEB_API_KEY', defaultValue: '');
    if (envKey.isNotEmpty) {
      _cachedRoutesApiKey = envKey.trim();
      return _cachedRoutesApiKey!;
    }
    try {
      final key = await _googleConfigChannel.invokeMethod<String>(
        'getGoogleWebApiKey',
      );
      if (key != null && key.trim().isNotEmpty) {
        _cachedRoutesApiKey = key.trim();
        return _cachedRoutesApiKey!;
      }
    } catch (e) {
      debugPrint('Google API key error: $e');
    }
    return '';
  }

  // ==========================================================
  // INIT — subscribe to store document
  // ==========================================================

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _storeSubscription?.cancel();
    super.dispose();
  }

  // ==========================================================
  // SUBSCRIBE TO LIVE STORE LOCATION
  // ==========================================================

  void _subscribeToStore(String storeId) {
    if (storeId.isEmpty || storeId == _lastStoreId) return;
    _lastStoreId = storeId;

    _storeSubscription?.cancel();

    _storeSubscription = FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .snapshots()
        .listen(
          (doc) {
            if (!mounted || !doc.exists) return;
            final data = doc.data();
            if (data == null) return;

            final lat = _number(data['latitude']);
            final lng = _number(data['longitude']);
            if (lat == 0 && lng == 0) return;

            final newStore = LatLng(lat, lng);
            final changed = _storeLocation == null ||
                _storeLocation!.latitude != newStore.latitude ||
                _storeLocation!.longitude != newStore.longitude;

            if (!changed) return;

            setState(() {
              _storeLocation = newStore;
            });

            // Re-request route when store moves
            if (_riderLocation == null && _customerLocation != null) {
              _requestRoute(newStore, _customerLocation!);
            }
          },
          onError: (e) => debugPrint('Store stream error: $e'),
        );
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

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
        if (snapshot.hasError) {
          return _mapUnavailable('Unable to load live delivery.');
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _cardBorder),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: _primaryGreen),
            ),
          );
        }

        final data = snapshot.data!.data();
        if (data == null) return _mapUnavailable('Delivery information unavailable.');

        // ======================================================
        // CUSTOMER LOCATION
        // ======================================================

        final cLat = data['customerLatitude'];
        final cLng = data['customerLongitude'];
        if (cLat is! num || cLng is! num) {
          return _mapUnavailable('Delivery location is unavailable.');
        }
        final customer = LatLng(cLat.toDouble(), cLng.toDouble());
        _customerLocation = customer;

        // ======================================================
        // STORE ID → subscribe to live store stream
        // ======================================================

        final storeId = data['storeId']?.toString().trim() ?? '';
        if (storeId.isNotEmpty) {
          _subscribeToStore(storeId);
        }

        // ======================================================
        // RIDER
        // ======================================================

        final rName = data['riderName'];
        if (rName != null && rName.toString().trim().isNotEmpty) {
          _riderName = rName.toString();
        }

        final rLat = data['riderLatitude'];
        final rLng = data['riderLongitude'];

        if (rLat is num && rLng is num) {
          _riderLocation = LatLng(rLat.toDouble(), rLng.toDouble());
        }

        // ======================================================
        // REQUEST ROUTE (debounced, outside of build)
        // ======================================================

        final from = _riderLocation ?? _storeLocation;
        if (from != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _requestRoute(from, customer);
          });
        }

        // ======================================================
        // BUILD MARKERS
        // ======================================================

        final markers = <Marker>{};

        if (_storeLocation != null) {
          markers.add(Marker(
            markerId: const MarkerId('store'),
            position: _storeLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: 'Store'),
          ));
        }

        markers.add(Marker(
          markerId: const MarkerId('customer'),
          position: customer,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Delivery Address'),
        ));

        if (_riderLocation != null) {
          markers.add(Marker(
            markerId: const MarkerId('rider'),
            position: _riderLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(title: _riderName),
          ));
        }

        // ======================================================
        // MAIN MAP CARD
        // ======================================================

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(
                color: _primaryGreen.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // ==================================================
              // ADJUSTABLE MAP (ROTATABLE, TILTABLE, PAN/ZOOM)
              // ==================================================
              SizedBox(
                height: 280,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _riderLocation ?? _storeLocation ?? customer,
                        zoom: 14,
                      ),
                      onMapCreated: (c) {
                        _mapController = c;
                        if (!_initialFitDone) {
                          _initialFitDone = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
                        }
                      },
                      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                        Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      },
                      rotateGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      compassEnabled: false,
                      myLocationEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      onCameraMove: (position) {
                        if ((position.bearing - _currentBearing).abs() > 1.0) {
                          setState(() {
                            _currentBearing = position.bearing;
                            _isMapRotated = position.bearing.abs() > 2.0;
                          });
                        }
                      },
                      onCameraMoveStarted: () {
                        _userInteractedWithMap = true;
                      },
                      markers: markers,
                      polylines: {
                        if (_routePoints.length >= 2)
                          Polyline(
                            polylineId: const PolylineId('delivery_route'),
                            points: _routePoints,
                            color: _primaryGreen,
                            width: 5,
                            jointType: JointType.round,
                            startCap: Cap.roundCap,
                            endCap: Cap.roundCap,
                          ),
                      },
                    ),

                    // Top-Left Gesture Hint
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.60),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_rounded, color: Colors.white, size: 13),
                            SizedBox(width: 5),
                            Text(
                              '2 fingers to rotate & tilt',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Top-Right Floating Controls (Recenter, Reset North, Zoom)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Column(
                        children: [
                          // Fit Route / Recenter
                          _buildMapFloatingButton(
                            icon: Icons.crop_free_rounded,
                            tooltip: 'Fit route in view',
                            onTap: () {
                              _userInteractedWithMap = false;
                              _fitBounds();
                            },
                          ),
                          const SizedBox(height: 6),
                          // Reset Compass / North Button
                          _buildMapFloatingButton(
                            icon: Icons.navigation_rounded,
                            tooltip: 'Reset to North',
                            iconAngle: -_currentBearing * (math.pi / 180),
                            iconColor: _isMapRotated ? Colors.redAccent : _primaryGreen,
                            onTap: () {
                              _mapController?.animateCamera(
                                CameraUpdate.newCameraPosition(
                                  CameraPosition(
                                    target: _riderLocation ?? _storeLocation ?? customer,
                                    zoom: 15,
                                    bearing: 0,
                                    tilt: 0,
                                  ),
                                ),
                              );
                              setState(() {
                                _currentBearing = 0;
                                _isMapRotated = false;
                              });
                            },
                          ),
                          const SizedBox(height: 6),
                          // Zoom In (+)
                          _buildMapFloatingButton(
                            icon: Icons.add_rounded,
                            tooltip: 'Zoom in',
                            onTap: () {
                              _mapController?.animateCamera(CameraUpdate.zoomIn());
                            },
                          ),
                          const SizedBox(height: 4),
                          // Zoom Out (-)
                          _buildMapFloatingButton(
                            icon: Icons.remove_rounded,
                            tooltip: 'Zoom out',
                            onTap: () {
                              _mapController?.animateCamera(CameraUpdate.zoomOut());
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // ETA + DELIVERY PARTNER
              // ==================================================
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _tintGreen,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: _tintGreenBorder),
                          ),
                          child: const Icon(
                            Icons.access_time_rounded,
                            color: _primaryGreen,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _riderLocation != null
                                    ? 'Arriving in ${_etaMinutes()} min'
                                    : _storeLocation != null
                                        ? 'Store → Customer route shown'
                                        : 'Waiting for rider assignment',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _riderLocation != null
                                    ? '${_formatDistance()} away • Live GPS'
                                    : 'Live tracking starts when rider picks up',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
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
                              strokeWidth: 2.2,
                              color: _primaryGreen,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _tintGreen,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _tintGreenBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: _primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delivery_dining_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _riderName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _riderLocation != null
                                      ? 'Your delivery partner is on the way'
                                      : 'Preparing your delivery',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_riderLocation != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _tintGreenBorder),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, color: _primaryGreen, size: 7),
                                  SizedBox(width: 5),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: _primaryGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
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
  // MAP FLOATING BUTTON
  // ==========================================================

  Widget _buildMapFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    double iconAngle = 0.0,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.white,
      elevation: 2.5,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Transform.rotate(
            angle: iconAngle,
            child: Icon(icon, size: 19, color: iconColor ?? _primaryGreen),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // REQUEST GOOGLE ROUTES (debounced)
  // ==========================================================

  Future<void> _requestRoute(LatLng from, LatLng to) async {
    final routesApiKey = await _getRoutesApiKey();
    if (routesApiKey.isEmpty) return;

    // Skip if same origin/destination as last request
    if (_lastRouteFrom != null && _lastRouteTo != null &&
        _lastRouteFrom!.latitude == from.latitude &&
        _lastRouteFrom!.longitude == from.longitude &&
        _lastRouteTo!.latitude == to.latitude &&
        _lastRouteTo!.longitude == to.longitude) {
      return;
    }

    final now = DateTime.now();
    if (_lastRouteRequest != null &&
        now.difference(_lastRouteRequest!) < const Duration(seconds: 10)) {
      return;
    }

    _lastRouteRequest = now;
    _lastRouteFrom = from;
    _lastRouteTo = to;

    if (mounted) setState(() => _loadingRoute = true);

    try {
      final url = Uri.parse(
        'https://routes.googleapis.com/directions/v2:computeRoutes',
      );

      final body = {
        'origin': {
          'location': {'latLng': {'latitude': from.latitude, 'longitude': from.longitude}},
        },
        'destination': {
          'location': {'latLng': {'latitude': to.latitude, 'longitude': to.longitude}},
        },
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE',
        'polylineQuality': 'HIGH_QUALITY',
        'polylineEncoding': 'ENCODED_POLYLINE',
        'computeAlternativeRoutes': false,
        'units': 'METRIC',
      };

      final response = await http
          .post(url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-Goog-Api-Key': routesApiKey,
              'X-Goog-FieldMask':
                  'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline',
            },
            body: jsonEncode(body))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;

      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) return;

      final route = routes.first as Map<String, dynamic>;
      final distance = (route['distanceMeters'] as num?)?.toDouble() ?? 0;
      final duration = _parseGoogleDurationSeconds(route['duration']?.toString() ?? '');

      final polyline = route['polyline'];
      final dynamic encoded = polyline is Map ? polyline['encodedPolyline'] : null;
      final points = (encoded == null || encoded.isEmpty)
          ? <LatLng>[]
          : _decodePolyline(encoded);

      if (!mounted) return;

      setState(() {
        _routePoints = points;
        _routeDistance = distance;
        _routeDuration = duration;
        _loadingRoute = false;
      });

      // Follow rider without wiping user bearing/tilt
      final controller = _mapController;
      if (controller != null && _riderLocation != null) {
        if (!_initialFitDone) {
          _initialFitDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
        } else if (!_userInteractedWithMap) {
          controller.animateCamera(CameraUpdate.newLatLng(_riderLocation!));
        }
      }
    } catch (e) {
      debugPrint('Route error: $e');
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  double _parseGoogleDurationSeconds(String value) {
    final match = RegExp(r'^([0-9]+(?:\.[0-9]+)?)s$').firstMatch(value.trim());
    if (match == null) return 0;
    return double.tryParse(match.group(1)!) ?? 0;
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int latitude = 0;
    int longitude = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      while (true) {
        if (index >= encoded.length) return points;
        final byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
        if (byte < 0x20) break;
      }
      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      latitude += deltaLat;

      shift = 0;
      result = 0;
      while (true) {
        if (index >= encoded.length) return points;
        final byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
        if (byte < 0x20) break;
      }
      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      longitude += deltaLng;
      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }
    return points;
  }

  void _fitBounds() {
    final controller = _mapController;
    if (controller == null) return;

    final points = <LatLng>[
      ?_customerLocation,
      ?_storeLocation,
      ?_riderLocation,
      ..._routePoints,
    ];

    if (points.isEmpty) return;

    if (points.length == 1) {
      controller.moveCamera(CameraUpdate.newLatLngZoom(points.first, 14));
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  int _etaMinutes() {
    if (_routeDuration <= 0) return 1;
    return math.max(1, (_routeDuration / 60).ceil());
  }

  String _formatDistance() {
    if (_routeDistance <= 0) return '--';
    if (_routeDistance >= 1000) {
      return '${(_routeDistance / 1000).toStringAsFixed(1)} km';
    }
    return '${_routeDistance.toStringAsFixed(0)} m';
  }

  Widget _mapUnavailable(String message) {
    return Container(
      width: double.infinity,
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _bgScreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_rounded, color: Colors.grey.shade400, size: 40),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }
}


