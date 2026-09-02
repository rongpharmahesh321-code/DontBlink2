import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../models/address.dart';
import '../services/address_service.dart';
import 'location_map_screen.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();

  final phoneController = TextEditingController();

  final houseController = TextEditingController();

  final areaController = TextEditingController();

  final cityController = TextEditingController();

  final stateController = TextEditingController();

  final pincodeController = TextEditingController();

  bool isDefault = false;

  bool loading = false;

  bool gettingLocation = false;

  double? latitude;

  double? longitude;

  final AddressService addressService = AddressService();

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    houseController.dispose();
    areaController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();

    super.dispose();
  }

  // ==========================================
  // FORM FIELD
  // ==========================================

  Widget buildField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),

      child: TextFormField(
        controller: controller,

        keyboardType: keyboardType,

        maxLines: maxLines,

        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "Please enter $label";
          }

          return null;
        },

        decoration: InputDecoration(
          labelText: label,

          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ==========================================
  // GET CURRENT LOCATION
  // ==========================================

  Future<void> getCurrentLocation() async {
    if (gettingLocation) return;

    setState(() {
      gettingLocation = true;
    });

    try {
      // ========================================
      // CHECK GPS
      // ========================================

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception("Please turn on Location/GPS.");
      }

      // ========================================
      // CHECK PERMISSION
      // ========================================

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied.");
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          "Location permission permanently denied. "
          "Enable it from Android Settings.",
        );
      }

      // ========================================
      // TRY LAST KNOWN LOCATION FIRST
      // ========================================

      Position? position;

      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {
        position = null;
      }

      // ========================================
      // USE LAST LOCATION IF AVAILABLE
      // ========================================

      if (position != null) {
        debugPrint(
          "Using last known location: "
          "${position.latitude}, "
          "${position.longitude}",
        );
      }

      // ========================================
      // GET FRESH LOCATION
      // ========================================

      if (position == null) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        ).timeout(const Duration(seconds: 12));
      }

      // ========================================
      // SAVE COORDINATES IMMEDIATELY
      // ========================================

      latitude = position.latitude;

      longitude = position.longitude;

      if (mounted) {
        setState(() {});
      }

      debugPrint(
        "Customer location: "
        "$latitude, $longitude",
      );

      // ========================================
      // REVERSE GEOCODING
      // ========================================

      await _reverseGeocode(position.latitude, position.longitude);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Location detected successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } on TimeoutException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Location is taking too long. "
            "Please try again.",
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          gettingLocation = false;
        });
      }
    }
  }
  // ==========================================
  // REVERSE GEOCODING
  // ==========================================

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2'
        '&lat=$lat'
        '&lon=$lon'
        '&addressdetails=1'
        '&zoom=18'
        '&accept-language=en',
      );

      final response = await http
          .get(url, headers: {'User-Agent': 'DontBlink/1.0'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint(
          'Reverse geocoding failed: '
          '${response.statusCode}',
        );
        return;
      }

      final data = jsonDecode(response.body);

      final address = data['address'] ?? {};

      if (!mounted) return;

      setState(() {
        houseController.text = address['house_number'] ?? '';

        areaController.text =
            address['suburb'] ??
            address['neighbourhood'] ??
            address['village'] ??
            address['town'] ??
            '';

        cityController.text =
            address['city'] ?? address['town'] ?? address['village'] ?? '';

        stateController.text = address['state'] ?? '';

        pincodeController.text = address['postcode'] ?? '';
      });
    } on TimeoutException {
      debugPrint('Reverse geocoding timed out.');

      // GPS coordinates are already saved.
      // User can enter the address manually.
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    }
  }

  // ==========================================
  // SAVE ADDRESS
  // ==========================================

  Future<void> saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select your location first."),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final address = Address(
        id: "",

        fullName: fullNameController.text.trim(),

        phone: phoneController.text.trim(),

        house: houseController.text.trim(),

        area: areaController.text.trim(),

        city: cityController.text.trim(),

        state: stateController.text.trim(),

        pincode: pincodeController.text.trim(),

        isDefault: isDefault,

        latitude: latitude,

        longitude: longitude,
      );

      await addressService.addAddress(address);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Address saved successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Address"),

        backgroundColor: Colors.green,

        foregroundColor: Colors.white,
      ),

      body: Form(
        key: _formKey,

        child: ListView(
          padding: const EdgeInsets.all(16),

          children: [
            buildField(controller: fullNameController, label: "Full Name"),

            buildField(
              controller: phoneController,
              label: "Phone Number",
              keyboardType: TextInputType.phone,
            ),

            buildField(controller: houseController, label: "House / Flat No."),

            buildField(controller: areaController, label: "Area / Locality"),

            buildField(controller: cityController, label: "City"),

            buildField(controller: stateController, label: "State"),

            buildField(
              controller: pincodeController,
              label: "PIN Code",
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 5),

            // ==================================
            // CURRENT LOCATION
            // ==================================
            SizedBox(
              height: 52,

              child: OutlinedButton.icon(
                icon: gettingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        latitude == null
                            ? Icons.my_location
                            : Icons.check_circle,
                      ),

                label: Text(
                  gettingLocation
                      ? "Getting Location..."
                      : latitude == null
                      ? "USE CURRENT LOCATION"
                      : "LOCATION CAPTURED ✓",
                ),

                onPressed: gettingLocation ? null : getCurrentLocation,

                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,

                  side: const BorderSide(color: Colors.green),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // ==================================
            // VIEW LOCATION ON MAP
            // ==================================
            if (latitude != null && longitude != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 15),

                child: ElevatedButton.icon(
                  icon: const Icon(Icons.map),

                  label: const Text("VIEW ON MAP"),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,

                    foregroundColor: Colors.white,

                    minimumSize: const Size(double.infinity, 52),
                  ),

                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LocationMapScreen(
                          customerLatitude: latitude!,
                          customerLongitude: longitude!,
                        ),
                      ),
                    );
                  },
                ),
              ),

            // ==================================
            // DEFAULT ADDRESS
            // ==================================
            SwitchListTile(
              value: isDefault,

              activeColor: Colors.green,

              title: const Text("Set as Default Address"),

              onChanged: (value) {
                setState(() {
                  isDefault = value;
                });
              },
            ),

            const SizedBox(height: 25),

            // ==================================
            // SAVE ADDRESS
            // ==================================
            SizedBox(
              height: 55,

              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),

                onPressed: loading ? null : saveAddress,

                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "SAVE ADDRESS",

                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
