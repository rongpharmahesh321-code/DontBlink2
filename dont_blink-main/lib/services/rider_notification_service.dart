import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// ============================================================
/// RIDER NOTIFICATION SERVICE
/// ============================================================
///
/// Handles:
/// 1. FCM permission.
/// 2. FCM token registration.
/// 3. Saving the token to users/{riderUid}.
/// 4. Token refresh.
/// 5. Foreground delivery-offer messages.
/// 6. Notification tap handling.
///
/// The Cloud Function sends:
///
///   type: delivery_offer
///   orderId: <order id>
///
/// The service intentionally does NOT accept an order.
/// Accepting must still happen through the Firestore transaction
/// in rider_orders_screen.dart so only one rider can win.
/// ============================================================

@pragma('vm:entry-point')
Future<void> riderFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  // Do not perform Firestore writes here.
  //
  // For messages containing a normal `notification` payload,
  // Firebase/Android will display the notification automatically
  // while the app is in the background.
  //
  // Keep this handler lightweight.
  if (message.data['type'] == 'delivery_offer') {
    // Intentionally empty.
    //
    // The notification itself is displayed by FCM.
  }
}

class RiderNotificationService {
  RiderNotificationService._();

  static final RiderNotificationService instance = RiderNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  final StreamController<RemoteMessage> _deliveryOfferController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get deliveryOffers => _deliveryOfferController.stream;

  bool _initialized = false;

  // ==========================================================
  // INITIALIZE
  // ==========================================================

  Future<void> initialize() async {
    if (_initialized) return;

    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    // Android 13+ and iOS require notification permission.
    await _requestPermission();

    // Register the background handler exactly once.
    FirebaseMessaging.onBackgroundMessage(
      riderFirebaseMessagingBackgroundHandler,
    );

    // Get the current FCM token.
    await _saveCurrentToken();

    // Keep Firestore synchronized if Firebase rotates the token.
    await _tokenSubscription?.cancel();

    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (token) async {
        await _saveToken(token);
      },
      onError: (error) {
        // Token refresh errors should not crash the rider screen.
      },
    );

    // Foreground messages are delivered here.
    await _foregroundSubscription?.cancel();

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] == 'delivery_offer') {
        if (!_deliveryOfferController.isClosed) {
          _deliveryOfferController.add(message);
        }
      }
    });

    // User tapped a notification while the app was in background.
    await _openedSubscription?.cancel();

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      if (message.data['type'] == 'delivery_offer') {
        if (!_deliveryOfferController.isClosed) {
          _deliveryOfferController.add(message);
        }
      }
    });

    // User tapped a notification that launched the app from
    // a completely terminated state.
    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null &&
        initialMessage.data['type'] == 'delivery_offer') {
      // Give the app a moment to finish building before the screen
      // consumes the event.
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (!_deliveryOfferController.isClosed) {
          _deliveryOfferController.add(initialMessage);
        }
      });
    }

    _initialized = true;
  }

  // ==========================================================
  // PERMISSION
  // ==========================================================

  Future<NotificationSettings> _requestPermission() async {
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
  }

  // ==========================================================
  // TOKEN
  // ==========================================================

  Future<void> _saveCurrentToken() async {
    try {
      final token = await _messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        return;
      }

      await _saveToken(token);
    } catch (_) {
      // A notification failure must not crash the rider UI.
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;

    if (user == null || token.trim().isEmpty) {
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token.trim(),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Firestore rules/network problems are handled silently here.
      //
      // The rider screen can still operate normally.
    }
  }

  // ==========================================================
  // DELIVERY OFFER DATA
  // ==========================================================

  String? orderIdFrom(RemoteMessage message) {
    final value = message.data['orderId'];

    if (value == null) {
      return null;
    }

    final id = value.toString().trim();

    return id.isEmpty ? null : id;
  }

  String titleFrom(RemoteMessage message) {
    return message.notification?.title ?? '🚴 Delivery Available';
  }

  String bodyFrom(RemoteMessage message) {
    return message.notification?.body ??
        'A new delivery is available near you.';
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();

    _tokenSubscription = null;
    _foregroundSubscription = null;
    _openedSubscription = null;

    _initialized = false;
  }

  Future<void> close() async {
    await dispose();

    if (!_deliveryOfferController.isClosed) {
      await _deliveryOfferController.close();
    }
  }
}
