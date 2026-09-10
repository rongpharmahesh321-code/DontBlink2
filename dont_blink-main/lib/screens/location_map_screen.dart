import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dont_blink/utils/emoji_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

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

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _googleConfigChannel = MethodChannel(
    'com.doorstepp.app/google_config',
  );

  String? _cachedApiKey;

  Future<String> _getGoogleWebApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }
    const envKey = String.fromEnvironment('GOOGLE_WEB_API_KEY', defaultValue: '');
    if (envKey.isNotEmpty) {
      _cachedApiKey = envKey;
      return envKey;
    }
    try {
      final key = await _googleConfigChannel.invokeMethod<String>(
        'getGoogleWebApiKey',
      );
      if (key != null && key.trim().isNotEmpty) {
        _cachedApiKey = key.trim();
        return _cachedApiKey!;
      }
    } catch (e) {
      debugPrint('Google API key error: $e');
    }
    return '';
  }

  // ==========================================================
  // GOOGLE MAP
  // ==========================================================

  GoogleMapController? _mapController;
  bool _mapReady = false;

  // ==========================================================
  // LOCATIONS
  // ==========================================================

  late final LatLng customerLocation;
  LatLng? storeLocation; // loaded from Firestore order data

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
  // EMOJI MARKERS
  // ==========================================================

  BitmapDescriptor? _riderIcon;    // 🛵
  BitmapDescriptor? _customerIcon; // 🏠
  BitmapDescriptor? _storeIcon;    // 🏪

  Future<void> _loadEmojiMarkers() async {
    final rider    = await emojiMarker('🛵', size: 72);
    final customer = await emojiMarker('🏠', size: 72);
    final store    = await emojiMarker('🏪', size: 72);
    if (!mounted) return;
    setState(() {
      _riderIcon    = rider;
      _customerIcon = customer;
      _storeIcon    = store;
    });
  }

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

    // storeLocation is read from the Firestore order document in _processOrderData

    _riderAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _riderAnimationController.addListener(() {
      if (!mounted) return;

      setState(() {});

      final animated = animatedRiderLocation;

      if (_mapReady && animated != null) {
        try {
          _mapController?.animateCamera(CameraUpdate.newLatLng(animated));
        } catch (_) {}
      }
    });

    _loadEmojiMarkers();
  }

  @override
  void dispose() {
    _riderAnimationController.dispose();
    super.dispose();
  }

  // ==========================================================
  // STATUS
  // ==========================================================

  String _normalizedStatus(String status) {
    return status
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }


  double _straightLineDistanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;

    final dLat = _degreesToRadians(b.latitude - a.latitude);
    final dLon = _degreesToRadians(b.longitude - a.longitude);

    final lat1 = _degreesToRadians(a.latitude);
    final lat2 = _degreesToRadians(b.latitude);

    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  double _degreesToRadians(double value) => value * math.pi / 180;

  bool get _riderIsNearby {
    if (riderLocation == null) return false;

    return _straightLineDistanceMeters(riderLocation!, customerLocation) <= 500;
  }

  bool get _riderArrived {
    if (riderLocation == null) return false;

    return _straightLineDistanceMeters(riderLocation!, customerLocation) <= 50;
  }

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
        if (_riderArrived) return 'Rider has arrived';
        if (_riderIsNearby) return 'Arriving soon';
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
        if (_riderIsNearby) return 'Your rider is nearby.';
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

  int _etaMinutes() {
    if (routeDurationSeconds <= 0) return 1;
    return math.max(1, (routeDurationSeconds / 60).ceil());
  }

  String _formatDistance() {
    if (routeDistanceMeters <= 0) return '--';

    if (routeDistanceMeters >= 1000) {
      return '${(routeDistanceMeters / 1000).toStringAsFixed(1)} km';
    }

    return '${routeDistanceMeters.toStringAsFixed(0)} m';
  }

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

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '₹${value.toInt()}';
    }

    return '₹${value.toStringAsFixed(2)}';
  }

  // ==========================================================
  // FIRESTORE
  // ==========================================================

  void _processOrderData(Map<String, dynamic> data) {
    orderStatus = data['status']?.toString() ?? 'Out for Delivery';
    riderName = data['riderName']?.toString() ?? 'Your Delivery Partner';
    riderPhone = data['riderPhone']?.toString() ?? '';
    paymentMethod = data['paymentMethod']?.toString() ?? '';

    final totalValue = data['grandTotal'];

    if (totalValue is num) {
      grandTotal = totalValue.toDouble();
    } else {
      grandTotal = double.tryParse(totalValue?.toString() ?? '') ?? 0;
    }

    // -------------------------------------------------------
    // Read accurate store location from the order document
    // -------------------------------------------------------
    final storeLat = data['storeLatitude'];
    final storeLng = data['storeLongitude'];
    if (storeLat is num && storeLng is num &&
        (storeLat != 0 || storeLng != 0)) {
      storeLocation = LatLng(storeLat.toDouble(), storeLng.toDouble());
    }

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

        if (previousRiderLocation == null) {
          _riderAnimationController.value = 1;
        } else {
          _riderAnimationController.forward(from: 0);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _requestGoogleRoute(newLocation);
        });
      }
    }
  }

  LatLng? get animatedRiderLocation {
    if (riderLocation == null) return null;
    if (previousRiderLocation == null) return riderLocation;

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
  // GOOGLE ROUTES API
  // ==========================================================

  Future<void> _requestGoogleRoute(LatLng rider) async {
    final apiKey = await _getGoogleWebApiKey();
    if (apiKey.trim().isEmpty) {
      debugPrint(
        'GOOGLE_WEB_API_KEY is not configured.',
      );
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
      final uri = Uri.parse(
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
              'latitude': customerLocation.latitude,
              'longitude': customerLocation.longitude,
            },
          },
        },
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE',
        'computeAlternativeRoutes': false,
        'polylineEncoding': 'GEO_JSON_LINESTRING',
        'languageCode': 'en-US',
        'units': 'METRIC',
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask':
              'routes.distanceMeters,'
              'routes.duration,'
              'routes.polyline.geoJsonLinestring',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Google Routes API returned ${response.statusCode}: '
          '${response.body}',
        );
      }

      final Map<String, dynamic> result = jsonDecode(response.body);

      final routes = result['routes'];

      if (routes is! List || routes.isEmpty) {
        throw Exception('Google could not find a road route.');
      }

      final route = routes.first as Map<String, dynamic>;

      final points = <LatLng>[];

      final geoJson = route['polyline']?['geoJsonLinestring'];

      final coordinates = geoJson?['coordinates'];

      if (coordinates is List) {
        for (final coordinate in coordinates) {
          if (coordinate is List && coordinate.length >= 2) {
            final longitude = (coordinate[0] as num).toDouble();
            final latitude = (coordinate[1] as num).toDouble();

            points.add(LatLng(latitude, longitude));
          }
        }
      }

      final distance = (route['distanceMeters'] as num?)?.toDouble() ?? 0;

      final durationText = route['duration']?.toString() ?? '0s';

      final durationSeconds = _parseGoogleDurationSeconds(durationText);

      if (!mounted) return;

      setState(() {
        routePoints = points;
        routeDistanceMeters = distance;
        routeDurationSeconds = durationSeconds;
        loadingRoute = false;
      });
    } catch (e) {
      debugPrint('Google customer route error: $e');

      if (!mounted) return;

      setState(() {
        loadingRoute = false;
      });
    }
  }

  double _parseGoogleDurationSeconds(String value) {
    final match = RegExp(r'^([0-9]+(?:\.[0-9]+)?)s$').firstMatch(value.trim());

    if (match == null) return 0;

    return double.tryParse(match.group(1)!) ?? 0;
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
  // CAMERA
  // ==========================================================

  void _centerOnRider() {
    if (!_mapReady || riderLocation == null) return;

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: riderLocation!, zoom: 16),
      ),
    );
  }

  void _centerOnCustomer() {
    if (!_mapReady) return;

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: customerLocation, zoom: 16),
      ),
    );
  }

  // ==========================================================
  // ADDRESS-ONLY MAP
  // ==========================================================

  Widget _buildAddressMap() {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('customer'),
        position: customerLocation,
        infoWindow: const InfoWindow(title: 'Delivery Address'),
      ),
      if (storeLocation != null)
        Marker(
          markerId: const MarkerId('store'),
          position: storeLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Doorstepp Store'),
        ),
    };

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Delivery Address',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: customerLocation,
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            markers: markers,
            onMapCreated: (controller) {
              _mapController = controller;
              _mapReady = true;
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_on, color: Colors.red),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This is your saved delivery location.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
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
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (widget.orderId == null) {
      return _buildAddressMap();
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
              child: CircularProgressIndicator(color: AppColors.primary),
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

          final markers = <Marker>{
            if (storeLocation != null)
              Marker(
                markerId: const MarkerId('store'),
                position: storeLocation!,
                icon: _storeIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                infoWindow: const InfoWindow(title: 'Doorstepp Store'),
              ),
            // Customer = 🏠 emoji
            Marker(
              markerId: const MarkerId('customer'),
              position: customerLocation,
              icon: _customerIcon ?? BitmapDescriptor.defaultMarker,
              infoWindow: const InfoWindow(title: 'Your Delivery Address'),
            ),
            // Rider = animated 🛵 emoji – moves smoothly towards customer
            if (rider != null)
              Marker(
                markerId: const MarkerId('rider'),
                position: rider,
                icon: _riderIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
                    ),
                infoWindow: InfoWindow(title: riderName),
                flat: true,
                anchor: const Offset(0.5, 0.5),
              ),
          };


          final polylines = <Polyline>{
            if (routePoints.length >= 2)
              Polyline(
                polylineId: const PolylineId('delivery_route'),
                points: routePoints,
                color: AppColors.primary,
                width: 6,
                jointType: JointType.round,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
          };

          return Stack(
            children: [
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: rider ?? customerLocation,
                    zoom: 14,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  trafficEnabled: true,
                  markers: markers,
                  polylines: polylines,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _mapReady = true;
                  },
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
                      color: AppColors.primary,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(22),
                        bottomRight: Radius.circular(22),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
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

              if (rider != null)
                Positioned(top: 125, right: 15, child: _liveBadge()),

              // ==================================================
              // MAP CONTROLS
              // ==================================================
              Positioned(
                right: 15,
                bottom: 365,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'customer_center_rider',
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      onPressed: rider == null ? null : _centerOnRider,
                      child: const Icon(Icons.delivery_dining),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'customer_center_address',
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      onPressed: _centerOnCustomer,
                      child: const Icon(Icons.home),
                    ),
                  ],
                ),
              ),

              Positioned(
                left: 15,
                bottom: 365,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.traffic, color: AppColors.primary, size: 16),
                      SizedBox(width: 5),
                      Text(
                        'LIVE TRAFFIC',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

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
  // RIDER BADGE
  // ==========================================================


  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          Icon(Icons.circle, color: AppColors.primary, size: 8),
          SizedBox(width: 5),
          Text(
            'LIVE',
            style: TextStyle(
              color: AppColors.primary,
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
            Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 14),

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

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.tintGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
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
                        child: const Icon(Icons.phone, color: AppColors.primary),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

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
                      color: AppColors.tintGreenBorder,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.payment, color: AppColors.primary),
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

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tintGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _riderArrived ? Icons.home : Icons.delivery_dining,
                    color: AppColors.primary,
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
                        color: AppColors.primary,
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
          Icon(icon, color: AppColors.primary, size: 22),
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
        backgroundColor: AppColors.primary,
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
