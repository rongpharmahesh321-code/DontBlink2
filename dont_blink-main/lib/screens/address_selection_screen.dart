import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/address_service.dart';

class AddressSelectionScreen extends StatefulWidget {
  // ==========================================================
  // CALLBACK
  //
  // AuthGate uses this to know that an address has been saved.
  // ==========================================================

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
  // MAP
  // ==========================================================

  final MapController _mapController = MapController();

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

  static const Color green = Colors.green;

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      // GET CURRENT LOCATION
      // --------------------------------------------------------

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final location = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {
        _selectedLocation = location;
      });

      // --------------------------------------------------------
      // MOVE MAP
      // --------------------------------------------------------

      _mapController.move(location, 17);

      // --------------------------------------------------------
      // REVERSE GEOCODE
      // --------------------------------------------------------

      await _reverseGeocode(location);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  // ==========================================================
  // REVERSE GEOCODING
  // ==========================================================

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2'
        '&lat=${location.latitude}'
        '&lon=${location.longitude}'
        '&zoom=18'
        '&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'Doorstepp/1.0',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Unable to find address.');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final displayName = data['display_name']?.toString() ?? '';

      if (!mounted) return;

      setState(() {
        _selectedAddress = displayName.trim();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _selectedAddress = '';
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Location found, but we could not get the address. '
              'You can search for it manually.',
            ),
          ),
        );
    }
  }

  // ==========================================================
  // SEARCH ADDRESS
  // ==========================================================

  Future<void> _searchAddress(String query) async {
    final text = query.trim();

    if (text.length < 3) {
      setState(() {
        _searchResults = [];
      });

      return;
    }

    if (_searching) {
      return;
    }

    setState(() {
      _searching = true;
    });

    try {
      final encoded = Uri.encodeQueryComponent(text);

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=jsonv2'
        '&q=$encoded'
        '&limit=5'
        '&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'Doorstepp/1.0',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Search failed.');
      }

      final List<dynamic> results = jsonDecode(response.body);

      final List<_SearchResult> parsed = [];

      for (final result in results) {
        if (result is! Map<String, dynamic>) {
          continue;
        }

        final lat = double.tryParse(result['lat']?.toString() ?? '');

        final lon = double.tryParse(result['lon']?.toString() ?? '');

        final displayName = result['display_name']?.toString() ?? '';

        if (lat == null || lon == null || displayName.isEmpty) {
          continue;
        }

        parsed.add(
          _SearchResult(location: LatLng(lat, lon), address: displayName),
        );
      }

      if (!mounted) return;

      setState(() {
        _searchResults = parsed;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to search for that address.'),
            backgroundColor: Colors.red,
          ),
        );
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

    setState(() {
      _selectedLocation = result.location;
      _selectedAddress = result.address;
      _searchResults = [];
      _searchController.text = result.address;
    });

    _mapController.move(result.location, 17);
  }

  // ==========================================================
  // CONFIRM ADDRESS
  // ==========================================================

  Future<void> _confirmAddress() async {
    if (_saving) {
      return;
    }

    // --------------------------------------------------------
    // LOCATION CHECK
    // --------------------------------------------------------

    final location = _selectedLocation;

    if (location == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please select your delivery location first.'),
            backgroundColor: Colors.orange,
          ),
        );

      return;
    }

    // --------------------------------------------------------
    // ADDRESS CHECK
    // --------------------------------------------------------

    if (_selectedAddress.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please select a valid address.'),
            backgroundColor: Colors.orange,
          ),
        );

      return;
    }

    // --------------------------------------------------------
    // START SAVING
    // --------------------------------------------------------

    setState(() {
      _saving = true;
    });

    try {
      // ------------------------------------------------------
      // SAVE TO:
      //
      // users/{uid}/addresses/{addressId}
      // ------------------------------------------------------

      await addressService.saveSelectedLocation(
        address: _selectedAddress.trim(),
        latitude: location.latitude,
        longitude: location.longitude,
      );

      if (!mounted) return;

      // ------------------------------------------------------
      // TELL AUTHGATE
      // ------------------------------------------------------

      widget.onAddressSaved?.call();

      // ------------------------------------------------------
      // SUCCESS MESSAGE
      // ------------------------------------------------------

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Delivery address saved!'),
            backgroundColor: Colors.green,
          ),
        );

      // ------------------------------------------------------
      // SMALL DELAY FOR SUCCESS FEEDBACK
      // ------------------------------------------------------

      await Future.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;

      // ------------------------------------------------------
      // RETURN
      //
      // If opened from another screen, return there.
      // AuthGate will already have switched to MainScreen.
      // ------------------------------------------------------

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Unable to save address: '
              '${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
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
  // LOCATION MARKER
  // ==========================================================

  Widget _locationMarker() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: green,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: const Icon(Icons.location_on, color: Colors.white, size: 27),
    );
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
          // MAP
          // ====================================================
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,

                  options: MapOptions(
                    initialCenter: location ?? const LatLng(25.8438, 93.4348),
                    initialZoom: location == null ? 13 : 17,

                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),

                    onTap: (_, point) async {
                      if (_saving) {
                        return;
                      }

                      setState(() {
                        _selectedLocation = point;
                        _searchResults = [];
                      });

                      await _reverseGeocode(point);
                    },
                  ),

                  children: [
                    // ------------------------------------------
                    // MAP
                    // ------------------------------------------
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/'
                          '{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.dontblink.app',
                    ),

                    // ------------------------------------------
                    // MARKER
                    // ------------------------------------------
                    if (location != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: location,
                            width: 60,
                            height: 60,
                            child: _locationMarker(),
                          ),
                        ],
                      ),
                  ],
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
                  // ==================================================
                  // ADDRESS TITLE
                  // ==================================================
                  const Text(
                    'Deliver to',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),

                  const SizedBox(height: 5),

                  // ==================================================
                  // SELECTED ADDRESS
                  // ==================================================
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
