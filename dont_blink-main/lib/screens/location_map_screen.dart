import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationMapScreen extends StatefulWidget {
  final String? orderId;
  final double customerLatitude;
  final double customerLongitude;

  const LocationMapScreen({
    super.key,
    this.orderId,
    required this.customerLatitude,
    required this.customerLongitude,
  });

  static const double storeLatitude = 25.8438;
  static const double storeLongitude = 93.4348;

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================
  // MAP
  // ==========================================================

  final MapController _mapController = MapController();

  bool _mapReady = false;

  // ==========================================================
  // LOCATIONS
  // ==========================================================

  late final LatLng customerLocation;
  late final LatLng storeLocation;

  LatLng? riderLocation;
  LatLng? previousRiderLocation;

  // ==========================================================
  // ROUTE
  // ==========================================================

  List<LatLng> routePoints = [];

  double routeDistanceMeters = 0;

  double routeDurationSeconds = 0;

  bool loadingRoute = false;

  DateTime? lastRouteRequest;

  // ==========================================================
  // ORDER
  // ==========================================================

  String orderStatus = 'Out for Delivery';

  String riderName = 'Your Delivery Partner';

  String riderPhone = '';

  String paymentMethod = '';

  double grandTotal = 0;

  // ==========================================================
  // RIDER ANIMATION
  // ==========================================================

  late final AnimationController _riderAnimationController;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    customerLocation = LatLng(
      widget.customerLatitude,
      widget.customerLongitude,
    );

    storeLocation = const LatLng(
      LocationMapScreen.storeLatitude,
      LocationMapScreen.storeLongitude,
    );

    _riderAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // IMPORTANT:
    // Rebuild every animation frame so the rider actually moves smoothly.
    _riderAnimationController.addListener(() {
      if (!mounted) return;

      setState(() {});

      // Smoothly follow rider.
      final animated = animatedRiderLocation;

      if (_mapReady && animated != null) {
        try {
          _mapController.move(animated, _mapController.camera.zoom);
        } catch (_) {}
      }
    });
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _riderAnimationController.dispose();
    super.dispose();
  }

  // ==========================================================
  // NORMALIZE STATUS
  // ==========================================================

  String _normalizedStatus(String status) {
    return status
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  // ==========================================================
  // IS RIDER ACTIVE
  // ==========================================================

  bool get _isDeliveryActive {
    final status = _normalizedStatus(orderStatus);

    return status == 'out for delivery' ||
        status == 'picked up' ||
        status == 'accepted';
  }

  // ==========================================================
  // DISTANCE TO CUSTOMER
  // ==========================================================

  double _straightLineDistanceMeters(LatLng a, LatLng b) {
    const Distance distance = Distance();

    return distance.as(LengthUnit.Meter, a, b);
  }

  // ==========================================================
  // RIDER NEARBY
  // ==========================================================

  bool get _riderIsNearby {
    if (riderLocation == null) {
      return false;
    }

    final distance = _straightLineDistanceMeters(
      riderLocation!,
      customerLocation,
    );

    return distance <= 500;
  }

  bool get _riderArrived {
    if (riderLocation == null) {
      return false;
    }

    final distance = _straightLineDistanceMeters(
      riderLocation!,
      customerLocation,
    );

    return distance <= 50;
  }

  // ==========================================================
  // STATUS TITLE
  // ==========================================================

  String _statusTitle() {
    switch (_normalizedStatus(orderStatus)) {
      case 'placed':
        return 'Order placed';

      case 'packed':
        return 'Your order is packed';

      case 'assigned to rider':
        return 'Rider assigned';

      case 'accepted':
        return 'Rider accepted';

      case 'picked up':
        return 'Order picked up';

      case 'out for delivery':
        if (_riderArrived) {
          return 'Rider has arrived';
        }

        if (_riderIsNearby) {
          return 'Arriving soon';
        }

        if (riderLocation != null) {
          return 'Arriving in ${_etaMinutes()} min';
        }

        return 'Your order is on the way';

      case 'delivered':
        return 'Order delivered';

      case 'cancelled':
        return 'Order cancelled';

      default:
        return 'Preparing your order';
    }
  }

  // ==========================================================
  // STATUS SUBTITLE
  // ==========================================================

  String _statusSubtitle() {
    switch (_normalizedStatus(orderStatus)) {
      case 'placed':
        return 'We have received your order.';

      case 'packed':
        return 'Your groceries are packed and ready.';

      case 'assigned to rider':
        return 'A delivery partner has been assigned.';

      case 'accepted':
        return 'Your delivery partner accepted the order.';

      case 'picked up':
        return 'Your rider is picking up your order.';

      case 'out for delivery':
        if (_riderArrived) {
          return 'Your delivery partner is at your location.';
        }

        if (_riderIsNearby) {
          return 'Your rider is nearby.';
        }

        if (riderLocation != null) {
          return 'Your order is on the way to your doorstep.';
        }

        return 'Waiting for live rider location.';

      case 'delivered':
        return 'Enjoy your order!';

      case 'cancelled':
        return 'This order has been cancelled.';

      default:
        return 'We are preparing your order.';
    }
  }

  // ==========================================================
  // ETA
  // ==========================================================

  int _etaMinutes() {
    if (routeDurationSeconds <= 0) {
      return 1;
    }

    return math.max(1, (routeDurationSeconds / 60).ceil());
  }

  // ==========================================================
  // DISTANCE
  // ==========================================================

  String _formatDistance() {
    if (routeDistanceMeters <= 0) {
      return '--';
    }

    if (routeDistanceMeters >= 1000) {
      return '${(routeDistanceMeters / 1000).toStringAsFixed(1)} km';
    }

    return '${routeDistanceMeters.toStringAsFixed(0)} m';
  }

  // ==========================================================
  // PAYMENT
  // ==========================================================

  String _paymentText() {
    if (paymentMethod.trim().isEmpty) {
      return 'Payment confirmed';
    }

    final method = paymentMethod.trim().toLowerCase();

    if (method.contains('cash') ||
        method.contains('cod') ||
        method.contains('delivery')) {
      return 'Pay ${_formatPrice(grandTotal)} on delivery';
    }

    return 'Payment of ${_formatPrice(grandTotal)} confirmed';
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
  // PROCESS FIRESTORE DATA
  // ==========================================================

  void _processOrderData(Map<String, dynamic> data) {
    final newStatus = data['status']?.toString() ?? 'Out for Delivery';

    final newRiderName =
        data['riderName']?.toString() ?? 'Your Delivery Partner';

    final newRiderPhone = data['riderPhone']?.toString() ?? '';

    final newPaymentMethod = data['paymentMethod']?.toString() ?? '';

    double newGrandTotal = 0;

    final totalValue = data['grandTotal'];

    if (totalValue is num) {
      newGrandTotal = totalValue.toDouble();
    } else {
      newGrandTotal = double.tryParse(totalValue?.toString() ?? '') ?? 0;
    }

    orderStatus = newStatus;
    riderName = newRiderName;
    riderPhone = newRiderPhone;
    paymentMethod = newPaymentMethod;
    grandTotal = newGrandTotal;

    // ========================================================
    // RIDER GPS
    // ========================================================

    final latValue = data['riderLatitude'];
    final lngValue = data['riderLongitude'];

    if (latValue is num && lngValue is num) {
      final newLocation = LatLng(latValue.toDouble(), lngValue.toDouble());

      final changed =
          riderLocation == null ||
          riderLocation!.latitude != newLocation.latitude ||
          riderLocation!.longitude != newLocation.longitude;

      if (changed) {
        previousRiderLocation = riderLocation;

        riderLocation = newLocation;

        // First location should appear immediately.
        if (previousRiderLocation == null) {
          _riderAnimationController.value = 1;
        } else {
          _riderAnimationController.forward(from: 0);
        }

        // Request route AFTER the current build finishes.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          _requestRoute(newLocation);
        });
      }
    }
  }

  // ==========================================================
  // ANIMATED RIDER LOCATION
  // ==========================================================

  LatLng? get animatedRiderLocation {
    if (riderLocation == null) {
      return null;
    }

    if (previousRiderLocation == null) {
      return riderLocation;
    }

    final t = Curves.easeInOut.transform(_riderAnimationController.value);

    final latitude =
        previousRiderLocation!.latitude +
        (riderLocation!.latitude - previousRiderLocation!.latitude) * t;

    final longitude =
        previousRiderLocation!.longitude +
        (riderLocation!.longitude - previousRiderLocation!.longitude) * t;

    return LatLng(latitude, longitude);
  }

  // ==========================================================
  // REQUEST ROAD ROUTE
  // ==========================================================

  Future<void> _requestRoute(LatLng rider) async {
    final now = DateTime.now();

    if (lastRouteRequest != null &&
        now.difference(lastRouteRequest!) < const Duration(seconds: 8)) {
      return;
    }

    lastRouteRequest = now;

    if (mounted) {
      setState(() {
        loadingRoute = true;
      });
    }

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${rider.longitude},${rider.latitude};'
        '${customerLocation.longitude},'
        '${customerLocation.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Routing server returned ${response.statusCode}');
      }

      final Map<String, dynamic> result = jsonDecode(response.body);

      if (result['code'] != 'Ok') {
        throw Exception('Route not found');
      }

      final routes = result['routes'];

      if (routes == null || routes.isEmpty) {
        throw Exception('No route available');
      }

      final route = routes[0];

      final geometry = route['geometry'];

      final coordinates = geometry['coordinates'];

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
        routePoints = points;

        routeDistanceMeters = (route['distance'] as num).toDouble();

        routeDurationSeconds = (route['duration'] as num).toDouble();

        loadingRoute = false;
      });
    } catch (e) {
      debugPrint('Customer route error: $e');

      if (!mounted) return;

      setState(() {
        loadingRoute = false;
      });
    }
  }

  // ==========================================================
  // CALL RIDER
  // ==========================================================

  Future<void> _callRider() async {
    if (riderPhone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rider phone number is not available.')),
      );

      return;
    }

    final uri = Uri(scheme: 'tel', path: riderPhone.trim());

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Call rider error: $e');
    }
  }

  // ==========================================================
  // CENTER ON RIDER
  // ==========================================================

  void _centerOnRider() {
    if (!_mapReady || riderLocation == null) {
      return;
    }

    _mapController.move(riderLocation!, 16);
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (widget.orderId == null) {
      return _buildError('Live tracking is not available for this order.');
    }

    return Scaffold(
      backgroundColor: Colors.white,

      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId!)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildError('Unable to load live delivery.');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildError('This order could not be found.');
          }

          final data = snapshot.data!.data();

          if (data != null) {
            _processOrderData(data);
          }

          final rider = animatedRiderLocation;

          return Stack(
            children: [
              // ==================================================
              // MAP
              // ==================================================
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapController,

                  options: MapOptions(
                    initialCenter: rider ?? customerLocation,

                    initialZoom: 14,

                    onMapReady: () {
                      _mapReady = true;
                    },
                  ),

                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                      userAgentPackageName: 'com.dontblink.app',
                    ),

                    // =================================================
                    // ROUTE
                    // =================================================
                    if (routePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePoints,
                            strokeWidth: 5,
                            color: Colors.green,
                          ),
                        ],
                      ),

                    // =================================================
                    // MARKERS
                    // =================================================
                    MarkerLayer(
                      markers: [
                        // STORE
                        Marker(
                          point: storeLocation,
                          width: 60,
                          height: 60,
                          child: _mapMarker(
                            icon: Icons.store,
                            color: Colors.green,
                          ),
                        ),

                        // CUSTOMER
                        Marker(
                          point: customerLocation,
                          width: 64,
                          height: 64,
                          child: _mapMarker(
                            icon: Icons.home,
                            color: Colors.red,
                          ),
                        ),

                        // RIDER
                        if (rider != null)
                          Marker(
                            point: rider,
                            width: 74,
                            height: 74,
                            child: _riderMarker(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ==================================================
              // TOP HEADER
              // ==================================================
              Positioned(
                top: 0,
                left: 0,
                right: 0,

                child: SafeArea(
                  bottom: false,

                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 10, 18, 16),

                    decoration: const BoxDecoration(
                      color: Colors.green,

                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(22),
                        bottomRight: Radius.circular(22),
                      ),
                    ),

                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },

                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),

                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                _statusSubtitle(),

                                maxLines: 1,

                                overflow: TextOverflow.ellipsis,

                                textAlign: TextAlign.center,

                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),

                              const SizedBox(height: 2),

                              Text(
                                _statusTitle(),

                                maxLines: 1,

                                overflow: TextOverflow.ellipsis,

                                textAlign: TextAlign.center,

                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (loadingRoute)
                          const SizedBox(
                            width: 22,
                            height: 22,

                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const SizedBox(width: 22),
                      ],
                    ),
                  ),
                ),
              ),

              // ==================================================
              // LIVE BADGE
              // ==================================================
              if (rider != null)
                Positioned(top: 125, right: 15, child: _liveBadge()),

              // ==================================================
              // CENTER RIDER
              // ==================================================
              Positioned(
                right: 15,
                bottom: 365,

                child: FloatingActionButton.small(
                  heroTag: 'customer_center_rider',

                  backgroundColor: Colors.white,

                  foregroundColor: Colors.green,

                  onPressed: rider == null ? null : _centerOnRider,

                  child: const Icon(Icons.my_location),
                ),
              ),

              // ==================================================
              // BOTTOM SHEET
              // ==================================================
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,

                child: _buildBottomSheet(),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================================
  // MAP MARKER
  // ==========================================================

  Widget _mapMarker({required IconData icon, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,

        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.20), blurRadius: 7),
        ],
      ),

      child: Icon(icon, color: color, size: 34),
    );
  }

  // ==========================================================
  // RIDER MARKER
  // ==========================================================

  Widget _riderMarker() {
    return Stack(
      alignment: Alignment.center,

      children: [
        // Outer pulse
        Container(
          width: 68,
          height: 68,

          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.18),

            shape: BoxShape.circle,
          ),
        ),

        Container(
          width: 54,
          height: 54,

          decoration: BoxDecoration(
            color: Colors.green,

            shape: BoxShape.circle,

            border: Border.all(color: Colors.white, width: 4),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),

                blurRadius: 8,
              ),
            ],
          ),

          child: const Icon(
            Icons.delivery_dining,
            color: Colors.white,
            size: 30,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // LIVE BADGE
  // ==========================================================

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
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
    );
  }

  // ==========================================================
  // BOTTOM SHEET
  // ==========================================================

  Widget _buildBottomSheet() {
    return SafeArea(
      top: false,

      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),

        decoration: const BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 15,
              offset: Offset(0, -4),
            ),
          ],
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            // HANDLE
            Container(
              width: 45,
              height: 5,

              decoration: BoxDecoration(
                color: Colors.grey.shade300,

                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 14),

            // ==================================================
            // ARRIVAL + DISTANCE
            // ==================================================
            if (riderLocation != null)
              Row(
                children: [
                  Expanded(
                    child: _infoBox(
                      icon: Icons.access_time,
                      title: 'Arrival',
                      value: _riderArrived ? 'Arrived' : '${_etaMinutes()} min',
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _infoBox(
                      icon: Icons.navigation,
                      title: 'Distance',
                      value: _formatDistance(),
                    ),
                  ),
                ],
              ),

            if (riderLocation != null) const SizedBox(height: 14),

            // ==================================================
            // RIDER CARD
            // ==================================================
            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(13),

              decoration: BoxDecoration(
                color: Colors.green.shade50,

                borderRadius: BorderRadius.circular(16),
              ),

              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,

                    decoration: BoxDecoration(
                      color: Colors.green,

                      borderRadius: BorderRadius.circular(15),
                    ),

                    child: const Icon(
                      Icons.delivery_dining,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          riderLocation != null ? "I'm $riderName" : riderName,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          _riderArrived
                              ? 'Your rider has reached your location'
                              : riderLocation != null
                              ? 'Your delivery partner is on the way'
                              : 'Waiting for live rider location',

                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (riderPhone.trim().isNotEmpty)
                    GestureDetector(
                      onTap: _callRider,

                      child: Container(
                        width: 42,
                        height: 42,

                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),

                        child: const Icon(Icons.phone, color: Colors.green),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ==================================================
            // PAYMENT
            // ==================================================
            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(
                color: Colors.grey.shade50,

                borderRadius: BorderRadius.circular(14),
              ),

              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,

                    decoration: BoxDecoration(
                      color: Colors.green.shade100,

                      borderRadius: BorderRadius.circular(11),
                    ),

                    child: const Icon(Icons.payment, color: Colors.green),
                  ),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          _paymentText(),

                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          paymentMethod.trim().isEmpty
                              ? 'Order payment'
                              : paymentMethod,

                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ==================================================
            // DELIVERY MESSAGE
            // ==================================================
            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(
                color: Colors.green.shade50,

                borderRadius: BorderRadius.circular(12),
              ),

              child: Row(
                children: [
                  Icon(
                    _riderArrived ? Icons.home : Icons.delivery_dining,

                    color: Colors.green,
                    size: 22,
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      _riderArrived
                          ? 'Your rider has arrived at your doorstep.'
                          : riderLocation != null
                          ? 'Delivering your order to your doorstep.'
                          : 'Your order will be delivered to your doorstep.',

                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

        borderRadius: BorderRadius.circular(13),
      ),

      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 22),

          const SizedBox(width: 9),

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
                    fontSize: 16,
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
  // ERROR
  // ==========================================================

  Widget _buildError(String message) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text('Track Order'),

        backgroundColor: Colors.green,

        foregroundColor: Colors.white,
      ),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              const Icon(Icons.location_off, color: Colors.grey, size: 65),

              const SizedBox(height: 15),

              Text(
                message,

                textAlign: TextAlign.center,

                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
