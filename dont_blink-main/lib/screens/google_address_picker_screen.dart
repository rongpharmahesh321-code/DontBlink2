import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';

class GoogleAddressPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const GoogleAddressPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<GoogleAddressPickerScreen> createState() =>
      _GoogleAddressPickerScreenState();
}

class _GoogleAddressPickerScreenState extends State<GoogleAddressPickerScreen> {
  static const MethodChannel _googleConfigChannel = MethodChannel(
    'com.doorstepp.app/google_config',
  );

  GoogleMapController? _mapController;

  static const LatLng _defaultLocation = LatLng(25.8438, 93.4348);

  late LatLng _selectedLocation;

  String _selectedAddress = 'Move the map to select your location.';
  String _formattedAddress = '';

  String _house = '';
  String _area = '';
  String _city = '';
  String _state = '';
  String _pincode = '';

  bool _loadingAddress = false;
  bool _gettingLocation = false;
  bool _confirming = false;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<_PlaceSearchResult> _searchResults = [];
  bool _searching = false;

  String? _cachedApiKey;

  Future<String> _getApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }

    const envKey = String.fromEnvironment('GOOGLE_WEB_API_KEY', defaultValue: '');
    if (envKey.isNotEmpty) {
      _cachedApiKey = envKey;
      return envKey;
    }

    try {
      final key = await _googleConfigChannel.invokeMethod<String>(
        'getGoogleWebApiKey',
      );
      if (key != null && key.trim().isNotEmpty) {
        _cachedApiKey = key.trim();
        return _cachedApiKey!;
      }
    } catch (e) {
      debugPrint('Google API key error: $e');
    }

    return '';
  }

  @override
  void initState() {
    super.initState();

    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    } else {
      _selectedLocation = _defaultLocation;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reverseGeocode(_selectedLocation.latitude, _selectedLocation.longitude);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onCameraMove(CameraPosition position) {
    _selectedLocation = position.target;
  }

  Future<void> _onCameraIdle() async {
    await _reverseGeocode(
      _selectedLocation.latitude,
      _selectedLocation.longitude,
    );
  }

  Future<void> _useCurrentLocation() async {
    if (_gettingLocation || _confirming) return;

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
          'Location permission is permanently denied. Please enable location permission in Settings.',
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

      final location = LatLng(position.latitude, position.longitude);

      _selectedLocation = location;

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 17),
        ),
      );

      await _reverseGeocode(location.latitude, location.longitude);
    } on TimeoutException {
      _showMessage(
        'Location is taking too long. Please try again.',
        error: true,
      );
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _gettingLocation = false;
        });
      }
    }
  }

  Future<void> _reverseGeocode(double latitude, double longitude) async {
    if (_loadingAddress) return;

    final apiKey = await _getApiKey();
    if (apiKey.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingAddress = false;
          _selectedAddress =
              'Google web-service API key is not configured.';
        });
      }
      return;
    }

    setState(() {
      _loadingAddress = true;
    });

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$latitude,$longitude'
        '&language=en'
        '&region=in'
        '&key=$apiKey',
      );

      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Google Geocoding returned ${response.statusCode}.');
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw Exception('Invalid geocoding response.');
      }

      final status = decoded['status']?.toString();

      if (status != 'OK') {
        final errorMessage = decoded['error_message']?.toString().trim() ?? '';

        throw Exception(
          errorMessage.isNotEmpty
              ? 'Google Geocoding error: $status — $errorMessage'
              : 'Google Geocoding error: $status',
        );
      }

      final results = decoded['results'];

      if (results is! List || results.isEmpty) {
        throw Exception('No address found for this location.');
      }

      final first = results.first;

      final formatted = first['formatted_address']?.toString().trim() ?? '';

      if (formatted.isEmpty) {
        throw Exception('Address could not be determined.');
      }

      final parsed = _parseAddressComponents(first['address_components']);

      if (!mounted) return;

      setState(() {
        _formattedAddress = formatted;
        _selectedAddress = formatted;

        _house = parsed.house;
        _area = parsed.area;
        _city = parsed.city;
        _state = parsed.state;
        _pincode = parsed.pincode;
      });
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _selectedAddress = 'Address lookup timed out.';
      });
    } catch (e) {
      debugPrint('Google reverse geocoding error: $e');

      if (!mounted) return;

      setState(() {
        _selectedAddress =
            'Address lookup failed. Tap Confirm only after a valid address is found.';
      });

      _showMessage(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _loadingAddress = false;
        });
      }
    }
  }

  _ParsedAddress _parseAddressComponents(dynamic rawComponents) {
    if (rawComponents is! List) {
      return const _ParsedAddress();
    }

    String streetNumber = '';
    String route = '';
    String premise = '';
    String sublocality = '';
    String sublocality2 = '';
    String locality = '';
    String postalTown = '';
    String adminArea = '';
    String postalCode = '';

    for (final component in rawComponents) {
      if (component is! Map) continue;

      final types = component['types'];

      if (types is! List) continue;

      final longName = component['long_name']?.toString().trim() ?? '';

      if (longName.isEmpty) continue;

      bool hasType(String type) => types.contains(type);

      if (hasType('street_number')) {
        streetNumber = longName;
      } else if (hasType('route')) {
        route = longName;
      } else if (hasType('premise')) {
        premise = longName;
      } else if (hasType('sublocality_level_1')) {
        sublocality = longName;
      } else if (hasType('sublocality_level_2')) {
        sublocality2 = longName;
      } else if (hasType('locality')) {
        locality = longName;
      } else if (hasType('postal_town')) {
        postalTown = longName;
      } else if (hasType('administrative_area_level_1')) {
        adminArea = longName;
      } else if (hasType('postal_code')) {
        postalCode = longName;
      }
    }

    String house;

    if (premise.isNotEmpty && streetNumber.isNotEmpty) {
      house = '$premise, $streetNumber';
    } else if (premise.isNotEmpty) {
      house = premise;
    } else if (streetNumber.isNotEmpty && route.isNotEmpty) {
      house = '$streetNumber, $route';
    } else if (streetNumber.isNotEmpty) {
      house = streetNumber;
    } else if (route.isNotEmpty) {
      house = route;
    } else {
      house = '';
    }

    String area;

    if (sublocality.isNotEmpty && sublocality2.isNotEmpty) {
      area = '$sublocality, $sublocality2';
    } else if (sublocality.isNotEmpty) {
      area = sublocality;
    } else if (sublocality2.isNotEmpty) {
      area = sublocality2;
    } else {
      area = '';
    }

    final city = locality.isNotEmpty ? locality : postalTown;

    return _ParsedAddress(
      house: house,
      area: area,
      city: city,
      state: adminArea,
      pincode: postalCode,
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _searchPlaces(query),
    );
  }

  Future<void> _searchPlaces(String query) async {
    final apiKey = await _getApiKey();
    if (apiKey.isEmpty) {
      _showMessage(
        'Google web-service API key is not configured.',
        error: true,
      );
      return;
    }

    setState(() {
      _searching = true;
    });

    try {
      final uri = Uri.parse(
        'https://places.googleapis.com/v1/places:searchText',
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask':
              'places.id,places.displayName,places.formattedAddress,places.location',
        },
        body: jsonEncode({
          'textQuery': query,
          'languageCode': 'en',
          'regionCode': 'IN',
          'maxResultCount': 6,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Places search returned ${response.statusCode}.');
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw Exception('Invalid Places response.');
      }

      final rawPlaces = decoded['places'];

      if (rawPlaces is! List) {
        if (mounted) {
          setState(() => _searchResults = []);
        }
        return;
      }

      final results = <_PlaceSearchResult>[];

      for (final raw in rawPlaces) {
        if (raw is! Map) continue;

        final location = raw['location'];

        if (location is! Map) continue;

        final lat = (location['latitude'] as num?)?.toDouble();
        final lng = (location['longitude'] as num?)?.toDouble();

        if (lat == null || lng == null) continue;

        final displayName = raw['displayName'];

        String name = '';

        if (displayName is Map) {
          name = displayName['text']?.toString().trim() ?? '';
        }

        final address = raw['formattedAddress']?.toString().trim() ?? '';

        results.add(
          _PlaceSearchResult(
            name: name.isEmpty ? address : name,
            address: address,
            latitude: lat,
            longitude: lng,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      debugPrint('Google Places search error: $e');

      if (!mounted) return;

      setState(() {
        _searchResults = [];
      });

      _showMessage('Could not search this location.', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  Future<void> _selectSearchResult(_PlaceSearchResult result) async {
    FocusScope.of(context).unfocus();

    _searchController.text = result.name;

    _selectedLocation = LatLng(result.latitude, result.longitude);

    setState(() {
      _searchResults = [];
      _selectedAddress = result.address.isNotEmpty
          ? result.address
          : result.name;
    });

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _selectedLocation, zoom: 17),
      ),
    );

    await _reverseGeocode(result.latitude, result.longitude);
  }

  void _confirmLocation() {
    if (_confirming) return;

    if (_loadingAddress) {
      _showMessage('Please wait while we find the address.', error: true);
      return;
    }

    if (_selectedAddress.trim().isEmpty ||
        _selectedAddress == 'Could not detect the address.' ||
        _selectedAddress == 'Address lookup timed out.' ||
        _selectedAddress ==
            'Google web-service API key is not available. Run with --dart-define=GOOGLE_WEB_API_KEY=YOUR_KEY.') {
      _showMessage('Please select a valid delivery location.', error: true);
      return;
    }

    setState(() {
      _confirming = true;
    });

    final result = GoogleAddressPickerResult(
      address: _formattedAddress.isNotEmpty
          ? _formattedAddress
          : _selectedAddress,
      house: _house,
      area: _area,
      city: _city,
      state: _state,
      pincode: _pincode,
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
    );

    Navigator.pop(context, result);
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red : AppColors.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }

  Widget _buildSearchBox() {
    return Positioned(
      top: 0,
      left: 14,
      right: 14,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Material(
              elevation: 5,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search area, street or place',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                            });
                          },
                          icon: const Icon(Icons.close),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            if (_searching)
              Container(
                margin: const EdgeInsets.only(top: 5),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            if (!_searching && _searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 5),
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];

                    return ListTile(
                      dense: true,
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.tintGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        result.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        result.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),
                      onTap: () => _selectSearchResult(result),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(26),
              topRight: Radius.circular(26),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 18,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'DELIVER TO',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.tintGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loadingAddress
                              ? 'Finding address...'
                              : _selectedAddress,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedLocation.latitude.toStringAsFixed(6)}, '
                          '${_selectedLocation.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_house.isNotEmpty ||
                  _area.isNotEmpty ||
                  _city.isNotEmpty ||
                  _state.isNotEmpty ||
                  _pincode.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (_house.isNotEmpty)
                      _addressChip(Icons.home_outlined, _house),
                    if (_area.isNotEmpty)
                      _addressChip(Icons.location_city_outlined, _area),
                    if (_city.isNotEmpty)
                      _addressChip(Icons.location_city, _city),
                    if (_state.isNotEmpty)
                      _addressChip(Icons.map_outlined, _state),
                    if (_pincode.isNotEmpty)
                      _addressChip(Icons.markunread_mailbox_outlined, _pincode),
                  ],
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loadingAddress || _confirming
                      ? null
                      : _confirmLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _confirming
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'CONFIRM LOCATION',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressChip(IconData icon, String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: const Text(
          'Choose delivery location',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 16,
            ),
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            buildingsEnabled: true,
            indoorViewEnabled: false,
            trafficEnabled: false,
          ),

          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 38),
              child: Icon(
                Icons.location_on_rounded,
                color: AppColors.primary,
                size: 52,
              ),
            ),
          ),

          _buildSearchBox(),

          Positioned(
            right: 16,
            bottom: 340,
            child: FloatingActionButton(
              heroTag: 'google_current_location',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              elevation: 5,
              onPressed: _gettingLocation ? null : _useCurrentLocation,
              child: _gettingLocation
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),

          _buildBottomPanel(),
        ],
      ),
    );
  }
}

// =============================================================
// GOOGLE ADDRESS PICKER RESULT
// =============================================================

class GoogleAddressPickerResult {
  final String address;
  final String house;
  final String area;
  final String city;
  final String state;
  final String pincode;
  final double latitude;
  final double longitude;

  const GoogleAddressPickerResult({
    required this.address,
    required this.house,
    required this.area,
    required this.city,
    required this.state,
    required this.pincode,
    required this.latitude,
    required this.longitude,
  });
}

// =============================================================
// INTERNAL PARSED ADDRESS
// =============================================================

class _ParsedAddress {
  final String house;
  final String area;
  final String city;
  final String state;
  final String pincode;

  const _ParsedAddress({
    this.house = '',
    this.area = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
  });
}

// =============================================================
// SEARCH RESULT
// =============================================================

class _PlaceSearchResult {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const _PlaceSearchResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}
