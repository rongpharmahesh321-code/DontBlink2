import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/order.dart';
import 'location_map_screen.dart';
import 'order_details_screen.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  // ==========================================================
  // STATUS COLOR
  // ==========================================================

  Color _statusColor(String status) {
    switch (status) {
      case 'Delivered':
        return Colors.green;

      case 'Out for Delivery':
        return Colors.orange;

      case 'Picked Up':
        return Colors.teal;

      case 'Accepted':
        return Colors.blue;

      case 'Assigned to Rider':
        return Colors.indigo;

      case 'Packed':
        return Colors.blue;

      case 'Cancelled':
        return Colors.red;

      case 'Placed':
        return Colors.deepPurple;

      default:
        return Colors.deepPurple;
    }
  }

  // ==========================================================
  // STATUS ICON
  // ==========================================================

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Delivered':
        return Icons.check_circle;

      case 'Out for Delivery':
        return Icons.delivery_dining;

      case 'Picked Up':
        return Icons.inventory_2;

      case 'Accepted':
        return Icons.thumb_up;

      case 'Assigned to Rider':
        return Icons.person_pin_circle;

      case 'Packed':
        return Icons.inventory;

      case 'Cancelled':
        return Icons.cancel;

      case 'Placed':
        return Icons.shopping_bag;

      default:
        return Icons.shopping_bag;
    }
  }

  // ==========================================================
  // STATUS DESCRIPTION
  // ==========================================================

  String _statusDescription(String status) {
    switch (status) {
      case 'Placed':
        return 'Order received';

      case 'Packed':
        return 'Your order is packed';

      case 'Assigned to Rider':
        return 'Rider assigned';

      case 'Accepted':
        return 'Rider accepted your order';

      case 'Picked Up':
        return 'Rider picked up your order';

      case 'Out for Delivery':
        return 'Your order is on the way';

      case 'Delivered':
        return 'Order delivered successfully';

      case 'Cancelled':
        return 'Order has been cancelled';

      default:
        return 'Order is being processed';
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
  // FORMAT DATE
  // ==========================================================

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) {
      return 'Recently';
    }

    DateTime? date;

    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    }

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
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please log in',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

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
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          // ==================================================
          // LOADING
          // ==================================================

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          // ==================================================
          // ERROR
          // ==================================================

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),

                    const SizedBox(height: 15),

                    const Text(
                      'Unable to load orders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          final orders = snapshot.data?.docs ?? [];

          // ==================================================
          // EMPTY
          // ==================================================

          if (orders.isEmpty) {
            return RefreshIndicator(
              color: Colors.green,

              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 500));
              },

              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),

                children: const [
                  SizedBox(height: 150),

                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 85,
                    color: Colors.grey,
                  ),

                  SizedBox(height: 20),

                  Center(
                    child: Text(
                      'No Orders Yet',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  SizedBox(height: 8),

                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 35),
                      child: Text(
                        'Your orders will appear here '
                        'after you place your first order.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // ==================================================
          // ORDER LIST
          // ==================================================

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),

            itemCount: orders.length,

            itemBuilder: (context, index) {
              final doc = orders[index];

              final data = doc.data();

              final order = OrderModel.fromFirestore(doc.id, data);

              return _AnimatedOrderCard(
                index: index,
                child: _buildOrderCard(context, order, data),
              );
            },
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
    OrderModel order,
    Map<String, dynamic> data,
  ) {
    final String status = order.status;

    final Color color = _statusColor(status);

    final bool activeDelivery = status == 'Out for Delivery';

    final bool cancelled = status == 'Cancelled';

    final int currentIndex = _statusIndex(status);

    final String? riderName = data['riderName']?.toString();

    final dynamic createdAt = data['createdAt'];

    return Card(
      elevation: 3,

      margin: const EdgeInsets.only(bottom: 18),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

      child: Padding(
        padding: const EdgeInsets.all(17),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ==================================================
            // HEADER
            // ==================================================
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,

                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),

                    borderRadius: BorderRadius.circular(15),
                  ),

                  child: Icon(_statusIcon(status), color: color, size: 28),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        'Order #${order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase()}',

                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        _formatDate(createdAt),

                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  constraints: const BoxConstraints(maxWidth: 115),

                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),

                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),

                    borderRadius: BorderRadius.circular(20),
                  ),

                  child: Text(
                    status,
                    textAlign: TextAlign.center,

                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ==================================================
            // DESCRIPTION
            // ==================================================
            Text(
              _statusDescription(status),

              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 16),

            // ==================================================
            // TIMELINE
            // ==================================================
            if (!cancelled) _buildTimeline(currentIndex),

            // ==================================================
            // CANCELLED
            // ==================================================
            if (cancelled)
              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(13),

                decoration: BoxDecoration(
                  color: Colors.red.shade50,

                  borderRadius: BorderRadius.circular(12),
                ),

                child: const Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'This order has been cancelled.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // ==================================================
            // RIDER
            // ==================================================
            if (riderName != null && riderName.isNotEmpty)
              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: Colors.blue.shade50,

                  borderRadius: BorderRadius.circular(12),
                ),

                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue,

                      child: Icon(
                        Icons.delivery_dining,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          const Text(
                            'Your Rider',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),

                          Text(
                            riderName,

                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    if (activeDelivery)
                      const Icon(Icons.location_on, color: Colors.green),
                  ],
                ),
              ),

            const SizedBox(height: 15),

            // ==================================================
            // ORDER SUMMARY
            // ==================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),

              decoration: BoxDecoration(
                color: Colors.grey.shade50,

                borderRadius: BorderRadius.circular(12),
              ),

              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: Colors.green),

                  const SizedBox(width: 10),

                  Text(
                    '${order.items.length} item(s)',

                    style: const TextStyle(color: Colors.grey),
                  ),

                  const Spacer(),

                  Text(
                    '₹${order.grandTotal.toStringAsFixed(0)}',

                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // ==================================================
            // IMPORTANT:
            // LIVE TRACKING BUTTON
            // ==================================================
            if (activeDelivery)
              _buildTrackOrderButton(context, order.id)
            else
              _buildViewOrderButton(context, order),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // TRACK MY ORDER BUTTON
  // ==========================================================

  Widget _buildTrackOrderButton(BuildContext context, String orderId) {
    return SizedBox(
      width: double.infinity,
      height: 54,

      child: ElevatedButton.icon(
        icon: const Icon(Icons.location_on, size: 24),

        label: const Text(
          'TRACK MY ORDER',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),

        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          elevation: 3,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),

        onPressed: () {
          _openTracking(context, orderId);
        },
      ),
    );
  }

  // ==========================================================
  // OPEN TRACKING
  // ==========================================================

  Future<void> _openTracking(BuildContext context, String orderId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!doc.exists) {
        if (!context.mounted) return;

        _showMessage(context, 'Order not found.');

        return;
      }

      final Map<String, dynamic> data = doc.data()!;

      // ======================================================
      // CUSTOMER LATITUDE
      // ======================================================

      final dynamic latitude = data['customerLatitude'];

      // ======================================================
      // CUSTOMER LONGITUDE
      // ======================================================

      final dynamic longitude = data['customerLongitude'];

      if (latitude is! num || longitude is! num) {
        if (!context.mounted) return;

        _showMessage(
          context,
          'Customer delivery location is not available for this order.',
        );

        return;
      }

      // ======================================================
      // OPEN MAP
      // ======================================================

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LocationMapScreen(
            orderId: orderId,
            customerLatitude: latitude.toDouble(),
            customerLongitude: longitude.toDouble(),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      _showMessage(context, 'Unable to open live tracking.');
    }
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ==========================================================
  // VIEW ORDER BUTTON
  // ==========================================================

  Widget _buildViewOrderButton(BuildContext context, OrderModel order) {
    return SizedBox(
      width: double.infinity,
      height: 50,

      child: ElevatedButton.icon(
        icon: const Icon(Icons.visibility),

        label: const Text(
          'VIEW ORDER DETAILS',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),

        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)),
          );
        },
      ),
    );
  }

  // ==========================================================
  // TIMELINE
  // ==========================================================

  Widget _buildTimeline(int currentIndex) {
    const stages = [
      'Placed',
      'Packed',
      'Rider Assigned',
      'Accepted',
      'Picked Up',
      'On the Way',
      'Delivered',
    ];

    return Column(
      children: List.generate(stages.length, (index) {
        final bool completed = currentIndex >= index;

        final bool active = currentIndex == index;

        final bool isLast = index == stages.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),

                  width: 28,
                  height: 28,

                  decoration: BoxDecoration(
                    color: completed ? Colors.green : Colors.grey.shade200,

                    shape: BoxShape.circle,

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

                if (!isLast)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),

                    width: 2,
                    height: 25,

                    color: currentIndex > index
                        ? Colors.green
                        : Colors.grey.shade200,
                  ),
              ],
            ),

            const SizedBox(width: 12),

            Padding(
              padding: const EdgeInsets.only(top: 5),

              child: Text(
                stages[index],

                style: TextStyle(
                  color: completed ? Colors.green : Colors.grey,

                  fontWeight: active || completed
                      ? FontWeight.bold
                      : FontWeight.normal,

                  fontSize: 13,
                ),
              ),
            ),
          ],
        );
      }),
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
      begin: const Offset(0, 0.06),
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
