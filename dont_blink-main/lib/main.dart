import 'package:dont_blink/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'providers/cart_provider.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep a practical decoded-image cache for product grids.
  // This improves repeat opens without precaching the whole catalogue.
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

  // ==========================================================
  // FIREBASE
  // ==========================================================

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ==========================================================
  // PUSH NOTIFICATIONS
  // ==========================================================

  await NotificationService.initialize();

  // ==========================================================
  // RUN APP
  // ==========================================================

  runApp(
    ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: const DontBlinkApp(),
    ),
  );
}

class DontBlinkApp extends StatelessWidget {
  const DontBlinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'doorstepp',
      theme: AppTheme.lightTheme,

      // ========================================================
      // SPLASH SCREEN
      // ========================================================
      home: const SplashScreen(),
    );
  }
}
