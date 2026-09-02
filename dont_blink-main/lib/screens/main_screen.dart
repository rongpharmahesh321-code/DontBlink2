import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'wishlist_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // ==========================================================
  // CURRENT TAB
  // ==========================================================

  int currentIndex = 0;

  // ==========================================================
  // SCREENS
  // ==========================================================

  late final List<Widget> screens;

  @override
  void initState() {
    super.initState();

    screens = const [
      HomeScreen(),
      WishlistScreen(),
      CartScreen(),
      ProfileScreen(),
    ];
  }

  // ==========================================================
  // TAB CHANGE
  // ==========================================================

  void _onTabChanged(int index) {
    if (currentIndex == index) {
      return;
    }

    setState(() {
      currentIndex = index;
    });
  }

  // ==========================================================
  // ANDROID BACK BUTTON
  // ==========================================================
  //
  // If the user is on Wishlist / Cart / Profile,
  // Android Back goes to Home instead of closing the app.
  //
  // If the user is already on Home, normal Android Back
  // behavior is allowed.
  //
  // IMPORTANT:
  // This does NOT interfere with Orders/Admin screens.
  // Those are separate routes and Android Back will first
  // pop those routes normally.
  // ==========================================================

  Future<bool> _handleBack() async {
    if (currentIndex != 0) {
      setState(() {
        currentIndex = 0;
      });

      return false;
    }

    return true;
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: currentIndex == 0,

      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        if (currentIndex != 0) {
          setState(() {
            currentIndex = 0;
          });
        }
      },

      child: Scaffold(
        // ======================================================
        // BODY
        // ======================================================
        body: IndexedStack(index: currentIndex, children: screens),

        // ======================================================
        // BOTTOM NAVIGATION
        // ======================================================
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,

          type: BottomNavigationBarType.fixed,

          selectedItemColor: Colors.green,

          unselectedItemColor: Colors.grey,

          onTap: _onTabChanged,

          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),

            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Wishlist',
            ),

            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: 'Cart',
            ),

            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
