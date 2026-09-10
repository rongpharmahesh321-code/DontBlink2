import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dont_blink/widgets/cached_product_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreManagerScreen extends StatefulWidget {
  const StoreManagerScreen({super.key});

  @override
  State<StoreManagerScreen> createState() => _StoreManagerScreenState();
}

class _StoreManagerScreenState extends State<StoreManagerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final Future<DocumentSnapshot<Map<String, dynamic>>> _userDocFuture;

  @override
  void initState() {
    super.initState();
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _userDocFuture = Future.error('User is not logged in.');
    } else {
      _userDocFuture = _firestore.collection('users').doc(uid).get();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _userDocFuture,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF059669),
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        if (userSnapshot.hasError ||
            !userSnapshot.hasData ||
            !userSnapshot.data!.exists) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load Store Manager profile.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final userData = userSnapshot.data!.data()!;
        final role = userData['role']?.toString().trim() ?? '';

        if (role != 'storeManager') {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.red,
                      size: 50,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Access Denied',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This account is not assigned as a Store Manager.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final storeId = userData['storeId']?.toString().trim() ?? '';

        if (storeId.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: const Text('Store Manager'),
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 56,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'No store assigned',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Please contact your administrator to assign a dark store to your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return _StoreManagerDashboard(storeId: storeId);
      },
    );
  }
}

class _StoreManagerDashboard extends StatefulWidget {
  final String storeId;

  const _StoreManagerDashboard({required this.storeId});

  @override
  State<_StoreManagerDashboard> createState() => _StoreManagerDashboardState();
}

class _StoreManagerDashboardState extends State<_StoreManagerDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Memoized Streams so setState never causes streams to recreate or flicker
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _storeStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _productsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _inventoryStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _ridersStream;

  int _selectedTabIndex = 0;

  // Order filters & search
  String _orderStatusFilter = 'All';
  String _orderSearchQuery = '';
  final TextEditingController _orderSearchController = TextEditingController();

  // Inventory filters & search
  String _inventoryFilter = 'All';
  String _inventorySearchQuery = '';
  final TextEditingController _inventorySearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _initStreams(widget.storeId);
  }

  @override
  void didUpdateWidget(covariant _StoreManagerDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storeId != widget.storeId) {
      _initStreams(widget.storeId);
    }
  }

  void _initStreams(String storeId) {
    _storeStream = _firestore.collection('stores').doc(storeId).snapshots();
    _productsStream = _firestore.collection('products').snapshots();
    _ordersStream = _firestore
        .collection('orders')
        .where('storeId', isEqualTo: storeId)
        .snapshots();
    _inventoryStream = _firestore
        .collection('stores')
        .doc(storeId)
        .collection('inventory')
        .snapshots();
    _ridersStream = _firestore
        .collection('users')
        .where('role', isEqualTo: 'rider')
        .where('storeId', isEqualTo: storeId)
        .snapshots();
  }

  @override
  void dispose() {
    _orderSearchController.dispose();
    _inventorySearchController.dispose();
    super.dispose();
  }

  // ==========================================================
  // FIRESTORE ACTIONS
  // ==========================================================

  Future<void> _setStoreStatus(String status) async {
    try {
      await _firestore.collection('stores').doc(widget.storeId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) _showMessage('Store status set to $status');
    } catch (_) {
      if (mounted) _showMessage('Could not update store status.', error: true);
    }
  }

  Future<void> _setActive(bool active) async {
    try {
      await _firestore.collection('stores').doc(widget.storeId).update({
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _showMessage(active ? 'Store activated.' : 'Store deactivated.');
      }
    } catch (_) {
      if (mounted) _showMessage('Could not update store.', error: true);
    }
  }

  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) _showMessage('Order updated to "$status"');
    } catch (_) {
      if (mounted) _showMessage('Could not update order.', error: true);
    }
  }

  Future<void> _adjustInventoryStock(
    String productId,
    int currentStock,
    int delta,
  ) async {
    final newStock = (currentStock + delta).clamp(0, 99999);
    try {
      await _firestore
          .collection('stores')
          .doc(widget.storeId)
          .collection('inventory')
          .doc(productId)
          .set({
            'stock': newStock,
            'isAvailable': newStock > 0,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      HapticFeedback.lightImpact();
    } catch (_) {
      if (mounted) _showMessage('Could not update stock.', error: true);
    }
  }

  Future<void> _toggleInventoryAvailability(
    String productId,
    bool currentVal,
  ) async {
    try {
      await _firestore
          .collection('stores')
          .doc(widget.storeId)
          .collection('inventory')
          .doc(productId)
          .set({
            'isAvailable': !currentVal,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      HapticFeedback.selectionClick();
    } catch (_) {
      if (mounted) _showMessage('Could not toggle item.', error: true);
    }
  }

  Future<void> _editInventoryDialog({
    required String productId,
    required Map<String, dynamic> inventoryData,
    required String productName,
    required String? imageUrl,
  }) async {
    final currentStock = _toInt(inventoryData['stock']);
    final stockController = TextEditingController(
      text: currentStock.toString(),
    );
    bool isAvailable = inventoryData['isAvailable'] != false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedProductImage(
                        url: imageUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFF059669),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Current Stock Quantity',
                      hintText: 'Enter units available',
                      prefixIcon: const Icon(
                        Icons.shelves,
                        color: Color(0xFF059669),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: SwitchListTile.adaptive(
                      value: isAvailable,
                      activeTrackColor: const Color(0xFF059669),
                      title: const Text(
                        'Available in this store',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        isAvailable
                            ? 'Customers can order this item'
                            : 'Marked as out-of-stock / hidden',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onChanged: (val) {
                        setDialogState(() => isAvailable = val);
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final stock = int.tryParse(stockController.text.trim());
                    if (stock == null || stock < 0) {
                      _showMessage('Enter a valid stock quantity.', error: true);
                      return;
                    }

                    try {
                      await _firestore
                          .collection('stores')
                          .doc(widget.storeId)
                          .collection('inventory')
                          .doc(productId)
                          .set({
                            'stock': stock,
                            'isAvailable': isAvailable && stock > 0,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (_) {
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, false);
                      }
                      if (mounted) {
                        _showMessage(
                          'Could not update inventory.',
                          error: true,
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'SAVE CHANGES',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    stockController.dispose();
    if (saved == true && mounted) _showMessage('Inventory updated.');
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('Are you sure you want to sign out of the store?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('LOG OUT'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _auth.signOut();
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final clean = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) {
      _showMessage('Phone number not available', error: true);
      return;
    }
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showMessage('Could not initiate phone call', error: true);
      }
    } catch (_) {
      _showMessage('Could not initiate phone call', error: true);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: error ? Colors.red.shade700 : const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(14),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  int _toInt(dynamic val) {
    if (val is num) return val.toInt();
    return int.tryParse(val?.toString() ?? '') ?? 0;
  }

  String _toStr(dynamic val, [String fallback = '']) {
    final s = val?.toString().trim() ?? '';
    return s.isEmpty ? fallback : s;
  }

  // ==========================================================
  // MAIN BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _storeStream,
      builder: (context, storeSnap) {
        if (storeSnap.connectionState == ConnectionState.waiting &&
            !storeSnap.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF059669),
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        if (!storeSnap.hasData || !storeSnap.data!.exists) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(child: Text('Assigned store not found in database.')),
          );
        }

        final storeData = storeSnap.data!.data() ?? {};
        final storeName = _toStr(storeData['name'], 'Dark Store');
        final storeCode = _toStr(storeData['code']);
        final storeStatus =
            _toStr(storeData['status'], 'OPEN').toUpperCase();
        final isActive = storeData['isActive'] != false;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _productsStream,
          builder: (context, productsSnap) {
            // Build a fast lookup catalog for products (name, image, category, unit, price)
            final productCatalog = <String, Map<String, dynamic>>{};
            for (final doc in productsSnap.data?.docs ?? []) {
              productCatalog[doc.id] = doc.data();
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _ordersStream,
              builder: (context, ordersSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _inventoryStream,
                  builder: (context, inventorySnap) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _ridersStream,
                      builder: (context, ridersSnap) {
                        final orders = ordersSnap.data?.docs ?? [];
                        final inventory = inventorySnap.data?.docs ?? [];
                        final riders = ridersSnap.data?.docs ?? [];

                        // Compute summary numbers
                        final ordersToPack = orders.where((d) {
                          final st = _toStr(d.data()['status']).toLowerCase();
                          return st == 'placed' || st == 'accepted';
                        }).length;

                        final activeDeliveries = orders.where((d) {
                          final st = _toStr(d.data()['status']).toLowerCase();
                          return st == 'packed' ||
                              st == 'assigned to rider' ||
                              st == 'picked up' ||
                              st == 'out for delivery';
                        }).length;

                        final lowStockCount = inventory.where((d) {
                          final stock = _toInt(d.data()['stock']);
                          return stock <= 5;
                        }).length;

                        return Scaffold(
                          backgroundColor: const Color(0xFFF1F5F9),
                          appBar: _buildAppBar(
                            storeName: storeName,
                            storeCode: storeCode,
                            storeStatus: storeStatus,
                            isActive: isActive,
                          ),
                          body: Column(
                            children: [
                              // Operational stats header
                              _buildOperationalHeader(
                                storeStatus: storeStatus,
                                isActive: isActive,
                                ordersToPack: ordersToPack,
                                activeDeliveries: activeDeliveries,
                                lowStockCount: lowStockCount,
                                totalRiders: riders.length,
                              ),

                              // Screen tab content with preserved state
                              Expanded(
                                child: IndexedStack(
                                  index: _selectedTabIndex,
                                  children: [
                                    // TAB 0: Fulfillment & Orders (With Product Photos)
                                    _buildOrdersView(orders, productCatalog),

                                    // TAB 1: Inventory Catalog (With Product Photos)
                                    _buildInventoryView(
                                      inventory,
                                      productCatalog,
                                    ),

                                    // TAB 2: Store Riders Fleet
                                    _buildRidersView(riders),

                                    // TAB 3: Store Operations & Settings
                                    _buildStoreSettingsView(
                                      storeData,
                                      storeName,
                                      storeCode,
                                      storeStatus,
                                      isActive,
                                      orders.length,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          bottomNavigationBar: _buildBottomNav(
                            ordersToPack: ordersToPack,
                            lowStockCount: lowStockCount,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // APP BAR
  // ==========================================================

  PreferredSizeWidget _buildAppBar({
    required String storeName,
    required String storeCode,
    required String storeStatus,
    required bool isActive,
  }) {
    final isStoreOpen = isActive && storeStatus == 'OPEN';

    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF0F172A), // Dark slate
      foregroundColor: Colors.white,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: .2),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: .4),
              ),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Color(0xFF34D399),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isStoreOpen
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      !isActive
                          ? 'INACTIVE'
                          : storeStatus == 'OPEN'
                              ? 'ACCEPTING ORDERS'
                              : 'STORE BUSY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isStoreOpen
                            ? const Color(0xFF6EE7B7)
                            : const Color(0xFFFCA5A5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (storeCode.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '•  $storeCode',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: .6),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Sign Out',
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded, size: 20),
        ),
      ],
    );
  }

  // ==========================================================
  // OPERATIONAL STATS HEADER
  // ==========================================================

  Widget _buildOperationalHeader({
    required String storeStatus,
    required bool isActive,
    required int ordersToPack,
    required int activeDeliveries,
    required int lowStockCount,
    required int totalRiders,
  }) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          // Store Status Toggle Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: .10),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.power_settings_new_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Dark Store Status:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Toggle OPEN / BUSY
                InkWell(
                  onTap: () {
                    final next = storeStatus == 'OPEN' ? 'BUSY' : 'OPEN';
                    _setStoreStatus(next);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: storeStatus == 'OPEN'
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          storeStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.swap_horiz_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Active Switch
                InkWell(
                  onTap: () => _setActive(!isActive),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withValues(alpha: .15)
                          : Colors.red.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? 'Active' : 'Disabled',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 4 Key KPIs
          Row(
            children: [
              _buildKpiCard(
                label: 'To Pack',
                value: '$ordersToPack',
                icon: Icons.inventory_rounded,
                color: ordersToPack > 0
                    ? const Color(0xFFF97316) // Orange alert
                    : const Color(0xFF38BDF8),
                badge: ordersToPack > 0 ? 'Urgent' : null,
                onTap: () {
                  setState(() {
                    _selectedTabIndex = 0;
                    _orderStatusFilter = 'To Pack';
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildKpiCard(
                label: 'En Route',
                value: '$activeDeliveries',
                icon: Icons.delivery_dining_rounded,
                color: const Color(0xFF34D399),
                onTap: () {
                  setState(() {
                    _selectedTabIndex = 0;
                    _orderStatusFilter = 'All';
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildKpiCard(
                label: 'Low Stock',
                value: '$lowStockCount',
                icon: Icons.warning_amber_rounded,
                color: lowStockCount > 0
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF94A3B8),
                onTap: () {
                  setState(() {
                    _selectedTabIndex = 1;
                    _inventoryFilter = 'Low Stock';
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildKpiCard(
                label: 'Riders',
                value: '$totalRiders',
                icon: Icons.two_wheeler_rounded,
                color: const Color(0xFFA78BFA),
                onTap: () => setState(() => _selectedTabIndex = 2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? badge,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: badge != null
                  ? color.withValues(alpha: .5)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .7),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // TAB 0: FULFILLMENT & ORDERS WITH PRODUCT PHOTOS
  // ==========================================================

  Widget _buildOrdersView(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allOrders,
    Map<String, Map<String, dynamic>> productCatalog,
  ) {
    // Sort newest first
    final sortedOrders = [...allOrders];
    sortedOrders.sort((a, b) {
      final at = a.data()['createdAt'];
      final bt = b.data()['createdAt'];
      if (at is Timestamp && bt is Timestamp) {
        return bt.compareTo(at);
      }
      return 0;
    });

    // Apply status filter
    final filtered = sortedOrders.where((doc) {
      final data = doc.data();
      final status = _toStr(data['status']).toLowerCase();

      if (_orderStatusFilter == 'To Pack') {
        if (status != 'placed' && status != 'accepted') return false;
      } else if (_orderStatusFilter == 'Packed') {
        if (status != 'packed') return false;
      } else if (_orderStatusFilter == 'Out for Delivery') {
        if (status != 'out for delivery' &&
            status != 'picked up' &&
            status != 'assigned to rider') {
          return false;
        }
      } else if (_orderStatusFilter == 'Delivered') {
        if (status != 'delivered') return false;
      } else if (_orderStatusFilter == 'Cancelled') {
        if (status != 'cancelled') return false;
      }

      // Search query
      if (_orderSearchQuery.isNotEmpty) {
        final q = _orderSearchQuery.toLowerCase();
        final orderId = doc.id.toLowerCase();
        final custName = _toStr(data['customerName']).toLowerCase();
        final custPhone = _toStr(data['customerPhone']).toLowerCase();
        return orderId.contains(q) ||
            custName.contains(q) ||
            custPhone.contains(q);
      }

      return true;
    }).toList();

    return Column(
      children: [
        // Search & Filter header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              // Search Input
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _orderSearchController,
                  style: const TextStyle(fontSize: 13),
                  onChanged: (val) {
                    setState(() => _orderSearchQuery = val.trim());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search order ID, customer name, phone...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    suffixIcon: _orderSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _orderSearchController.clear();
                              setState(() => _orderSearchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Status Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildOrderFilterChip('All', allOrders.length),
                    _buildOrderFilterChip(
                      'To Pack',
                      allOrders.where((d) {
                        final st = _toStr(d.data()['status']).toLowerCase();
                        return st == 'placed' || st == 'accepted';
                      }).length,
                      badgeColor: const Color(0xFFEA580C),
                    ),
                    _buildOrderFilterChip(
                      'Packed',
                      allOrders.where((d) {
                        return _toStr(d.data()['status']).toLowerCase() ==
                            'packed';
                      }).length,
                    ),
                    _buildOrderFilterChip(
                      'Out for Delivery',
                      allOrders.where((d) {
                        final st = _toStr(d.data()['status']).toLowerCase();
                        return st == 'out for delivery' ||
                            st == 'picked up' ||
                            st == 'assigned to rider';
                      }).length,
                    ),
                    _buildOrderFilterChip(
                      'Delivered',
                      allOrders.where((d) {
                        return _toStr(d.data()['status']).toLowerCase() ==
                            'delivered';
                      }).length,
                    ),
                    _buildOrderFilterChip(
                      'Cancelled',
                      allOrders.where((d) {
                        return _toStr(d.data()['status']).toLowerCase() ==
                            'cancelled';
                      }).length,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Orders list with persistent PageStorageKey so scroll never resets
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No Orders Found',
                  subtitle: _orderSearchQuery.isNotEmpty
                      ? 'No orders matched your search query'
                      : 'No orders under "$_orderStatusFilter" status',
                )
              : ListView.builder(
                  key: const PageStorageKey('store_orders_list_key'),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    return _ModernOrderCard(
                      key: ValueKey(doc.id),
                      doc: doc,
                      productCatalog: productCatalog,
                      onUpdateStatus: (newStatus) =>
                          _updateOrderStatus(doc.id, newStatus),
                      onMakeCall: _makeCall,
                      onShowMessage: _showMessage,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOrderFilterChip(
    String label,
    int count, {
    Color? badgeColor,
  }) {
    final isSelected = _orderStatusFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: const Color(0xFF059669),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFF059669) : Colors.transparent,
          ),
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: .25)
                      : (badgeColor ?? Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? Colors.white
                        : (badgeColor != null
                            ? Colors.white
                            : Colors.grey.shade800),
                  ),
                ),
              ),
            ],
          ],
        ),
        onSelected: (val) {
          setState(() => _orderStatusFilter = label);
        },
      ),
    );
  }

  // ==========================================================
  // TAB 1: INVENTORY & CATALOG WITH PRODUCT PHOTOS
  // ==========================================================

  Widget _buildInventoryView(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> inventoryDocs,
    Map<String, Map<String, dynamic>> productCatalog,
  ) {
    // Merge store inventory with central catalog
    final items = inventoryDocs.map((doc) {
      final invData = doc.data();
      final productId = doc.id;
      final catalogData = productCatalog[productId] ?? {};
      final stock = _toInt(invData['stock']);
      final isAvailable = invData['isAvailable'] != false;
      final name = _toStr(
        invData['name'],
        _toStr(catalogData['name'], 'Product'),
      );
      final category = _toStr(catalogData['category'], 'General');
      final sellingUnit = _toStr(catalogData['sellingUnit']);
      final price = _toStr(
        invData['price'],
        _toStr(catalogData['price'], '0'),
      );
      final imageUrl = _toStr(
        catalogData['image'],
        _toStr(catalogData['imageUrl']),
      );

      return {
        'docId': productId,
        'name': name,
        'stock': stock,
        'isAvailable': isAvailable,
        'category': category,
        'sellingUnit': sellingUnit,
        'price': price,
        'imageUrl': imageUrl,
        'invData': invData,
      };
    }).toList();

    // Filter
    final filtered = items.where((item) {
      final stock = item['stock'] as int;
      final isAvailable = item['isAvailable'] as bool;

      if (_inventoryFilter == 'Low Stock') {
        if (stock > 5) return false;
      } else if (_inventoryFilter == 'Out of Stock') {
        if (stock > 0) return false;
      } else if (_inventoryFilter == 'Available') {
        if (!isAvailable) return false;
      } else if (_inventoryFilter == 'Unavailable') {
        if (isAvailable) return false;
      }

      if (_inventorySearchQuery.isNotEmpty) {
        final q = _inventorySearchQuery.toLowerCase();
        final name = (item['name'] as String).toLowerCase();
        final cat = (item['category'] as String).toLowerCase();
        return name.contains(q) || cat.contains(q);
      }

      return true;
    }).toList();

    return Column(
      children: [
        // Search & Filter header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              // Search field
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _inventorySearchController,
                  style: const TextStyle(fontSize: 13),
                  onChanged: (val) {
                    setState(() => _inventorySearchQuery = val.trim());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products by name or category...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    suffixIcon: _inventorySearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _inventorySearchController.clear();
                              setState(() => _inventorySearchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildInventoryFilterChip('All', items.length),
                    _buildInventoryFilterChip(
                      'Low Stock',
                      items.where((i) => (i['stock'] as int) <= 5).length,
                      badgeColor: Colors.orange.shade700,
                    ),
                    _buildInventoryFilterChip(
                      'Out of Stock',
                      items.where((i) => (i['stock'] as int) == 0).length,
                      badgeColor: Colors.red.shade700,
                    ),
                    _buildInventoryFilterChip(
                      'Available',
                      items.where((i) => i['isAvailable'] == true).length,
                    ),
                    _buildInventoryFilterChip(
                      'Unavailable',
                      items.where((i) => i['isAvailable'] == false).length,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Products List with PageStorageKey so scroll position never resets
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No Products Found',
                  subtitle: _inventorySearchQuery.isNotEmpty
                      ? 'No items matched your search query'
                      : 'No inventory under "$_inventoryFilter" filter',
                )
              : ListView.builder(
                  key: const PageStorageKey('store_inventory_list_key'),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildModernInventoryCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInventoryFilterChip(
    String label,
    int count, {
    Color? badgeColor,
  }) {
    final isSelected = _inventoryFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: const Color(0xFF059669),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFF059669) : Colors.transparent,
          ),
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: .25)
                      : (badgeColor ?? Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? Colors.white
                        : (badgeColor != null
                            ? Colors.white
                            : Colors.grey.shade800),
                  ),
                ),
              ),
            ],
          ],
        ),
        onSelected: (val) {
          setState(() => _inventoryFilter = label);
        },
      ),
    );
  }

  // ==========================================================
  // MODERN INVENTORY CARD WITH PRODUCT PHOTOS & DIRECT ADJUST
  // ==========================================================

  Widget _buildModernInventoryCard(Map<String, dynamic> item) {
    final productId = item['docId'] as String;
    final name = item['name'] as String;
    final stock = item['stock'] as int;
    final isAvailable = item['isAvailable'] as bool;
    final category = item['category'] as String;
    final sellingUnit = item['sellingUnit'] as String;
    final price = item['price'] as String;
    final imageUrl = item['imageUrl'] as String;
    final invData = item['invData'] as Map<String, dynamic>;

    final isLow = stock <= 5 && stock > 0;
    final isZero = stock == 0;

    return Container(
      key: ValueKey(productId),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isZero
              ? Colors.red.shade200
              : isLow
                  ? Colors.orange.shade200
                  : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. PRODUCT PHOTO
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? CachedProductImage(
                    url: imageUrl,
                    width: 58,
                    height: 58,
                    fit: BoxFit.contain,
                    placeholder: Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: const Icon(
                      Icons.fastfood_outlined,
                      size: 24,
                      color: Colors.grey,
                    ),
                  )
                : const Icon(
                    Icons.inventory_2_outlined,
                    size: 26,
                    color: Colors.grey,
                  ),
          ),
          const SizedBox(width: 12),

          // 2. PRODUCT DETAILS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    if (sellingUnit.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        sellingUnit,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      '₹$price',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Stock indicator & availability toggle
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isZero
                            ? Colors.red
                            : isLow
                                ? Colors.orange
                                : const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isZero
                          ? 'Out of Stock'
                          : isLow
                              ? 'Low Stock: $stock left'
                              : 'In Stock: $stock',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isZero
                            ? Colors.red.shade700
                            : isLow
                                ? Colors.orange.shade800
                                : const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () =>
                          _toggleInventoryAvailability(productId, isAvailable),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? const Color(0xFFECFDF5)
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isAvailable
                                ? const Color(0xFFA7F3D0)
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Text(
                          isAvailable ? 'AVAILABLE' : 'OFFLINE',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: isAvailable
                                ? const Color(0xFF059669)
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. FAST QUICK STOCK ADJUSTER (- / +) AND EDIT
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Minus button
                  InkWell(
                    onTap: () => _adjustInventoryStock(productId, stock, -1),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(
                        Icons.remove,
                        size: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Current stock
                  Text(
                    '$stock',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Plus button
                  InkWell(
                    onTap: () => _adjustInventoryStock(productId, stock, 1),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF059669).withValues(alpha: .3),
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 14,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _editInventoryDialog(
                  productId: productId,
                  inventoryData: invData,
                  productName: name,
                  imageUrl: imageUrl,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'EDIT ALL',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // TAB 2: STORE RIDERS FLEET
  // ==========================================================

  Widget _buildRidersView(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> riders,
  ) {
    if (riders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.two_wheeler_rounded,
        title: 'No Riders Assigned',
        subtitle:
            'No delivery partners are currently assigned to this dark store.',
      );
    }

    return ListView.builder(
      key: const PageStorageKey('store_riders_list_key'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: riders.length,
      itemBuilder: (context, idx) {
        final doc = riders[idx];
        final data = doc.data();
        final name = _toStr(data['name'], 'Delivery Partner');
        final email = _toStr(data['email']);
        final phone = _toStr(data['phone'], _toStr(data['phoneNumber']));
        final vehicle = _toStr(data['vehicleNumber']);
        final isOnline = data['isOnline'] == true;

        return Container(
          key: ValueKey(doc.id),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF059669).withValues(alpha: .15),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF059669),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? Colors.green : Colors.grey,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    if (vehicle.isNotEmpty)
                      Text(
                        'Vehicle: $vehicle',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              // Call action button
              if (phone.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _makeCall(phone),
                  icon: const Icon(Icons.call, size: 14),
                  label: const Text('CALL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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
  // TAB 3: STORE SETTINGS & OPERATIONS
  // ==========================================================

  Widget _buildStoreSettingsView(
    Map<String, dynamic> storeData,
    String storeName,
    String storeCode,
    String storeStatus,
    bool isActive,
    int totalOrders,
  ) {
    final address = _toStr(storeData['address'], 'No physical address');
    final city = _toStr(storeData['city'], 'Store City');
    final phone = _toStr(storeData['phone'], 'Not specified');
    final radius = _toStr(storeData['serviceRadiusKm'], '5.0');
    final priority = _toStr(storeData['priority'], '1');

    return ListView(
      key: const PageStorageKey('store_settings_list_key'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      physics: const BouncingScrollPhysics(),
      children: [
        // Store Profile Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFF059669),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (storeCode.isNotEmpty)
                          Text(
                            'Store ID / Code: $storeCode',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _buildStoreDetailRow(
                Icons.location_on_outlined,
                'Address',
                '$address, $city',
              ),
              _buildStoreDetailRow(
                Icons.phone_outlined,
                'Store Helpline',
                phone,
              ),
              _buildStoreDetailRow(
                Icons.radar_rounded,
                'Service Radius',
                '$radius km delivery coverage',
              ),
              _buildStoreDetailRow(
                Icons.bar_chart_rounded,
                'Routing Priority',
                'Priority rank: $priority',
              ),
              _buildStoreDetailRow(
                Icons.receipt_long_outlined,
                'Lifetime Orders',
                '$totalOrders store orders',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Quick Store Operational Controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'OPERATIONAL TOGGLES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: storeStatus == 'OPEN',
                activeTrackColor: const Color(0xFF059669),
                title: const Text(
                  'Accept New Orders (Store Open)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  storeStatus == 'OPEN'
                      ? 'Store is OPEN and receiving customer orders'
                      : 'Store is BUSY (new orders reroute to other stores)',
                  style: const TextStyle(fontSize: 11),
                ),
                onChanged: (val) {
                  _setStoreStatus(val ? 'OPEN' : 'BUSY');
                },
              ),
              const Divider(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: isActive,
                activeTrackColor: const Color(0xFF059669),
                title: const Text(
                  'Store Active Status',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  isActive
                      ? 'Store is online and discoverable'
                      : 'Store is completely disabled',
                  style: const TextStyle(fontSize: 11),
                ),
                onChanged: (val) {
                  _setActive(val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Dark store operations guidelines
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withValues(alpha: .06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF059669).withValues(alpha: .2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    color: Color(0xFF059669),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Fulfillment Best Practices',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '1. When a new order arrives, review product photos and verify item count on the visual packing checklist.\n'
                '2. Check off items as you bag them to ensure 100% packing accuracy.\n'
                '3. Press "Mark as Packed & Ready" immediately so the assigned rider can pick up without delay.\n'
                '4. Keep inventory stock updated; out-of-stock items will automatically reroute orders to backup dark stores.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Logout
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('LOG OUT OF STORE MANAGER'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // EMPTY STATE HELPER
  // ==========================================================

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // BOTTOM NAVIGATION
  // ==========================================================

  Widget _buildBottomNav({
    required int ordersToPack,
    required int lowStockCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) {
          setState(() => _selectedTabIndex = index);
          HapticFeedback.selectionClick();
        },
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF059669),
        unselectedItemColor: Colors.grey.shade500,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: ordersToPack > 0,
              label: Text('$ordersToPack'),
              backgroundColor: const Color(0xFFEA580C),
              child: const Icon(Icons.receipt_long_rounded),
            ),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: lowStockCount > 0,
              label: Text('$lowStockCount'),
              backgroundColor: Colors.red,
              child: const Icon(Icons.inventory_2_rounded),
            ),
            label: 'Inventory',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.two_wheeler_rounded),
            label: 'Riders',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.storefront_rounded),
            label: 'Store Info',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DEDICATED STATEFUL ORDER CARD (WITH SELF-CONTAINED CHECKLIST)
// Tapping a product item ONLY updates this card, NEVER refreshes screen
// ============================================================

class _ModernOrderCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Map<String, Map<String, dynamic>> productCatalog;
  final ValueChanged<String> onUpdateStatus;
  final ValueChanged<String> onMakeCall;
  final void Function(String, {bool error}) onShowMessage;

  const _ModernOrderCard({
    super.key,
    required this.doc,
    required this.productCatalog,
    required this.onUpdateStatus,
    required this.onMakeCall,
    required this.onShowMessage,
  });

  @override
  State<_ModernOrderCard> createState() => _ModernOrderCardState();
}

class _ModernOrderCardState extends State<_ModernOrderCard> {
  // Self-contained packing checklist indices for this order only
  final Set<int> _checkedItemIndices = <int>{};

  double _toDouble(dynamic val) {
    if (val is num) return val.toDouble();
    return double.tryParse(val?.toString() ?? '') ?? 0.0;
  }

  int _toInt(dynamic val) {
    if (val is num) return val.toInt();
    return int.tryParse(val?.toString() ?? '') ?? 0;
  }

  String _toStr(dynamic val, [String fallback = '']) {
    final s = val?.toString().trim() ?? '';
    return s.isEmpty ? fallback : s;
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp is! Timestamp) return 'Recently';
    final date = timestamp.toDate();
    final diff = DateTime.now().difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return const Color(0xFFEA580C);
      case 'accepted':
        return const Color(0xFF2563EB);
      case 'packed':
        return const Color(0xFF7C3AED);
      case 'assigned to rider':
      case 'assigned':
        return const Color(0xFF0284C7);
      case 'picked up':
      case 'out for delivery':
        return const Color(0xFF0D9488);
      case 'delivered':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF4B5563);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final orderId = widget.doc.id;
    final shortId =
        orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId;
    final status = _toStr(data['status'], 'Placed');
    final statusColor = _statusColor(status);
    final customerName = _toStr(data['customerName'], 'Customer');
    final customerPhone = _toStr(data['customerPhone']);
    final address = _toStr(data['address']);
    final grandTotal = _toDouble(data['grandTotal']);
    final paymentMethod = _toStr(data['paymentMethod'], 'Prepaid');
    final isPrepaid = data['isPrepaid'] == true;
    final amountToCollect = _toDouble(data['amountToCollect']);
    final isRerouted = data['isRerouted'] == true;
    final originalStore = _toStr(data['originalNearestStoreName']);
    final riderName = _toStr(data['riderName']);
    final riderPhone = _toStr(data['riderPhone']);
    final hasRider = _toStr(data['riderId']).isNotEmpty;

    // Parse items
    final rawItems = data['items'];
    final items = <Map<String, dynamic>>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          items.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final isNeedPacking =
        status.toLowerCase() == 'placed' || status.toLowerCase() == 'accepted';
    final isPacked = status.toLowerCase() == 'packed';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNeedPacking
              ? const Color(0xFFF97316).withValues(alpha: .3)
              : Colors.grey.shade200,
          width: isNeedPacking ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. CARD TOP: Order ID, Time, Status Pill
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                // Order ID with copy icon
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: orderId));
                    widget.onShowMessage('Order ID copied to clipboard');
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#$shortId',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.copy_rounded,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Time placed
                Text(
                  _formatTimeAgo(data['createdAt']),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Status Pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: .25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. REROUTED ORDER BANNER (IF REROUTED FROM ANOTHER STORE)
          if (isRerouted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: const Color(0xFFFEF3C7),
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    size: 15,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      originalStore.isNotEmpty
                          ? '⚡ REROUTED ORDER: Re-routed from "$originalStore" due to store stock'
                          : '⚡ REROUTED ORDER: Auto-rerouted from backup store',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1, thickness: 1),

          // 3. PACKING LIST HEADER WITH ITEM COUNT
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            color: const Color(0xFFFAFAFA),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_bag_outlined,
                  size: 15,
                  color: Color(0xFF059669),
                ),
                const SizedBox(width: 6),
                Text(
                  'ITEMS TO PACK (${items.length})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${grandTotal.toStringAsFixed(0)} Total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),

          // 4. THE CORE FEATURE: PRODUCT PHOTOS FOR ORDER ITEMS!
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'No item details provided.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              itemCount: items.length,
              separatorBuilder: (context, _) =>
                  Divider(height: 12, color: Colors.grey.shade100),
              itemBuilder: (context, idx) {
                final item = items[idx];
                final productId =
                    _toStr(item['productId'], _toStr(item['id']));
                final itemName = _toStr(
                  item['name'],
                  _toStr(
                    item['productName'],
                    widget.productCatalog[productId]?['name'] ?? 'Product',
                  ),
                );
                final itemQuantity = _toInt(item['quantity']);

                // Resolving Product Image:
                // 1. From order item image field
                // 2. From central productCatalog image or imageUrl
                String? imageUrl = _toStr(item['image']);
                if (imageUrl.isEmpty) {
                  final catData = widget.productCatalog[productId];
                  if (catData != null) {
                    imageUrl = _toStr(
                      catData['image'],
                      _toStr(catData['imageUrl']),
                    );
                  }
                }

                // Checkbox state handled strictly in this card's State!
                final isChecked = _checkedItemIndices.contains(idx);

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isChecked) {
                        _checkedItemIndices.remove(idx);
                      } else {
                        _checkedItemIndices.add(idx);
                        HapticFeedback.lightImpact();
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        // Checkbox for packing
                        Checkbox(
                          value: isChecked,
                          activeColor: const Color(0xFF059669),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _checkedItemIndices.add(idx);
                                HapticFeedback.lightImpact();
                              } else {
                                _checkedItemIndices.remove(idx);
                              }
                            });
                          },
                        ),

                        // PRODUCT PHOTO THUMBNAIL
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: imageUrl.isNotEmpty
                              ? CachedProductImage(
                                  url: imageUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.contain,
                                  placeholder: Container(
                                    color: Colors.grey.shade100,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: const Icon(
                                    Icons.fastfood_outlined,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                )
                              : const Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                        ),
                        const SizedBox(width: 10),

                        // ITEM NAME & DETAILS
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  decoration: isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isChecked
                                      ? Colors.grey
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              if (widget.productCatalog[productId]
                                      ?['sellingUnit'] !=
                                  null)
                                Text(
                                  '${widget.productCatalog[productId]!['sellingUnit']}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // QUANTITY BADGE PILL
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isChecked
                                ? Colors.green.shade50
                                : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '× $itemQuantity',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: isChecked
                                  ? const Color(0xFF059669)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          const Divider(height: 1, thickness: 1),

          // 5. CUSTOMER, ADDRESS & PAYMENT INFO
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 15,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        customerName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (customerPhone.isNotEmpty)
                      InkWell(
                        onTap: () => widget.onMakeCall(customerPhone),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.call_rounded,
                                size: 12,
                                color: Color(0xFF059669),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Call',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                // Payment & Rider Row
                Row(
                  children: [
                    // Payment badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isPrepaid
                            ? Colors.blue.shade50
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPrepaid
                            ? 'PAID ($paymentMethod)'
                            : 'COLLECT CASH: ₹${amountToCollect.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isPrepaid
                              ? Colors.blue.shade800
                              : Colors.amber.shade900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Rider assignment
                    if (hasRider)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.two_wheeler_rounded,
                            size: 14,
                            color: Color(0xFF059669),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            riderName.isNotEmpty ? riderName : 'Rider Assigned',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
                          if (riderPhone.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => widget.onMakeCall(riderPhone),
                              child: const Icon(
                                Icons.phone_forwarded,
                                size: 13,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ],
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.hourglass_top_rounded,
                            size: 13,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Assigning Rider...',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 6. ACTION BUTTONS: "MARK PACKED" OR MENU
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: Row(
              children: [
                if (isNeedPacking)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onUpdateStatus('Packed'),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text(
                        'MARK AS PACKED & READY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  )
                else if (isPacked)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD8B4FE)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.done_all_rounded,
                            size: 16,
                            color: Color(0xFF7C3AED),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'PACKED • WAITING FOR RIDER PICKUP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      'Status: $status',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),

                // Status menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (val) => widget.onUpdateStatus(val),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'Packed',
                      child: Text('Mark Packed'),
                    ),
                    PopupMenuItem(
                      value: 'Out for Delivery',
                      child: Text('Mark Out for Delivery'),
                    ),
                    PopupMenuItem(
                      value: 'Delivered',
                      child: Text('Mark Delivered'),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'Cancelled',
                      child: Text(
                        'Cancel Order',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
