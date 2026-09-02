import 'package:flutter/material.dart';

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({super.key});

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  // ==========================================================
  // ANIMATIONS
  // ==========================================================

  late final AnimationController _mainController;

  late final AnimationController _checkController;

  late final AnimationController _deliveryController;

  late final Animation<double> _fadeAnimation;

  late final Animation<double> _scaleAnimation;

  late final Animation<double> _checkAnimation;

  late final Animation<Offset> _slideAnimation;

  late final Animation<double> _deliveryAnimation;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    // --------------------------------------------------------
    // MAIN ANIMATION
    // --------------------------------------------------------

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOutBack),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _mainController, curve: Curves.easeOutCubic),
        );

    // --------------------------------------------------------
    // CHECKMARK
    // --------------------------------------------------------

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOutBack,
    );

    // --------------------------------------------------------
    // DELIVERY
    // --------------------------------------------------------

    _deliveryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _deliveryAnimation = CurvedAnimation(
      parent: _deliveryController,
      curve: Curves.easeOutCubic,
    );

    // --------------------------------------------------------
    // START
    // --------------------------------------------------------

    _mainController.forward();

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        _checkController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _deliveryController.forward();
      }
    });
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _mainController.dispose();
    _checkController.dispose();
    _deliveryController.dispose();

    super.dispose();
  }

  // ==========================================================
  // CONTINUE SHOPPING
  // ==========================================================

  void _continueShopping() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent accidentally returning to Checkout.
      canPop: false,

      child: Scaffold(
        backgroundColor: Colors.green,

        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,

            child: SlideTransition(
              position: _slideAnimation,

              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 30,
                ),

                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 60,
                  ),

                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      const SizedBox(height: 20),

                      // ==================================================
                      // SUCCESS ICON
                      // ==================================================
                      ScaleTransition(
                        scale: _checkAnimation,

                        child: Container(
                          width: 125,
                          height: 125,

                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),

                          child: ScaleTransition(
                            scale: _checkAnimation,

                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.green,
                              size: 82,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ==================================================
                      // SUCCESS TITLE
                      // ==================================================
                      ScaleTransition(
                        scale: _scaleAnimation,

                        child: const Text(
                          'Order Placed\nSuccessfully!',
                          textAlign: TextAlign.center,

                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            height: 1.15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // ==================================================
                      // SUBTITLE
                      // ==================================================
                      FadeTransition(
                        opacity: _fadeAnimation,

                        child: const Text(
                          'Your groceries are being packed.',
                          textAlign: TextAlign.center,

                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      ),

                      const SizedBox(height: 35),

                      // ==================================================
                      // DELIVERY CARD
                      // ==================================================
                      FadeTransition(
                        opacity: _deliveryAnimation,

                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.12),
                            end: Offset.zero,
                          ).animate(_deliveryAnimation),

                          child: Container(
                            width: double.infinity,

                            padding: const EdgeInsets.all(20),

                            decoration: BoxDecoration(
                              color: Colors.white,

                              borderRadius: BorderRadius.circular(22),

                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 15,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),

                            child: Column(
                              children: [
                                // --------------------------------
                                // DELIVERY ICON
                                // --------------------------------
                                Container(
                                  width: 65,
                                  height: 65,

                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    shape: BoxShape.circle,
                                  ),

                                  child: const Icon(
                                    Icons.delivery_dining,
                                    color: Colors.green,
                                    size: 42,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                const Text(
                                  'Estimated Delivery',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),

                                const SizedBox(height: 5),

                                // --------------------------------
                                // TIME
                                // --------------------------------
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),

                                  duration: const Duration(milliseconds: 700),

                                  curve: Curves.easeOutBack,

                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: value,
                                      child: child,
                                    );
                                  },

                                  child: const Text(
                                    '10 - 15 mins',

                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                const Text(
                                  'We\'ll notify you when your order is on the way.',
                                  textAlign: TextAlign.center,

                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 35),

                      // ==================================================
                      // ORDER STATUS
                      // ==================================================
                      FadeTransition(
                        opacity: _deliveryAnimation,

                        child: Row(
                          children: [
                            Expanded(
                              child: _statusItem(
                                icon: Icons.check_circle,
                                title: 'Confirmed',
                                active: true,
                              ),
                            ),

                            _statusLine(active: true),

                            Expanded(
                              child: _statusItem(
                                icon: Icons.inventory_2,
                                title: 'Packing',
                                active: true,
                              ),
                            ),

                            _statusLine(active: false),

                            Expanded(
                              child: _statusItem(
                                icon: Icons.delivery_dining,
                                title: 'Delivery',
                                active: false,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ==================================================
                      // CONTINUE SHOPPING
                      // ==================================================
                      FadeTransition(
                        opacity: _deliveryAnimation,

                        child: SizedBox(
                          width: double.infinity,
                          height: 56,

                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,

                              foregroundColor: Colors.green,

                              elevation: 3,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),

                            onPressed: _continueShopping,

                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,

                              children: [
                                Icon(Icons.shopping_bag),

                                SizedBox(width: 8),

                                Text(
                                  'Continue Shopping',

                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ==================================================
                      // FOOTER
                      // ==================================================
                      FadeTransition(
                        opacity: _deliveryAnimation,

                        child: const Text(
                          'Thank you for shopping with Don\'t Blink 💚',

                          textAlign: TextAlign.center,

                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),

                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // STATUS ITEM
  // ==========================================================

  Widget _statusItem({
    required IconData icon,
    required String title,
    required bool active,
  }) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),

          width: 42,
          height: 42,

          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white24,

            shape: BoxShape.circle,
          ),

          child: Icon(
            icon,

            size: 23,

            color: active ? Colors.green : Colors.white54,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          title,

          textAlign: TextAlign.center,

          style: TextStyle(
            color: active ? Colors.white : Colors.white54,

            fontSize: 11,

            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // STATUS LINE
  // ==========================================================

  Widget _statusLine({required bool active}) {
    return Expanded(
      child: Container(
        height: 2,

        margin: const EdgeInsets.only(bottom: 25),

        color: active ? Colors.white : Colors.white24,
      ),
    );
  }
}
