import 'package:dont_blink/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'providers/cart_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      title: "doorstepp",
      theme: AppTheme.lightTheme,

      // ========================================================
      // SPLASH SCREEN
      // ========================================================
      home: const SplashScreen(),
    );
  }
}
