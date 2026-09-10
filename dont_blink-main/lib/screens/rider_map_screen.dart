import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dont_blink/utils/emoji_marker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/delivery_tracking_service.dart';

enum NavigationTarget { store, customer }

class RiderMapScreen extends StatefulWidget {
  final String orderId;
  final double customerLatitude;
  final double customerLongitude;
  final double? storeLatitude;
  final double? storeLongitude;
  final String? storeName;
  final String? storeCode;
  final bool isRerouted;
  final String? originalNearestStoreName;
  final bool initialFocusStore;

  const RiderMapScreen({
    super.key,
    required this.orderId,
    required this.customerLatitude,
    required this.customerLongitude,
    this.storeLatitude,
    this.storeLongitude,
    this.storeName,
    this.storeCode,
    this.isRerouted = false,
    this.originalNearestStoreName,
    this.initialFocusStore = false,
  });

  @override
  State<RiderMapScreen> createState() => _RiderMapScreenState();
}

class _RiderMapScreenState extends State<RiderMapScreen>
    with SingleTickerProviderStateMixin {
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  GoogleMapController? _mapController;
  bool _mapReady = false;

  late final LatLng customerLocation;
  LatLng? storeLocation;
  String storeName = 'Doorstepp Store';
  String storeCode = '';
  bool _loadingStoreLocation = false;

  LatLng? riderLocation;
  LatLng? previousRiderLocation;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _orderSubscription;

  bool _tracking = false;

  List<LatLng> routePoints = [];
  double routeDistanceMeters = 0;
  double routeDurationSeconds = 0;
  bool loadingRoute = false;
  DateTime? lastRouteRequest;

  String orderStatus = 'Out for Delivery';
  String customerName = 'Customer';
  String customerPhone = '';
  String customerAddress = '';
  double grandTotal = 0;
  bool isPrepaid = false;
  String paymentMethod = 'Cash on Delivery';
  bool _delivering = false;
  bool hasSurcharge = false;
  double riderEarnings = 16.0;

  NavigationTarget _activeTarget = NavigationTarget.store;
  bool _manuallySwitchedTarget = false;
  bool isRerouted = false;
  String originalNearestStoreName = '';

  late final AnimationController _riderAnimationController;

  // Emoji markers
  BitmapDescriptor? _customerIcon; // 🏠 shown to rider
  BitmapDescriptor? _riderSelfIcon; // 🛵 shown for rider's own position
  BitmapDescriptor? _storeIcon; // 🏬 shown for store pickup location

  Future<void> _loadEmojiMarkers() async {
    final customer = await emojiMarker('🏠', size: 72);
    final riderSelf = await emojiMarker('🛵', size: 72);
    final store = await emojiMarker('🏬', size: 72);
    if (!mounted) return;
    setState(() {
      _customerIcon = customer;
      _riderSelfIcon = riderSelf;
      _storeIcon = store;
    });
  }

  @override
  void initState() {
    super.initState();

    customerLocation = LatLng(
      widget.customerLatitude,
      widget.customerLongitude,
    );

    if (widget.storeLatitude != null &&
        widget.storeLongitude != null &&
        widget.storeLatitude != 0 &&
        widget.storeLongitude != 0) {
      storeLocation = LatLng(widget.storeLatitude!, widget.storeLongitude!);
    }

    if (widget.storeName != null && widget.storeName!.isNotEmpty) {
      storeName = widget.storeName!;
    }
    if (widget.storeCode != null && widget.storeCode!.isNotEmpty) {
      storeCode = widget.storeCode!;
    }
    isRerouted = widget.isRerouted;
    if (widget.originalNearestStoreName != null &&
        widget.originalNearestStoreName!.isNotEmpty) {
      originalNearestStoreName = widget.originalNearestStoreName!;
    }

    _activeTarget = widget.initialFocusStore
        ? NavigationTarget.store
        : NavigationTarget.customer;

    _riderAnimationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..addListener(() {
            if (mounted) setState(() {});
          });

    _listenToOrder();
    _loadEmojiMarkers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startTracking();
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _orderSubscription?.cancel();
    _riderAnimationController.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapReady = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fitRoute();
    });
  }

  void _listenToOrder() {
    _orderSubscription = _firestore
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!snapshot.exists) return;

            final data = snapshot.data();
            if (data == null) return;

            _processOrderData(data);
          },
          onError: (error) {
            debugPrint('Order listener error: $error');
          },
        );
  }

  // ==========================================================
  // LOAD STORE LOCATION FROM FIREBASE
  // ==========================================================

  Future<void> _loadStoreLocation(Map<String, dynamic> orderData) async {
    if (_loadingStoreLocation) return;

    final orderStoreLat = _number(orderData['storeLatitude']);
    final orderStoreLng = _number(orderData['storeLongitude']);

    final orderStoreName = orderData['storeName']?.toString().trim() ?? '';
    final orderStoreCode = orderData['storeCode']?.toString().trim() ?? '';
    final orderIsRerouted = orderData['isRerouted'] == true;
    final orderOriginalStore =
        orderData['originalNearestStoreName']?.toString().trim() ?? '';

    // Prefer the exact store location saved with this order.
    if (orderStoreLat != 0 || orderStoreLng != 0) {
      if (!mounted) return;

      setState(() {
        storeLocation = LatLng(orderStoreLat, orderStoreLng);

        if (orderStoreName.isNotEmpty) {
          storeName = orderStoreName;
        }

        if (orderStoreCode.isNotEmpty) {
          storeCode = orderStoreCode;
        }

        isRerouted = orderIsRerouted;
        if (orderOriginalStore.isNotEmpty) {
          originalNearestStoreName = orderOriginalStore;
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mapReady) return;
        _fitRoute();
      });

      return;
    }

    // Fallback: read the current store document.
    final storeId = orderData['storeId']?.toString().trim() ?? '';

    if (storeId.isEmpty) return;

    _loadingStoreLocation = true;

    try {
      final doc = await _firestore.collection('stores').doc(storeId).get();

      if (!doc.exists || !mounted) return;

      final data = doc.data();

      if (data == null) return;

      final lat = _number(data['latitude']);
      final lng = _number(data['longitude']);

      if (lat == 0 && lng == 0) return;

      final name = data['name']?.toString().trim() ?? '';
      final code = data['code']?.toString().trim() ?? '';

      setState(() {
        storeLocation = LatLng(lat, lng);

        if (name.isNotEmpty) {
          storeName = name;
        }

        if (code.isNotEmpty) {
          storeCode = code;
        }

        isRerouted = orderIsRerouted;
        if (orderOriginalStore.isNotEmpty) {
          originalNearestStoreName = orderOriginalStore;
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mapReady) return;
        _fitRoute();
      });
    } catch (e) {
      debugPrint('Firebase store location error: $e');
    } finally {
      _loadingStoreLocation = false;
    }
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _processOrderData(Map<String, dynamic> data) {
    if (!mounted) return;

    unawaited(_loadStoreLocation(data));

    final newStatus = data['status']?.toString() ?? 'Out for Delivery';
    final sLower = newStatus.toLowerCase();
    final newCustomerName = data['customerName']?.toString() ?? 'Customer';
    final newCustomerPhone = data['customerPhone']?.toString() ?? '';
    final newAddress = data['address']?.toString() ?? '';

    if (!_manuallySwitchedTarget) {
      if (sLower == 'picked up' ||
          sLower == 'out for delivery' ||
          sLower == 'delivered') {
        _activeTarget = NavigationTarget.customer;
      } else {
        _activeTarget = NavigationTarget.store;
      }
    }

    double newTotal = 0;
    final total = data['grandTotal'];

    if (total is num) {
      newTotal = total.toDouble();
    } else {
      newTotal = double.tryParse(total?.toString() ?? '') ?? 0;
    }

    final method = (data['paymentMethod'] ?? '').toString();
    final prepaid = data['isPrepaid'] == true ||
        data['paymentStatus']?.toString().toLowerCase() == 'paid' ||
        method.toLowerCase() == 'online' ||
        method.toLowerCase() == 'online payment' ||
        method.toLowerCase() == 'upi';

    final fee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    final surcharge = (data['deliverySurcharge'] as num?)?.toDouble() ?? 0.0;
    final bool hasSurge =
        data['hasSurcharge'] == true || surcharge > 0 || fee > 25.0;
    final double earnings = (data['riderPayout'] as num?)?.toDouble() ??
        (data['riderEarnings'] as num?)?.toDouble() ??
        (hasSurge ? 19.0 : 16.0);

    setState(() {
      orderStatus = newStatus;
      customerName = newCustomerName;
      customerPhone = newCustomerPhone;
      customerAddress = newAddress;
      grandTotal = newTotal;
      isPrepaid = prepaid;
      paymentMethod = method.isNotEmpty
          ? method
          : (prepaid ? 'Paid Online' : 'Cash on Delivery');
      hasSurcharge = hasSurge;
      riderEarnings = earnings;
    });

    final lat = data['riderLatitude'];
    final lng = data['riderLongitude'];

    if (lat is! num || lng is! num) return;

    final newLocation = LatLng(lat.toDouble(), lng.toDouble());

    final changed =
        riderLocation == null ||
        riderLocation!.latitude != newLocation.latitude ||
        riderLocation!.longitude != newLocation.longitude;

    if (!changed) return;

    previousRiderLocation = riderLocation;
    riderLocation = newLocation;

    if (previousRiderLocation == null) {
      _riderAnimationController.value = 1;
    } else {
      _riderAnimationController.forward(from: 0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      unawaited(_requestRoute(newLocation));

      if (_mapReady) {
        _animateCameraTo(newLocation);
      }
    });
  }

  LatLng? get animatedRiderLocation {
    if (riderLocation == null) return null;
    if (previousRiderLocation == null) return riderLocation;

    final t = Curves.easeInOut.transform(_riderAnimationController.value);

    return LatLng(
      previousRiderLocation!.latitude +
          (riderLocation!.latitude - previousRiderLocation!.latitude) * t,
      previousRiderLocation!.longitude +
          (riderLocation!.longitude - previousRiderLocation!.longitude) * t,
    );
  }

  bool get isPickupPhase {
    final s = orderStatus.toLowerCase();
    return s != 'picked up' && s != 'out for delivery' && s != 'delivered';
  }

  LatLng get currentDestination {
    if (_activeTarget == NavigationTarget.store && storeLocation != null) {
      return storeLocation!;
    }
    return customerLocation;
  }

  double _distanceToTarget() {
    final rider = riderLocation;
    if (rider == null) return 0;

    final dest = currentDestination;
    return Geolocator.distanceBetween(
      rider.latitude,
      rider.longitude,
      dest.latitude,
      dest.longitude,
    );
  }

  String _formatDistance() {
    if (routeDistanceMeters <= 0) return '--';

    if (routeDistanceMeters >= 1000) {
      return '${(routeDistanceMeters / 1000).toStringAsFixed(1)} km';
    }

    return '${routeDistanceMeters.toStringAsFixed(0)} m';
  }

  int _etaMinutes() {
    if (routeDurationSeconds <= 0) return 1;
    return math.max(1, (routeDurationSeconds / 60).ceil());
  }

  bool get _arrived {
    final distance = _distanceToTarget();
    return distance > 0 && distance <= 50;
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '₹${value.toInt()}';
    }
    return '₹${value.toStringAsFixed(2)}';
  }

  Future<bool> _checkLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) return false;

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
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required for live tracking.'),
        ),
      );

      return false;
    }

    return true;
  }

  Future<void> _startTracking() async {
    if (_tracking) return;

    final allowed = await _checkLocationPermission();
    if (!allowed) return;

    try {
      if (mounted) {
        setState(() {
          _tracking = true;
        });
      }

      await _positionSubscription?.cancel();

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (position) async {
              await _updateRiderLocation(position);

              if (!mounted) return;

              final newLocation = LatLng(position.latitude, position.longitude);

              final changed =
                  riderLocation == null ||
                  riderLocation!.latitude != newLocation.latitude ||
                  riderLocation!.longitude != newLocation.longitude;

              if (!changed) return;

              previousRiderLocation = riderLocation;
              riderLocation = newLocation;

              _riderAnimationController.forward(from: 0);

              unawaited(_requestRoute(newLocation));

              if (_mapReady) {
                _animateCameraTo(newLocation);
              }

              setState(() {});
            },
            onError: (error) {
              debugPrint('GPS stream error: $error');
            },
          );

      try {
        final lastPosition = await Geolocator.getLastKnownPosition();

        if (lastPosition != null) {
          await _updateRiderLocation(lastPosition);

          if (!mounted) return;

          riderLocation = LatLng(lastPosition.latitude, lastPosition.longitude);
          previousRiderLocation = null;
          _riderAnimationController.value = 1;

          setState(() {});

          unawaited(_requestRoute(riderLocation!));

          if (_mapReady) {
            _animateCameraTo(riderLocation!, zoom: 16);
          }
        }
      } catch (e) {
        debugPrint('Last known GPS error: $e');
      }

      unawaited(_getFreshLocation());
    } catch (e) {
      debugPrint('Start tracking error: $e');

      if (!mounted) return;

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

  Future<void> _getFreshLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      await _updateRiderLocation(position);

      if (!mounted) return;

      final location = LatLng(position.latitude, position.longitude);

      previousRiderLocation = riderLocation;
      riderLocation = location;

      _riderAnimationController.forward(from: 0);

      unawaited(_requestRoute(location));

      if (_mapReady) {
        _animateCameraTo(location, zoom: 16);
      }

      setState(() {});
    } catch (e) {
      debugPrint('Fresh GPS error: $e');
    }
  }

  Future<void> _updateRiderLocation(Position position) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

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

  Future<void> _requestRoute(LatLng rider) async {
    final routesApiKey = await _getRoutesApiKey();
    if (routesApiKey.isEmpty) {
      debugPrint(
        'Google Routes API key is not configured.',
      );

      if (mounted) {
        setState(() {
          loadingRoute = false;
        });
      }
      return;
    }

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
        'https://routes.googleapis.com/directions/v2:computeRoutes',
      );

      final body = {
        'origin': {
          'location': {
            'latLng': {
              'latitude': rider.latitude,
              'longitude': rider.longitude,
            },
          },
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': currentDestination.latitude,
              'longitude': currentDestination.longitude,
            },
          },
        },
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE',
        'polylineQuality': 'HIGH_QUALITY',
        'polylineEncoding': 'ENCODED_POLYLINE',
        'languageCode': 'en-US',
        'computeAlternativeRoutes': false,
        'units': 'METRIC',
      };

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-Goog-Api-Key': routesApiKey,
              'X-Goog-FieldMask':
                  'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception(
          'Google Routes returned ${response.statusCode}: '
          '${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid Google Routes response.');
      }

      final routes = decoded['routes'];

      if (routes is! List || routes.isEmpty) {
        throw Exception('No route available.');
      }

      final route = routes.first;

      if (route is! Map) {
        throw Exception('Invalid route.');
      }

      final distance = (route['distanceMeters'] as num?)?.toDouble() ?? 0;

      final durationString = route['duration']?.toString() ?? '';

      final durationSeconds = _parseGoogleDurationSeconds(durationString);

      final polyline = route['polyline'];

      final encoded = polyline is Map
          ? polyline['encodedPolyline']?.toString()
          : null;

      final points = encoded == null || encoded.isEmpty
          ? <LatLng>[]
          : _decodePolyline(encoded);

      if (!mounted) return;

      setState(() {
        routePoints = points;
        routeDistanceMeters = distance;
        routeDurationSeconds = durationSeconds;
        loadingRoute = false;
      });
    } catch (e) {
      debugPrint('Google Routes error: $e');

      if (!mounted) return;

      setState(() {
        loadingRoute = false;
      });
    }
  }

  double _parseGoogleDurationSeconds(String value) {
    final match = RegExp(r'^([0-9]+(?:\.[0-9]+)?)s$').firstMatch(value);

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

  void _animateCameraTo(LatLng location, {double zoom = 16}) {
    final controller = _mapController;
    if (controller == null) return;

    unawaited(
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: zoom),
        ),
      ),
    );
  }

  void _centerOnRider() {
    final rider = riderLocation;
    if (!_mapReady || rider == null) return;

    _animateCameraTo(rider);
  }

  Future<void> _fitRoute() async {
    final controller = _mapController;
    if (!_mapReady || controller == null) return;

    final points = <LatLng>[
      customerLocation,
      ?storeLocation,
      ?riderLocation,
      ...routePoints,
    ];

    if (points.length == 1) {
      _animateCameraTo(points.first, zoom: 14);
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (e) {
      debugPrint('Fit route error: $e');
    }
  }

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
  // IN-APP NAVIGATION
  // ==========================================================
  //
  // Navigation stays inside Doorstepp.
  // We do NOT launch the external Google Maps application.
  //
  // The GoogleMap already displays:
  // - rider location
  // - customer location
  // - Google road route
  // - traffic
  //
  // Pressing this button simply focuses the in-app map on the
  // active rider -> customer route and requests a fresh route.
  // ==========================================================

  Future<void> _openNavigation({NavigationTarget? target}) async {
    final rider = riderLocation;

    if (!_mapReady || _mapController == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Map is still loading. Please try again.'),
          ),
        );
      }
      return;
    }

    final effectiveTarget = target ?? _activeTarget;
    final dest =
        (effectiveTarget == NavigationTarget.store && storeLocation != null)
            ? storeLocation!
            : customerLocation;

    if (rider == null) {
      try {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: dest, zoom: 15),
          ),
        );
      } catch (e) {
        debugPrint('Camera error: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              effectiveTarget == NavigationTarget.store
                  ? 'Start live GPS to show your route to the dark store.'
                  : 'Start live GPS to show your live route to the customer.',
            ),
          ),
        );
      }

      return;
    }

    // Request a fresh Google road route immediately.
    lastRouteRequest = null;
    await _requestRoute(rider);

    if (!mounted || _mapController == null) return;

    // Keep navigation entirely inside Doorstepp by fitting the
    // route on our GoogleMap.
    await _fitRoute();

    if (!mounted) return;

    // Also launch Google Maps turn-by-turn navigation for live voice guidance
    final lat = dest.latitude;
    final lng = dest.longitude;
    final navUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    try {
      if (await canLaunchUrl(navUri)) {
        await launchUrl(navUri);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Navigation launch error: $e');
    }
  }

  // ==========================================================
  // MARK ORDER PICKED UP FLOW
  // ==========================================================

  Future<void> _markOrderPickedUp() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.teal, size: 26),
            SizedBox(width: 8),
            Text('Confirm Store Pickup?'),
          ],
        ),
        content: Text(
          'Have you collected the order items from ${storeName.isNotEmpty ? storeName : "the store"}?',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Yes, Picked Up'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _delivering = true;
    });

    try {
      final ref = _firestore.collection('orders').doc(widget.orderId);
      await ref.update({
        'status': 'Picked Up',
        'pickedUpAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        orderStatus = 'Picked Up';
        _delivering = false;
        _manuallySwitchedTarget = false;
        _activeTarget = NavigationTarget.customer;
      });

      if (riderLocation != null) {
        lastRouteRequest = null;
        unawaited(_requestRoute(riderLocation!));
      }
      _fitRoute();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order picked up! Now delivering to customer.'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _delivering = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================================
  // MARK ORDER DELIVERED FLOW
  // ==========================================================

  Future<void> _markOrderDelivered() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 26),
            SizedBox(width: 8),
            Text('Complete Delivery?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirm that you have handed the order to the customer.',
              style: TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasSurcharge ? const Color(0xFFEFF6FF) : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasSurcharge
                      ? const Color(0xFF93C5FD)
                      : Colors.green.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasSurcharge ? Icons.cloudy_snowing : Icons.monetization_on,
                    color: hasSurcharge ? const Color(0xFF1D4ED8) : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasSurcharge
                          ? 'You will receive ₹${riderEarnings.toInt()} for this delivery (incl. ₹3 rain surge) 🌧️'
                          : 'You will receive ₹${riderEarnings.toInt()} for this delivery.',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: hasSurcharge
                            ? const Color(0xFF1D4ED8)
                            : Colors.green,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Yes, Delivered'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _delivering = true;
    });

    try {
      final ref = _firestore.collection('orders').doc(widget.orderId);
      await ref.update({
        'status': 'Delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'riderPayout': riderEarnings,
        'riderEarnings': riderEarnings,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await DeliveryTrackingService.instance.stopAfterDelivered(
        orderId: widget.orderId,
      );

      if (!mounted) return;

      setState(() {
        orderStatus = 'Delivered';
        _delivering = false;
      });

      // Show celebratory dialog
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 44,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Delivery Completed! 🎉',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You earned ₹${riderEarnings.toInt()} for this delivery${hasSurcharge ? " (incl. ₹3 rain surge bonus!)" : ""}.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: hasSurcharge ? const Color(0xFF1D4ED8) : Colors.green,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your earnings have been updated on your dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context); // Go back to orders
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'BACK TO DASHBOARD',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _delivering = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rider = animatedRiderLocation;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: rider ?? customerLocation,
                zoom: 15,
              ),
              onMapCreated: _onMapCreated,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: true,
              trafficEnabled: true,
              rotateGesturesEnabled: true,
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: true,
              zoomGesturesEnabled: true,
              markers: {
                if (storeLocation != null)
                  Marker(
                    markerId: const MarkerId('store'),
                    position: storeLocation!,
                    icon: _storeIcon ??
                        BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueOrange,
                        ),
                    anchor: const Offset(0.5, 0.5),
                    infoWindow: InfoWindow(
                      title: '🏬 $storeName ${isRerouted ? "(Backup Store)" : ""}',
                      snippet: storeCode.isEmpty
                          ? 'Dark Store Pickup'
                          : 'Store Code: $storeCode',
                    ),
                  ),
                // Customer = 🏠 emoji (large, clearly visible)
                Marker(
                  markerId: const MarkerId('customer'),
                  position: customerLocation,
                  icon: _customerIcon ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                  anchor: const Offset(0.5, 0.5),
                  infoWindow: InfoWindow(
                    title: customerName.isNotEmpty ? customerName : 'Customer',
                    snippet: customerAddress.isEmpty
                        ? 'Delivery location'
                        : customerAddress,
                  ),
                ),
                // Rider self = 🛵 emoji (animated, smooth)
                if (rider != null)
                  Marker(
                    markerId: const MarkerId('rider'),
                    position: rider,
                    icon: _riderSelfIcon ??
                        BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen,
                        ),
                    flat: true,
                    anchor: const Offset(0.5, 0.5),
                    infoWindow: const InfoWindow(
                      title: 'You',
                      snippet: 'Your location',
                    ),
                  ),
              },
              polylines: {
                if (routePoints.length >= 2)
                  Polyline(
                    polylineId: const PolylineId('delivery_route'),
                    points: routePoints,
                    color: Colors.green,
                    width: 6,
                    jointType: JointType.round,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                  ),
              },
            ),
          ),

          // ==========================================================
          // COMPACT TOP FLOATING BAR (IN SAFEARIA) WITH STORE TABS
          // ==========================================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Title & Status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _activeTarget == NavigationTarget.store
                                          ? '🏬 $storeName'
                                          : (customerName.isNotEmpty
                                              ? '🏠 $customerName'
                                              : '🏠 Customer'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _tracking
                                          ? Colors.green.shade50
                                          : Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _tracking ? 'GPS ON' : 'GPS OFF',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: _tracking
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _activeTarget == NavigationTarget.store
                                    ? (storeCode.isNotEmpty
                                        ? 'Store Code: $storeCode • Dark store pickup'
                                        : 'Dark store pickup location')
                                    : (customerAddress.trim().isEmpty
                                        ? 'Customer delivery location'
                                        : customerAddress.trim()),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Call button if targeting customer
                        if (_activeTarget == NavigationTarget.customer &&
                            customerPhone.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _callCustomer,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: const Icon(
                                Icons.phone_rounded,
                                color: Colors.green,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Two-tab target selector: [🏬 Pickup Store] | [🏠 Customer]
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _manuallySwitchedTarget = true;
                                _activeTarget = NavigationTarget.store;
                              });
                              if (riderLocation != null) {
                                lastRouteRequest = null;
                                unawaited(_requestRoute(riderLocation!));
                              }
                              _fitRoute();
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: _activeTarget == NavigationTarget.store
                                    ? const Color(0xFF4F46E5)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '🏬 Store Pickup',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _activeTarget == NavigationTarget.store
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                  if (isRerouted) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade300,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Rerouted',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _manuallySwitchedTarget = true;
                                _activeTarget = NavigationTarget.customer;
                              });
                              if (riderLocation != null) {
                                lastRouteRequest = null;
                                unawaited(_requestRoute(riderLocation!));
                              }
                              _fitRoute();
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: _activeTarget == NavigationTarget.customer
                                    ? Colors.green
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '🏠 Customer Delivery',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _activeTarget == NavigationTarget.customer
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Map FAB Controls (Center & Fit Route) positioned cleanly above bottom sheet
          Positioned(
            right: 14,
            bottom: 235,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'rider_fit_route',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green,
                  elevation: 3,
                  onPressed: _fitRoute,
                  child: const Icon(Icons.fit_screen_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'rider_center',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green,
                  elevation: 3,
                  onPressed: rider == null ? null : _centerOnRider,
                  child: const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
          ),

          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomSheet()),
        ],
      ),
    );
  }

  // ==========================================================
  // COMPACT BOTTOM SHEET
  // ==========================================================

  Widget _buildBottomSheet() {
    final isTargetStore = _activeTarget == NavigationTarget.store;
    final distance = _distanceToTarget();
    final arrived = _arrived;
    final isDelivered = orderStatus.toLowerCase() == 'delivered';
    final sLower = orderStatus.toLowerCase();
    final isPrePickup = sLower != 'picked up' &&
        sLower != 'out for delivery' &&
        sLower != 'delivered';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 10),

            // Top Row: ETA, Distance & Rider Payout Badge
            Row(
              children: [
                // ETA & Distance
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 15,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        arrived
                            ? 'Arrived'
                            : riderLocation == null
                            ? '--'
                            : '${_etaMinutes()} min',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isTargetStore
                            ? Icons.storefront_rounded
                            : Icons.navigation_rounded,
                        size: 14,
                        color: isTargetStore
                            ? const Color(0xFF4F46E5)
                            : Colors.green,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        routeDistanceMeters > 0
                            ? _formatDistance()
                            : riderLocation == null
                            ? '--'
                            : distance < 1000
                            ? '${distance.toStringAsFixed(0)} m'
                            : '${(distance / 1000).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Rider Payout Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hasSurcharge
                        ? const Color(0xFFEFF6FF)
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasSurcharge
                          ? const Color(0xFF93C5FD)
                          : Colors.green.shade300,
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
                            ? 'You get: ₹${riderEarnings.toInt()} (Surge)'
                            : 'You get: ₹${riderEarnings.toInt()}',
                        style: TextStyle(
                          color: hasSurcharge
                              ? const Color(0xFF1D4ED8)
                              : Colors.green,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Store Info Card (when targeting store or in pickup phase)
            if (isTargetStore) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFF4F46E5),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  storeName.isNotEmpty
                                      ? storeName
                                      : 'Dark Store',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    color: Color(0xFF312E81),
                                  ),
                                ),
                              ),
                              if (storeCode.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    storeCode,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isRerouted
                                ? '⚡ REROUTED: Collect order items from this backup store'
                                : 'Collect order items from this dark store',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isRerouted
                                  ? const Color(0xFFC2410C)
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Order & Payment Summary row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isPrepaid ? Colors.blue.shade50 : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPrepaid
                      ? Colors.blue.shade200
                      : Colors.amber.shade300,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isPrepaid
                        ? Icons.check_circle_outline_rounded
                        : Icons.payments_outlined,
                    size: 16,
                    color: isPrepaid
                        ? Colors.blue.shade700
                        : Colors.amber.shade900,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPrepaid
                        ? 'Prepaid Online • Do not collect cash'
                        : 'Collect Cash: ${_formatPrice(grandTotal)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isPrepaid
                          ? Colors.blue.shade800
                          : const Color(0xFF78350F),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '#${widget.orderId.length > 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Action Buttons: Navigate + Mark Status
            if (isDelivered)
              Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'DELIVERED • EARNED ₹${riderEarnings.toInt()}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (isPrePickup && isTargetStore)
              Row(
                children: [
                  // Navigate to Store
                  Expanded(
                    flex: 4,
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.directions_rounded,
                          color: Color(0xFF4F46E5),
                          size: 18,
                        ),
                        label: const Text(
                          'TO STORE',
                          style: TextStyle(
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w900,
                            fontSize: 11.5,
                          ),
                        ),
                        onPressed: () =>
                            _openNavigation(target: NavigationTarget.store),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF4F46E5),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Mark Picked Up Button
                  Expanded(
                    flex: 6,
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: _delivering
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.inventory_2_outlined,
                                size: 19,
                              ),
                        label: Text(
                          _delivering ? 'UPDATING...' : 'MARK PICKED UP',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: _delivering ? null : _markOrderPickedUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  // Navigate Button
                  Expanded(
                    flex: 4,
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.navigation_rounded,
                          color: Colors.green,
                          size: 18,
                        ),
                        label: Text(
                          isTargetStore ? 'TO STORE' : 'NAVIGATE',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: _openNavigation,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.green,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Mark Delivered Button
                  Expanded(
                    flex: 6,
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: _delivering
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                              ),
                        label: Text(
                          _delivering ? 'UPDATING...' : 'MARK DELIVERED',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                          ),
                        ),
                        onPressed: _delivering ? null : _markOrderDelivered,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

