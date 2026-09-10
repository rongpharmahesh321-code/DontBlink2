import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _ordersChannel =
      AndroidNotificationChannel(
    'doorstepp_orders',
    'Doorstepp Orders',
    description: 'Notifications for new and updated Doorstepp orders.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _deliveryOffersChannel =
      AndroidNotificationChannel(
    'delivery_offers',
    'Delivery Offers',
    description: 'Notifications for nearby delivery offers for riders.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedAppSubscription;

  // ==========================================================
  // INITIALIZE
  // ==========================================================

  static Future<void> initialize() async {
    try {
      // --------------------------------------------------------
      // iOS / GENERAL PERMISSION
      // --------------------------------------------------------

      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // --------------------------------------------------------
      // ANDROID LOCAL NOTIFICATIONS
      // --------------------------------------------------------

      if (!kIsWeb) {
        const androidSettings = AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        );

        const initializationSettings = InitializationSettings(
          android: androidSettings,
        );

        await _localNotifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );

        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        await androidPlugin?.createNotificationChannel(_ordersChannel);
        await androidPlugin?.createNotificationChannel(_deliveryOffersChannel);

        await androidPlugin?.requestNotificationsPermission();
      }

      // --------------------------------------------------------
      // FCM TOKEN
      // --------------------------------------------------------

      await _saveToken();

      // --------------------------------------------------------
      // TOKEN REFRESH
      // --------------------------------------------------------

      await _tokenSubscription?.cancel();

      _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
        await _saveToken(token);
      });

      // --------------------------------------------------------
      // FOREGROUND NOTIFICATIONS
      // --------------------------------------------------------

      await _foregroundSubscription?.cancel();

      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );

      // --------------------------------------------------------
      // NOTIFICATION TAP
      // --------------------------------------------------------

      await _openedAppSubscription?.cancel();

      _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleNotificationOpened,
      );

      // --------------------------------------------------------
      // APP OPENED FROM TERMINATED STATE
      // --------------------------------------------------------

      final initialMessage = await _messaging.getInitialMessage();

      if (initialMessage != null) {
        _handleNotificationOpened(initialMessage);
      }

      debugPrint('Doorstepp NotificationService initialized.');
    } catch (e, stackTrace) {
      debugPrint('NotificationService initialization error: $e');
      debugPrint('$stackTrace');
    }
  }

  // ==========================================================
  // SAVE FCM TOKEN
  // ==========================================================

  static Future<void> _saveToken([String? providedToken]) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        debugPrint('FCM token not saved because no user is signed in yet.');
        return;
      }

      final token = providedToken ?? await _messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        debugPrint('FCM token is empty.');
        return;
      }

      final cleanToken = token.trim();
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': cleanToken,
        'fcmTokens': FieldValue.arrayUnion([cleanToken]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('FCM token saved for user ${user.uid}.');
    } catch (e) {
      debugPrint('Could not save FCM token: $e');
    }
  }

  // ==========================================================
  // REFRESH TOKEN AFTER LOGIN
  // ==========================================================

  static Future<void> refreshUserToken() async {
    await _saveToken();
  }

  // ==========================================================
  // FOREGROUND MESSAGE
  // ==========================================================

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint(
      'Foreground notification received: '
      '${message.messageId}',
    );

    final notification = message.notification;

    if (notification == null || kIsWeb) {
      return;
    }

    final isDeliveryOffer = message.data['type'] == 'delivery_offer';
    final targetChannel =
        isDeliveryOffer ? _deliveryOffersChannel : _ordersChannel;

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Doorstepp',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          targetChannel.id,
          targetChannel.name,
          channelDescription: targetChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
      ),
      payload: message.data.isEmpty ? null : message.data.toString(),
    );
  }

  // ==========================================================
  // NOTIFICATION OPENED
  // ==========================================================

  static void _handleNotificationOpened(RemoteMessage message) {
    debugPrint('Notification opened: ${message.data}');

    // We will connect this later to:
    //
    // Admin -> Admin Orders
    // Rider -> Rider Orders
    // Customer -> Order Tracking
    //
    // For now we simply receive the notification safely.
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
  }

  // ==========================================================
  // CLEANUP
  // ==========================================================

  static Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();

    _tokenSubscription = null;
    _foregroundSubscription = null;
    _openedAppSubscription = null;
  }
}
