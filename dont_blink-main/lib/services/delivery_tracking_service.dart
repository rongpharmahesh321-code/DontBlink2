import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

/// Doorstepp live delivery GPS.
///
/// This service is intended to be started ONLY when a rider has an active
/// delivery. It writes the rider's live position to:
///
/// orders/{orderId}
///
/// Fields:
/// riderId
/// riderLatitude
/// riderLongitude
/// riderLocationUpdatedAt
///
/// On Android, AndroidSettings.foregroundNotificationConfig keeps the
/// Geolocator stream running as a foreground service when the rider
/// backgrounds/minimizes the app.
class DeliveryTrackingService {
  DeliveryTrackingService._();

  static final DeliveryTrackingService instance = DeliveryTrackingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<Position>? _positionSubscription;

  String? _trackingOrderId;

  bool get isTracking => _positionSubscription != null;

  String? get trackingOrderId => _trackingOrderId;

  // ----------------------------------------------------------
  // START
  // ----------------------------------------------------------

  Future<bool> start({required String orderId}) async {
    final user = _auth.currentUser;

    if (user == null) {
      debugPrint('Delivery GPS: rider is not logged in.');
      return false;
    }

    if (orderId.trim().isEmpty) {
      debugPrint('Delivery GPS: empty order ID.');
      return false;
    }

    final ready = await _prepareLocation();

    if (!ready) {
      return false;
    }

    try {
      // Stop an old session before starting another order.
      await stop();

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final riderName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'Delivery Partner';

      final riderPhone = user.phoneNumber?.trim() ?? '';

      // --------------------------------------------------------
      // INITIAL LOCATION
      // --------------------------------------------------------

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

      _trackingOrderId = orderId;

      // --------------------------------------------------------
      // ANDROID FOREGROUND LOCATION SERVICE
      // --------------------------------------------------------
      //
      // The persistent notification is intentional: Android requires
      // visible foreground-service behavior for continuous location
      // tracking. The rider can minimize the app while the delivery
      // continues.
      //
      // On iOS, this falls back to normal LocationSettings.
      // --------------------------------------------------------

      final locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Doorstepp delivery is active',
          notificationText:
              'Your location is being used for live delivery tracking.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );

      // --------------------------------------------------------
      // LIVE STREAM
      // --------------------------------------------------------

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) async {
              final activeOrderId = _trackingOrderId;

              if (activeOrderId == null) {
                return;
              }

              try {
                await _firestore
                    .collection('orders')
                    .doc(activeOrderId)
                    .update({
                      'riderLatitude': position.latitude,
                      'riderLongitude': position.longitude,
                      'riderLocationUpdatedAt': FieldValue.serverTimestamp(),
                    });

                debugPrint(
                  'DOORSTEPP LIVE GPS: '
                  '${position.latitude}, '
                  '${position.longitude}',
                );
              } catch (e) {
                debugPrint('Doorstepp delivery GPS Firestore error: $e');
              }
            },
            onError: (Object error) {
              debugPrint('Doorstepp delivery GPS stream error: $error');
            },
            cancelOnError: false,
          );

      debugPrint('Doorstepp delivery tracking started for $orderId');

      return true;
    } catch (e) {
      debugPrint('Doorstepp start delivery tracking error: $e');

      await stop();

      return false;
    }
  }

  // ----------------------------------------------------------
  // STOP
  // ----------------------------------------------------------

  Future<void> stop() async {
    await _positionSubscription?.cancel();

    _positionSubscription = null;
    _trackingOrderId = null;

    debugPrint('Doorstepp delivery GPS stopped.');
  }

  // ----------------------------------------------------------
  // STOP AFTER DELIVERY
  // ----------------------------------------------------------

  Future<void> stopAfterDelivered({required String orderId}) async {
    final user = _auth.currentUser;

    await stop();

    if (user == null) return;

    try {
      // Keep the last known rider location for the completed order,
      // but mark the live tracking session as finished.
      await _firestore.collection('orders').doc(orderId).update({
        'riderTrackingActive': false,
        'riderTrackingStoppedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Doorstepp stop-after-delivery Firestore error: $e');
    }
  }

  // ----------------------------------------------------------
  // LOCATION PREPARATION
  // ----------------------------------------------------------

  Future<bool> _prepareLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      debugPrint('Doorstepp GPS: location service is disabled.');
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('Doorstepp GPS: location permission denied.');
      return false;
    }

    return true;
  }
}
