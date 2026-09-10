import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/store.dart';
import '../services/store_service.dart';

class AdminStoresScreen extends StatefulWidget {
  const AdminStoresScreen({super.key});

  @override
  State<AdminStoresScreen> createState() => _AdminStoresScreenState();
}

class _AdminStoresScreenState extends State<AdminStoresScreen> {
  final StoreService _storeService = StoreService();
  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  String _filter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StoreModel> _filtered(List<StoreModel> stores) {
    final query = _search.trim().toLowerCase();

    return stores.where((store) {
      final status = store.status.toUpperCase();

      if (_filter == 'Open' && status != 'OPEN') return false;
      if (_filter == 'Busy' && status != 'BUSY') return false;
      if (_filter == 'Closed' && status != 'CLOSED') return false;
      if (_filter == 'Inactive' && store.isActive) return false;

      if (query.isEmpty) return true;

      return store.name.toLowerCase().contains(query) ||
          store.code.toLowerCase().contains(query) ||
          store.city.toLowerCase().contains(query) ||
          store.address.toLowerCase().contains(query);
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return Colors.green;
      case 'BUSY':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  Future<void> _openEditor({StoreModel? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final codeController = TextEditingController(text: existing?.code ?? '');
    final addressController = TextEditingController(
      text: existing?.address ?? '',
    );
    final cityController = TextEditingController(text: existing?.city ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');

    final latitudeController = TextEditingController(
      text: existing == null ? '' : existing.latitude.toString(),
    );

    final longitudeController = TextEditingController(
      text: existing == null ? '' : existing.longitude.toString(),
    );

    final radiusController = TextEditingController(
      text: existing?.serviceRadiusKm.toString() ?? '5',
    );

    final priorityController = TextEditingController(
      text: existing?.priority.toString() ?? '1',
    );

    String status = existing?.status.toUpperCase() ?? 'OPEN';
    bool active = existing?.isActive ?? true;

    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * .94,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 9),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.store_rounded,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              existing == null
                                  ? 'Add dark store'
                                  : 'Edit dark store',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext, false),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Form(
                        key: formKey,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                          children: [
                            _sectionTitle(
                              'Basic information',
                              Icons.storefront_outlined,
                            ),
                            const SizedBox(height: 8),
                            _field(
                              nameController,
                              'Store name',
                              'e.g. Diphu North Store',
                              Icons.store_outlined,
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Enter store name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _field(
                                    codeController,
                                    'Store code',
                                    'DPH-N01',
                                    Icons.tag_rounded,
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _field(
                                    cityController,
                                    'City',
                                    'Diphu',
                                    Icons.location_city_outlined,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _field(
                              addressController,
                              'Store address',
                              'Full dark-store address',
                              Icons.location_on_outlined,
                              maxLines: 2,
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Enter store address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            _field(
                              phoneController,
                              'Store phone',
                              'Store contact number',
                              Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 18),
                            _sectionTitle(
                              'Location & delivery coverage',
                              Icons.gps_fixed_rounded,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'These values are used later by the intelligent store-selection engine.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                Expanded(
                                  child: _field(
                                    latitudeController,
                                    'Latitude',
                                    '25.8438',
                                    Icons.north_rounded,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: true,
                                        ),
                                    validator: (value) {
                                      final n = double.tryParse(
                                        (value ?? '').trim(),
                                      );
                                      if (n == null || n < -90 || n > 90) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _field(
                                    longitudeController,
                                    'Longitude',
                                    '93.4370',
                                    Icons.east_rounded,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: true,
                                        ),
                                    validator: (value) {
                                      final n = double.tryParse(
                                        (value ?? '').trim(),
                                      );
                                      if (n == null || n < -180 || n > 180) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _field(
                                    radiusController,
                                    'Service radius (km)',
                                    '5',
                                    Icons.radio_button_checked,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: (value) {
                                      final n = double.tryParse(
                                        (value ?? '').trim(),
                                      );
                                      if (n == null || n <= 0) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _field(
                                    priorityController,
                                    'Priority',
                                    '1',
                                    Icons.priority_high_rounded,
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      final n = int.tryParse(
                                        (value ?? '').trim(),
                                      );
                                      if (n == null || n < 1) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _sectionTitle(
                              'Store availability',
                              Icons.tune_rounded,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: status,
                              decoration: _inputDecoration(
                                'Store status',
                                Icons.power_settings_new_rounded,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'OPEN',
                                  child: Text('OPEN'),
                                ),
                                DropdownMenuItem(
                                  value: 'BUSY',
                                  child: Text('BUSY'),
                                ),
                                DropdownMenuItem(
                                  value: 'CLOSED',
                                  child: Text('CLOSED'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setSheetState(() {
                                  status = value;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: SwitchListTile.adaptive(
                                value: active,
                                activeColor: Colors.green,
                                title: const Text(
                                  'Store is active',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Inactive stores are excluded from customer selection.',
                                  style: TextStyle(fontSize: 9),
                                ),
                                onChanged: (value) {
                                  setSheetState(() {
                                    active = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.green.shade100,
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.green,
                                    size: 21,
                                  ),
                                  SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      'Selection engine ready: location, radius, status and priority will be used when matching customers to stores.',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 9,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }

                                  final payload = <String, dynamic>{
                                    'name': nameController.text.trim(),
                                    'code': codeController.text
                                        .trim()
                                        .toUpperCase(),
                                    'address': addressController.text.trim(),
                                    'city': cityController.text.trim(),
                                    'phone': phoneController.text.trim(),
                                    'latitude': double.parse(
                                      latitudeController.text.trim(),
                                    ),
                                    'longitude': double.parse(
                                      longitudeController.text.trim(),
                                    ),
                                    'serviceRadiusKm': double.parse(
                                      radiusController.text.trim(),
                                    ),
                                    'priority': int.parse(
                                      priorityController.text.trim(),
                                    ),
                                    'status': status,
                                    'isActive': active,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  };

                                  try {
                                    if (existing == null) {
                                      payload['createdAt'] =
                                          FieldValue.serverTimestamp();

                                      await FirebaseFirestore.instance
                                          .collection('stores')
                                          .add(payload);
                                    } else {
                                      await FirebaseFirestore.instance
                                          .collection('stores')
                                          .doc(existing.id)
                                          .update(payload);
                                    }

                                    if (!mounted) return;
                                    Navigator.pop(sheetContext, true);
                                  } catch (e) {
                                    if (!mounted) return;

                                    _message(
                                      'Could not save store: $e',
                                      error: true,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  existing == null
                                      ? 'ADD DARK STORE'
                                      : 'SAVE CHANGES',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
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
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    codeController.dispose();
    addressController.dispose();
    cityController.dispose();
    phoneController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    radiusController.dispose();
    priorityController.dispose();

    if (saved == true && mounted) {
      _message(
        existing == null
            ? 'Dark store added successfully.'
            : 'Dark store updated successfully.',
      );
    }
  }

  Future<void> _deleteStore(StoreModel store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete dark store?',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            '“${store.name}” will be removed from the store network. Existing orders are not modified.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _storeService.deleteStore(store.id);

      if (mounted) {
        _message('Store deleted.');
      }
    } catch (e) {
      if (mounted) {
        _message('Could not delete store: $e', error: true);
      }
    }
  }

  Future<void> _toggleActive(StoreModel store) async {
    try {
      await _storeService.setStoreActive(store.id, !store.isActive);
    } catch (e) {
      if (mounted) {
        _message('Could not update store: $e', error: true);
      }
    }
  }

  Future<void> _changeStatus(StoreModel store) async {
    final statuses = ['OPEN', 'BUSY', 'CLOSED'];

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Store status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                ...statuses.map((status) {
                  final selected = store.status.toUpperCase() == status;

                  return ListTile(
                    leading: Icon(
                      Icons.circle,
                      size: 13,
                      color: _statusColor(status),
                    ),
                    title: Text(
                      status,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () => Navigator.pop(context, status),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || selected == store.status.toUpperCase()) {
      return;
    }

    try {
      await _storeService.setStoreStatus(store.id, selected);
    } catch (e) {
      if (mounted) {
        _message('Could not update status: $e', error: true);
      }
    }
  }

  Widget _storeCard(StoreModel store) {
    final statusColor = _statusColor(store.status);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 5, 16, 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.store_rounded,
                  color: Colors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${store.code} • ${store.city.isEmpty ? store.address : store.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _openEditor(existing: store);
                      break;
                    case 'status':
                      _changeStatus(store);
                      break;
                    case 'active':
                      _toggleActive(store);
                      break;
                    case 'delete':
                      _deleteStore(store);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit store')),
                  const PopupMenuItem(
                    value: 'status',
                    child: Text('Change status'),
                  ),
                  PopupMenuItem(
                    value: 'active',
                    child: Text(store.isActive ? 'Deactivate' : 'Activate'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete store',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              _metric(
                icon: Icons.location_on_outlined,
                label: '${store.serviceRadiusKm.toStringAsFixed(1)} km',
              ),
              _metric(
                icon: Icons.priority_high_rounded,
                label: 'Priority ${store.priority}',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  store.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Icon(
                  store.isActive
                      ? Icons.check_circle_outline
                      : Icons.pause_circle_outline,
                  size: 16,
                  color: store.isActive ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    store.isActive
                        ? 'Eligible for intelligent store selection'
                        : 'Excluded from customer store selection',
                    style: TextStyle(
                      color: store.isActive
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric({required IconData icon, required String label}) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.green),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 17, color: Colors.green),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.green),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: _inputDecoration(label, icon).copyWith(hintText: hint),
    );
  }

  void _message(String message, {bool error = false}) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7F6),
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Dark Stores',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_business_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text(
          'ADD DARK STORE',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<List<StoreModel>>(
        stream: _storeService.getStores(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load stores.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final stores = snapshot.data ?? <StoreModel>[];

          final filtered = _filtered(stores);

          final open = stores.where((store) {
            return store.status.toUpperCase() == 'OPEN' && store.isActive;
          }).length;

          final busy = stores.where((store) {
            return store.status.toUpperCase() == 'BUSY' && store.isActive;
          }).length;

          final inactive = stores.where((store) => !store.isActive).length;

          return RefreshIndicator(
            color: Colors.green,
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 250));

              if (mounted) {
                setState(() {});
              }
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Container(
                      height: 50,
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
                        decoration: const InputDecoration(
                          hintText: 'Search stores, code or city',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.green,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 47,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      children: ['All', 'Open', 'Busy', 'Closed', 'Inactive']
                          .map((filter) {
                            final selected = _filter == filter;

                            return Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                selected: selected,
                                label: Text(
                                  filter,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                selectedColor: Colors.green,
                                backgroundColor: Colors.white,
                                onSelected: (_) {
                                  setState(() {
                                    _filter = filter;
                                  });
                                },
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        _summary('${stores.length}', 'Stores'),
                        _divider(),
                        _summary('$open', 'Open'),
                        _divider(),
                        _summary('$busy', 'Busy'),
                        _divider(),
                        _summary('$inactive', 'Inactive'),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.store_mall_directory_outlined,
                              color: Colors.green,
                              size: 60,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'No dark stores found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              stores.isEmpty
                                  ? 'Add your first store to start building the multi-store network.'
                                  : 'Try another search or filter.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return _storeCard(filtered[index]);
                    }, childCount: filtered.length),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summary(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 7,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 27, color: Colors.white24);
  }
}
