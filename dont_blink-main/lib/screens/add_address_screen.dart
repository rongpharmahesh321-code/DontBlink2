import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/address.dart';
import '../services/address_service.dart';
import '../theme/app_colors.dart';
import 'google_address_picker_screen.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _houseController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();

  final AddressService _addressService = AddressService();

  bool _isDefault = false;
  bool _saving = false;
  bool _gettingLocation = false;

  double? _latitude;
  double? _longitude;
  String _formattedAddress = '';

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  String? _requiredValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $label';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return 'Please enter Phone Number';
    }

    final cleaned = phone.replaceAll(RegExp(r'[\s-]'), '');

    if (!RegExp(r'^\d{10}$').hasMatch(cleaned)) {
      return 'Enter a valid 10-digit number';
    }

    return null;
  }

  String? _pincodeValidator(String? value) {
    final pincode = value?.trim() ?? '';

    if (pincode.isEmpty) {
      return 'Please enter PIN Code';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(pincode)) {
      return 'Enter a valid 6-digit PIN';
    }

    return null;
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        maxLines: maxLines,
        maxLength: maxLength,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 21),
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: AppColors.tintGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    if (_gettingLocation || _saving) return;

    setState(() => _gettingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception('Please turn on Location/GPS.');
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Please enable it from your device settings.',
        );
      }

      Position? position;

      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {
        position = null;
      }

      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;

      setState(() {
        _latitude = position!.latitude;
        _longitude = position.longitude;
      });

      await _openGoogleAddressPicker(
        initialLatitude: position.latitude,
        initialLongitude: position.longitude,
      );
    } on TimeoutException {
      if (!mounted) return;
      _showMessage(
        'Location is taking too long. Please try again.',
        error: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) {
        setState(() => _gettingLocation = false);
      }
    }
  }

  Future<void> _openGoogleAddressPicker({
    double? initialLatitude,
    double? initialLongitude,
  }) async {
    if (_saving) return;

    final result = await Navigator.push<GoogleAddressPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => GoogleAddressPickerScreen(
          initialLatitude: initialLatitude ?? _latitude,
          initialLongitude: initialLongitude ?? _longitude,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
      _formattedAddress = result.address;

      if (result.house.isNotEmpty) {
        _houseController.text = result.house;
      }

      if (result.area.isNotEmpty) {
        _areaController.text = result.area;
      }

      if (result.city.isNotEmpty) {
        _cityController.text = result.city;
      }

      if (result.state.isNotEmpty) {
        _stateController.text = result.state;
      }

      if (result.pincode.isNotEmpty) {
        _pincodeController.text = result.pincode;
      }
    });

    _showMessage('Delivery location updated.', success: true);
  }

  Future<void> _viewMap() async {
    await _openGoogleAddressPicker(
      initialLatitude: _latitude,
      initialLongitude: _longitude,
    );
  }

  Future<void> _saveAddress() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      _showMessage('Please select your delivery location first.', error: true);
      return;
    }

    if (_saving) return;

    setState(() => _saving = true);

    try {
      final address = Address(
        id: '',
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        house: _houseController.text.trim(),
        area: _areaController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        formattedAddress: _formattedAddress,
        isDefault: _isDefault,
        latitude: _latitude,
        longitude: _longitude,
      );

      await _addressService.addAddress(address);

      if (!mounted) return;

      _showMessage('Address saved successfully.', success: true);

      await Future<void>.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;

      Navigator.pop(context, address);
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildLocationCard() {
    final captured = _latitude != null && _longitude != null;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: captured ? AppColors.tintGreen : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: captured ? AppColors.tintGreenBorder : Colors.orange.shade100,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: captured ? Colors.white : Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  captured
                      ? Icons.location_on_rounded
                      : Icons.location_searching,
                  color: captured ? AppColors.primary : Colors.orange,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      captured
                          ? 'Delivery location captured'
                          : 'Delivery location required',
                      style: TextStyle(
                        color: captured ? AppColors.primary : Colors.orange.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      captured
                          ? 'Your exact map location will be used for delivery.'
                          : 'Choose your delivery location on Google Maps.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (captured)
                const Icon(Icons.check_circle, color: AppColors.primary, size: 21),
            ],
          ),
          if (_formattedAddress.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.place_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formattedAddress,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _gettingLocation ? null : _getCurrentLocation,
              icon: _gettingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(
                      captured
                          ? Icons.my_location_rounded
                          : Icons.my_location_rounded,
                    ),
              label: Text(
                _gettingLocation
                    ? 'GETTING LOCATION...'
                    : captured
                    ? 'USE CURRENT LOCATION'
                    : 'USE CURRENT LOCATION',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _viewMap,
              icon: const Icon(Icons.map_outlined, size: 20),
              label: Text(
                captured ? 'CHANGE LOCATION ON MAP' : 'CHOOSE LOCATION ON MAP',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultCard() {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SwitchListTile.adaptive(
        value: _isDefault,
        activeColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.tintGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.star_outline_rounded, color: AppColors.primary),
        ),
        title: const Text(
          'Set as Default Address',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Use this address automatically at checkout.',
          style: TextStyle(fontSize: 10),
        ),
        onChanged: _saving
            ? null
            : (value) {
                setState(() => _isDefault = value);
              },
      ),
    );
  }

  void _showMessage(
    String message, {
    bool error = false,
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error
              ? Colors.red
              : success
              ? AppColors.primary
              : Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Add Address',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Form(
            key: _formKey,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(19),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add your delivery address',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Save your details and location for faster checkout.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _sectionTitle(
                  icon: Icons.person_outline,
                  title: 'Personal Details',
                  subtitle: 'Who should receive the order?',
                ),
                _buildField(
                  controller: _fullNameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => _requiredValidator(value, 'Full Name'),
                ),
                _buildField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textCapitalization: TextCapitalization.none,
                  maxLength: 10,
                  validator: _phoneValidator,
                ),
                const SizedBox(height: 7),
                _sectionTitle(
                  icon: Icons.home_outlined,
                  title: 'Address Details',
                  subtitle: 'Enter the address where your order should arrive.',
                ),
                _buildField(
                  controller: _houseController,
                  label: 'House / Flat No.',
                  icon: Icons.home_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      _requiredValidator(value, 'House / Flat No.'),
                ),
                _buildField(
                  controller: _areaController,
                  label: 'Area / Locality',
                  icon: Icons.location_city_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      _requiredValidator(value, 'Area / Locality'),
                ),
                _buildField(
                  controller: _cityController,
                  label: 'City',
                  icon: Icons.location_city,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => _requiredValidator(value, 'City'),
                ),
                _buildField(
                  controller: _stateController,
                  label: 'State',
                  icon: Icons.map_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => _requiredValidator(value, 'State'),
                ),
                _buildField(
                  controller: _pincodeController,
                  label: 'PIN Code',
                  icon: Icons.markunread_mailbox_outlined,
                  keyboardType: TextInputType.number,
                  textCapitalization: TextCapitalization.none,
                  maxLength: 6,
                  validator: _pincodeValidator,
                ),
                const SizedBox(height: 5),
                _sectionTitle(
                  icon: Icons.location_on_outlined,
                  title: 'Delivery Location',
                  subtitle: 'A precise map location is required for delivery.',
                ),
                _buildLocationCard(),
                const SizedBox(height: 15),
                _buildDefaultCard(),
                const SizedBox(height: 20),
                SizedBox(
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveAddress,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _saving ? 'SAVING ADDRESS...' : 'SAVE ADDRESS',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: Colors.grey.shade500,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Your address is saved securely to your account',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _houseController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }
}
