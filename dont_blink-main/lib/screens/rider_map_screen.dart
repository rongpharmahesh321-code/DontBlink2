import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class RiderMapScreen extends StatefulWidget {
  final String orderId;
  final double customerLatitude;
  final double customerLongitude;

  const RiderMapScreen({
    super.key,
    required this.orderId,
    required this.customerLatitude,
    required this.customerLongitude,
  });

  // ==========================================================
  // DON'T BLINK STORE LOCATION
  // ==========================================================

  static const double storeLatitude = 25.8438;
  static const double storeLongitude = 93.4348;

  @override
  State<RiderMapScreen> createState() => _RiderMapScreenState();
}

class _RiderMapScreenState extends State<RiderMapScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================
  // FIREBASE
  // ==========================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

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
  // GPS
  // ==========================================================

  StreamSubscription<Position>? _positionSubscription;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _orderSubscription;

  bool _tracking = false;

  bool _locationPermissionDenied = false;

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

  String customerName = 'Customer';

  String customerPhone = '';

  String customerAddress = '';

  double grandTotal = 0;

  // ==========================================================
  // ANIMATION
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
      RiderMapScreen.storeLatitude,
      RiderMapScreen.storeLongitude,
    );

    _riderAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _riderAnimationController.addListener(() {
      if (!mounted) return;

      setState(() {});
    });

    _listenToOrder();
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _positionSubscription?.cancel();

    _orderSubscription?.cancel();

    _riderAnimationController.dispose();

    super.dispose();
  }

  // ==========================================================
  // LISTEN TO ORDER
  // ==========================================================

  void _listenToOrder() {
    _orderSubscription = _firestore
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!snapshot.exists) {
              return;
            }

            final data = snapshot.data();

            if (data == null) {
              return;
            }

            _processOrderData(data);
          },
          onError: (error) {
            debugPrint('Order listener error: $error');
          },
        );
  }

  // ==========================================================
  // PROCESS ORDER
  // ==========================================================

  void _processOrderData(Map<String, dynamic> data) {
    if (!mounted) return;

    final newStatus = data['status']?.toString() ?? 'Out for Delivery';

    final newCustomerName = data['customerName']?.toString() ?? 'Customer';

    final newCustomerPhone = data['customerPhone']?.toString() ?? '';

    final newAddress = data['address']?.toString() ?? '';

    double newTotal = 0;

    final total = data['grandTotal'];

    if (total is num) {
      newTotal = total.toDouble();
    } else {
      newTotal = double.tryParse(total?.toString() ?? '') ?? 0;
    }

    setState(() {
      orderStatus = newStatus;

      customerName = newCustomerName;

      customerPhone = newCustomerPhone;

      customerAddress = newAddress;

      grandTotal = newTotal;
    });

    // ========================================================
    // RIDER GPS FROM FIRESTORE
    // ========================================================

    final lat = data['riderLatitude'];

    final lng = data['riderLongitude'];

    if (lat is num && lng is num) {
      final newLocation = LatLng(lat.toDouble(), lng.toDouble());

      final changed =
          riderLocation == null ||
          riderLocation!.latitude != newLocation.latitude ||
          riderLocation!.longitude != newLocation.longitude;

      if (!changed) {
        return;
      }

      previousRiderLocation = riderLocation;

      riderLocation = newLocation;

      if (previousRiderLocation == null) {
        _riderAnimationController.value = 1;
      } else {
        _riderAnimationController.forward(from: 0);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _requestRoute(newLocation);

        if (_mapReady) {
          try {
            _mapController.move(newLocation, _mapController.camera.zoom);
          } catch (_) {}
        }
      });
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
  // STATUS TITLE
  // ==========================================================

  String _statusTitle() {
    switch (_normalizedStatus(orderStatus)) {
      case 'assigned to rider':
        return 'Delivery assigned';

      case 'accepted':
        return 'Order accepted';

      case 'picked up':
        return 'Order picked up';

      case 'out for delivery':
        if (riderLocation != null) {
          return 'Delivering order';
        }

        return 'Ready for delivery';

      case 'delivered':
        return 'Order delivered';

      case 'cancelled':
        return 'Order cancelled';

      default:
        return 'Delivery';
    }
  }

  // ==========================================================
  // STATUS SUBTITLE
  // ==========================================================

  String _statusSubtitle() {
    switch (_normalizedStatus(orderStatus)) {
      case 'assigned to rider':
        return 'Get ready for delivery';

      case 'accepted':
        return 'You accepted this order';

      case 'picked up':
        return 'Order picked up';

      case 'out for delivery':
        if (_tracking) {
          return 'Live GPS tracking active';
        }

        return 'Start live tracking';

      case 'delivered':
        return 'Delivery completed';

      case 'cancelled':
        return 'This order was cancelled';

      default:
        return 'Delivery';
    }
  }

  // ==========================================================
  // DISTANCE TO CUSTOMER
  // ==========================================================

  double _distanceToCustomer() {
    final rider = riderLocation;

    if (rider == null) {
      return 0;
    }

    const Distance distance = Distance();

    return distance.as(LengthUnit.Meter, rider, customerLocation);
  }

  // ==========================================================
  // FORMAT DISTANCE
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
  // ETA
  // ==========================================================

  int _etaMinutes() {
    if (routeDurationSeconds <= 0) {
      return 1;
    }

    return math.max(1, (routeDurationSeconds / 60).ceil());
  }

  // ==========================================================
  // ARRIVAL CHECK
  // ==========================================================

  bool get _arrived {
    final distance = _distanceToCustomer();

    return distance > 0 && distance <= 50;
  }

  bool get _nearby {
    final distance = _distanceToCustomer();

    return distance > 50 && distance <= 500;
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
  // CHECK GPS
  // ==========================================================

  Future<bool> _checkLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) {
        return false;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please turn on GPS.')));

      await Geolocator.openLocationSettings();

      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) {
        return false;
      }

      setState(() {
        _locationPermissionDenied = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required for live tracking.'),
        ),
      );

      return false;
    }

    return true;
  }

  // ==========================================================
  // START FAST LIVE GPS
  // ==========================================================

  Future<void> _startTracking() async {
    if (_tracking) {
      return;
    }

    final allowed = await _checkLocationPermission();

    if (!allowed) {
      return;
    }

    try {
      // ======================================================
      // SHOW LIVE IMMEDIATELY
      // ======================================================

      if (mounted) {
        setState(() {
          _tracking = true;

          _locationPermissionDenied = false;
        });
      }

      // ======================================================
      // CANCEL OLD STREAM
      // ======================================================

      await _positionSubscription?.cancel();

      // ======================================================
      // START STREAM IMMEDIATELY
      // ======================================================

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) async {
              await _updateRiderLocation(position);

              if (!mounted) {
                return;
              }

              final newLocation = LatLng(position.latitude, position.longitude);

              final changed =
                  riderLocation == null ||
                  riderLocation!.latitude != newLocation.latitude ||
                  riderLocation!.longitude != newLocation.longitude;

              if (!changed) {
                return;
              }

              previousRiderLocation = riderLocation;

              riderLocation = newLocation;

              _riderAnimationController.forward(from: 0);

              _requestRoute(newLocation);

              if (_mapReady) {
                try {
                  _mapController.move(newLocation, _mapController.camera.zoom);
                } catch (_) {}
              }

              setState(() {});
            },
            onError: (error) {
              debugPrint('GPS stream error: $error');
            },
          );

      // ======================================================
      // LAST KNOWN LOCATION
      // ======================================================

      try {
        final lastPosition = await Geolocator.getLastKnownPosition();

        if (lastPosition != null) {
          await _updateRiderLocation(lastPosition);

          if (!mounted) {
            return;
          }

          final location = LatLng(
            lastPosition.latitude,
            lastPosition.longitude,
          );

          previousRiderLocation = null;

          riderLocation = location;

          _riderAnimationController.value = 1;

          setState(() {});

          _requestRoute(location);

          if (_mapReady) {
            try {
              _mapController.move(location, 16);
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('Last known GPS error: $e');
      }

      // ======================================================
      // FRESH GPS IN BACKGROUND
      // ======================================================

      unawaited(_getFreshLocation());
    } catch (e) {
      debugPrint('Start tracking error: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _tracking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start GPS: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================================
  // FRESH GPS
  // ==========================================================

  Future<void> _getFreshLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      await _updateRiderLocation(position);

      if (!mounted) {
        return;
      }

      final location = LatLng(position.latitude, position.longitude);

      previousRiderLocation = riderLocation;

      riderLocation = location;

      _riderAnimationController.forward(from: 0);

      _requestRoute(location);

      if (_mapReady) {
        try {
          _mapController.move(location, 16);
        } catch (_) {}
      }

      setState(() {});
    } catch (e) {
      debugPrint('Fresh GPS error: $e');
    }
  }
  // ==========================================================
  // UPDATE RIDER LOCATION IN FIRESTORE
  // ==========================================================

  Future<void> _updateRiderLocation(Position position) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return;
      }

      await _firestore.collection('orders').doc(widget.orderId).update({
        'riderLatitude': position.latitude,

        'riderLongitude': position.longitude,

        'riderLocationUpdatedAt': FieldValue.serverTimestamp(),

        'riderId': user.uid,
      });
    } catch (e) {
      debugPrint('Firestore GPS update error: $e');
    }
  }

  // ==========================================================
  // STOP TRACKING
  // ==========================================================

  Future<void> _stopTracking() async {
    await _positionSubscription?.cancel();

    _positionSubscription = null;

    if (!mounted) {
      return;
    }

    setState(() {
      _tracking = false;
    });
  }

  // ==========================================================
  // REQUEST ROAD ROUTE
  // ==========================================================

  Future<void> _requestRoute(LatLng rider) async {
    final now = DateTime.now();

    // Prevent excessive requests.
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
        headers: const {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Routing server returned '
          '${response.statusCode}',
        );
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;

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

      if (!mounted) {
        return;
      }

      setState(() {
        routePoints = points;

        routeDistanceMeters = (route['distance'] as num).toDouble();

        routeDurationSeconds = (route['duration'] as num).toDouble();

        loadingRoute = false;
      });
    } catch (e) {
      debugPrint('OSRM route error: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        loadingRoute = false;
      });
    }
  }

  // ==========================================================
  // CENTER RIDER
  // ==========================================================

  void _centerOnRider() {
    final rider = riderLocation;

    if (!_mapReady || rider == null) {
      return;
    }

    try {
      _mapController.move(rider, 16);
    } catch (_) {}
  }

  // ==========================================================
  // FIT RIDER + CUSTOMER
  // ==========================================================

  void _fitRoute() {
    if (!_mapReady) {
      return;
    }

    final rider = riderLocation;

    try {
      if (rider == null) {
        _mapController.move(customerLocation, 14);

        return;
      }

      final bounds = LatLngBounds.fromPoints([rider, customerLocation]);

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(80),
          maxZoom: 16,
        ),
      );
    } catch (e) {
      debugPrint('Fit route error: $e');
    }
  }

  // ==========================================================
  // CALL CUSTOMER
  // ==========================================================

  Future<void> _callCustomer() async {
    if (customerPhone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer phone number is not available.'),
        ),
      );

      return;
    }

    final uri = Uri(scheme: 'tel', path: customerPhone.trim());

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open phone app.')),
        );
      }
    } catch (e) {
      debugPrint('Call customer error: $e');
    }
  }

  // ==========================================================
  // OPEN GOOGLE MAPS NAVIGATION
  // ==========================================================

  Future<void> _openNavigation() async {
    final rider = riderLocation;

    late final Uri uri;

    if (rider != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${rider.latitude},${rider.longitude}'
        '&destination=${customerLocation.latitude},${customerLocation.longitude}'
        '&travelmode=driving',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1'
        '&query=${customerLocation.latitude},${customerLocation.longitude}',
      );
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open navigation.')),
        );
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final rider = animatedRiderLocation;

    return Scaffold(
      backgroundColor: Colors.white,

      body: Stack(
        children: [
          // ====================================================
          // MAP
          // ====================================================
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,

              options: MapOptions(
                initialCenter: rider ?? customerLocation,

                initialZoom: 15,

                onMapReady: () {
                  _mapReady = true;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) {
                      return;
                    }

                    if (riderLocation != null) {
                      _fitRoute();
                    }
                  });
                },
              ),

              children: [
                // ==================================================
                // OPEN STREET MAP
                // ==================================================
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                  userAgentPackageName: 'com.dontblink.app',
                ),

                // ==================================================
                // ROAD ROUTE
                // ==================================================
                if (routePoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,

                        strokeWidth: 6,

                        color: Colors.green,

                        borderStrokeWidth: 2,

                        borderColor: Colors.white,
                      ),
                    ],
                  ),

                // ==================================================
                // MAP MARKERS
                // ==================================================
                MarkerLayer(
                  markers: [
                    // ==============================================
                    // STORE
                    // ==============================================
                    Marker(
                      point: storeLocation,

                      width: 64,

                      height: 64,

                      child: _buildMapMarker(
                        icon: Icons.store,

                        color: Colors.green,

                        label: 'STORE',
                      ),
                    ),

                    // ==============================================
                    // CUSTOMER
                    // ==============================================
                    Marker(
                      point: customerLocation,

                      width: 70,

                      height: 70,

                      child: _buildMapMarker(
                        icon: Icons.home,

                        color: Colors.red,

                        label: 'CUSTOMER',
                      ),
                    ),

                    // ==============================================
                    // RIDER
                    // ==============================================
                    if (rider != null)
                      Marker(
                        point: rider,

                        width: 82,

                        height: 82,

                        child: _buildRiderMarker(),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ====================================================
          // TOP HEADER
          // ====================================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,

            child: SafeArea(
              bottom: false,

              child: Container(
                padding: const EdgeInsets.fromLTRB(7, 9, 12, 15),

                decoration: const BoxDecoration(
                  color: Colors.green,

                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),

                    bottomRight: Radius.circular(24),
                  ),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,

                      blurRadius: 10,

                      offset: Offset(0, 3),
                    ),
                  ],
                ),

                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },

                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),

                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            customerName,

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,

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

                            style: const TextStyle(
                              color: Colors.white,

                              fontSize: 19,

                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // GPS STATUS
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,

                        vertical: 7,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),

                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: Row(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          Icon(
                            _tracking ? Icons.gps_fixed : Icons.gps_off,

                            color: Colors.white,

                            size: 15,
                          ),

                          const SizedBox(width: 4),

                          Text(
                            _tracking ? 'LIVE' : 'OFF',

                            style: const TextStyle(
                              color: Colors.white,

                              fontWeight: FontWeight.bold,

                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ====================================================
          // CUSTOMER INFO
          // ====================================================
          Positioned(
            top: 125,
            left: 15,
            right: 15,

            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(16),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),

                    blurRadius: 10,
                  ),
                ],
              ),

              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,

                    decoration: BoxDecoration(
                      color: Colors.red.shade50,

                      shape: BoxShape.circle,
                    ),

                    child: const Icon(Icons.home, color: Colors.red),
                  ),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          'DELIVER TO',

                          style: TextStyle(
                            color: Colors.grey.shade600,

                            fontSize: 9,

                            fontWeight: FontWeight.bold,

                            letterSpacing: 0.8,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          customerAddress.trim().isEmpty
                              ? 'Customer location'
                              : customerAddress,

                          maxLines: 2,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(
                            fontWeight: FontWeight.w600,

                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (customerPhone.trim().isNotEmpty)
                    GestureDetector(
                      onTap: _callCustomer,

                      child: Container(
                        width: 42,
                        height: 42,

                        decoration: BoxDecoration(
                          color: Colors.green.shade50,

                          shape: BoxShape.circle,
                        ),

                        child: const Icon(Icons.phone, color: Colors.green),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ====================================================
          // GPS LIVE BADGE
          // ====================================================
          if (_tracking)
            Positioned(
              top: 215,
              right: 15,

              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
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
                      'GPS LIVE',

                      style: TextStyle(
                        color: Colors.green,

                        fontWeight: FontWeight.bold,

                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ====================================================
          // MAP CONTROLS
          // ====================================================
          Positioned(
            right: 15,
            bottom: 400,

            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'rider_fit_route',

                  backgroundColor: Colors.white,

                  foregroundColor: Colors.green,

                  onPressed: _fitRoute,

                  child: const Icon(Icons.fit_screen),
                ),

                const SizedBox(height: 10),

                FloatingActionButton.small(
                  heroTag: 'rider_center',

                  backgroundColor: Colors.white,

                  foregroundColor: Colors.green,

                  onPressed: rider == null ? null : _centerOnRider,

                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),

          // ====================================================
          // BOTTOM SHEET
          // ====================================================
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomSheet()),
        ],
      ),
    );
  }

  // ==========================================================
  // MAP MARKER
  // ==========================================================

  Widget _buildMapMarker({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,

      children: [
        Container(
          width: 48,
          height: 48,

          decoration: BoxDecoration(
            color: Colors.white,

            shape: BoxShape.circle,

            border: Border.all(color: color, width: 3),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),

                blurRadius: 8,
              ),
            ],
          ),

          child: Icon(icon, color: color, size: 27),
        ),

        const SizedBox(height: 2),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(6),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),

                blurRadius: 4,
              ),
            ],
          ),

          child: Text(
            label,

            style: TextStyle(
              color: color,

              fontWeight: FontWeight.bold,

              fontSize: 8,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // RIDER MARKER
  // ==========================================================

  Widget _buildRiderMarker() {
    return Stack(
      alignment: Alignment.center,

      children: [
        Container(
          width: 78,
          height: 78,

          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),

            shape: BoxShape.circle,
          ),
        ),

        Container(
          width: 58,
          height: 58,

          decoration: BoxDecoration(
            color: Colors.green,

            shape: BoxShape.circle,

            border: Border.all(color: Colors.white, width: 4),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),

                blurRadius: 10,
              ),
            ],
          ),

          child: const Icon(
            Icons.delivery_dining,

            color: Colors.white,

            size: 32,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // BOTTOM SHEET
  // ==========================================================

  Widget _buildBottomSheet() {
    final distance = _distanceToCustomer();

    final nearby = _nearby;

    final arrived = _arrived;

    return SafeArea(
      top: false,

      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 13, 18, 18),

        decoration: const BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),

            topRight: Radius.circular(28),
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black12,

              blurRadius: 18,

              offset: Offset(0, -5),
            ),
          ],
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            // ==================================================
            // HANDLE
            // ==================================================
            Container(
              width: 45,
              height: 5,

              decoration: BoxDecoration(
                color: Colors.grey.shade300,

                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 13),

            // ==================================================
            // ETA + DISTANCE
            // ==================================================
            Row(
              children: [
                Expanded(
                  child: _infoBox(
                    icon: Icons.access_time,

                    title: 'ETA',

                    value: arrived
                        ? 'Arrived'
                        : riderLocation == null
                        ? '--'
                        : '${_etaMinutes()} min',
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _infoBox(
                    icon: Icons.navigation,

                    title: 'Distance',

                    value: routeDistanceMeters > 0
                        ? _formatDistance()
                        : riderLocation == null
                        ? '--'
                        : distance < 1000
                        ? '${distance.toStringAsFixed(0)} m'
                        : '${(distance / 1000).toStringAsFixed(1)} km',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 13),

            // ==================================================
            // CUSTOMER CARD
            // ==================================================
            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(13),

              decoration: BoxDecoration(
                color: Colors.red.shade50,

                borderRadius: BorderRadius.circular(16),
              ),

              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,

                    decoration: const BoxDecoration(
                      color: Colors.red,

                      shape: BoxShape.circle,
                    ),

                    child: const Icon(
                      Icons.home,

                      color: Colors.white,

                      size: 28,
                    ),
                  ),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          arrived
                              ? 'You have arrived'
                              : nearby
                              ? 'Customer is nearby'
                              : 'Deliver to',

                          style: const TextStyle(
                            fontSize: 16,

                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          customerName,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(
                            color: Colors.grey,

                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (customerPhone.trim().isNotEmpty)
                    GestureDetector(
                      onTap: _callCustomer,

                      child: Container(
                        width: 43,
                        height: 43,

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
            // START GPS
            // ==================================================
            SizedBox(
              width: double.infinity,

              height: 52,

              child: ElevatedButton.icon(
                icon: Icon(_tracking ? Icons.gps_fixed : Icons.gps_not_fixed),

                label: Text(_tracking ? 'LIVE GPS TRACKING' : 'START LIVE GPS'),

                onPressed: _tracking ? null : _startTracking,

                style: ElevatedButton.styleFrom(
                  backgroundColor: _tracking ? Colors.green : Colors.orange,

                  foregroundColor: Colors.white,

                  elevation: 0,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 9),

            // ==================================================
            // NAVIGATION
            // ==================================================
            SizedBox(
              width: double.infinity,

              height: 52,

              child: OutlinedButton.icon(
                icon: const Icon(Icons.navigation, color: Colors.green),

                label: const Text(
                  'NAVIGATE TO CUSTOMER',

                  style: TextStyle(
                    color: Colors.green,

                    fontWeight: FontWeight.bold,
                  ),
                ),

                onPressed: _openNavigation,

                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.green),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 9),

            // ==================================================
            // GPS INFORMATION
            // ==================================================
            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(11),

              decoration: BoxDecoration(
                color: _tracking ? Colors.green.shade50 : Colors.orange.shade50,

                borderRadius: BorderRadius.circular(12),
              ),

              child: Row(
                children: [
                  Icon(
                    _tracking ? Icons.location_on : Icons.location_searching,

                    color: _tracking ? Colors.green : Colors.orange,

                    size: 20,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      _tracking
                          ? 'Your live location is being shared with the customer.'
                          : 'Start GPS so the customer can see your live location.',

                      style: TextStyle(
                        color: _tracking ? Colors.green : Colors.orange,

                        fontSize: 11,

                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 9),

            // ==================================================
            // ORDER INFORMATION
            // ==================================================
            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(11),

              decoration: BoxDecoration(
                color: Colors.grey.shade50,

                borderRadius: BorderRadius.circular(12),
              ),

              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.grey, size: 20),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      'Order #${widget.orderId.length > 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId.toUpperCase()}',

                      style: const TextStyle(
                        color: Colors.grey,

                        fontSize: 11,

                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  Text(
                    _formatPrice(grandTotal),

                    style: const TextStyle(
                      color: Colors.green,

                      fontWeight: FontWeight.bold,

                      fontSize: 15,
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

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

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
}
