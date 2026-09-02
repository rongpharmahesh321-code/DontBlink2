import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'rider_map_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================================
  // UPDATE STATUS
  // ==========================================================

  Future<void> updateStatus(String orderId, String status) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Order status updated to $status'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Unable to update order: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  // ==========================================================
  // ASSIGN RIDER
  // ==========================================================

  Future<void> assignRider(BuildContext context, String orderId) async {
    try {
      final ridersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'rider')
          .get();

      if (ridersSnapshot.docs.isEmpty) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('No riders found')));

        return;
      }

      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.65,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),

                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select Rider',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: ridersSnapshot.docs.length,
                      itemBuilder: (context, index) {
                        final riderDoc = ridersSnapshot.docs[index];

                        final rider = riderDoc.data();

                        final riderName =
                            rider['name']?.toString() ?? 'Unknown Rider';

                        final riderEmail = rider['email']?.toString() ?? '';

                        final riderUid =
                            rider['uid']?.toString() ?? riderDoc.id;

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 5,
                            ),
                            leading: const CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.green,
                              child: Icon(
                                Icons.delivery_dining,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              riderName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(riderEmail),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              try {
                                await _firestore
                                    .collection('orders')
                                    .doc(orderId)
                                    .update({
                                      'riderId': riderUid,
                                      'riderName': riderName,
                                      'riderEmail': riderEmail,
                                      'status': 'Assigned to Rider',
                                      'assignedAt':
                                          FieldValue.serverTimestamp(),
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });

                                if (!sheetContext.mounted) {
                                  return;
                                }

                                Navigator.pop(sheetContext);

                                if (!mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Order assigned to $riderName',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Unable to assign rider: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Unable to load riders: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  // ==========================================================
  // STATUS COLOR
  // ==========================================================

  Color statusColor(String status) {
    switch (status) {
      case 'Placed':
        return Colors.blue;

      case 'Confirmed':
        return Colors.indigo;

      case 'Packing':
        return Colors.orange;

      case 'Assigned to Rider':
        return Colors.deepPurple;

      case 'Out for Delivery':
        return Colors.teal;

      case 'Delivered':
        return Colors.green;

      case 'Cancelled':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  // ==========================================================
  // STATUS ICON
  // ==========================================================

  IconData statusIcon(String status) {
    switch (status) {
      case 'Placed':
        return Icons.receipt_long;

      case 'Confirmed':
        return Icons.check_circle_outline;

      case 'Packing':
        return Icons.inventory_2;

      case 'Assigned to Rider':
        return Icons.person_pin_circle;

      case 'Out for Delivery':
        return Icons.delivery_dining;

      case 'Delivered':
        return Icons.check_circle;

      case 'Cancelled':
        return Icons.cancel;

      default:
        return Icons.info_outline;
    }
  }

  // ==========================================================
  // PRICE
  // ==========================================================

  String formatPrice(dynamic value) {
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

  String formatDate(dynamic timestamp) {
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

    return '$day/$month/${date.year} • '
        '$hour:$minute $period';
  }

  // ==========================================================
  // PRODUCT PLACEHOLDER
  // ==========================================================

  Widget productPlaceholder() {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  // ==========================================================
  // PRODUCTS
  // ==========================================================

  Widget buildProducts(List<dynamic> items) {
    if (items.isEmpty) {
      return Card(
        color: Colors.grey.shade50,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.shopping_bag_outlined, color: Colors.grey),
              SizedBox(width: 10),
              Text(
                'No product information available',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shopping_bag, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Products Ordered',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 12),

            ...items.map((item) {
              if (item is! Map) {
                return const SizedBox.shrink();
              }

              final name = item['name']?.toString() ?? 'Unknown Product';

              final price = item['price']?.toString() ?? '₹0';

              final quantity = item['quantity']?.toString() ?? '1';

              final image = item['image']?.toString() ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: image.trim().isNotEmpty
                          ? Image.network(
                              image,
                              width: 55,
                              height: 55,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return productPlaceholder();
                              },
                            )
                          : productPlaceholder(),
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
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            'Qty: $quantity',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      price,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // PAYMENT INFORMATION
  // ==========================================================
  //
  // IMPORTANT:
  // We determine COD using paymentMethod.
  //
  // We DO NOT use isPrepaid.
  //
  // COD:
  //   paymentMethod = Cash on Delivery
  //
  // PREPAID:
  //   paymentMethod = UPI
  //   paymentMethod = Cashfree
  //
  // ==========================================================

  Widget buildPaymentInformation(
    Map<String, dynamic> order,
    dynamic grandTotal,
  ) {
    final String paymentMethod =
        order['paymentMethod']?.toString().trim() ?? '';

    final String normalized = paymentMethod.toLowerCase();

    final bool isCOD = normalized == 'cash on delivery' || normalized == 'cod';

    final double total = _numericValue(grandTotal);

    final double amountToCollect = isCOD ? total : 0;

    // ========================================================
    // COD
    // ========================================================

    if (isCOD) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.payments,
                    color: Colors.white,
                    size: 23,
                  ),
                ),

                const SizedBox(width: 11),

                const Expanded(
                  child: Text(
                    'CASH ON DELIVERY',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            const Divider(height: 1),

            const SizedBox(height: 13),

            Row(
              children: [
                const Icon(Icons.money, color: Colors.orange),

                const SizedBox(width: 8),

                const Expanded(
                  child: Text(
                    'Collect from customer',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                Text(
                  formatPrice(amountToCollect),
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 9),

            Text(
              'Customer has not paid online. '
              'Collect payment on delivery.',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // ========================================================
    // PREPAID
    // ========================================================

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 23),
              ),

              const SizedBox(width: 11),

              const Expanded(
                child: Text(
                  'PREPAID',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'PAID',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          const Divider(height: 1),

          const SizedBox(height: 13),

          const Row(
            children: [
              Icon(Icons.verified, color: Colors.green),

              SizedBox(width: 8),

              Expanded(
                child: Text(
                  'Customer has already paid',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Text(
                '₹0',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          Text(
            'Do not collect payment '
            'from the customer.',
            style: TextStyle(color: Colors.green.shade800, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // NUMERIC VALUE
  // ==========================================================

  double _numericValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value == null) {
      return 0;
    }

    final cleaned = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');

    return double.tryParse(cleaned) ?? 0;
  }

  // ==========================================================
  // STATUS ACTIONS
  // ==========================================================

  List<Widget> buildStatusActions(
    BuildContext context,
    String orderId,
    String status,
  ) {
    final List<Widget> buttons = [];

    if (status == 'Placed') {
      buttons.add(
        _actionButton(
          label: 'Confirm',
          icon: Icons.check_circle_outline,
          color: Colors.indigo,
          onPressed: () {
            updateStatus(orderId, 'Confirmed');
          },
        ),
      );
    }

    if (status == 'Confirmed') {
      buttons.add(
        _actionButton(
          label: 'Start Packing',
          icon: Icons.inventory_2,
          color: Colors.orange,
          onPressed: () {
            updateStatus(orderId, 'Packing');
          },
        ),
      );
    }

    if (status == 'Packing') {
      buttons.add(
        _actionButton(
          label: 'Assign Rider',
          icon: Icons.delivery_dining,
          color: Colors.deepPurple,
          onPressed: () {
            assignRider(context, orderId);
          },
        ),
      );
    }

    if (status == 'Assigned to Rider') {
      buttons.add(
        _actionButton(
          label: 'Out for Delivery',
          icon: Icons.local_shipping,
          color: Colors.teal,
          onPressed: () {
            updateStatus(orderId, 'Out for Delivery');
          },
        ),
      );
    }

    if (status == 'Out for Delivery') {
      buttons.add(
        _actionButton(
          label: 'Mark Delivered',
          icon: Icons.check_circle,
          color: Colors.green,
          onPressed: () {
            updateStatus(orderId, 'Delivered');
          },
        ),
      );
    }

    if (status != 'Delivered' && status != 'Cancelled') {
      buttons.add(
        _actionButton(
          label: 'Cancel',
          icon: Icons.cancel_outlined,
          color: Colors.red,
          onPressed: () {
            _showCancelConfirmation(context, orderId);
          },
        ),
      );
    }

    return buttons;
  }

  // ==========================================================
  // ACTION BUTTON
  // ==========================================================

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ==========================================================
  // CANCEL CONFIRMATION
  // ==========================================================

  void _showCancelConfirmation(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Cancel Order?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to '
            'cancel this order?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('NO'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                updateStatus(orderId, 'Cancelled');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('CANCEL ORDER'),
            ),
          ],
        );
      },
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
          'Admin Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('orders')
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
                padding: const EdgeInsets.all(20),
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

          // ==================================================
          // ORDERS
          // ==================================================

          final orders = snapshot.data?.docs ?? [];

          // ==================================================
          // EMPTY
          // ==================================================

          if (orders.isEmpty) {
            return RefreshIndicator(
              color: Colors.green,

              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 400));
              },

              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),

                children: const [
                  SizedBox(height: 180),

                  Icon(Icons.receipt_long, size: 80, color: Colors.grey),

                  SizedBox(height: 18),

                  Center(
                    child: Text(
                      'No Orders Yet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  SizedBox(height: 8),

                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30),
                      child: Text(
                        'Customer orders will '
                        'appear here automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
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

              final order = doc.data();

              return _AnimatedAdminCard(
                key: ValueKey(doc.id),

                index: index,

                child: _buildOrderCard(context, doc.id, order),
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
    String orderId,
    Map<String, dynamic> order,
  ) {
    final status = order['status']?.toString() ?? 'Placed';

    final customerName = order['customerName']?.toString() ?? 'Customer';

    final customerPhone = order['customerPhone']?.toString() ?? '';

    final address = order['address']?.toString() ?? 'No address';

    final grandTotal = order['grandTotal'] ?? 0;

    final createdAt = order['createdAt'];

    final riderName = order['riderName']?.toString() ?? '';

    // ========================================================
    // PAYMENT METHOD
    // ========================================================

    final paymentMethod = order['paymentMethod']?.toString().trim() ?? '';

    // ========================================================
    // CUSTOMER LOCATION
    // ========================================================

    final double? customerLatitude = (order['customerLatitude'] as num?)
        ?.toDouble();

    final double? customerLongitude =
        ((order['customerLongitude'] ?? order['customerlongitude']) as num?)
            ?.toDouble();

    // ========================================================
    // ITEMS
    // ========================================================

    final List<dynamic> items = order['items'] is List
        ? List<dynamic>.from(order['items'])
        : [];

    final color = statusColor(status);

    return Card(
      elevation: 2,

      margin: const EdgeInsets.only(bottom: 18),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ==================================================
            // HEADER
            // ==================================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Container(
                  width: 50,
                  height: 50,

                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),

                  child: Icon(statusIcon(status), color: color, size: 27),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Order #${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  constraints: const BoxConstraints(maxWidth: 110),

                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),

                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),

                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            const Divider(height: 1),

            const SizedBox(height: 14),

            // ==================================================
            // DATE
            // ==================================================
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: Colors.grey,
                ),

                const SizedBox(width: 7),

                Text(
                  formatDate(createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ==================================================
            // CUSTOMER PHONE
            // ==================================================
            if (customerPhone.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.phone, size: 17, color: Colors.green),

                  const SizedBox(width: 8),

                  Text(
                    customerPhone,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

            if (customerPhone.isNotEmpty) const SizedBox(height: 12),

            // ==================================================
            // ADDRESS
            // ==================================================
            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(13),

              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Icon(Icons.location_on, color: Colors.green),

                  const SizedBox(width: 9),

                  Expanded(
                    child: Text(address, style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ==================================================
            // CUSTOMER LOCATION
            // ==================================================
            if (customerLatitude != null && customerLongitude != null)
              SizedBox(
                width: double.infinity,

                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map, color: Colors.green),

                  label: const Text(
                    'VIEW CUSTOMER LOCATION',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RiderMapScreen(
                          orderId: orderId,
                          customerLatitude: customerLatitude,
                          customerLongitude: customerLongitude,
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 15),

            // ==================================================
            // PRODUCTS
            // ==================================================
            buildProducts(items),

            const SizedBox(height: 15),

            // ==================================================
            // TOTAL
            // ==================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),

              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),

              child: Row(
                children: [
                  const Text(
                    'Order Total',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),

                  const Spacer(),

                  Text(
                    formatPrice(grandTotal),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // ==================================================
            // PAYMENT
            // ==================================================
            buildPaymentInformation(order, grandTotal),

            const SizedBox(height: 15),

            // ==================================================
            // RIDER
            // ==================================================
            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(13),

              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),

              child: Row(
                children: [
                  const Icon(Icons.delivery_dining, color: Colors.green),

                  const SizedBox(width: 9),

                  const Text(
                    'Rider:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(width: 5),

                  Expanded(
                    child: Text(
                      riderName.isEmpty ? 'Not assigned' : riderName,
                      style: TextStyle(
                        color: riderName.isEmpty ? Colors.grey : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ==================================================
            // ACTIONS
            // ==================================================
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: buildStatusActions(context, orderId, status),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// ANIMATED ADMIN CARD
// =============================================================

class _AnimatedAdminCard extends StatefulWidget {
  final Widget child;
  final int index;

  const _AnimatedAdminCard({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<_AnimatedAdminCard> createState() => _AnimatedAdminCardState();
}

class _AnimatedAdminCardState extends State<_AnimatedAdminCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _fadeAnimation;

  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    final delay = widget.index * 60;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350 + delay),
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
