import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/main_screen.dart';
import '../screens/signin_screen.dart';
import '../screens/rider_home_screen.dart';
import '../screens/admin_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _role;
  User? _lastUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ======================================================
        // WAITING FOR FIREBASE AUTH
        // ======================================================

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xffF7F8FA),
            body: SizedBox.expand(),
          );
        }

        // ======================================================
        // USER
        // ======================================================

        final user = snapshot.data;

        // ======================================================
        // LOGGED OUT
        // ======================================================

        if (user == null) {
          _lastUser = null;
          _role = null;

          return const SignInScreen();
        }

        // ======================================================
        // NEW LOGIN
        // ======================================================

        if (_lastUser?.uid != user.uid) {
          _lastUser = user;

          _loadRole(user);
        }

        // ======================================================
        // CUSTOMER DEFAULT
        //
        // This is intentionally MainScreen.
        //
        // Therefore normal customers go directly to the
        // customer app instead of seeing a loading screen.
        // ======================================================

        if (_role == null) {
          return const MainScreen();
        }

        // ======================================================
        // RIDER
        // ======================================================

        if (_role == 'rider') {
          return const RiderHomeScreen();
        }

        // ======================================================
        // ADMIN
        // ======================================================

        if (_role == 'admin') {
          return const AdminScreen();
        }

        // ======================================================
        // CUSTOMER
        // ======================================================

        return const MainScreen();
      },
    );
  }

  // ==========================================================
  // LOAD ROLE
  // ==========================================================

  Future<void> _loadRole(User user) async {
    try {
      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) {
        return;
      }

      final data = document.data();

      final role = data?['role']?.toString().trim().toLowerCase();

      setState(() {
        _role = role ?? 'customer';
      });
    } catch (e) {
      debugPrint('AuthGate role error: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _role = 'customer';
      });
    }
  }
}
