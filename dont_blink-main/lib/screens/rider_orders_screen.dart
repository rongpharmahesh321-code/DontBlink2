import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'rider_map_screen.dart';
import '../services/rider_notification_service.dart';
import '../services/delivery_tracking_service.dart';

class RiderOrdersScreen extends StatefulWidget {
  const RiderOrdersScreen({super.key});

  @override
  State<RiderOrdersScreen> createState() => _RiderOrdersScreenState();
}

class _RiderOrdersScreenState extends State<RiderOrdersScreen>
    with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loadingProfile = true;
  bool _locationReady = false;
  bool _riderAvailable = false;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _ordersStream;

  StreamSubscription<Position>? _availabilityPositionSubscription;
  Timer? _heartbeatTimer;

  DateTime? _lastAvailabilityWrite;

  final Set<String> _processingOrders = <String>{};

  final RiderNotificationService _notificationService =
      RiderNotificationService.instance;

  StreamSubscription<RemoteMessage>? _deliveryOfferSubscription;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initializeRider();
    _initializeNotifications();
  }

  // ==========================================================
  // NOTIFICATIONS
  // ==========================================================

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();

      await _deliveryOfferSubscription?.cancel();

      _deliveryOfferSubscription = _notificationService.deliveryOffers.listen(
        _handleDeliveryOfferNotification,
        onError: (error) {
          debugPrint('Delivery notification stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('Rider notification initialization error: $e');
    }
  }

  void _handleDeliveryOfferNotification(RemoteMessage message) {
    if (!mounted) return;

    final orderId = _notificationService.orderIdFrom(message);
    final title = _notificationService.titleFrom(message);
    final body = _notificationService.bodyFrom(message);

    debugPrint(
      'DELIVERY OFFER RECEIVED: '
      'orderId=$orderId',
    );

    _showMessage(orderId == null ? '$title\n$body' : '$title\n$body');
  }

  // ==========================================================
  // BUILD RIDER ORDER STREAM
  // ==========================================================
  //
  // This is intentionally based on TWO conditions:
  //
  // 1. riderId == current rider
  //
  //    Existing deliveries belonging to this rider.
  //
  // 2. offeredRiderIds contains current rider
  //
  //    New nearby deliveries explicitly offered to this rider.
  //
  // IMPORTANT:
  // The Firestore rules MUST also allow both conditions.
  // ==========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildOrdersStream(String uid) {
    return _firestore.collection('orders').snapshots();
  }

  // ==========================================================
  // INITIALIZE RIDER
  // ==========================================================

  Future<void> _initializeRider() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
        });
      }
      return;
    }

    try {
      final userRef = _firestore.collection('users').doc(user.uid);

      final userSnapshot = await userRef.get();

      if (!userSnapshot.exists) {
        throw Exception('Rider profile not found.');
      }

      final data = userSnapshot.data() ?? <String, dynamic>{};

      final role = data['role']?.toString().trim() ?? '';

      if (role != 'rider') {
        throw Exception('This account is not a rider.');
      }

      final isAvailable = data['isAvailable'] == true;

      if (!mounted) return;

      setState(() {
        _loadingProfile = false;
        _riderAvailable = isAvailable;
        _ordersStream = _buildOrdersStream(user.uid);
      });

      // Start GPS immediately.
      await _startAvailabilityTracking();
    } catch (e) {
      debugPrint('Rider initialization error: $e');

      if (!mounted) return;

      setState(() {
        _loadingProfile = false;
      });

      _showMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  // ==========================================================
  // LOCATION PERMISSION
  // ==========================================================

  Future<bool> _prepareLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (mounted) {
        _showMessage('Please turn on Location/GPS.', error: true);
      }

      await Geolocator.openLocationSettings();

      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showMessage(
          'Location permission is required to receive nearby deliveries.',
          error: true,
        );
      }

      return false;
    }

    return true;
  }

  // ==========================================================
  // START AVAILABILITY GPS
  // ==========================================================

  Future<void> _startAvailabilityTracking() async {
    final user = _auth.currentUser;

    if (user == null) return;

    final ready = await _prepareLocation();

    if (!ready) {
      if (mounted) {
        setState(() {
          _locationReady = false;
          _riderAvailable = false;
        });
      }

      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await _writeAvailabilityLocation(position, available: true);

      await _availabilityPositionSubscription?.cancel();

      _availabilityPositionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 50,
            ),
          ).listen(
            (position) async {
              if (!_riderAvailable) return;

              await _writeAvailabilityLocation(position, available: true);
            },
            onError: (error) {
              debugPrint('Rider availability GPS error: $error');
            },
          );

      // Periodic heartbeat timer every 45s so stationary riders stay fresh in Firestore
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
        if (!_riderAvailable || !mounted) return;
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          await _writeAvailabilityLocation(pos, available: true, force: true);
        } catch (_) {}
      });

      if (!mounted) return;

      setState(() {
        _locationReady = true;
        _riderAvailable = true;
      });
    } catch (e) {
      debugPrint('Availability tracking error: $e');

      if (mounted) {
        setState(() {
          _locationReady = false;
          _riderAvailable = false;
        });
      }
    }
  }

  // ==========================================================
  // WRITE RIDER LOCATION
  // ==========================================================

  Future<void> _writeAvailabilityLocation(
    Position position, {
    required bool available,
    bool force = false,
  }) async {
    final user = _auth.currentUser;

    if (user == null) return;

    final now = DateTime.now();

    if (!force &&
        _lastAvailabilityWrite != null &&
        now.difference(_lastAvailabilityWrite!) < const Duration(seconds: 20)) {
      return;
    }

    _lastAvailabilityWrite = now;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'role': 'rider',
        'isAvailable': available,
        'riderLatitude': position.latitude,
        'riderLongitude': position.longitude,
        'riderLocationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
        'RIDER GPS: '
        '${position.latitude}, '
        '${position.longitude}',
      );
    } catch (e) {
      debugPrint('Unable to save rider location: $e');
    }
  }

  // ==========================================================
  // ONLINE / OFFLINE
  // ==========================================================

  Future<void> _setRiderAvailability(bool available) async {
    final user = _auth.currentUser;

    if (user == null) return;

    if (available) {
      await _startAvailabilityTracking();

      if (!_locationReady) return;

      if (mounted) {
        setState(() {
          _riderAvailable = true;
        });
      }

      return;
    }

    try {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      await _availabilityPositionSubscription?.cancel();

      _availabilityPositionSubscription = null;

      await _firestore.collection('users').doc(user.uid).set({
        'isAvailable': false,
        'riderLocationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _riderAvailable = false;
      });

      _showMessage('You are now offline for new deliveries.');
    } catch (e) {
      if (mounted) {
        _showMessage('Could not change availability.', error: true);
      }
    }
  }

  // ==========================================================
  // APP LIFECYCLE
  // ==========================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      if (_riderAvailable) {
        _startAvailabilityTracking();
      }
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _availabilityPositionSubscription?.pause();
    }
  }

  // ==========================================================
  // ACCEPT DELIVERY
  // ==========================================================
  //
  // IMPORTANT:
  //
  // Firestore transaction makes this atomic.
  //
  // Rider A and Rider B can press ACCEPT.
  //
  // Only ONE transaction can successfully set riderId.
  //
  // The other rider gets:
  //
  // "This delivery has already been claimed..."
  // ==========================================================

  Future<bool> _claimOrder(String orderId) async {
    final user = _auth.currentUser;

    if (user == null) return false;

    if (_processingOrders.contains(orderId)) {
      return false;
    }

    setState(() {
      _processingOrders.add(orderId);
    });

    try {
      final riderName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'Delivery Partner';

      final riderPhone = user.phoneNumber?.trim() ?? '';

      final ref = _firestore.collection('orders').doc(orderId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);

        if (!snapshot.exists) {
          throw Exception('Delivery no longer exists.');
        }

        final data = snapshot.data() ?? <String, dynamic>{};

        final status = data['status']?.toString().trim().toLowerCase() ?? '';

        final existingRider = data['riderId']?.toString().trim() ?? '';

        // -----------------------------------------------
        // Already claimed
        // -----------------------------------------------

        if (existingRider.isNotEmpty && existingRider != user.uid) {
          throw Exception(
            'This delivery has already been claimed by another rider.',
          );
        }

        // -----------------------------------------------
        // Do not accept completed/cancelled orders
        // -----------------------------------------------

        if (status == 'delivered' || status == 'cancelled') {
          throw Exception('This delivery is no longer available.');
        }

        // -----------------------------------------------
        // ATOMIC CLAIM: First rider to accept wins
        // -----------------------------------------------

        // -----------------------------------------------
        // ATOMIC CLAIM
        // -----------------------------------------------

        transaction.update(ref, {
          'riderId': user.uid,
          'riderName': riderName,
          'riderPhone': riderPhone,
          'status': 'Assigned to Rider',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return true;

      _showMessage('Delivery accepted successfully.');

      return true;
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
      }

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _processingOrders.remove(orderId);
        });
      }
    }
  }

  // ==========================================================
  // UPDATE STATUS
  // ==========================================================

  Future<void> _updateStatus({
    required String orderId,
    required String status,
  }) async {
    final user = _auth.currentUser;

    if (user == null) return;

    if (_processingOrders.contains(orderId)) {
      return;
    }

    setState(() {
      _processingOrders.add(orderId);
    });

    try {
      final ref = _firestore.collection('orders').doc(orderId);
      double earnedPayout = 16.0;
      bool hasSurge = false;

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);

        if (!snapshot.exists) {
          throw Exception('Order no longer exists.');
        }

        final data = snapshot.data() ?? <String, dynamic>{};

        final riderId = data['riderId']?.toString().trim() ?? '';

        if (riderId != user.uid) {
          throw Exception('This order is not assigned to you.');
        }

        final updateData = <String, dynamic>{
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (status == 'Delivered') {
          final fee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
          final surcharge = (data['deliverySurcharge'] as num?)?.toDouble() ?? 0.0;
          hasSurge = data['hasSurcharge'] == true || surcharge > 0 || fee > 25.0;
          earnedPayout = (data['riderPayout'] as num?)?.toDouble() ??
              (data['riderEarnings'] as num?)?.toDouble() ??
              (hasSurge ? 19.0 : 16.0);

          updateData['deliveredAt'] = FieldValue.serverTimestamp();
          updateData['riderPayout'] = earnedPayout;
          updateData['riderEarnings'] = earnedPayout;
        }

        transaction.update(ref, updateData);
      });

      if (mounted) {
        if (status == 'Delivered') {
          _showMessage(
            hasSurge
                ? '🎉 Delivery completed! You earned ₹${earnedPayout.toInt()} (incl. ₹3 rain surge) 🌧️'
                : '🎉 Delivery completed! You earned ₹${earnedPayout.toInt()}.',
          );
        } else {
          _showMessage('Order updated to $status.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingOrders.remove(orderId);
        });
      }
    }
  }

  // ==========================================================
  // START DELIVERY TRACKING
  // ==========================================================

  Future<bool> _startDeliveryTracking(String orderId) async {
    final started = await DeliveryTrackingService.instance.start(
      orderId: orderId,
    );

    if (mounted && !started) {
      _showMessage('Unable to start live delivery tracking.', error: true);
    }

    return started;
  }

  // ==========================================================
  // CALL CUSTOMER
  // ==========================================================

  Future<void> _callCustomer(String phone) async {
    final value = phone.trim();

    if (value.isEmpty) {
      _showMessage('Customer phone number is unavailable.', error: true);
      return;
    }

    final uri = Uri(scheme: 'tel', path: value);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showMessage('Unable to open phone dialer.', error: true);
      }
    } catch (e) {
      _showMessage('Unable to call customer.', error: true);
    }
  }

  // ==========================================================
  // OPEN MAP & NAVIGATION
  // ==========================================================

  Future<void> _openStoreNavigation({
    required double latitude,
    required double longitude,
    required String storeName,
  }) async {
    final navUri = Uri.parse('google.navigation:q=$latitude,$longitude&mode=d');
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );

    try {
      if (await canLaunchUrl(navUri)) {
        await launchUrl(navUri);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        _showMessage('Unable to open map for $storeName.', error: true);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Map error: $e', error: true);
      }
    }
  }

  void _openMap(
    String orderId,
    Map<String, dynamic> order, {
    bool focusStore = false,
  }) {
    final customerLatitude = _toDouble(order['customerLatitude']);
    final customerLongitude = _toDouble(order['customerLongitude']);
    final storeLatitude = _toDouble(order['storeLatitude']);
    final storeLongitude = _toDouble(order['storeLongitude']);
    final storeName = order['storeName']?.toString().trim() ?? '';
    final storeCode = order['storeCode']?.toString().trim() ?? '';
    final isRerouted = order['isRerouted'] == true;
    final originalNearestStoreName =
        order['originalNearestStoreName']?.toString().trim() ?? '';

    if (customerLatitude == null || customerLongitude == null) {
      _showMessage(
        'Customer GPS location is not available for this order.',
        error: true,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RiderMapScreen(
          orderId: orderId,
          customerLatitude: customerLatitude,
          customerLongitude: customerLongitude,
          storeLatitude: storeLatitude,
          storeLongitude: storeLongitude,
          storeName: storeName,
          storeCode: storeCode,
          isRerouted: isRerouted,
          originalNearestStoreName: originalNearestStoreName,
          initialFocusStore: focusStore,
        ),
      ),
    );
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString().trim() ?? '');
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
        ),
      );
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
        return Colors.orange;

      case 'picked up':
        return Colors.teal;

      case 'accepted':
        return Colors.blue;

      case 'assigned to rider':
        return Colors.indigo;

      case 'packed':
        return Colors.deepPurple;

      case 'placed':
        return Colors.orange;

      default:
        return Colors.grey;
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    final ordersStream = _ordersStream;

    return Scaffold(
      backgroundColor: const Color(0xffF5F7F6),
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Deliveries',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: _riderAvailable ? 'Go offline' : 'Go online',
            onPressed: () => _setRiderAvailability(!_riderAvailable),
            icon: Icon(
              _riderAvailable
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ==================================================
          // AVAILABILITY
          // ==================================================
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _riderAvailable ? Colors.green.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _riderAvailable
                    ? Colors.green.shade100
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _riderAvailable
                        ? Colors.green.shade100
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _riderAvailable
                        ? Icons.delivery_dining_rounded
                        : Icons.pause_circle_outline_rounded,
                    color: _riderAvailable ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _riderAvailable ? 'You are online' : 'You are offline',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _riderAvailable
                              ? Colors.green
                              : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _riderAvailable
                            ? 'Nearby delivery requests can be sent to you.'
                            : 'Go online to receive nearby delivery requests.',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _riderAvailable,
                  activeThumbColor: Colors.green,
                  activeTrackColor: Colors.green.shade200,
                  onChanged: _setRiderAvailability,
                ),
              ],
            ),
          ),

          // ==================================================
          // ORDERS
          // ==================================================
          Expanded(
            child: ordersStream == null
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  )
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: ordersStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.green),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Unable to load deliveries.\n\n${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        );
                      }

                      final currentUid = _auth.currentUser?.uid;

                      final orders = (snapshot.data?.docs ?? []).where((doc) {
                        final data = doc.data();

                        final riderId =
                            data['riderId']?.toString().trim() ?? '';

                        final status =
                            data['status']?.toString().trim().toLowerCase() ??
                            '';

                        final mine = riderId == currentUid;

                        final finished =
                            status == 'delivered' || status == 'cancelled';

                        // --------------------------------
                        // IMPORTANT:
                        //
                        // An order offered to this rider
                        // is visible only while it remains
                        // unassigned.
                        //
                        // Once another rider accepts it,
                        // riderId is no longer empty and this
                        // rider immediately loses it.
                        // --------------------------------

                        if (finished) {
                          return false;
                        }

                        if (mine) {
                          return true;
                        }

                        // If unassigned, show to ALL riders so anyone can accept
                        if (riderId.isEmpty) {
                          return true;
                        }

                        return false;
                      }).toList();

                      orders.sort((a, b) {
                        final aValue = a.data()['createdAt'];

                        final bValue = b.data()['createdAt'];

                        if (aValue is Timestamp && bValue is Timestamp) {
                          return bValue.compareTo(aValue);
                        }

                        if (aValue is Timestamp) {
                          return -1;
                        }

                        if (bValue is Timestamp) {
                          return 1;
                        }

                        return 0;
                      });

                      if (orders.isEmpty) {
                        return RefreshIndicator(
                          color: Colors.green,
                          onRefresh: () async {
                            await Future<void>.delayed(
                              const Duration(milliseconds: 300),
                            );
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 130),
                              Icon(
                                Icons.delivery_dining,
                                size: 82,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 18),
                              Center(
                                child: Text(
                                  'No Deliveries Yet',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 30),
                                child: Text(
                                  'Nearby delivery requests will appear here when you are online.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        color: Colors.green,
                        onRefresh: () async {
                          await Future<void>.delayed(
                            const Duration(milliseconds: 300),
                          );
                        },
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            final doc = orders[index];

                            return _buildOrderCard(context, doc.id, doc.data());
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
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
    final riderId = order['riderId']?.toString().trim() ?? '';
    final unassigned = riderId.isEmpty;
    final status = order['status']?.toString() ?? 'Placed';
    final statusLower = status.toLowerCase();
    final customerName = order['customerName']?.toString() ?? 'Customer';
    final phone =
        (order['customerPhone'] ??
                order['phone'] ??
                order['phoneNumber'] ??
                order['customerNumber'] ??
                '')
            .toString()
            .trim();

    final address = order['address']?.toString() ?? 'No address';
    final total = order['grandTotal'] ?? 0;
    final storeName = order['storeName']?.toString().trim() ?? '';
    final storeCode = order['storeCode']?.toString().trim() ?? '';
    final storeLat = _toDouble(order['storeLatitude']);
    final storeLng = _toDouble(order['storeLongitude']);
    final isRerouted = order['isRerouted'] == true;
    final originalNearestStoreName =
        order['originalNearestStoreName']?.toString().trim() ?? '';
    final items = (order['items'] as List?) ?? [];

    final color = _statusColor(status);
    final processing = _processingOrders.contains(orderId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRerouted ? Colors.orange.shade200 : Colors.grey.shade100,
          width: isRerouted ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: unassigned
                      ? Colors.orange.shade50
                      : color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  unassigned
                      ? Icons.notifications_active_outlined
                      : Icons.receipt_long_outlined,
                  color: unassigned ? Colors.orange : color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unassigned ? 'Delivery Available' : 'My Delivery',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase()}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          // Rerouted Warning Banner (if nearest store was out of stock)
          if (isRerouted) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.alt_route_rounded,
                    color: Color(0xFFC2410C),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚡ REROUTED BACKUP STORE PICKUP',
                          style: TextStyle(
                            color: Color(0xFFC2410C),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          originalNearestStoreName.isNotEmpty
                              ? 'Primary store was out of stock. Collect order from $storeName.'
                              : 'Collect items from the alternate store indicated below.',
                          style: const TextStyle(
                            color: Color(0xFF9A3412),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // STEP 1: PICKUP STORE
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'STEP 1 • PICKUP STORE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (storeCode.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          storeCode,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (storeLat != null &&
                        storeLng != null &&
                        storeLat != 0 &&
                        storeLng != 0)
                      GestureDetector(
                        onTap: () => _openStoreNavigation(
                          latitude: storeLat,
                          longitude: storeLng,
                          storeName:
                              storeName.isNotEmpty ? storeName : 'Store',
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.directions_rounded,
                              size: 15,
                              color: Color(0xFF4F46E5),
                            ),
                            SizedBox(width: 2),
                            Text(
                              'Directions',
                              style: TextStyle(
                                color: Color(0xFF4F46E5),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFF4F46E5),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            storeName.isNotEmpty
                                ? storeName
                                : 'Doorstepp Dark Store',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isRerouted
                                ? '⚠️ Alternate dark store pickup (inventory backup)'
                                : 'Collect packed items at this store',
                            style: TextStyle(
                              color: isRerouted
                                  ? const Color(0xFFC2410C)
                                  : Colors.grey.shade600,
                              fontSize: 10,
                              fontWeight: isRerouted
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // STEP 2: DELIVER TO CUSTOMER
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'STEP 2 • DELIVER TO CUSTOMER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF14532D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF16A34A),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 10.5,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (items.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '📦 ${items.length} ${items.length == 1 ? "item" : "items"} to collect',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],

          const SizedBox(height: 8),

          Builder(
            builder: (context) {
              final fee = (order['deliveryFee'] as num?)?.toDouble() ?? 0.0;
              final surcharge =
                  (order['deliverySurcharge'] as num?)?.toDouble() ?? 0.0;
              final bool hasSurcharge =
                  order['hasSurcharge'] == true || surcharge > 0 || fee > 25.0;
              final double riderEarning =
                  (order['riderPayout'] as num?)?.toDouble() ??
                  (order['riderEarnings'] as num?)?.toDouble() ??
                  (hasSurcharge ? 19.0 : 16.0);

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order total: ₹$total',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: hasSurcharge
                          ? const Color(0xFFEFF6FF)
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasSurcharge
                            ? const Color(0xFF93C5FD)
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasSurcharge ? '🌧️' : '💰',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasSurcharge
                              ? 'Earn ₹${riderEarning.toInt()} Surge'
                              : 'Earn ₹${riderEarning.toInt()}',
                          style: TextStyle(
                            color: hasSurcharge
                                ? const Color(0xFF1D4ED8)
                                : Colors.green,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // ==================================================
          // ACCEPT (FOR UNASSIGNED ORDERS)
          // ==================================================
          if (unassigned)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: processing
                    ? null
                    : () async {
                        await _claimOrder(orderId);
                      },
                icon: processing
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.assignment_ind_outlined),
                label: Text(
                  processing ? 'ACCEPTING...' : 'ACCEPT DELIVERY',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            )
          // ==================================================
          // MY DELIVERY ACTIONS
          // ==================================================
          else
            Column(
              children: [
                // If not yet picked up: show Store Map & Customer Map
                if (statusLower == 'assigned to rider' ||
                    statusLower == 'placed' ||
                    statusLower == 'confirmed') ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openMap(
                            orderId,
                            order,
                            focusStore: true,
                          ),
                          icon: const Icon(
                            Icons.storefront_outlined,
                            size: 16,
                          ),
                          label: const Text(
                            'STORE MAP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            side: const BorderSide(color: Color(0xFF4F46E5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openMap(
                            orderId,
                            order,
                            focusStore: false,
                          ),
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: const Text(
                            'CUSTOMER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _callCustomer(phone),
                          icon: const Icon(Icons.phone_outlined, size: 20),
                          color: Colors.green,
                          tooltip: 'Call Customer',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: processing
                          ? null
                          : () => _updateStatus(
                              orderId: orderId,
                              status: 'Picked Up',
                            ),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text(
                        'MARK PICKED UP FROM STORE',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: phone.isEmpty
                              ? null
                              : () => _callCustomer(phone),
                          icon: const Icon(Icons.phone_outlined, size: 18),
                          label: const Text('CALL'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openMap(
                            orderId,
                            order,
                            focusStore: false,
                          ),
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('MAP'),
                        ),
                      ),
                    ],
                  ),

                  // PICKED UP → OUT FOR DELIVERY
                  if (statusLower == 'picked up') ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: processing
                            ? null
                            : () async {
                                await _startDeliveryTracking(orderId);
                              },
                        icon: const Icon(Icons.location_on_outlined),
                        label: const Text(
                          'START DELIVERY TO CUSTOMER',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // OUT FOR DELIVERY → DELIVERED
                  if (statusLower == 'out for delivery') ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: processing
                            ? null
                            : () async {
                                await _updateStatus(
                                  orderId: orderId,
                                  status: 'Delivered',
                                );

                                if (mounted) {
                                  await DeliveryTrackingService.instance
                                      .stopAfterDelivered(orderId: orderId);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'MARK DELIVERED',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _availabilityPositionSubscription?.cancel();

    _deliveryOfferSubscription?.cancel();

    _notificationService.dispose();

    super.dispose();
  }
}
