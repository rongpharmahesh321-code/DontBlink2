import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'rider_map_screen.dart';

class RiderOrdersScreen extends StatefulWidget {
  const RiderOrdersScreen({super.key});

  @override
  State<RiderOrdersScreen> createState() => _RiderOrdersScreenState();
}

class _RiderOrdersScreenState extends State<RiderOrdersScreen> {
  // ==========================================================
  // FIRESTORE
  // ==========================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================================
  // CACHED ORDERS STREAM
  //
  // IMPORTANT:
  // We create this ONCE instead of creating the Firestore
  // query every time build() runs.
  // ==========================================================

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream;

  // ==========================================================
  // GPS
  // ==========================================================

  StreamSubscription<Position>? _positionSubscription;

  String? _trackingOrderId;

  // ==========================================================
  // PROCESSING ORDERS
  // ==========================================================

  final Set<String> _processingOrders = <String>{};

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _ordersStream = _firestore
          .collection('orders')
          .where('riderId', isEqualTo: user.uid)
          .snapshots();
    } else {
      _ordersStream = const Stream.empty();
    }
  }

  // ==========================================================
  // UPDATE ORDER STATUS
  // ==========================================================

  Future<void> updateStatus({
    required String orderId,
    required String status,
  }) async {
    // Prevent double taps.
    if (_processingOrders.contains(orderId)) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _processingOrders.add(orderId);
    });

    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Order status updated to $status'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Unable to update order status.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Unable to update order: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _processingOrders.remove(orderId);
        });
      }
    }
  }

  // ==========================================================
  // START LIVE GPS TRACKING
  // ==========================================================

  Future<bool> startTracking(String orderId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) {
          return false;
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Rider account not found.'),
              backgroundColor: Colors.red,
            ),
          );

        return false;
      }

      // ======================================================
      // CHECK GPS SERVICE
      // ======================================================

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) {
          return false;
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Please turn on Location/GPS.'),
              behavior: SnackBarBehavior.floating,
            ),
          );

        await Geolocator.openLocationSettings();

        return false;
      }

      // ======================================================
      // CHECK PERMISSION
      // ======================================================

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return false;
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required '
                'for live delivery tracking.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );

        return false;
      }

      // ======================================================
      // GET CURRENT POSITION
      // ======================================================

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // ======================================================
      // RIDER DETAILS
      // ======================================================

      final riderName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'Delivery Partner';

      final riderPhone = user.phoneNumber?.trim() ?? '';

      // ======================================================
      // SAVE INITIAL LOCATION
      //
      // This also changes the order to Out for Delivery.
      // ======================================================

      await _firestore.collection('orders').doc(orderId).update({
        'riderId': user.uid,
        'riderName': riderName,
        'riderPhone': riderPhone,
        'riderLatitude': position.latitude,
        'riderLongitude': position.longitude,
        'riderLocationUpdatedAt': FieldValue.serverTimestamp(),
        'status': 'Out for Delivery',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ======================================================
      // STOP PREVIOUS GPS SESSION
      // ======================================================

      await _positionSubscription?.cancel();

      _positionSubscription = null;

      _trackingOrderId = orderId;

      // ======================================================
      // LIVE GPS SETTINGS
      // ======================================================

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      // ======================================================
      // START GPS STREAM
      // ======================================================

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) async {
              try {
                await _firestore.collection('orders').doc(orderId).update({
                  'riderLatitude': position.latitude,
                  'riderLongitude': position.longitude,
                  'riderLocationUpdatedAt': FieldValue.serverTimestamp(),
                });

                debugPrint(
                  'LIVE RIDER GPS: '
                  '${position.latitude}, '
                  '${position.longitude}',
                );
              } catch (e) {
                debugPrint('GPS update error: $e');
              }
            },
            onError: (error) {
              debugPrint('GPS stream error: $error');
            },
          );

      if (!mounted) {
        return true;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Live GPS tracking started 📍'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

      return true;
    } catch (e) {
      debugPrint('Start tracking error: $e');

      if (!mounted) {
        return false;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Unable to start GPS tracking: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );

      return false;
    }
  }

  // ==========================================================
  // STOP LIVE GPS
  // ==========================================================

  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();

    _positionSubscription = null;

    _trackingOrderId = null;
  }

  // ==========================================================
  // CALL CUSTOMER
  // ==========================================================

  Future<void> callCustomer(String phone) async {
    if (phone.trim().isEmpty) {
      return;
    }

    final phoneUri = Uri(scheme: 'tel', path: phone.trim());

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Unable to open phone app.')),
          );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Unable to call customer: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _positionSubscription?.cancel();

    super.dispose();
  }
  // ==========================================================
  // STATUS COLOR
  // ==========================================================

  Color statusColor(String status) {
    switch (status) {
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

  IconData statusIcon(String status) {
    switch (status) {
      case 'Assigned to Rider':
        return Icons.person_pin_circle;

      case 'Accepted':
        return Icons.check_circle_outline;

      case 'Picked Up':
        return Icons.inventory_2;

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
  // FORMAT PRICE
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
  // FORMAT DATE
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
  // PAYMENT INFORMATION
  // ==========================================================

  Widget buildPaymentInformation(Map<String, dynamic> order) {
    final String paymentMethod =
        order['paymentMethod']?.toString() ?? 'Cash on Delivery';

    final String paymentStatus =
        order['paymentStatus']?.toString() ?? 'Pending';

    // --------------------------------------------------------
    // DETERMINE PREPAID
    // --------------------------------------------------------

    final String normalizedPaymentMethod = paymentMethod.trim().toLowerCase();

    final bool isPrepaid = order['isPrepaid'] is bool
        ? order['isPrepaid'] as bool
        : normalizedPaymentMethod != 'cash on delivery' &&
              normalizedPaymentMethod != 'cod';

    // --------------------------------------------------------
    // AMOUNT TO COLLECT
    // --------------------------------------------------------

    double amountToCollect = 0;

    final amountValue = order['amountToCollect'];

    if (amountValue is num) {
      amountToCollect = amountValue.toDouble();
    } else {
      amountToCollect = double.tryParse(amountValue?.toString() ?? '') ?? 0;
    }

    // --------------------------------------------------------
    // OLD COD ORDERS FALLBACK
    // --------------------------------------------------------

    if (!isPrepaid && amountToCollect <= 0) {
      final grandTotal = order['grandTotal'];

      if (grandTotal is num) {
        amountToCollect = grandTotal.toDouble();
      } else {
        amountToCollect = double.tryParse(grandTotal?.toString() ?? '') ?? 0;
      }
    }

    // ========================================================
    // PREPAID
    // ========================================================

    if (isPrepaid) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.green.shade50,

          borderRadius: BorderRadius.circular(16),

          border: Border.all(color: Colors.green.shade300, width: 1.5),
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

                  child: const Icon(Icons.verified, color: Colors.white),
                ),

                const SizedBox(width: 11),

                const Expanded(
                  child: Text(
                    'PREPAID',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
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

                  child: Text(
                    paymentStatus.toUpperCase(),

                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              'Payment: $paymentMethod',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 8),

            const Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: Colors.green),

                SizedBox(width: 7),

                Expanded(
                  child: Text(
                    'Payment already received',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            const Row(
              children: [
                Icon(Icons.money_off, size: 18, color: Colors.green),

                SizedBox(width: 7),

                Text(
                  'Collect from customer: ₹0',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ========================================================
    // COD
    // ========================================================

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.orange.shade50,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: Colors.orange.shade300, width: 1.5),
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

                child: const Icon(Icons.payments, color: Colors.white),
              ),

              const SizedBox(width: 11),

              const Expanded(
                child: Text(
                  'CASH ON DELIVERY',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
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

                child: Text(
                  paymentStatus.toUpperCase(),

                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          const Text(
            'Customer must pay when the order is delivered.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,

            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

            decoration: BoxDecoration(
              color: Colors.orange.shade100,

              borderRadius: BorderRadius.circular(12),
            ),

            child: Row(
              children: [
                const Icon(
                  Icons.currency_rupee,
                  color: Colors.orange,
                  size: 22,
                ),

                const SizedBox(width: 7),

                const Expanded(
                  child: Text(
                    'COLLECT FROM CUSTOMER',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Text(
                  formatPrice(amountToCollect),

                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
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
  // PRODUCT PLACEHOLDER
  // ==========================================================

  Widget productPlaceholder() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
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
                'No product information',
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
                  'Products',
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
                      borderRadius: BorderRadius.circular(9),
                      child: image.trim().isNotEmpty
                          ? Image.network(
                              image,
                              width: 58,
                              height: 58,
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

                          const SizedBox(height: 5),

                          Text(
                            'Quantity: $quantity',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
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
  // BUILD SCREEN
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Rider is not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF7F8FA),

      appBar: AppBar(
        title: const Text('My Deliveries'),

        centerTitle: true,

        backgroundColor: Colors.green,

        foregroundColor: Colors.white,

        elevation: 0,
      ),

      // ========================================================
      // IMPORTANT
      //
      // We now use the CACHED `_ordersStream`
      // created in initState().
      //
      // This prevents the Firestore query itself from being
      // recreated every time the screen rebuilds.
      // ========================================================
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ordersStream,

        builder: (context, snapshot) {
          // ====================================================
          // LOADING
          // ====================================================

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          // ====================================================
          // ERROR
          // ====================================================

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
                      'Unable to load deliveries',
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

          // ====================================================
          // ORDERS
          // ====================================================

          final orders = snapshot.data?.docs ?? [];

          // ====================================================
          // EMPTY
          // ====================================================

          if (orders.isEmpty) {
            return RefreshIndicator(
              color: Colors.green,

              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 500));
              },

              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),

                children: const [
                  SizedBox(height: 180),

                  Icon(Icons.delivery_dining, size: 85, color: Colors.grey),

                  SizedBox(height: 18),

                  Center(
                    child: Text(
                      'No Deliveries Yet',
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
                        'Orders assigned to you '
                        'will appear here automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // ====================================================
          // ORDER LIST
          // ====================================================

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),

            itemCount: orders.length,

            itemBuilder: (context, index) {
              final doc = orders[index];

              final order = doc.data();

              return _AnimatedRiderCard(
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
    final status = order['status']?.toString() ?? 'Assigned to Rider';

    final customerName = order['customerName']?.toString() ?? 'Customer';

    final customerPhone = order['customerPhone']?.toString() ?? '';

    final address = order['address']?.toString() ?? 'No address';

    final total = order['grandTotal'] ?? 0;

    final createdAt = order['createdAt'];

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

    final isProcessing = _processingOrders.contains(orderId);

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

                Container(
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

            const SizedBox(height: 13),

            // ==================================================
            // CALL CUSTOMER
            // ==================================================
            if (customerPhone.isNotEmpty)
              SizedBox(
                width: double.infinity,

                child: OutlinedButton.icon(
                  icon: const Icon(Icons.phone, color: Colors.green),

                  label: const Text(
                    'CALL CUSTOMER',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  onPressed: isProcessing
                      ? null
                      : () {
                          callCustomer(customerPhone);
                        },
                ),
              ),

            const SizedBox(height: 12),

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
            // DELIVERY MAP
            // ==================================================
            if (customerLatitude != null && customerLongitude != null)
              SizedBox(
                width: double.infinity,

                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map, color: Colors.green),

                  label: const Text(
                    'VIEW DELIVERY MAP',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  onPressed: isProcessing
                      ? null
                      : () {
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
              )
            else
              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),

                child: const Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.orange),

                    SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        'Customer GPS location is not available.',
                        style: TextStyle(color: Colors.orange, fontSize: 13),
                      ),
                    ),
                  ],
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
                    formatPrice(total),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ==================================================
            // PAYMENT INFORMATION
            // ==================================================
            buildPaymentInformation(order),

            const SizedBox(height: 18),
            // ==================================================
            // DELIVERY PROGRESS
            // ==================================================
            _buildStatusTimeline(status),

            const SizedBox(height: 18),

            // ==================================================
            // ACTION
            // ==================================================
            _buildActionButton(
              context: context,
              orderId: orderId,
              status: status,
            ),
          ],
        ),
      ),
    );
  }
  // ==========================================================
  // STATUS TIMELINE
  // ==========================================================

  Widget _buildStatusTimeline(String status) {
    const stages = [
      'Assigned to Rider',
      'Accepted',
      'Picked Up',
      'Out for Delivery',
      'Delivered',
    ];

    final currentIndex = stages.indexOf(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Progress',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 14),

        ...List.generate(stages.length, (index) {
          final completed = currentIndex >= index;
          final active = currentIndex == index;
          final stage = stages[index];

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: completed ? Colors.green : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      completed ? Icons.check : Icons.circle,
                      size: completed ? 18 : 8,
                      color: completed ? Colors.white : Colors.grey,
                    ),
                  ),

                  if (index < stages.length - 1)
                    Container(
                      width: 2,
                      height: 25,
                      color: currentIndex > index
                          ? Colors.green
                          : Colors.grey.shade300,
                    ),
                ],
              ),

              const SizedBox(width: 12),

              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  stage,
                  style: TextStyle(
                    color: completed ? Colors.green : Colors.grey,
                    fontWeight: active || completed
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ==========================================================
  // ACTION BUTTON
  // ==========================================================

  Widget _buildActionButton({
    required BuildContext context,
    required String orderId,
    required String status,
  }) {
    final processing = _processingOrders.contains(orderId);

    // ========================================================
    // ACCEPT DELIVERY
    // ========================================================

    if (status == 'Assigned to Rider') {
      return SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton.icon(
          icon: processing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle),

          label: Text(
            processing ? 'ACCEPTING...' : 'ACCEPT DELIVERY',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          onPressed: processing
              ? null
              : () async {
                  await updateStatus(orderId: orderId, status: 'Accepted');
                },

          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    // ========================================================
    // PICK UP ORDER
    // ========================================================

    if (status == 'Accepted') {
      return SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton.icon(
          icon: processing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.inventory_2),

          label: Text(
            processing ? 'UPDATING...' : 'PICK UP ORDER',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          onPressed: processing
              ? null
              : () async {
                  await updateStatus(orderId: orderId, status: 'Picked Up');
                },

          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    // ========================================================
    // START DELIVERY
    // ========================================================

    if (status == 'Picked Up') {
      return SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton.icon(
          icon: processing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.delivery_dining),

          label: Text(
            processing ? 'STARTING...' : 'START DELIVERY',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          onPressed: processing
              ? null
              : () async {
                  setState(() {
                    _processingOrders.add(orderId);
                  });

                  try {
                    final started = await startTracking(orderId);

                    if (!started) {
                      return;
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        _processingOrders.remove(orderId);
                      });
                    }
                  }
                },

          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    // ========================================================
    // SLIDE TO DELIVER
    // ========================================================

    if (status == 'Out for Delivery') {
      return _SlideToDeliver(
        onDelivered: () async {
          await stopTracking();

          await updateStatus(orderId: orderId, status: 'Delivered');
        },
      );
    }

    // ========================================================
    // DELIVERED
    // ========================================================

    if (status == 'Delivered') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green),

            SizedBox(width: 8),

            Text(
              'ORDER DELIVERED',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // ========================================================
    // CANCELLED
    // ========================================================

    if (status == 'Cancelled') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, color: Colors.red),

            SizedBox(width: 8),

            Text(
              'ORDER CANCELLED',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================
}

// =============================================================
// ANIMATED RIDER CARD
// =============================================================

class _AnimatedRiderCard extends StatefulWidget {
  final Widget child;
  final int index;

  const _AnimatedRiderCard({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<_AnimatedRiderCard> createState() => _AnimatedRiderCardState();
}

class _AnimatedRiderCardState extends State<_AnimatedRiderCard>
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

// =============================================================
// SLIDE TO DELIVER
// =============================================================

class _SlideToDeliver extends StatefulWidget {
  final Future<void> Function() onDelivered;

  const _SlideToDeliver({required this.onDelivered});

  @override
  State<_SlideToDeliver> createState() => _SlideToDeliverState();
}

class _SlideToDeliverState extends State<_SlideToDeliver> {
  double position = 0;

  bool completed = false;

  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,

      child: LayoutBuilder(
        builder: (context, constraints) {
          const double height = 64;

          const double knobSize = 56;

          final maxPosition = constraints.maxWidth - knobSize - 4;

          return Container(
            height: height,

            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.green, width: 1.5),
            ),

            child: Stack(
              alignment: Alignment.center,

              children: [
                // ==========================================
                // SLIDE TEXT
                // ==========================================
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: completed ? 0 : 1,

                  child: const Text(
                    'SLIDE TO DELIVER',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),

                // ==========================================
                // LOADING / COMPLETED
                // ==========================================
                if (loading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.green,
                    ),
                  )
                else if (completed)
                  const Text(
                    'DELIVERED ✓',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                // ==========================================
                // SLIDER KNOB
                // ==========================================
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 150),

                  curve: Curves.easeOut,

                  left: position + 2,

                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (completed || loading) {
                        return;
                      }

                      setState(() {
                        position += details.delta.dx;

                        if (position < 0) {
                          position = 0;
                        }

                        if (position > maxPosition) {
                          position = maxPosition;
                        }
                      });
                    },

                    onHorizontalDragEnd: (_) async {
                      if (completed || loading) {
                        return;
                      }

                      if (position >= maxPosition * 0.85) {
                        setState(() {
                          position = maxPosition;

                          loading = true;
                        });

                        try {
                          await widget.onDelivered();

                          if (!mounted) {
                            return;
                          }

                          setState(() {
                            completed = true;

                            loading = false;
                          });
                        } catch (e) {
                          if (!mounted) {
                            return;
                          }

                          setState(() {
                            position = 0;
                            loading = false;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Unable to complete delivery: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } else {
                        setState(() {
                          position = 0;
                        });
                      }
                    },

                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),

                      width: knobSize,

                      height: knobSize,

                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),

                      child: Icon(
                        completed
                            ? Icons.check
                            : loading
                            ? Icons.hourglass_top
                            : Icons.chevron_right,

                        color: Colors.white,

                        size: 32,
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
}
