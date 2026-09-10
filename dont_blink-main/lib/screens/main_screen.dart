import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'wishlist_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================
  // CURRENT TAB
  // ==========================================================

  int currentIndex = 0;

  // ==========================================================
  // ALL SCREENS ARE CREATED ONCE
  // ==========================================================
  //
  // IMPORTANT:
  // PageView was NOT enough here because pages far away from
  // the current page can be disposed/rebuilt.
  //
  // IndexedStack keeps ALL four screens mounted.
  //
  // Therefore:
  //
  // Home -> Profile -> Home
  //
  // does NOT recreate HomeScreen.
  //
  // The same HomeScreen State stays alive.
  // ==========================================================

  late final List<Widget> screens;

  // ==========================================================
  // BUBBLE TAP ANIMATION
  // ==========================================================

  late final AnimationController _tapAnimationController;

  @override
  void initState() {
    super.initState();

    _tapAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    screens = const [
      HomeScreen(),
      WishlistScreen(),
      OrdersScreen(),
      ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    _tapAnimationController.dispose();
    super.dispose();
  }

  // ==========================================================
  // TAB CHANGE
  // ==========================================================

  void _onTabChanged(int index) {
    if (index == currentIndex) {
      _tapAnimationController.forward(from: 0);
      return;
    }

    _tapAnimationController.forward(from: 0);

    setState(() {
      currentIndex = index;
    });
  }

  // ==========================================================
  // GO HOME
  // ==========================================================

  void _goHome() {
    if (currentIndex == 0) {
      return;
    }

    _tapAnimationController.forward(from: 0);

    setState(() {
      currentIndex = 0;
    });
  }

  // ==========================================================
  // NAVIGATION ITEM
  // ==========================================================

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool selected = currentIndex == index;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: () => _onTabChanged(index),
            radius: 34,
            containedInkWell: true,
            highlightShape: BoxShape.circle,
            splashColor: AppColors.primary.withValues(alpha: 0.12),
            highlightColor: AppColors.primary.withValues(alpha: 0.06),
            child: SizedBox(
              height: 68,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _tapAnimationController,
                    builder: (context, child) {
                      final bool isTapped =
                          _tapAnimationController.isAnimating && selected;

                      final double progress = Curves.easeOut.transform(
                        _tapAnimationController.value,
                      );

                      final double scale = isTapped
                          ? 0.92 + (progress * 0.16)
                          : 1.0;

                      return Transform.scale(
                        scale: scale,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isTapped)
                              Opacity(
                                opacity: (1.0 - progress) * 0.35,
                                child: Transform.scale(
                                  scale: 1.0 + (progress * 0.65),
                                  child: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutBack,
                              width: selected ? 46 : 40,
                              height: selected ? 46 : 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? AppColors.primary.withValues(alpha: 0.13)
                                    : Colors.transparent,
                              ),
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  transitionBuilder: (child, animation) {
                                    return ScaleTransition(
                                      scale: animation,
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    selected ? activeIcon : icon,
                                    key: ValueKey<bool>(selected),
                                    size: selected ? 25 : 23,
                                    color: selected
                                        ? AppColors.primary
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      fontSize: selected ? 10.5 : 10,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? AppColors.primary : Colors.grey.shade600,
                    ),
                    child: Text(label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // BOTTOM NAVIGATION
  // ==========================================================

  Widget _buildBottomNavigation() {
    return SafeArea(
      top: false,
      child: Container(
        height: 78,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildNavItem(
              index: 0,
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
            ),
            _buildNavItem(
              index: 1,
              icon: Icons.favorite_border_rounded,
              activeIcon: Icons.favorite_rounded,
              label: 'Wishlist',
            ),
            _buildNavItem(
              index: 2,
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: 'Orders',
            ),
            _buildNavItem(
              index: 3,
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
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
          _goHome();
        }
      },
      child: Scaffold(
        // ======================================================
        // IMPORTANT FIX
        // ======================================================
        //
        // IndexedStack keeps every screen alive.
        //
        // Only the selected screen is visible.
        //
        // There is NO PageView movement, so:
        //
        // Home -> Profile
        //
        // never visually passes through Wishlist or Cart.
        //
        // And Home is NOT disposed while another tab is open.
        // ======================================================
        body: IndexedStack(index: currentIndex, children: screens),

        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }
}
