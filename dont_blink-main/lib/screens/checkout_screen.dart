import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/address.dart';
import '../models/cart.dart';

import '../services/address_service.dart';
import '../services/order_service.dart';
import '../services/weather_service.dart';
import '../services/cashfree_service.dart';
import '../services/auth_service.dart';

import '../widgets/address_card.dart';
import '../widgets/delivery_badge.dart';
import '../widgets/info_card.dart';
import '../widgets/payment_card.dart';
import '../widgets/price_row.dart';
import '../widgets/primary_button.dart';

import '../providers/cart_provider.dart';

import 'add_address_screen.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================
  // PAYMENT
  // ==========================================================

  String paymentMethod = 'Cash on Delivery';

  // ==========================================================
  // SERVICES
  // ==========================================================

  final OrderService orderService = OrderService();

  final AddressService addressService = AddressService();

  final WeatherService weatherService = WeatherService();

  final CashfreeService cashfreeService = CashfreeService();

  final AuthService authService = AuthService();

  // ==========================================================
  // FIREBASE
  // ==========================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==========================================================
  // ADDRESS STREAM
  // ==========================================================

  late final Stream<List<Address>> _addressesStream;

  // ==========================================================
  // ADDRESS
  // ==========================================================

  Address? selectedAddress;

  // ==========================================================
  // WEATHER
  // ==========================================================

  WeatherData? weatherData;

  bool weatherLoading = true;

  // ==========================================================
  // ORDER
  // ==========================================================

  bool placingOrder = false;

  // ==========================================================
  // PHONE VERIFICATION
  // ==========================================================

  final TextEditingController _checkoutPhoneController =
      TextEditingController();

  final TextEditingController _checkoutOtpController = TextEditingController();

  String? _checkoutVerificationId;

  int? _checkoutResendToken;

  bool _phoneVerificationLoading = false;

  // ==========================================================
  // ANIMATION
  // ==========================================================

  late final AnimationController _animationController;

  late final Animation<double> _fadeAnimation;

  late final Animation<Offset> _slideAnimation;

  // ==========================================================
  // INIT STATE
  // ==========================================================

  @override
  void initState() {
    super.initState();

    // --------------------------------------------------------
    // ADDRESS STREAM
    // --------------------------------------------------------

    _addressesStream = addressService.getAddresses();

    // --------------------------------------------------------
    // ANIMATION
    // --------------------------------------------------------

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    // --------------------------------------------------------
    // WEATHER
    // --------------------------------------------------------

    _loadWeather();
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _animationController.dispose();

    _checkoutPhoneController.dispose();

    _checkoutOtpController.dispose();

    super.dispose();
  }

  // ==========================================================
  // WEATHER
  // ==========================================================

  Future<void> _loadWeather() async {
    try {
      final weather = await weatherService.getCurrentWeather();

      if (!mounted) {
        return;
      }

      setState(() {
        weatherData = weather;
        weatherLoading = false;
      });
    } catch (e) {
      debugPrint('Checkout weather error: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        weatherLoading = false;
      });
    }
  }

  // ==========================================================
  // PRICE PARSER
  // ==========================================================

  double _parsePrice(String price) {
    final cleaned = price.replaceAll(RegExp(r'[^0-9.]'), '').trim();

    return double.tryParse(cleaned) ?? 0;
  }

  // ==========================================================
  // FORMAT PRICE
  // ==========================================================

  String _formatPrice(double price) {
    if (price % 1 == 0) {
      return '₹${price.toInt()}';
    }

    return '₹${price.toStringAsFixed(2)}';
  }

  // ==========================================================
  // SUBTOTAL
  // ==========================================================

  double _calculateSubtotal() {
    double subtotal = 0;

    for (final item in Cart.items) {
      final price = _parsePrice(item.product.price);

      subtotal += price * item.quantity;
    }

    return subtotal;
  }

  // ==========================================================
  // DELIVERY FEE
  // ==========================================================

  double _getDeliveryFee() {
    if (weatherData != null) {
      return weatherData!.deliveryFee;
    }

    return 25;
  }

  // ==========================================================
  // DEFAULT ADDRESS
  // ==========================================================

  void _selectDefaultAddress(List<Address> addresses) {
    if (addresses.isEmpty) {
      selectedAddress = null;
      return;
    }

    // --------------------------------------------------------
    // KEEP CURRENT SELECTION
    // --------------------------------------------------------

    if (selectedAddress != null) {
      final exists = addresses.any(
        (address) => address.id == selectedAddress!.id,
      );

      if (exists) {
        return;
      }
    }

    // --------------------------------------------------------
    // DEFAULT ADDRESS
    // --------------------------------------------------------

    final defaults = addresses.where((address) => address.isDefault).toList();

    if (defaults.isNotEmpty) {
      selectedAddress = defaults.first;
    } else {
      selectedAddress = addresses.first;
    }
  }

  // ==========================================================
  // ADD ADDRESS
  // ==========================================================

  Future<void> _addAddress() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAddressScreen()),
    );

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // ==========================================================
  // ADDRESS SELECTOR
  // ==========================================================

  void _showAddressSelector(List<Address> addresses) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            height: MediaQuery.of(sheetContext).size.height * 0.70,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),

                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.green),

                      const SizedBox(width: 8),

                      const Expanded(
                        child: Text(
                          'Select Address',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: addresses.length,
                    itemBuilder: (context, index) {
                      final address = addresses[index];

                      final isSelected = selectedAddress?.id == address.id;

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 250 + (index * 70)),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 15 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Card(
                          elevation: isSelected ? 3 : 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.green
                                  : Colors.transparent,
                              width: isSelected ? 1.5 : 0,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),

                            leading: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                key: ValueKey(isSelected),
                                color: Colors.green,
                                size: 28,
                              ),
                            ),

                            title: Text(
                              address.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),

                                Text(
                                  '${address.house}, '
                                  '${address.area}, '
                                  '${address.city}, '
                                  '${address.state} - '
                                  '${address.pincode}',
                                ),

                                const SizedBox(height: 7),

                                if (address.latitude != null &&
                                    address.longitude != null)
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 15,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Location available',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber,
                                        color: Colors.orange,
                                        size: 15,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Location not captured',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                            onTap: () {
                              setState(() {
                                selectedAddress = address;
                              });

                              Navigator.pop(sheetContext);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // GET CURRENT USER PHONE
  // ==========================================================

  Future<String?> _getCurrentUserPhone() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final authPhone = user.phoneNumber?.trim() ?? '';

    if (authPhone.isNotEmpty) {
      return authPhone;
    }

    return await authService.getSavedPhoneNumber();
  }

  // ==========================================================
  // CHECKOUT PHONE
  // ==========================================================

  Future<bool> _ensurePhoneNumber() async {
    final phone = await _getCurrentUserPhone();

    // --------------------------------------------------------
    // PHONE ALREADY EXISTS
    // --------------------------------------------------------

    if (phone != null && phone.trim().isNotEmpty) {
      return true;
    }

    // --------------------------------------------------------
    // ASK CUSTOMER TO ADD PHONE
    // --------------------------------------------------------

    final result = await _showAddPhoneDialog();

    return result == true;
  }

  // ==========================================================
  // ADD PHONE DIALOG
  // ==========================================================

  Future<bool?> _showAddPhoneDialog() async {
    _checkoutPhoneController.clear();

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),

              title: const Text(
                'Add Mobile Number',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'A verified mobile number is required to place your order.',
                  ),

                  const SizedBox(height: 18),

                  TextField(
                    controller: _checkoutPhoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,

                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      prefixText: '+91 ',
                      hintText: '10-digit mobile number',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: _phoneVerificationLoading
                      ? null
                      : () {
                          Navigator.pop(dialogContext, false);
                        },
                  child: const Text('CANCEL'),
                ),

                ElevatedButton(
                  onPressed: _phoneVerificationLoading
                      ? null
                      : () async {
                          await _sendCheckoutOtp(setDialogState);
                        },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),

                  child: _phoneVerificationLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('SEND OTP'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // SEND CHECKOUT OTP
  // ==========================================================

  Future<void> _sendCheckoutOtp(StateSetter setDialogState) async {
    final phone = _checkoutPhoneController.text.trim().replaceAll(
      RegExp(r'\s+'),
      '',
    );

    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number.'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final fullPhone = '+91$phone';

    setDialogState(() {
      _phoneVerificationLoading = true;
    });

    try {
      await authService.sendOtpForCurrentUser(
        phoneNumber: fullPhone,

        onCodeSent: (String verificationId) {
          if (!mounted) {
            return;
          }

          _checkoutVerificationId = verificationId;

          setDialogState(() {
            _phoneVerificationLoading = false;
          });

          Navigator.pop(context);

          _showOtpDialog();
        },

        onError: (String error) {
          if (!mounted) {
            return;
          }

          setDialogState(() {
            _phoneVerificationLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        },

        onResendToken: (int? token) {
          _checkoutResendToken = token;
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setDialogState(() {
        _phoneVerificationLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================================
  // OTP DIALOG
  // ==========================================================

  Future<void> _showOtpDialog() async {
    _checkoutOtpController.clear();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool verifying = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),

              title: const Text(
                'Verify Mobile Number',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter the 6-digit OTP sent to your mobile number.',
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: _checkoutOtpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,

                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 5,
                    ),

                    decoration: InputDecoration(
                      hintText: '000000',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: verifying
                      ? null
                      : () {
                          Navigator.pop(dialogContext, false);
                        },
                  child: const Text('CANCEL'),
                ),

                ElevatedButton(
                  onPressed: verifying
                      ? null
                      : () async {
                          final otp = _checkoutOtpController.text.trim();

                          if (otp.length != 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter the 6-digit OTP.'),
                              ),
                            );

                            return;
                          }

                          final verificationId = _checkoutVerificationId;

                          if (verificationId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Verification expired. Please request a new OTP.',
                                ),
                              ),
                            );

                            return;
                          }

                          setDialogState(() {
                            verifying = true;
                          });

                          try {
                            await authService.verifyOtpAndLinkPhone(
                              verificationId: verificationId,
                              otp: otp,
                            );

                            if (!mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext, true);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Mobile number verified successfully.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) {
                              return;
                            }

                            setDialogState(() {
                              verifying = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),

                  child: verifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('VERIFY'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      _checkoutVerificationId = null;

      _checkoutOtpController.clear();
    }
  }

  // ==========================================================
  // PLACE ORDER
  // ==========================================================

  Future<void> _placeOrder({required double deliveryFee}) async {
    // ========================================================
    // CART CHECK
    // ========================================================

    if (Cart.items.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Your cart is empty.')));

      return;
    }

    // ========================================================
    // ADDRESS CHECK
    // ========================================================

    if (selectedAddress == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please select a delivery address.')),
        );

      return;
    }

    // ========================================================
    // LOCATION CHECK
    // ========================================================

    if (selectedAddress!.latitude == null ||
        selectedAddress!.longitude == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Please select your delivery location before placing the order.',
            ),
          ),
        );

      return;
    }

    // ========================================================
    // DOUBLE TAP PROTECTION
    // ========================================================

    if (placingOrder) {
      return;
    }

    // ========================================================
    // PHONE VERIFICATION
    //
    // Only required for users who don't already have a
    // verified phone number.
    // ========================================================

    final phone = await _getCurrentUserPhone();

    if (phone == null || phone.trim().isEmpty) {
      final verified = await _ensurePhoneNumber();

      if (!verified) {
        return;
      }
    }

    // ========================================================
    // START ORDER
    // ========================================================

    if (!mounted) {
      return;
    }

    setState(() {
      placingOrder = true;
    });

    try {
      // ======================================================
      // CALCULATE TOTAL
      // ======================================================

      final double subtotal = _calculateSubtotal();

      const double platformFee = 5;

      final double grandTotal = subtotal + deliveryFee + platformFee;

      // ======================================================
      // CASHFREE / UPI
      // ======================================================

      if (paymentMethod == 'Cashfree' || paymentMethod == 'UPI') {
        await _startCashfreePayment(
          amount: grandTotal,
          deliveryFee: deliveryFee,
        );

        return;
      }

      // ======================================================
      // CASH ON DELIVERY
      // ======================================================

      await _createFirestoreOrder(
        deliveryFee: deliveryFee,
        paymentMethod: 'Cash on Delivery',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        placingOrder = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  // ==========================================================
  // START CASHFREE PAYMENT
  // ==========================================================

  Future<void> _startCashfreePayment({
    required double amount,
    required double deliveryFee,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please login before making an online payment.');
    }

    // --------------------------------------------------------
    // GET VERIFIED PHONE
    // --------------------------------------------------------

    final phone = await _getCurrentUserPhone();

    if (phone == null || phone.trim().isEmpty) {
      throw Exception('A verified phone number is required for payment.');
    }

    // ========================================================
    // CREATE CASHFREE ORDER ID
    // ========================================================

    final cashfreeOrderId = 'DB_${DateTime.now().millisecondsSinceEpoch}';

    // ========================================================
    // CREATE CASHFREE ORDER
    // ========================================================

    final cashfreeOrder = await cashfreeService.createOrder(
      orderId: cashfreeOrderId,
      amount: amount,
      customerId: user.uid,
      customerName: selectedAddress!.fullName,
      customerPhone: phone,
    );

    // ========================================================
    // OPEN CASHFREE CHECKOUT
    // ========================================================

    await cashfreeService.openCheckout(
      orderId: cashfreeOrder.orderId,

      paymentSessionId: cashfreeOrder.paymentSessionId,

      onPaymentResult: (String orderId, String paymentStatus) async {
        await _handleCashfreeSuccess(
          orderId: orderId,
          deliveryFee: deliveryFee,
        );
      },

      onError: (String message) {
        if (!mounted) {
          return;
        }

        setState(() {
          placingOrder = false;
        });

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                message.isEmpty ? 'Cashfree payment failed.' : message,
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
    );
  }

  // ==========================================================
  // HANDLE CASHFREE SUCCESS
  // ==========================================================

  Future<void> _handleCashfreeSuccess({
    required String orderId,
    required double deliveryFee,
  }) async {
    try {
      final verification = await cashfreeService.verifyPayment(
        orderId: orderId,
      );

      if (!mounted) {
        return;
      }

      if (!verification.isPaid) {
        setState(() {
          placingOrder = false;
        });

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Payment was not successful. '
                'Status: ${verification.paymentStatus}',
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );

        return;
      }

      await _createFirestoreOrder(
        deliveryFee: deliveryFee,
        paymentMethod: 'Cashfree',
        orderId: orderId,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        placingOrder = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Payment verification failed: '
              '${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  // ==========================================================
  // CREATE FIRESTORE ORDER
  // ==========================================================

  Future<void> _createFirestoreOrder({
    required double deliveryFee,
    required String paymentMethod,
    String? orderId,
  }) async {
    if (selectedAddress == null) {
      throw Exception('Delivery address is missing.');
    }

    // --------------------------------------------------------
    // GET VERIFIED PHONE
    // --------------------------------------------------------

    final phone = await _getCurrentUserPhone();

    if (phone == null || phone.trim().isEmpty) {
      throw Exception('A verified phone number is required.');
    }

    // ========================================================
    // CREATE ORDER
    // ========================================================

    await orderService.placeOrder(
      customerName: selectedAddress!.fullName,

      customerPhone: phone,

      address:
          '${selectedAddress!.house}, '
          '${selectedAddress!.area}, '
          '${selectedAddress!.city}, '
          '${selectedAddress!.state} - '
          '${selectedAddress!.pincode}',

      paymentMethod: paymentMethod,

      customerLatitude: selectedAddress!.latitude!,

      customerLongitude: selectedAddress!.longitude!,

      deliveryFee: deliveryFee,
    );

    if (!mounted) {
      return;
    }

    // ========================================================
    // CLEAR CART
    // ========================================================

    context.read<CartProvider>().clear();

    // ========================================================
    // SUCCESS
    // ========================================================

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const OrderSuccessScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.94,
                end: 1.0,
              ).animate(curvedAnimation),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  // ==========================================================
  // SECTION ANIMATION
  // ==========================================================

  Widget _animatedSection(Widget child, {int delay = 0}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // ==========================================================
  // PAYMENT OPTION
  // ==========================================================

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final selected = paymentMethod == value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: PaymentCard(
        title: title,
        subtitle: subtitle,
        icon: icon,
        selected: selected,
        onTap: () {
          if (paymentMethod == value) {
            return;
          }

          setState(() {
            paymentMethod = value;
          });
        },
      ),
    );
  }

  // ==========================================================
  // PRODUCT IMAGE PLACEHOLDER
  // ==========================================================

  Widget _productImagePlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.shopping_bag, color: Colors.green),
    );
  }
  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final double subtotal = _calculateSubtotal();

    final double deliveryFee = _getDeliveryFee();

    const double platformFee = 5;

    final double grandTotal = subtotal + deliveryFee + platformFee;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // ========================================================
      // ADDRESS STREAM
      // ========================================================
      body: StreamBuilder<List<Address>>(
        stream: _addressesStream,

        builder: (context, snapshot) {
          // ====================================================
          // LOADING
          // ====================================================

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          // ====================================================
          // ERROR
          // ====================================================

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error loading addresses:\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          // ====================================================
          // ADDRESSES
          // ====================================================

          final addresses = snapshot.data ?? [];

          _selectDefaultAddress(addresses);

          // ====================================================
          // EMPTY CART
          // ====================================================

          if (Cart.items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 70,
                    color: Colors.grey,
                  ),

                  SizedBox(height: 12),

                  Text(
                    'Your cart is empty',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          // ====================================================
          // MAIN CHECKOUT
          // ====================================================

          return FadeTransition(
            opacity: _fadeAnimation,

            child: SlideTransition(
              position: _slideAnimation,

              child: ListView(
                padding: const EdgeInsets.all(16),

                children: [
                  // ==================================================
                  // DELIVERY ADDRESS
                  // ==================================================
                  _animatedSection(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'Delivery Address',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ==========================================
                        // NO ADDRESS
                        // ==========================================
                        if (addresses.isEmpty)
                          Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),

                            child: Padding(
                              padding: const EdgeInsets.all(20),

                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.location_off,
                                    size: 50,
                                    color: Colors.grey,
                                  ),

                                  const SizedBox(height: 10),

                                  const Text(
                                    'No saved address',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  const Text(
                                    'Please add a delivery '
                                    'address before placing '
                                    'your order.',
                                    textAlign: TextAlign.center,
                                  ),

                                  const SizedBox(height: 15),

                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add),

                                    label: const Text('ADD ADDRESS'),

                                    onPressed: _addAddress,

                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        // ==========================================
                        // ADDRESS AVAILABLE
                        // ==========================================
                        else
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),

                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: animation,
                                  child: child,
                                ),
                              );
                            },

                            child: AddressCard(
                              key: ValueKey(selectedAddress?.id),

                              title: selectedAddress!.fullName,

                              address:
                                  '${selectedAddress!.house}, '
                                  '${selectedAddress!.area}, '
                                  '${selectedAddress!.city}, '
                                  '${selectedAddress!.state} - '
                                  '${selectedAddress!.pincode}',

                              onTap: () {
                                _showAddressSelector(addresses);
                              },
                            ),
                          ),
                      ],
                    ),
                    delay: 50,
                  ),

                  const SizedBox(height: 18),

                  // ==================================================
                  // WEATHER
                  // ==================================================
                  _animatedSection(
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),

                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            child: child,
                          ),
                        );
                      },

                      child: weatherLoading
                          ? Card(
                              key: const ValueKey('weather_loading'),

                              child: const ListTile(
                                leading: SizedBox(
                                  width: 25,
                                  height: 25,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),

                                title: Text(
                                  'Checking weather...',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),

                                subtitle: Text('Calculating delivery fee'),
                              ),
                            )
                          : weatherData != null
                          ? Card(
                              key: const ValueKey('weather_loaded'),

                              color: weatherData!.isLightRain
                                  ? Colors.orange.shade50
                                  : Colors.green.shade50,

                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: weatherData!.isLightRain
                                      ? Colors.orange
                                      : Colors.green,

                                  child: Text(
                                    weatherData!.emoji,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),

                                title: Text(
                                  '${weatherData!.temperature.toStringAsFixed(0)}°C • '
                                  '${weatherData!.description}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                subtitle: weatherData!.isLightRain
                                    ? const Text(
                                        'Light rain delivery charge included',
                                      )
                                    : const Text('Normal delivery fee'),

                                trailing: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),

                                  child: Text(
                                    _formatPrice(deliveryFee),

                                    key: ValueKey(deliveryFee),

                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : const Card(
                              key: ValueKey('weather_error'),

                              child: ListTile(
                                leading: Icon(
                                  Icons.cloud_off,
                                  color: Colors.grey,
                                ),

                                title: Text('Weather unavailable'),

                                subtitle: Text('Using normal delivery fee'),
                              ),
                            ),
                    ),
                    delay: 100,
                  ),

                  const SizedBox(height: 15),

                  // ==================================================
                  // DELIVERY INFORMATION
                  // ==================================================
                  _animatedSection(
                    Column(
                      children: [
                        const InfoCard(
                          icon: Icons.delivery_dining,
                          title: 'Fast Delivery',
                          subtitle: 'Estimated arrival in 10 minutes',
                        ),

                        const SizedBox(height: 15),

                        const Align(
                          alignment: Alignment.centerLeft,
                          child: DeliveryBadge(minutes: 10),
                        ),
                      ],
                    ),
                    delay: 120,
                  ),

                  const SizedBox(height: 25),

                  // ==================================================
                  // ORDER SUMMARY
                  // ==================================================
                  _animatedSection(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'Order Summary',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        ...Cart.items.asMap().entries.map((entry) {
                          final index = entry.key;

                          final item = entry.value;

                          final itemPrice = _parsePrice(item.product.price);

                          final itemTotal = itemPrice * item.quantity;

                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),

                            duration: Duration(
                              milliseconds: 300 + (index * 70),
                            ),

                            curve: Curves.easeOutCubic,

                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(15 * (1 - value), 0),
                                  child: child,
                                ),
                              );
                            },

                            child: Card(
                              margin: const EdgeInsets.only(bottom: 12),

                              elevation: 1,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),

                              child: ListTile(
                                contentPadding: const EdgeInsets.all(8),

                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),

                                  child: item.product.image.trim().isEmpty
                                      ? _productImagePlaceholder()
                                      : Image.network(
                                          item.product.image,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) {
                                            return _productImagePlaceholder();
                                          },
                                        ),
                                ),

                                title: Text(
                                  item.product.name,

                                  maxLines: 1,

                                  overflow: TextOverflow.ellipsis,

                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                subtitle: Text('Qty: ${item.quantity}'),

                                trailing: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),

                                  child: Text(
                                    _formatPrice(itemTotal),

                                    key: ValueKey(itemTotal),

                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    delay: 150,
                  ),

                  const SizedBox(height: 15),

                  // ==================================================
                  // BILL DETAILS
                  // ==================================================
                  _animatedSection(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'Bill Details',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Card(
                          elevation: 1,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),

                          child: Padding(
                            padding: const EdgeInsets.all(18),

                            child: Column(
                              children: [
                                // --------------------------------
                                // SUBTOTAL
                                // --------------------------------
                                PriceRow(
                                  title: 'Subtotal',
                                  value: _formatPrice(subtotal),
                                ),

                                const SizedBox(height: 12),

                                // --------------------------------
                                // DELIVERY FEE
                                // --------------------------------
                                PriceRow(
                                  title: 'Delivery Fee',
                                  value: _formatPrice(deliveryFee),
                                ),

                                // --------------------------------
                                // RAIN SURCHARGE
                                // --------------------------------
                                if (weatherData != null &&
                                    weatherData!.isLightRain)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),

                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,

                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.umbrella,
                                              size: 16,
                                              color: Colors.orange,
                                            ),

                                            const SizedBox(width: 5),

                                            Text(
                                              'Rain surcharge included',
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const Text(
                                          '+₹10',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 12),

                                // --------------------------------
                                // PLATFORM FEE
                                // --------------------------------
                                const PriceRow(
                                  title: 'Platform Fee',
                                  value: '₹5',
                                ),

                                const Divider(height: 28),

                                // --------------------------------
                                // GRAND TOTAL
                                // --------------------------------
                                PriceRow(
                                  title: 'Grand Total',
                                  value: _formatPrice(grandTotal),
                                  isTotal: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    delay: 180,
                  ),

                  const SizedBox(height: 25),

                  // ==================================================
                  // PAYMENT METHOD
                  // ==================================================
                  _animatedSection(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'Payment Method',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ==========================================
                        // CASH ON DELIVERY
                        // ==========================================
                        _buildPaymentOption(
                          title: 'Cash on Delivery',
                          subtitle: 'Pay when your order arrives',
                          icon: Icons.payments,
                          value: 'Cash on Delivery',
                        ),

                        const SizedBox(height: 10),

                        // ==========================================
                        // UPI
                        // ==========================================
                        _buildPaymentOption(
                          title: 'UPI',
                          subtitle: 'Pay securely using UPI',
                          icon: Icons.account_balance_wallet,
                          value: 'UPI',
                        ),

                        const SizedBox(height: 10),

                        // ==========================================
                        // CASHFREE
                        // ==========================================
                        _buildPaymentOption(
                          title: 'Cashfree',
                          subtitle: 'UPI, Cards & Net Banking',
                          icon: Icons.payment,
                          value: 'Cashfree',
                        ),
                      ],
                    ),
                    delay: 210,
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // PLACE ORDER BUTTON
                  // ==================================================
                  _animatedSection(
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),

                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        );
                      },

                      child: placingOrder
                          ? Container(
                              key: const ValueKey('placing_order'),

                              height: 55,

                              width: double.infinity,

                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(14),
                              ),

                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,

                                children: [
                                  const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  Text(
                                    paymentMethod == 'Cashfree' ||
                                            paymentMethod == 'UPI'
                                        ? 'OPENING PAYMENT...'
                                        : 'PLACING ORDER...',

                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : PrimaryButton(
                              key: const ValueKey('place_order'),

                              text:
                                  paymentMethod == 'Cashfree' ||
                                      paymentMethod == 'UPI'
                                  ? 'PAY & PLACE ORDER'
                                  : 'PLACE ORDER',

                              icon:
                                  paymentMethod == 'Cashfree' ||
                                      paymentMethod == 'UPI'
                                  ? Icons.payment
                                  : Icons.shopping_bag,

                              onPressed: () async {
                                if (placingOrder) {
                                  return;
                                }

                                await _placeOrder(deliveryFee: deliveryFee);
                              },
                            ),
                    ),
                    delay: 230,
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
