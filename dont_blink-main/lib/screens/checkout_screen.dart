import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/address.dart';
import '../models/cart.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/wishlist.dart';
import '../services/firestore_service.dart';

import '../services/address_service.dart';
import '../services/order_service.dart';
import '../services/delivery_availability_service.dart';
import '../services/weather_service.dart';
import '../services/cashfree_service.dart';
import '../services/auth_service.dart';
import '../services/upi_payment_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../widgets/cached_product_image.dart';
import '../widgets/price_row.dart';
import '../widgets/select_payment_method_sheet.dart';

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

  bool get _isCodAvailable {
    final hour = DateTime.now().hour;
    // Available from 7:00 AM to 9:59 PM. Unavailable from 10:00 PM to 6:59 AM.
    return hour >= 7 && hour < 22;
  }

  late PaymentSelection selectedPayment = _isCodAvailable
      ? const PaymentSelection(
          type: 'COD',
          title: 'Cash on Delivery',
          subtitle: 'Pay cash or UPI on delivery',
        )
      : const PaymentSelection(
          type: 'UPI_INTENT',
          title: 'UPI',
          subtitle: 'Pay directly via UPI',
        );

  String get paymentMethod {
    if (selectedPayment.type == 'COD') return 'Cash on Delivery';
    return selectedPayment.title;
  }

  // ==========================================================
  // SERVICES
  // ==========================================================

  final OrderService orderService = OrderService();

  final AddressService addressService = AddressService();

  final WeatherService weatherService = WeatherService();

  final CashfreeService cashfreeService = CashfreeService();

  final AuthService authService = AuthService();

  final FirestoreService _firestoreService = FirestoreService();

  late final Stream<List<Product>> _recommendationsStream;

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
  // DELIVERY AVAILABILITY
  // ==========================================================

  final DeliveryAvailabilityService deliveryAvailabilityService =
      DeliveryAvailabilityService();

  DeliveryAvailability? deliveryAvailability;

  bool deliveryAvailabilityLoading = false;

  int _deliveryCheckRequest = 0;

  String? _lastDeliveryCheckKey;

  // ==========================================================
  // WEATHER
  // ==========================================================

  WeatherData? weatherData;

  bool weatherLoading = true;

  int _weatherRequest = 0;

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
    _recommendationsStream = _firestoreService.getPopularProducts();

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

    // Weather is loaded for the selected delivery address.
    // Do not use a fixed store-location weather value.

    _detectInstalledUpiApp();
    // Do not use a fixed store-location weather value.
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
  // AUTO-DETECT INSTALLED UPI APPS
  // ==========================================================

  Future<void> _detectInstalledUpiApp() async {
    try {
      final apps = await cashfreeService.getInstalledUPIApps();
      if (apps.isNotEmpty && mounted) {
        final firstApp = apps.first;
        final rawName = firstApp['displayName'] ??
            firstApp['appName'] ??
            firstApp['app_name'] ??
            firstApp['name'] ??
            '';
        final package = firstApp['id'] ??
            firstApp['appPackage'] ??
            firstApp['app_package'] ??
            firstApp['package'] ??
            '';
        final iconBase64 = firstApp['icon'] ??
            firstApp['base64Icon'] ??
            firstApp['appIcon']?.toString();

        final cleanTitle =
            _formatUpiTitle(rawName.toString(), package.toString());

        if (selectedPayment.type == 'UPI_INTENT' || !_isCodAvailable) {
          setState(() {
            selectedPayment = PaymentSelection(
              type: 'UPI_INTENT',
              title: cleanTitle,
              subtitle: cleanTitle == 'UPI'
                  ? 'Pay directly via UPI'
                  : 'Pay directly via $cleanTitle',
              appPackage: package.toString().trim().isNotEmpty
                  ? package.toString().trim()
                  : null,
              iconBase64: iconBase64?.toString().trim().isNotEmpty == true
                  ? iconBase64.toString().trim()
                  : null,
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error auto-detecting UPI app: $e');
    }
  }

  String _formatUpiTitle(String rawName, String package) {
    String name = rawName.trim();
    if (name.isEmpty || name.toLowerCase() == 'null') {
      final pkg = package.toLowerCase();
      if (pkg.contains('paisa') || pkg.contains('google')) {
        name = 'Google Pay';
      } else if (pkg.contains('phonepe')) {
        name = 'PhonePe';
      } else if (pkg.contains('paytm')) {
        name = 'Paytm';
      } else if (pkg.contains('amazon')) {
        name = 'Amazon Pay';
      } else if (pkg.contains('cred')) {
        name = 'CRED';
      } else if (pkg.contains('bhim')) {
        name = 'BHIM';
      } else {
        name = 'UPI';
      }
    }

    name = name
        .replaceAll(RegExp(r'\bUPI\s+UPI\b', caseSensitive: false), 'UPI')
        .trim();

    if (name.toUpperCase() == 'UPI') {
      return 'UPI';
    }

    return name;
  }

  // ==========================================================
  // WEATHER
  // ==========================================================

  Future<void> _loadWeatherForAddress(Address? address) async {
    if (!mounted) return;

    final latitude = address?.latitude;
    final longitude = address?.longitude;

    if (latitude == null || longitude == null) {
      if (!mounted) return;

      setState(() {
        weatherData = null;
        weatherLoading = false;
      });
      return;
    }

    final int requestId = ++_weatherRequest;

    setState(() {
      weatherLoading = true;
    });

    try {
      final weather = await weatherService.getCurrentWeather(
        latitude: latitude,
        longitude: longitude,
      );

      if (!mounted || requestId != _weatherRequest) {
        return;
      }

      setState(() {
        weatherData = weather;
        weatherLoading = false;
      });

      debugPrint(
        'Weather at delivery location '
        '($latitude, $longitude): '
        '${weather.description}, '
        'rain=${weather.rain}mm, '
        'showers=${weather.showers}mm',
      );
    } catch (e) {
      debugPrint('Checkout weather error: $e');

      if (!mounted || requestId != _weatherRequest) {
        return;
      }

      setState(() {
        weatherData = null;
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

  double _calculateSubtotal([List<CartItem>? items]) {
    double subtotal = 0;
    final list = items ?? Cart.items;

    for (final item in list) {
      final price = _parsePrice(item.product.price);

      subtotal += price * item.quantity;
    }

    return subtotal;
  }

  void _removeItem(BuildContext context, CartItem item) {
    context.read<CartProvider>().remove(item.product);
  }

  void _addItem(BuildContext context, CartItem item) {
    final stock = item.product.stock;

    if (stock > 0 && item.quantity >= stock) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('You have reached available stock limit.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }

    context.read<CartProvider>().add(item.product);
  }

  void _moveToWishlist(BuildContext context, CartItem item) {
    if (!Wishlist.contains(item.product)) {
      Wishlist.toggle(item.product);
    }

    context.read<CartProvider>().remove(item.product);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${item.product.name} moved to wishlist'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
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
  // ADDRESS DISPLAY
  // ==========================================================

  String _displayAddress(Address address) {
    final structured = [
      address.house,
      address.area,
      address.city,
      address.state,
    ].where((value) => value.trim().isNotEmpty).join(', ');

    final withPin = address.pincode.trim().isNotEmpty
        ? '$structured - ${address.pincode.trim()}'
        : structured;

    if (withPin.trim().isNotEmpty) {
      return withPin;
    }

    if (address.formattedAddress.trim().isNotEmpty) {
      return address.formattedAddress.trim();
    }

    return 'Delivery location selected';
  }

  // ==========================================================
  // DEFAULT ADDRESS
  // ==========================================================

  // ==========================================================
  // CHECK DELIVERY AVAILABILITY
  // ==========================================================

  Future<void> _checkDeliveryAvailability(Address? address) async {
    if (!mounted) return;

    final int requestId = ++_deliveryCheckRequest;

    final String addressKey =
        '${address?.id}|${address?.latitude}|${address?.longitude}';

    _lastDeliveryCheckKey = addressKey;

    if (address == null) {
      setState(() {
        deliveryAvailability = null;
        deliveryAvailabilityLoading = false;
      });
      return;
    }

    if (address.latitude == null || address.longitude == null) {
      setState(() {
        deliveryAvailability = const DeliveryAvailability(
          isDeliverable: false,
          store: null,
          message: 'Please select a delivery location for this address.',
        );
        deliveryAvailabilityLoading = false;
      });
      return;
    }

    setState(() {
      deliveryAvailabilityLoading = true;
      deliveryAvailability = null;
    });

    final result = await deliveryAvailabilityService.check(
      latitude: address.latitude,
      longitude: address.longitude,
    );

    if (!mounted || requestId != _deliveryCheckRequest) {
      return;
    }

    setState(() {
      deliveryAvailability = result;
      deliveryAvailabilityLoading = false;
    });
  }

  // ==========================================================
  // DELIVERY AVAILABILITY CARD
  // ==========================================================

  Widget _deliveryAvailabilityCard() {
    if (selectedAddress == null || deliveryAvailabilityLoading) {
      return const SizedBox.shrink();
    }

    final availability = deliveryAvailability;

    if (availability == null || availability.isDeliverable) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_outlined,
              color: Colors.red,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Builder(
              builder: (context) {
                final isStockIssue = availability.message
                    .toLowerCase()
                    .contains('out of stock');
                final title =
                    isStockIssue ? 'Items unavailable' : 'Not deliverable';
                final subtitle = isStockIssue
                    ? 'Please adjust item quantities in your cart.'
                    : 'Please choose another delivery address.';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      availability.message,
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

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
    final result = await Navigator.push<Address>(
      context,
      MaterialPageRoute(builder: (_) => const AddAddressScreen()),
    );

    if (!mounted) {
      return;
    }

    if (result != null) {
      setState(() {
        selectedAddress = result;
        deliveryAvailability = null;
        deliveryAvailabilityLoading = true;
        weatherData = null;
        weatherLoading = true;
      });

      _checkDeliveryAvailability(result);
      _loadWeatherForAddress(result);
    } else {
      setState(() {});
    }
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
                                deliveryAvailability = null;
                                deliveryAvailabilityLoading = true;
                                weatherData = null;
                                weatherLoading = true;
                              });

                              Navigator.pop(sheetContext);

                              _checkDeliveryAvailability(address);
                              _loadWeatherForAddress(address);
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

        onResendToken: (_) {},
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

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext, true);

                            if (!context.mounted) {
                              return;
                            }

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

                            if (!context.mounted) {
                              return;
                            }

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
    // DELIVERY AVAILABILITY SAFETY CHECK
    // ========================================================

    if (deliveryAvailabilityLoading) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Checking delivery availability. Please wait.'),
          ),
        );
      return;
    }

    if (deliveryAvailability == null || !deliveryAvailability!.isDeliverable) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              deliveryAvailability?.message ??
                  'Sorry, this location is not deliverable.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
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

      const double handlingFee = 5;
      const double platformFee = 5;

      final double grandTotal = subtotal + deliveryFee + handlingFee + platformFee;

      // ======================================================
      // UPI / ONLINE PAYMENT
      // ======================================================

      if (selectedPayment.type != 'COD') {
        await _startUpiPayment(
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
  // START DIRECT UPI PAYMENT
  // ==========================================================

  Future<void> _startUpiPayment({
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
    // CREATE ORDER ID
    // ========================================================

    final upiOrderId = 'DB_${DateTime.now().millisecondsSinceEpoch}';

    // ========================================================
    // LAUNCH NATIVE UPI INTENT & VERIFY BANK RESULT
    // ========================================================

    final result = await UpiPaymentService.initiateNativeUpiPayment(
      amount: amount,
      orderId: upiOrderId,
      specificAppPackage: selectedPayment.appPackage,
    );

    if (!mounted) {
      return;
    }

    if (result.isSuccess) {
      final paymentTitle = selectedPayment.title.isNotEmpty
          ? selectedPayment.title
          : 'UPI';
      final ref = (result.approvalRefNo != null && result.approvalRefNo!.trim().isNotEmpty)
          ? result.approvalRefNo!.trim()
          : (result.txnId != null && result.txnId!.trim().isNotEmpty
              ? result.txnId!.trim()
              : upiOrderId);

      final fullMethodName = 'UPI ($paymentTitle - Ref: $ref)';

      await _createFirestoreOrder(
        deliveryFee: deliveryFee,
        paymentMethod: fullMethodName,
        paymentStatus: 'Paid',
        orderId: upiOrderId,
      );

    } else {
      setState(() {
        placingOrder = false;
      });

      if (result.status == 'CANCELLED') {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Payment was cancelled. Order has not been placed.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'Help?',
                textColor: Colors.amberAccent,
                onPressed: () {
                  _showPaymentHelpSheet(
                    orderId: upiOrderId,
                    amount: amount,
                  );
                },
              ),
              backgroundColor: Colors.grey.shade900,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
      } else {
        // Bank failure, decline, or timeout
        await _showPaymentHelpSheet(
          orderId: upiOrderId,
          amount: amount,
          errorMessage: result.errorMessage,
        );
      }
    }
  }

  // ==========================================================
  // PAYMENT HELP & WHATSAPP SUPPORT SHEET
  // ==========================================================

  Future<void> _showPaymentHelpSheet({
    required String orderId,
    required double amount,
    String? errorMessage,
  }) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: Colors.red.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Not Confirmed',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Order: #$orderId • Total: ${_formatPrice(amount)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // RBI Auto-Refund Reassurance Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 18,
                          color: Colors.amber.shade900,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Was money debited from your bank?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Don\'t worry! As per RBI & NPCI auto-reversal guidelines, any amount debited during a bank server delay will be automatically refunded to your bank account within 24–48 hours.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.brown.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              if (errorMessage != null && errorMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  errorMessage,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 18),

              // WhatsApp Support Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _openWhatsAppSupport(
                      orderId: orderId,
                      amount: amount,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Chat on WhatsApp (9707247492)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Dismiss / Retry button
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Try Again or Change Payment Method',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // LAUNCH WHATSAPP SUPPORT
  // ==========================================================

  Future<void> _openWhatsAppSupport({
    required String orderId,
    required double amount,
  }) async {
    const phone = '919707247492';
    final message =
        'Hi Doorstepp Support, my UPI payment for order #$orderId of ${_formatPrice(amount)} had an issue. Here is my details:';
    final url = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(message)}');

    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }


  // ==========================================================
  // CREATE FIRESTORE ORDER
  // ==========================================================

  Future<void> _createFirestoreOrder({
    required double deliveryFee,
    required String paymentMethod,
    String? orderId,
    String? paymentStatus,
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

      address: _displayAddress(selectedAddress!),

      paymentMethod: paymentMethod,

      customerLatitude: selectedAddress!.latitude!,

      customerLongitude: selectedAddress!.longitude!,

      deliveryFee: deliveryFee,
      paymentStatus: paymentStatus,
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

  Widget _productImagePlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.shopping_bag, color: Colors.green),
    );
  }

  // ==========================================================
  // BLINKIT-STYLE APP BAR
  // ==========================================================

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      toolbarHeight: 65,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1B271E),
      elevation: 0.5,
      surfaceTintColor: Colors.transparent,
      leading: Navigator.canPop(context)
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Color(0xFF1B271E),
              ),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: const Text(
        'Checkout',
        style: TextStyle(
          color: Color(0xFF1B271E),
          fontWeight: FontWeight.w900,
          fontSize: 20,
          letterSpacing: -0.4,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Share',
          onPressed: () {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Cart link shared'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
          },
          icon: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.share_outlined, size: 20, color: Color(0xFF1B271E)),
              SizedBox(width: 4),
              Text(
                'Share',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B271E),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ==========================================================
  // DELIVERY ETA BANNER
  // ==========================================================

  Widget _buildDeliveryEtaBanner(int itemCount) {
    String etaText = 'Delivery in 8 to 10 minutes';
    final distance = deliveryAvailability?.distanceKm;
    if (distance != null) {
      if (distance > 12) {
        etaText = 'Delivery in 20 to 25 minutes';
      } else if (distance > 6) {
        etaText = 'Delivery in 15 to 20 minutes';
      } else if (distance > 3) {
        etaText = 'Delivery in 10 to 12 minutes';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EEE5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time_filled_rounded,
              color: Color(0xFF168A43),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etaText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B271E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Shipment of $itemCount ${itemCount == 1 ? 'item' : 'items'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
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
  // CART ITEMS CARD (Interactive steppers & move to wishlist)
  // ==========================================================

  Widget _buildCartItemsCard(BuildContext context, List<CartItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EEE5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final itemPrice = _parsePrice(item.product.price);
          final originalPrice = item.product.discount > 0
              ? itemPrice / (1 - (item.product.discount / 100))
              : 0.0;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedProductImage(
                        url: item.product.image,
                        width: 62,
                        height: 62,
                        fit: BoxFit.cover,
                        cacheWidth: 360,
                        cacheHeight: 360,
                        placeholder: _productImagePlaceholder(),
                        errorWidget: _productImagePlaceholder(),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Product title, unit, wishlist
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B271E),
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.product.sellingUnit.isNotEmpty
                                ? item.product.sellingUnit
                                : (item.product.category.isNotEmpty
                                    ? item.product.category
                                    : '1 unit'),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _moveToWishlist(context, item),
                            child: const Text(
                              'Move to wishlist',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF168A43),
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationStyle: TextDecorationStyle.dotted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Right column: stepper + price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFF168A43),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _removeItem(context, item),
                                child: const SizedBox(
                                  width: 28,
                                  height: 34,
                                  child: Icon(
                                    Icons.remove,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => _addItem(context, item),
                                child: const SizedBox(
                                  width: 28,
                                  height: 34,
                                  child: Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (originalPrice > itemPrice) ...[
                              Text(
                                _formatPrice(originalPrice * item.quantity),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              _formatPrice(itemPrice * item.quantity),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B271E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(
                  height: 16,
                  thickness: 0.8,
                  color: Color(0xFFEEF3EE),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ==========================================================
  // RECOMMENDATIONS ("You might also like")
  // ==========================================================

  Widget _buildRecommendations(List<CartItem> cartItems) {
    final cartProductIds = cartItems.map((e) => e.product.id).toSet();

    return StreamBuilder<List<Product>>(
      stream: _recommendationsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final products = snapshot.data!
            .where((p) => !cartProductIds.contains(p.id) && p.isAvailable)
            .take(10)
            .toList();

        if (products.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'You might also like',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B271E),
                ),
              ),
            ),
            SizedBox(
              height: 246,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: products.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final product = products[index];
                  final price = _parsePrice(product.price);
                  final originalPrice = product.discount > 0
                      ? price / (1 - (product.discount / 100))
                      : 0.0;

                  return Container(
                    width: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFE2EEE5),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image & Wishlist
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedProductImage(
                                url: product.image,
                                width: 120,
                                height: 95,
                                fit: BoxFit.contain,
                                placeholder: _productImagePlaceholder(),
                                errorWidget: _productImagePlaceholder(),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    Wishlist.toggle(product);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Wishlist.contains(product)
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 16,
                                    color: Wishlist.contains(product)
                                        ? Colors.red
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Unit & ADD button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                product.sellingUnit.isNotEmpty
                                    ? product.sellingUnit
                                    : (product.category.isNotEmpty
                                        ? product.category
                                        : '1 unit'),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              height: 28,
                              child: OutlinedButton(
                                onPressed: () {
                                  context.read<CartProvider>().add(product);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF168A43),
                                  side: const BorderSide(
                                    color: Color(0xFF168A43),
                                    width: 1.4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'ADD',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Price & discount
                        Row(
                          children: [
                            Text(
                              _formatPrice(price),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1B271E),
                              ),
                            ),
                            if (originalPrice > price) ...[
                              const SizedBox(width: 4),
                              Text(
                                _formatPrice(originalPrice),
                                style: TextStyle(
                                  fontSize: 10,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (product.discount > 0)
                          Text(
                            '${product.discount}% OFF',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF168A43),
                            ),
                          ),
                        const SizedBox(height: 4),
                        // Name
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B271E),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // BILL DETAILS CARD
  // ==========================================================

  Widget _buildBillDetailsCard({
    required double subtotal,
    required double deliveryFee,
    required double handlingFee,
    required double platformFee,
    required double grandTotal,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EEE5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B271E),
            ),
          ),
          const SizedBox(height: 14),
          PriceRow(
            title: 'Item Total',
            value: _formatPrice(subtotal),
          ),
          const SizedBox(height: 8),
          PriceRow(
            title: 'Delivery Partner Fee',
            value: deliveryFee == 0 ? 'FREE' : _formatPrice(deliveryFee),
          ),
          const SizedBox(height: 8),
          PriceRow(
            title: 'Handling Fee',
            value: _formatPrice(handlingFee),
          ),
          const SizedBox(height: 8),
          PriceRow(
            title: 'Platform Fee',
            value: _formatPrice(platformFee),
          ),
          const Divider(height: 24, thickness: 0.8, color: Color(0xFFE2EEE5)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B271E),
                ),
              ),
              Text(
                _formatPrice(grandTotal),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF168A43),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // CANCELLATION POLICY NOTE
  // ==========================================================

  Widget _buildCancellationPolicyNote() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EEE5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFF168A43),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Orders cannot be cancelled once packed for dispatch. In case of unexpected delay, full refund is guaranteed.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // EMPTY CART VIEW
  // ==========================================================

  Widget _buildEmptyCartView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F9F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 52,
                color: Color(0xFF168A43),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B271E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Explore products and add items to your cart.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF168A43),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: const Text(
                  'Browse Products',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // PAYMENT BRAND ICON
  // ==========================================================

  Widget _buildPaymentBrandIcon(PaymentSelection payment) {
    return PaymentBrandIcon(payment: payment, size: 34);
  }

  // ==========================================================
  // STICKY BOTTOM BAR (Blinkit 2-tier layout)
  // ==========================================================

  Widget _buildStickyBottomBar({
    required List<Address> addresses,
    required double grandTotal,
    required double deliveryFee,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tier 1: Address Strip
            Container(
              color: const Color(0xFFFAFCFA),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3CD),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_pin_circle_rounded,
                      color: Color(0xFFD97706),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedAddress != null
                              ? 'Delivering to ${selectedAddress!.fullName}'
                              : 'Select Delivery Address',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B271E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          selectedAddress != null
                              ? _displayAddress(selectedAddress!)
                              : 'Tap change to select address',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      if (addresses.isEmpty) {
                        _addAddress();
                      } else {
                        _showAddressSelector(addresses);
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF168A43),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      addresses.isEmpty ? 'Add' : 'Change',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEBEFEB)),

            // Tier 2: Payment Selector & Place Order
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  // Left side: Selected payment method
                  InkWell(
                    onTap: () async {
                      final result = await SelectPaymentMethodSheet.show(
                        context,
                        currentSelection: selectedPayment,
                        totalAmount: grandTotal,
                        isCodAvailable: _isCodAvailable,
                      );
                      if (result != null && mounted) {
                        setState(() {
                          selectedPayment = result;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPaymentBrandIcon(selectedPayment),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'PAY USING',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.grey.shade700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_up_rounded,
                                    size: 16,
                                    color: Colors.black87,
                                  ),
                                ],
                              ),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 105),
                                child: Text(
                                  selectedPayment.title,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1B271E),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Right side: Place order button
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: placingOrder ||
                                selectedAddress == null ||
                                deliveryAvailabilityLoading ||
                                deliveryAvailability == null ||
                                !deliveryAvailability!.isDeliverable
                            ? null
                            : () async {
                                await _placeOrder(deliveryFee: deliveryFee);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF168A43),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: placingOrder
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatPrice(grandTotal),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const Text(
                                        'TOTAL',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white70,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Place Order',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(
                                        Icons.arrow_right_rounded,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
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
    if (!_isCodAvailable && selectedPayment.type == 'COD') {
      selectedPayment = const PaymentSelection(
        type: 'UPI_INTENT',
        title: 'UPI',
        subtitle: 'Pay directly via UPI',
      );
    }

    return StreamBuilder<List<Address>>(
      stream: _addressesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFFF7FAF8),
            appBar: _buildAppBar(context),
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF7FAF8),
            appBar: _buildAppBar(context),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error loading addresses:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        final addresses = snapshot.data ?? [];
        _selectDefaultAddress(addresses);

        if (selectedAddress != null) {
          final addressKey =
              '${selectedAddress!.id}|'
              '${selectedAddress!.latitude}|'
              '${selectedAddress!.longitude}';

          if (_lastDeliveryCheckKey != addressKey) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _lastDeliveryCheckKey != addressKey) {
                _checkDeliveryAvailability(selectedAddress);
                _loadWeatherForAddress(selectedAddress);
              }
            });
          }
        }

        return Consumer<CartProvider>(
          builder: (context, cartProvider, _) {
            final cartItems = cartProvider.items;

            if (cartItems.isEmpty) {
              return Scaffold(
                backgroundColor: const Color(0xFFF7FAF8),
                appBar: _buildAppBar(context),
                body: _buildEmptyCartView(context),
              );
            }

            final double subtotal = _calculateSubtotal(cartItems);
            final double deliveryFee = _getDeliveryFee();
            const double handlingFee = 5;
            const double platformFee = 5;
            final double grandTotal = subtotal + deliveryFee + handlingFee + platformFee;

            return Scaffold(
              backgroundColor: const Color(0xFFF7FAF8),
              appBar: _buildAppBar(context),
              body: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    children: [
                      // 1. Delivery ETA Banner (Delivery in 8 to 10 minutes)
                      _buildDeliveryEtaBanner(cartItems.length),

                      // 2. Interactive Cart Items Card with steppers & move to wishlist
                      _buildCartItemsCard(context, cartItems),

                      const SizedBox(height: 16),

                      // 3. You might also like recommendations
                      _buildRecommendations(cartItems),

                      const SizedBox(height: 16),

                      // 4. Undeliverable Alert (only displayed if selected address cannot be served)
                      if (deliveryAvailability != null &&
                          !deliveryAvailability!.isDeliverable) ...[
                        _deliveryAvailabilityCard(),
                        const SizedBox(height: 16),
                      ],

                      // 5. Bill Details Card
                      _buildBillDetailsCard(
                        subtotal: subtotal,
                        deliveryFee: deliveryFee,
                        handlingFee: handlingFee,
                        platformFee: platformFee,
                        grandTotal: grandTotal,
                      ),

                      // 6. Cancellation policy note
                      _buildCancellationPolicyNote(),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: _buildStickyBottomBar(
                addresses: addresses,
                grandTotal: grandTotal,
                deliveryFee: deliveryFee,
              ),
            );
          },
        );
      },
    );
  }
}