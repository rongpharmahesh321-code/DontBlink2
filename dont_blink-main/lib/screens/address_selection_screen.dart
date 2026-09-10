import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../services/address_service.dart';

class AddressSelectionScreen extends StatefulWidget {
  final VoidCallback? onAddressSaved;

  const AddressSelectionScreen({super.key, this.onAddressSaved});

  @override
  State<AddressSelectionScreen> createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends State<AddressSelectionScreen> {
  // ==========================================================
  // SERVICE
  // ==========================================================

  final AddressService addressService = AddressService();

  // ==========================================================
  // GOOGLE CONFIG CHANNEL
  // ==========================================================

  static const MethodChannel _googleConfigChannel = MethodChannel(
    'com.doorstepp.app/google_config',
  );

  // ==========================================================
  // MAP
  // ==========================================================

  GoogleMapController? _mapController;

  static const LatLng _defaultLocation = LatLng(25.8438, 93.4348);

  LatLng? _selectedLocation;

  bool _loadingLocation = false;
  bool _saving = false;

  // ==========================================================
  // ADDRESS
  // ==========================================================

  String _selectedAddress = '';

  // ==========================================================
  // SEARCH
  // ==========================================================

  final TextEditingController _searchController = TextEditingController();

  bool _searching = false;

  List<_SearchResult> _searchResults = [];

  // ==========================================================
  // COLORS
  // ==========================================================

  static const Color green = Color(0xFF168A43);

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================================
  // GOOGLE WEB API KEY
  // ==========================================================

  Future<String> _getGoogleWebApiKey() async {
    try {
      final key = await _googleConfigChannel.invokeMethod<String>(
        'getGoogleWebApiKey',
      );

      if (key == null || key.trim().isEmpty) {
        throw Exception('Google Web API key is not configured.');
      }

      return key.trim();
    } on PlatformException catch (e) {
      debugPrint('Google API key error: ${e.message}');

      throw Exception('Unable to load Google API configuration.');
    } catch (e) {
      rethrow;
    }
  }

  // ==========================================================
  // MAP CREATED
  // ==========================================================

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  // ==========================================================
  // MOVE MAP
  // ==========================================================

  Future<void> _moveTo(LatLng location, {double zoom = 17}) async {
    final controller = _mapController;

    if (controller == null) {
      return;
    }

    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: zoom),
        ),
      );
    } catch (e) {
      debugPrint('Map camera error: $e');
    }
  }

  // ==========================================================
  // CURRENT LOCATION
  // ==========================================================

  Future<void> _useCurrentLocation() async {
    if (_saving || _loadingLocation) {
      return;
    }

    setState(() {
      _loadingLocation = true;
      _searchResults = [];
    });

    try {
      // --------------------------------------------------------
      // LOCATION SERVICE
      // --------------------------------------------------------

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Location services are turned off. '
          'Please enable location services.',
        );
      }

      // --------------------------------------------------------
      // PERMISSION
      // --------------------------------------------------------

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. '
          'Please enable it from Settings.',
        );
      }

      // --------------------------------------------------------
      // LAST KNOWN LOCATION FIRST
      // --------------------------------------------------------

      Position? position;

      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {
        position = null;
      }

      // --------------------------------------------------------
      // CURRENT LOCATION
      // --------------------------------------------------------

      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 12));

      final location = LatLng(position.latitude, position.longitude);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedLocation = location;
      });

      // --------------------------------------------------------
      // MOVE MAP
      // --------------------------------------------------------

      await _moveTo(location);

      // --------------------------------------------------------
      // GOOGLE REVERSE GEOCODING
      // --------------------------------------------------------

      await _reverseGeocode(location);
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Location is taking too long. Please try again.',
        error: true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  // ==========================================================
  // GOOGLE REVERSE GEOCODING
  // ==========================================================

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      final key = await _getGoogleWebApiKey();

      final url = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': '${location.latitude},${location.longitude}',
        'language': 'en',
        'key': key,
      });

      final response = await http
          .get(url, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Google address lookup failed.');
      }

      final data = jsonDecode(response.body);

      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid Google address response.');
      }

      final status = data['status']?.toString();

      if (status != 'OK') {
        final errorMessage = data['error_message']?.toString();

        throw Exception(
          errorMessage?.isNotEmpty == true
              ? errorMessage!
              : 'Google address lookup failed: $status',
        );
      }

      final results = data['results'];

      if (results is! List || results.isEmpty) {
        throw Exception('No address found for this location.');
      }

      final first = results.first;

      if (first is! Map) {
        throw Exception('Invalid address result.');
      }

      final formattedAddress =
          first['formatted_address']?.toString().trim() ?? '';

      if (formattedAddress.isEmpty) {
        throw Exception('No valid address found.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedAddress = formattedAddress;
      });
    } catch (e) {
      debugPrint('Google reverse geocoding error: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedAddress = '';
      });

      _showMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  // ==========================================================
  // GOOGLE ADDRESS SEARCH
  // ==========================================================

  Future<void> _searchAddress(String query) async {
    final text = query.trim();

    if (text.length < 3) {
      if (mounted) {
        setState(() {
          _searchResults = [];
        });
      }

      return;
    }

    if (_searching || _saving) {
      return;
    }

    setState(() {
      _searching = true;
    });

    try {
      final key = await _getGoogleWebApiKey();

      final url = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'address': text,
        'components': 'country:IN',
        'language': 'en',
        'region': 'in',
        'key': key,
      });

      final response = await http
          .get(url, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Google address search failed.');
      }

      final data = jsonDecode(response.body);

      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid Google search response.');
      }

      final status = data['status']?.toString();

      if (status != 'OK' && status != 'ZERO_RESULTS') {
        final errorMessage = data['error_message']?.toString();

        throw Exception(
          errorMessage?.isNotEmpty == true
              ? errorMessage!
              : 'Google address search failed: $status',
        );
      }

      final rawResults = data['results'];

      if (rawResults is! List) {
        throw Exception('No search results available.');
      }

      final List<_SearchResult> parsed = [];

      for (final result in rawResults) {
        if (result is! Map) {
          continue;
        }

        final formattedAddress =
            result['formatted_address']?.toString().trim() ?? '';

        final geometry = result['geometry'];

        if (geometry is! Map) {
          continue;
        }

        final location = geometry['location'];

        if (location is! Map) {
          continue;
        }

        final lat = (location['lat'] as num?)?.toDouble();

        final lng = (location['lng'] as num?)?.toDouble();

        if (lat == null || lng == null || formattedAddress.isEmpty) {
          continue;
        }

        parsed.add(
          _SearchResult(location: LatLng(lat, lng), address: formattedAddress),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _searchResults = parsed.take(5).toList();
      });

      if (parsed.isEmpty) {
        _showMessage('No matching address was found.', error: true);
      }
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Google address search timed out. Please try again.',
        error: true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  // ==========================================================
  // SELECT SEARCH RESULT
  // ==========================================================

  Future<void> _selectSearchResult(_SearchResult result) async {
    FocusScope.of(context).unfocus();

    if (_saving) {
      return;
    }

    setState(() {
      _selectedLocation = result.location;

      _selectedAddress = result.address;

      _searchResults = [];

      _searchController.text = result.address;
    });

    await _moveTo(result.location);
  }

  // ==========================================================
  // MAP TAP
  // ==========================================================

  Future<void> _selectMapLocation(LatLng location) async {
    if (_saving) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _selectedLocation = location;

      _selectedAddress = '';

      _searchResults = [];
    });

    await _reverseGeocode(location);
  }

  // ==========================================================
  // CONFIRM ADDRESS
  // ==========================================================

  Future<void> _confirmAddress() async {
    if (_saving) {
      return;
    }

    final location = _selectedLocation;

    if (location == null) {
      _showMessage('Please select your delivery location first.', error: true);

      return;
    }

    if (_selectedAddress.trim().isEmpty) {
      _showMessage('Please select a valid address.', error: true);

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await addressService.saveSelectedLocation(
        address: _selectedAddress.trim(),
        latitude: location.latitude,
        longitude: location.longitude,
      );

      if (!mounted) {
        return;
      }

      widget.onAddressSaved?.call();

      _showMessage('Delivery address saved!', success: true);

      await Future.delayed(const Duration(milliseconds: 350));

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to save address: '
        '${e.toString().replaceFirst('Exception: ', '')}',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ==========================================================
  // SEARCH RESULT WIDGET
  // ==========================================================

  Widget _buildSearchResult(_SearchResult result) {
    return ListTile(
      leading: const Icon(Icons.location_on, color: green),
      title: Text(result.address, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () {
        _selectSearchResult(result);
      },
    );
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
              ? green
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
    final location = _selectedLocation;

    return Scaffold(
      backgroundColor: const Color(0xffF7F8FA),

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        title: const Text(
          'Select Delivery Location',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: Column(
        children: [
          // ====================================================
          // SEARCH
          // ====================================================

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              enabled: !_saving,
              textInputAction: TextInputAction.search,
              onSubmitted: _searchAddress,
              decoration: InputDecoration(
                hintText: 'Search area, street, landmark...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: green,
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: _saving
                            ? null
                            : () {
                                _searchAddress(_searchController.text);
                              },
                        icon: const Icon(Icons.arrow_forward),
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 17),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ====================================================
          // SEARCH RESULTS
          // ====================================================
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              constraints: const BoxConstraints(maxHeight: 190),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return _buildSearchResult(_searchResults[index]);
                },
              ),
            ),

          // ====================================================
          // GOOGLE MAP
          // ====================================================
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: location ?? _defaultLocation,
                    zoom: location == null ? 13 : 17,
                  ),
                  onMapCreated: _onMapCreated,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  rotateGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  onTap: _selectMapLocation,
                  markers: {
                    if (location != null)
                      Marker(
                        markerId: const MarkerId('selected_delivery_location'),
                        position: location,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen,
                        ),
                        infoWindow: InfoWindow(
                          title: 'Delivery location',
                          snippet: _selectedAddress.isEmpty
                              ? 'Selected location'
                              : _selectedAddress,
                        ),
                      ),
                  },
                ),

                // =================================================
                // CURRENT LOCATION BUTTON
                // =================================================
                Positioned(
                  right: 16,
                  bottom: 20,
                  child: FloatingActionButton(
                    heroTag: 'select_location_current',
                    backgroundColor: Colors.white,
                    foregroundColor: green,
                    onPressed: _loadingLocation || _saving
                        ? null
                        : _useCurrentLocation,
                    child: _loadingLocation
                        ? const SizedBox(
                            width: 23,
                            height: 23,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: green,
                            ),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),

          // ====================================================
          // ADDRESS PANEL
          // ====================================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 15,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deliver to',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),

                  const SizedBox(height: 5),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: green, size: 24),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          _selectedAddress.isEmpty
                              ? 'Select your delivery location'
                              : _selectedAddress,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ==================================================
                  // USE CURRENT LOCATION
                  // ==================================================
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _loadingLocation || _saving
                          ? null
                          : _useCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text(
                        'USE CURRENT LOCATION',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: green,
                        side: const BorderSide(color: green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ==================================================
                  // CONFIRM
                  // ==================================================
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _confirmAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'CONFIRM LOCATION',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// SEARCH RESULT MODEL
// =============================================================

class _SearchResult {
  final LatLng location;
  final String address;

  const _SearchResult({required this.location, required this.address});
}
