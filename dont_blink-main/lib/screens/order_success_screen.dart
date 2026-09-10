import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'orders_screen.dart';

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({super.key});

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _checkController;
  late final AnimationController _contentController;

  late final Animation<double> _checkScale;
  late final Animation<double> _checkOpacity;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );

    _checkOpacity = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOut,
    );

    _contentOpacity = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    );

    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentController,
            curve: Curves.easeOutCubic,
          ),
        );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await _checkController.forward();

    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 120));

    if (!mounted) return;

    await _contentController.forward();
  }

  @override
  void dispose() {
    _checkController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ==========================================================
  // SUCCESS ICON
  // ==========================================================

  Widget _buildSuccessIcon() {
    return AnimatedBuilder(
      animation: _checkController,
      builder: (context, child) {
        return Opacity(
          opacity: _checkOpacity.value,
          child: Transform.scale(scale: _checkScale.value, child: child),
        );
      },
      child: Container(
        width: 122,
        height: 122,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.18),
              blurRadius: 30,
              spreadRadius: 7,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(9),
          decoration: const BoxDecoration(
            color: AppColors.tintGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 68),
        ),
      ),
    );
  }

  // ==========================================================
  // CONFIRMATION CARD
  // ==========================================================

  Widget _buildConfirmationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _infoIcon(Icons.verified_rounded),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order confirmed',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'We have received your order.',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _MiniStatus(
                  icon: Icons.receipt_long_outlined,
                  title: 'Order placed',
                  subtitle: 'Confirmed',
                ),
              ),
              _StatusLine(),
              Expanded(
                child: _MiniStatus(
                  icon: Icons.inventory_2_outlined,
                  title: 'Preparing',
                  subtitle: 'Coming next',
                ),
              ),
              _StatusLine(),
              Expanded(
                child: _MiniStatus(
                  icon: Icons.delivery_dining_outlined,
                  title: 'Delivery',
                  subtitle: 'On the way',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.tintGreen,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.primary, size: 21),
    );
  }

  // ==========================================================
  // DELIVERY NOTE
  // ==========================================================

  Widget _buildDeliveryNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.tintGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.tintGreenBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bolt_rounded, color: AppColors.primary, size: 23),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We are getting it ready',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'You can track your order from My Orders as its status changes.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    height: 1.4,
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
  // ACTIONS
  // ==========================================================

  void _viewOrders() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OrdersScreen()),
      (route) => route.isFirst,
    );
  }

  void _continueShopping() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _viewOrders();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // ------------------------------------------------
              // TOP BRAND BAR
              // ------------------------------------------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(25),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 9),
                    Text(
                      'doorstepp',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 25),
                  child: Column(
                    children: [
                      // ------------------------------------------------
                      // CHECK
                      // ------------------------------------------------
                      _buildSuccessIcon(),

                      const SizedBox(height: 23),

                      FadeTransition(
                        opacity: _contentOpacity,
                        child: SlideTransition(
                          position: _contentSlide,
                          child: Column(
                            children: [
                              const Text(
                                'Order placed!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 29,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),

                              const SizedBox(height: 7),

                              Text(
                                'Thank you for shopping with doorstepp.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),

                              const SizedBox(height: 24),

                              _buildConfirmationCard(),

                              const SizedBox(height: 12),

                              _buildDeliveryNote(),

                              const SizedBox(height: 24),

                              // ------------------------------------------------
                              // VIEW ORDERS
                              // ------------------------------------------------
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton.icon(
                                  onPressed: _viewOrders,
                                  icon: const Icon(Icons.receipt_long_outlined),
                                  label: const Text(
                                    'VIEW MY ORDERS',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 11),

                              // ------------------------------------------------
                              // CONTINUE SHOPPING
                              // ------------------------------------------------
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: _continueShopping,
                                  icon: const Icon(Icons.shopping_bag_outlined),
                                  label: const Text(
                                    'CONTINUE SHOPPING',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.primary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 22),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.verified_user_outlined,
                                    color: Colors.grey.shade500,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Your order is securely recorded',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MINI STATUS
// ============================================================

class _MiniStatus extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MiniStatus({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(height: 5),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 8),
        ),
      ],
    );
  }
}

// ============================================================
// STATUS CONNECTOR
// ============================================================

class _StatusLine extends StatelessWidget {
  const _StatusLine();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
        color: AppColors.tintGreenBorder,
      ),
    );
  }
}
