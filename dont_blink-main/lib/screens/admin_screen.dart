import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_banners_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_products_screen.dart';
import 'admin_sections_screen.dart';
import 'admin_stores_screen.dart';
import 'admin_store_inventory_screen.dart';
import 'admin_store_managers_screen.dart';
import 'admin_subcategories_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  bool _loading = true;
  bool _refreshing = false;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _orders = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _products = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _categories = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _subcategories = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _banners = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sections = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _users = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _stores = [];

  final Map<String, String> _collectionErrors = {};

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
    _loadDashboard();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeCollection(
    String collection,
  ) async {
    try {
      final snapshot = await _firestore.collection(collection).get();
      return snapshot.docs;
    } catch (e) {
      _collectionErrors[collection] = e.toString();
      return [];
    }
  }

  Future<void> _loadDashboard({bool showRefresh = false}) async {
    if (showRefresh) {
      setState(() => _refreshing = true);
    } else {
      setState(() => _loading = true);
    }

    _collectionErrors.clear();

    final results = await Future.wait([
      _safeCollection('orders'),
      _safeCollection('products'),
      _safeCollection('categories'),
      _safeCollection('banners'),
      _safeCollection('sections'),
      _safeCollection('users'),
      _safeCollection('stores'),
      _safeCollection('subcategories'),
    ]);

    if (!mounted) return;

    setState(() {
      _orders = results[0];
      _products = results[1];
      _categories = results[2];
      _banners = results[3];
      _sections = results[4];
      _users = results[5];
      _stores = results[6];
      _subcategories = results[7];
      _loading = false;
      _refreshing = false;
    });
  }

  void _openOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminOrdersScreen()),
    );
  }

  void _openProducts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminProductsScreen()),
    );
  }

  void _openCategories() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminCategoriesScreen()),
    );
  }

  void _openSubcategories() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminSubcategoriesScreen()),
    );
  }

  void _openSections() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminSectionsScreen()),
    );
  }

  void _openBanners() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminBannersScreen()),
    );
  }

  void _openStores() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminStoresScreen()),
    );
  }

  void _openInventory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminStoreInventoryScreen()),
    );
  }

  void _openLegalDocuments() {
    _showLegalEditor();
  }

  void _openStoreManagers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminStoreManagersScreen()),
    );
  }

  int _storeManagerCount() {
    return _users.where((doc) {
      return doc.data()['role']?.toString().trim() == 'storeManager';
    }).length;
  }

  Future<void> _showLegalEditor() async {
    final termsRef = _firestore.collection('legal_documents').doc('terms');
    final privacyRef = _firestore.collection('legal_documents').doc('privacy');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
              future: Future.wait([termsRef.get(), privacyRef.get()]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 280,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xff08A84F),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return SizedBox(
                    height: 280,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 42,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Unable to load Legal & Policies',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final terms = snapshot.data![0].data() ?? {};
                final privacy = snapshot.data![1].data() ?? {};

                final termsContent = terms['content']?.toString() ?? '';
                final privacyContent = privacy['content']?.toString() ?? '';

                final termsExists = termsContent.trim().isNotEmpty;
                final privacyExists = privacyContent.trim().isNotEmpty;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Legal & Policies',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add or edit the policies shown to customers in Settings.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),

                      _legalAdminCard(
                        icon: Icons.description_outlined,
                        title: 'Terms & Conditions',
                        exists: termsExists,
                        onTap: () => _editLegalDocument(
                          type: 'terms',
                          title: 'Terms & Conditions',
                          initialContent: termsContent,
                        ),
                      ),

                      const SizedBox(height: 12),

                      _legalAdminCard(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        exists: privacyExists,
                        onTap: () => _editLegalDocument(
                          type: 'privacy',
                          title: 'Privacy Policy',
                          initialContent: privacyContent,
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Tap ADD to create a policy or EDIT to update an existing one.',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _editLegalDocument({
    required String type,
    required String title,
    required String initialContent,
  }) async {
    final controller = TextEditingController(text: initialContent);

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              initialContent.trim().isEmpty ? 'Add $title' : 'Edit $title',
            ),
            content: SizedBox(
              width: 600,
              child: TextField(
                controller: controller,
                maxLines: 16,
                minLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Enter $title content...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('CANCEL'),
              ),
              FilledButton(
                onPressed: () async {
                  final content = controller.text.trim();

                  if (content.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter some content.'),
                      ),
                    );
                    return;
                  }

                  try {
                    await _firestore
                        .collection('legal_documents')
                        .doc(type)
                        .set({
                          'title': title,
                          'content': content,
                          'updatedAt': FieldValue.serverTimestamp(),
                          'updatedBy': _auth.currentUser?.uid ?? '',
                        }, SetOptions(merge: true));

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  } catch (e) {
                    if (!dialogContext.mounted) return;

                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Unable to save $title: $e')),
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff08A84F),
                ),
                child: const Text('SAVE'),
              ),
            ],
          );
        },
      );

      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title saved successfully.'),
            backgroundColor: const Color(0xff08A84F),
          ),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Widget _legalAdminCard({
    required IconData icon,
    required String title,
    required bool exists,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xffF7FAF8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffDDE9E1)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xffE8F5E9),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: const Color(0xff08783F)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exists
                        ? 'Added — tap to edit'
                        : 'Not added yet — tap to add',
                    style: TextStyle(
                      fontSize: 11,
                      color: exists
                          ? const Color(0xff08783F)
                          : Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              exists ? Icons.edit_outlined : Icons.add_circle_outline,
              color: const Color(0xff08A84F),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Logout?',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'Are you sure you want to logout from the admin dashboard?',
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
              ),
              child: const Text('LOGOUT'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;
    await _auth.signOut();
  }

  String _firstName() {
    final email = _auth.currentUser?.email ?? '';
    if (email.isEmpty) return 'Admin';

    final name = email.split('@').first.trim();
    return name.isEmpty ? 'Admin' : name;
  }

  int _availableProductCount() {
    return _products.where((doc) {
      final data = doc.data();
      final available = data['isAvailable'] != false;
      final rawStock = data['stock'];

      final stock = rawStock is num
          ? rawStock.toInt()
          : int.tryParse(rawStock?.toString() ?? '') ?? 0;

      return available && stock > 0;
    }).length;
  }

  int _activeCount(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return docs.where((doc) => doc.data()['isActive'] != false).length;
  }

  int _activeOrders() {
    int count = 0;

    for (final doc in _orders) {
      final status = doc.data()['status']?.toString().toLowerCase() ?? '';

      if (!status.contains('delivered') && !status.contains('cancel')) {
        count++;
      }
    }

    return count;
  }

  int _deliveredOrders() {
    return _orders.where((doc) {
      final status = doc.data()['status']?.toString().toLowerCase() ?? '';
      return status.contains('delivered');
    }).length;
  }

  int _cancelledOrders() {
    return _orders.where((doc) {
      final status = doc.data()['status']?.toString().toLowerCase() ?? '';
      return status.contains('cancel');
    }).length;
  }

  int _activeStores() {
    return _stores.where((doc) {
      return doc.data()['isActive'] != false;
    }).length;
  }

  int _openStoreCount() {
    return _stores.where((doc) {
      final status = doc.data()['status']?.toString().toUpperCase() ?? '';
      return status == 'OPEN';
    }).length;
  }

  int _busyStores() {
    return _stores.where((doc) {
      final status = doc.data()['status']?.toString().toUpperCase() ?? '';
      return status == 'BUSY';
    }).length;
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF0F9D58).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF0F9D58).withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Color(0xFF10B981),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'ADMIN CONSOLE • LIVE',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Hello, ${_firstName()} 👋',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: Colors.white.withValues(alpha: 0.10),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _loadDashboard(showRefresh: true),
                child: const Padding(
                  padding: EdgeInsets.all(9),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: const Color(0xFFEF4444).withValues(alpha: 0.18),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _logout,
                child: const Padding(
                  padding: EdgeInsets.all(9),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFF87171),
                    size: 19,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: const Color(0xFF94A3B8),
                    size: 11,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _storeNetworkCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F9D58).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.hub_outlined, color: Color(0xFF0F9D58), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dark-Store Network',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Multi-store inventory routing & dispatch nodes',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _openStores,
                icon: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _networkMetric('${_stores.length}', 'Total Stores'),
              _networkMetric('${_activeStores()}', 'Active'),
              _networkMetric('${_openStoreCount()}', 'Open'),
              _networkMetric('${_busyStores()}', 'Busy'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _networkMetric(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F9D58),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ordersOverview() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Orders Overview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openOrders,
                child: const Text(
                  'View all orders →',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F9D58),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _orderMetric('Active', '${_activeOrders()}', const Color(0xFFF59E0B)),
              _orderMetric('Delivered', '${_deliveredOrders()}', const Color(0xFF10B981)),
              _orderMetric('Cancelled', '${_cancelledOrders()}', const Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderMetric(String title, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _warningBanner() {
    if (_collectionErrors.isEmpty) {
      return const SizedBox.shrink();
    }

    final collections = _collectionErrors.keys.join(', ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade800,
            size: 21,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Could not read: $collections',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0F9D58)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardBody() {
    return RefreshIndicator(
      color: const Color(0xFF0F9D58),
      onRefresh: () => _loadDashboard(showRefresh: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _header()),
          SliverToBoxAdapter(child: _warningBanner()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionTitle('STORE AT A GLANCE', Icons.analytics_outlined),
                SizedBox(
                  height: 126,
                  child: GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.55,
                    children: [
                      _statCard(
                        title: 'Total orders',
                        value: '${_orders.length}',
                        icon: Icons.shopping_bag_outlined,
                        color: const Color(0xFFF59E0B),
                        onTap: _openOrders,
                      ),
                      _statCard(
                        title: 'Available products',
                        value: '${_availableProductCount()}',
                        icon: Icons.inventory_2_outlined,
                        color: const Color(0xFF0F9D58),
                        onTap: _openProducts,
                      ),
                      _statCard(
                        title: 'Categories',
                        value: '${_activeCount(_categories)}',
                        icon: Icons.category_outlined,
                        color: const Color(0xFF06B6D4),
                        onTap: _openCategories,
                      ),
                      _statCard(
                        title: 'Customers',
                        value: '${_users.length}',
                        icon: Icons.people_outline_rounded,
                        color: const Color(0xFF3B82F6),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _sectionTitle('DARK STORES & DISPATCH', Icons.hub_outlined),
                _storeNetworkCard(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _quickAction(
                        icon: Icons.store_rounded,
                        title: 'Dark Stores',
                        subtitle: 'Locations & routing',
                        color: const Color(0xFF0F9D58),
                        onTap: _openStores,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _quickAction(
                        icon: Icons.inventory_2_outlined,
                        title: 'Store Inventory',
                        subtitle: 'Multi-store stock',
                        color: const Color(0xFF6366F1),
                        onTap: _openInventory,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _quickAction(
                        icon: Icons.manage_accounts_outlined,
                        title: 'Store Managers',
                        subtitle: '${_storeManagerCount()} assigned',
                        color: const Color(0xFF8B5CF6),
                        onTap: _openStoreManagers,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _quickAction(
                        icon: Icons.delivery_dining_outlined,
                        title: 'Assign Riders',
                        subtitle: '${_activeOrders()} active orders',
                        color: const Color(0xFF3B82F6),
                        onTap: _openOrders,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ordersOverview(),
                const SizedBox(height: 18),
                _sectionTitle('CATALOGUE & MERCHANDISING', Icons.storefront_outlined),
                Row(
                  children: [
                    Expanded(
                      child: _quickAction(
                        icon: Icons.inventory_2_outlined,
                        title: 'Products Catalogue',
                        subtitle: 'Prices, units & stock',
                        color: const Color(0xFF0F9D58),
                        onTap: _openProducts,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _quickAction(
                        icon: Icons.category_outlined,
                        title: 'Categories',
                        subtitle: 'Store categories',
                        color: const Color(0xFF14B8A6),
                        onTap: _openCategories,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _quickAction(
                        icon: Icons.view_list_rounded,
                        title: 'Sections',
                        subtitle: '${_activeCount(_sections)} active',
                        color: const Color(0xFF6366F1),
                        onTap: _openSections,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _quickAction(
                        icon: Icons.view_carousel_rounded,
                        title: 'Home Banners',
                        subtitle: '${_activeCount(_banners)} active',
                        color: const Color(0xFFF97316),
                        onTap: _openBanners,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _quickAction(
                        icon: Icons.account_tree_outlined,
                        title: 'Subcategories',
                        subtitle: '${_subcategories.length} taxonomies',
                        color: const Color(0xFFF59E0B),
                        onTap: _openSubcategories,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _quickAction(
                        icon: Icons.description_outlined,
                        title: 'Legal Documents',
                        subtitle: 'Terms & Policies',
                        color: const Color(0xFF64748B),
                        onTap: _openLegalDocuments,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F9D58).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.verified_outlined,
                          color: Color(0xFF0F9D58),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Multi-Store Routing Active',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Intelligent dark-store selection & rider dispatch active.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF0F9D58),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7F6),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Stack(
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: _dashboardBody(),
                ),
                if (_refreshing)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
    );
  }
}
