import 'package:flutter/material.dart';

import '../models/address.dart';
import '../services/address_service.dart';
import '../services/customer_store_service.dart';
import 'add_address_screen.dart';

class SelectAddressScreen extends StatefulWidget {
  final Address? selectedAddress;

  const SelectAddressScreen({super.key, this.selectedAddress});

  @override
  State<SelectAddressScreen> createState() => _SelectAddressScreenState();
}

class _SelectAddressScreenState extends State<SelectAddressScreen> {
  final AddressService _addressService = AddressService();
  final CustomerStoreService _customerStoreService = CustomerStoreService();

  Address? _selectedAddress;
  String _search = '';

  final TextEditingController _searchController = TextEditingController();

  bool _selectingStore = false;

  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.selectedAddress;
  }

  // ==========================================================
  // ADDRESS FILTER
  // ==========================================================

  List<Address> _filterAddresses(List<Address> addresses) {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) {
      return addresses;
    }

    return addresses.where((address) {
      final text = [
        address.fullName,
        address.house,
        address.area,
        address.city,
        address.state,
        address.pincode,
      ].join(' ').toLowerCase();

      return text.contains(query);
    }).toList();
  }

  // ==========================================================
  // SELECT
  // ==========================================================

  void _selectAddress(Address address) {
    setState(() {
      _selectedAddress = address;
    });
  }

  // ==========================================================
  // CONFIRM + INTELLIGENT STORE SELECTION
  // ==========================================================

  Future<void> _confirmSelection() async {
    final address = _selectedAddress;

    if (address == null) {
      _showMessage('Please select a delivery address.', error: true);
      return;
    }

    final latitude = address.latitude;
    final longitude = address.longitude;

    if (latitude == null || longitude == null) {
      _showLocationWarning(address);
      return;
    }

    if (_selectingStore) {
      return;
    }

    setState(() {
      _selectingStore = true;
    });

    try {
      final result = await _customerStoreService.selectStoreForAddress(
        latitude: latitude,
        longitude: longitude,
      );

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _selectingStore = false;
        });

        await _showNoStoreDialog();
        return;
      }

      setState(() {
        _selectingStore = false;
      });

      _showMessage(
        'Delivery address confirmed',
      );

      // Give the user a brief moment to see the successful selection
      // before returning the address to the calling screen.
      await Future<void>.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;

      Navigator.pop(context, address);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _selectingStore = false;
      });

      _showMessage(
        'Could not set delivery location. Please try again.',
        error: true,
      );
    }
  }

  // ==========================================================
  // NO STORE FOUND
  // ==========================================================

  Future<void> _showNoStoreDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.location_off_outlined, color: Colors.orange),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Delivery unavailable',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: const Text(
            'Delivery is not available at this location yet. Please choose another address or try again later.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // LOCATION WARNING
  // ==========================================================

  void _showLocationWarning(Address address) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.location_off_outlined, color: Colors.orange),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Location Required',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: const Text(
            'This address does not have a delivery location saved. Please add the address again with a location before using it for delivery.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _addAddress();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('ADD NEW ADDRESS'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // ADD ADDRESS
  // ==========================================================

  Future<void> _addAddress() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAddressScreen()),
    );

    if (!mounted) return;

    setState(() {});
  }

  // ==========================================================
  // ADDRESS LABEL
  // ==========================================================

  String _addressLabel(Address address) {
    if (address.isDefault) {
      return 'DEFAULT';
    }

    return 'DELIVERY ADDRESS';
  }

  // ==========================================================
  // ADDRESS TEXT
  // ==========================================================

  String _addressLine(Address address) {
    final parts = <String>[
      address.house,
      address.area,
      address.city,
      address.state,
    ].where((value) => value.trim().isNotEmpty);

    return parts.join(', ');
  }

  String _locationStatus(Address address) {
    if (address.latitude != null && address.longitude != null) {
      return 'Delivery location confirmed';
    }

    return 'Location needs to be added';
  }

  // ==========================================================
  // SEARCH
  // ==========================================================

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _search = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search saved addresses',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.green),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _search = '';
                    });
                  },
                  icon: const Icon(Icons.close),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.green,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Where should we deliver?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count ${count == 1 ? 'saved address' : 'saved addresses'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ADDRESS CARD
  // ==========================================================

  Widget _buildAddressCard(Address address, int index) {
    final selected = _selectedAddress?.id == address.id;

    final hasLocation = address.latitude != null && address.longitude != null;

    final line = _addressLine(address);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index * 55),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.green : Colors.grey.shade100,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 9,
              offset: Offset(0, 3),
              spreadRadius: -5,
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _selectAddress(address),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected ? Colors.green : Colors.grey.shade500,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  address.fullName.trim().isEmpty
                                      ? 'Delivery Address'
                                      : address.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (address.isDefault) ...[
                                const SizedBox(width: 7),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const Text(
                                    'DEFAULT',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _addressLabel(address),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.home_outlined,
                        color: Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.isEmpty
                                  ? 'Address details unavailable'
                                  : line,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (address.pincode.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  'PIN: ${address.pincode}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      hasLocation
                          ? Icons.check_circle
                          : Icons.warning_amber_rounded,
                      color: hasLocation ? Colors.green : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _locationStatus(address),
                        style: TextStyle(
                          color: hasLocation ? Colors.green : Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (selected)
                      const Text(
                        'SELECTED',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
                if (!hasLocation)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Text(
                        'This address cannot be used for checkout until a delivery location is saved.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 9,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // EMPTY
  // ==========================================================

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: Colors.green,
                size: 58,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'No saved addresses',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a delivery address so your\n'
              'orders can reach you quickly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _addAddress,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text(
                  'ADD ADDRESS',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red : Colors.green,
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
      backgroundColor: const Color(0xffF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Select Address',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<Address>>(
        stream: _addressService.getAddresses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 50,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Unable to load addresses',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final addresses = snapshot.data ?? <Address>[];

          final filtered = _filterAddresses(addresses);

          return Column(
            children: [
              _buildSearchBar(),
              _buildHeader(addresses.length),
              if (addresses.isNotEmpty)
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  color: Colors.grey.shade400,
                                  size: 48,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'No matching address',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(top: 2, bottom: 100),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _buildAddressCard(filtered[index], index);
                          },
                        ),
                )
              else
                Expanded(child: _buildEmptyState()),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 14,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectingStore ? null : _addAddress,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 19),
                  label: const Text(
                    'ADD NEW',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _selectedAddress == null || _selectingStore
                      ? null
                      : _confirmSelection,
                  icon: _selectingStore
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _selectingStore ? 'FINDING STORE...' : 'USE THIS ADDRESS',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
