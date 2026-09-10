import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/address.dart';
import '../theme/app_colors.dart';
import 'location_map_screen.dart';

class EditAddressScreen extends StatefulWidget {
  final Address address;

  const EditAddressScreen({super.key, required this.address});

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================
  // FIREBASE
  // ==========================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================================
  // FORM
  // ==========================================================

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;

  late final TextEditingController _phoneController;

  late final TextEditingController _houseController;

  late final TextEditingController _areaController;

  late final TextEditingController _cityController;

  late final TextEditingController _stateController;

  late final TextEditingController _pincodeController;

  // ==========================================================
  // STATE
  // ==========================================================

  late bool _isDefault;

  late double? _latitude;
  late double? _longitude;

  bool _saving = false;
  bool _gettingLocation = false;
  bool _deleting = false;

  // ==========================================================
  // ANIMATION
  // ==========================================================

  late final AnimationController _animationController;

  late final Animation<double> _fadeAnimation;

  late final Animation<Offset> _slideAnimation;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    final address = widget.address;

    _fullNameController = TextEditingController(text: address.fullName);

    _phoneController = TextEditingController(text: address.phone);

    _houseController = TextEditingController(text: address.house);

    _areaController = TextEditingController(text: address.area);

    _cityController = TextEditingController(text: address.city);

    _stateController = TextEditingController(text: address.state);

    _pincodeController = TextEditingController(text: address.pincode);

    _isDefault = address.isDefault;

    _latitude = address.latitude;

    _longitude = address.longitude;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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

  // ==========================================================
  // VALIDATORS
  // ==========================================================

  String? _required(String? value, String label) {
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

  // ==========================================================
  // FORM FIELD
  // ==========================================================

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
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

  // ==========================================================
  // SECTION HEADER
  // ==========================================================

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

  // ==========================================================
  // LOCATION
  // ==========================================================

  Future<void> _updateLocation() async {
    if (_gettingLocation || _saving) {
      return;
    }

    setState(() {
      _gettingLocation = true;
    });

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
          'Location permission is permanently denied. Enable it from device settings.',
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

      _latitude = position.latitude;

      _longitude = position.longitude;

      if (mounted) {
        setState(() {});
      }

      await _reverseGeocode(position.latitude, position.longitude);

      if (!mounted) return;

      _showMessage('Delivery location updated.', success: true);
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
        setState(() {
          _gettingLocation = false;
        });
      }
    }
  }

  // ==========================================================
  // REVERSE GEOCODING
  // ==========================================================

  Future<void> _reverseGeocode(double latitude, double longitude) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2'
        '&lat=$latitude'
        '&lon=$longitude'
        '&addressdetails=1'
        '&zoom=18'
        '&accept-language=en',
      );

      final response = await http
          .get(uri, headers: const {'User-Agent': 'DontBlink/1.0'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        return;
      }

      final rawAddress = decoded['address'];

      if (rawAddress is! Map) {
        return;
      }

      final address = Map<String, dynamic>.from(rawAddress);

      if (!mounted) return;

      setState(() {
        final houseNumber = address['house_number']?.toString().trim();

        final road = address['road']?.toString().trim();

        if ((houseNumber != null && houseNumber.isNotEmpty) ||
            (road != null && road.isNotEmpty)) {
          _houseController.text = [
            if (houseNumber != null && houseNumber.isNotEmpty) houseNumber,
            if (road != null && road.isNotEmpty) road,
          ].join(' ');
        }

        final area = address['suburb']?.toString().trim().isNotEmpty == true
            ? address['suburb'].toString().trim()
            : address['neighbourhood']?.toString().trim().isNotEmpty == true
            ? address['neighbourhood'].toString().trim()
            : address['village']?.toString().trim() ?? '';

        if (area.isNotEmpty) {
          _areaController.text = area;
        }

        final city = address['city']?.toString().trim().isNotEmpty == true
            ? address['city'].toString().trim()
            : address['town']?.toString().trim().isNotEmpty == true
            ? address['town'].toString().trim()
            : address['village']?.toString().trim() ?? '';

        if (city.isNotEmpty) {
          _cityController.text = city;
        }

        final state = address['state']?.toString().trim() ?? '';

        if (state.isNotEmpty) {
          _stateController.text = state;
        }

        final pincode = address['postcode']?.toString().trim() ?? '';

        if (pincode.isNotEmpty) {
          _pincodeController.text = pincode;
        }
      });
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    }
  }

  // ==========================================================
  // MAP
  // ==========================================================

  Future<void> _viewMap() async {
    if (_latitude == null || _longitude == null) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationMapScreen(
          customerLatitude: _latitude!,
          customerLongitude: _longitude!,
        ),
      ),
    );
  }

  // ==========================================================
  // SAVE
  // ==========================================================

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_latitude == null || _longitude == null) {
      _showMessage(
        'Please add a delivery location before saving.',
        error: true,
      );
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please sign in again.', error: true);
      return;
    }

    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final addressRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .doc(widget.address.id);

      final batch = _firestore.batch();

      if (_isDefault) {
        final existing = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .where('isDefault', isEqualTo: true)
            .get();

        for (final doc in existing.docs) {
          if (doc.id != widget.address.id) {
            batch.update(doc.reference, {'isDefault': false});
          }
        }
      }

      batch.set(addressRef, {
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'house': _houseController.text.trim(),
        'area': _areaController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'isDefault': _isDefault,
        'latitude': _latitude,
        'longitude': _longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;

      _showMessage('Address updated successfully.', success: true);

      await Future<void>.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ==========================================================
  // LOCATION CARD
  // ==========================================================

  Widget _locationCard() {
    final available = _latitude != null && _longitude != null;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: available ? AppColors.tintGreen : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: available ? AppColors.tintGreenBorder : Colors.orange.shade100,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  available
                      ? Icons.location_on_rounded
                      : Icons.location_off_outlined,
                  color: available ? AppColors.primary : Colors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      available
                          ? 'Delivery location saved'
                          : 'Delivery location missing',
                      style: TextStyle(
                        color: available
                            ? AppColors.primary
                            : Colors.orange.shade800,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      available
                          ? 'Your current coordinates are saved with this address.'
                          : 'Add a location before saving this address.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (available)
                const Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _gettingLocation || _saving ? null : _updateLocation,
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
                      available
                          ? Icons.refresh_rounded
                          : Icons.my_location_rounded,
                    ),
              label: Text(
                _gettingLocation
                    ? 'UPDATING LOCATION...'
                    : available
                    ? 'UPDATE LOCATION'
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
          if (available) ...[
            const SizedBox(height: 5),
            TextButton.icon(
              onPressed: _viewMap,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text(
                'VIEW ON MAP',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // DEFAULT
  // ==========================================================

  Widget _defaultCard() {
    return Container(
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
                setState(() {
                  _isDefault = value;
                });
              },
      ),
    );
  }

  // ==========================================================
  // DELETE
  // ==========================================================

  Future<void> _deleteAddress() async {
    if (_deleting || _saving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Delete Address?',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: const Text(
            'This saved address will be permanently removed from your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please sign in again.', error: true);
      return;
    }

    setState(() {
      _deleting = true;
    });

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .doc(widget.address.id)
          .delete();

      if (!mounted) return;

      _showMessage('Address deleted.', success: true);

      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
        });
      }
    }
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void _showMessage(
    String message, {
    bool error = false,
    bool success = false,
  }) {
    if (!mounted) {
      return;
    }

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

  // ==========================================================
  // BUILD
  // ==========================================================

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
          'Edit Address',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Delete address',
            onPressed: _deleting || _saving ? null : _deleteAddress,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Form(
            key: _formKey,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 115),
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
                        Icons.edit_location_alt_outlined,
                        color: Colors.white,
                        size: 31,
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update your address',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Change your details or delivery location.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                _sectionHeader(
                  icon: Icons.person_outline,
                  title: 'Personal Details',
                  subtitle: 'Update the person receiving this order.',
                ),

                _field(
                  controller: _fullNameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => _required(value, 'Full Name'),
                ),

                _field(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textCapitalization: TextCapitalization.none,
                  maxLength: 10,
                  validator: _phoneValidator,
                ),

                const SizedBox(height: 7),

                _sectionHeader(
                  icon: Icons.home_outlined,
                  title: 'Address Details',
                  subtitle: 'Keep your delivery information accurate.',
                ),

                _field(
                  controller: _houseController,
                  label: 'House / Flat No.',
                  icon: Icons.home_outlined,
                  validator: (value) => _required(value, 'House / Flat No.'),
                ),

                _field(
                  controller: _areaController,
                  label: 'Area / Locality',
                  icon: Icons.location_city_outlined,
                  validator: (value) => _required(value, 'Area / Locality'),
                ),

                _field(
                  controller: _cityController,
                  label: 'City',
                  icon: Icons.location_city,
                  validator: (value) => _required(value, 'City'),
                ),

                _field(
                  controller: _stateController,
                  label: 'State',
                  icon: Icons.map_outlined,
                  validator: (value) => _required(value, 'State'),
                ),

                _field(
                  controller: _pincodeController,
                  label: 'PIN Code',
                  icon: Icons.markunread_mailbox_outlined,
                  keyboardType: TextInputType.number,
                  textCapitalization: TextCapitalization.none,
                  maxLength: 6,
                  validator: _pincodeValidator,
                ),

                const SizedBox(height: 5),

                _sectionHeader(
                  icon: Icons.location_on_outlined,
                  title: 'Delivery Location',
                  subtitle: 'Update the exact location used for delivery.',
                ),

                _locationCard(),

                const SizedBox(height: 15),

                _defaultCard(),

                const SizedBox(height: 22),

                SizedBox(
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _saving || _deleting ? null : _saveChanges,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'SAVING CHANGES...' : 'SAVE CHANGES',
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
                      'Your address is saved securely',
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

  // ==========================================================
  // DISPOSE
  // ==========================================================

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
