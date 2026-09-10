import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/order.dart';
import 'order_details_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  String _filter = 'All';

  final List<String> _statuses = const [
    'Placed',
    'Packed',
    'Assigned to Rider',
    'Accepted',
    'Picked Up',
    'Out for Delivery',
    'Delivered',
    'Cancelled',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================================
  // ORDERS
  // ==========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> get _ordersStream =>
      _firestore.collection('orders').snapshots();

  // ==========================================================
  // HELPERS
  // ==========================================================

  String _normalise(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isActive(String status) {
    final value = _normalise(status);

    return value != 'delivered' && value != 'cancelled';
  }

  Color _statusColor(String status) {
    switch (_normalise(status)) {
      case 'placed':
        return Colors.deepPurple;

      case 'packed':
      case 'packing':
        return Colors.blue;

      case 'assigned to rider':
        return Colors.indigo;

      case 'accepted':
        return Colors.cyan.shade700;

      case 'picked up':
        return Colors.teal;

      case 'out for delivery':
        return Colors.orange;

      case 'delivered':
        return Colors.green;

      case 'cancelled':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (_normalise(status)) {
      case 'placed':
        return Icons.shopping_bag_outlined;

      case 'packed':
      case 'packing':
        return Icons.inventory_2_outlined;

      case 'assigned to rider':
        return Icons.person_pin_circle_outlined;

      case 'accepted':
        return Icons.thumb_up_outlined;

      case 'picked up':
        return Icons.inventory_outlined;

      case 'out for delivery':
        return Icons.delivery_dining_outlined;

      case 'delivered':
        return Icons.check_circle_outline;

      case 'cancelled':
        return Icons.cancel_outlined;

      default:
        return Icons.shopping_bag_outlined;
    }
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatDate(dynamic value) {
    final date = _date(value);

    if (date == null) {
      return 'Recently';
    }

    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/${date.year} • '
        '$hour:$minute $period';
  }

  String _timeAgo(dynamic value) {
    final date = _date(value);

    if (date == null) {
      return 'Recently';
    }

    final difference = DateTime.now().difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return _formatDate(value);
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _price(dynamic value) {
    final amount = _number(value);

    if (amount == amount.roundToDouble()) {
      return '₹${amount.toInt()}';
    }

    return '₹${amount.toStringAsFixed(2)}';
  }

  int _itemCount(Map<String, dynamic> data) {
    final raw = data['items'];

    if (raw is! List) {
      return 0;
    }

    int count = 0;

    for (final item in raw) {
      if (item is Map) {
        count += _number(item['quantity']).toInt();
      }
    }

    return count;
  }

  String _itemPreview(Map<String, dynamic> data) {
    final raw = data['items'];

    if (raw is! List || raw.isEmpty) {
      return 'No item information';
    }

    final names = <String>[];

    for (final item in raw.take(2)) {
      if (item is Map) {
        final name = item['name']?.toString().trim() ?? '';

        if (name.isNotEmpty) {
          names.add(name);
        }
      }
    }

    if (names.isEmpty) {
      return 'Items in this order';
    }

    final extra = raw.length > 2 ? ' + ${raw.length - 2} more' : '';

    return '${names.join(', ')}$extra';
  }

  // ==========================================================
  // FILTER
  // ==========================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtered(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final query = _search.trim().toLowerCase();

    final result = docs.where((doc) {
      final data = doc.data();

      final status = data['status']?.toString() ?? 'Placed';

      if (_filter == 'Active' && !_isActive(status)) {
        return false;
      }

      if (_filter == 'Delivered' && _normalise(status) != 'delivered') {
        return false;
      }

      if (_filter == 'Cancelled' && _normalise(status) != 'cancelled') {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final customer = data['customerName']?.toString().toLowerCase() ?? '';

      final phone = data['customerPhone']?.toString().toLowerCase() ?? '';

      final address = data['address']?.toString().toLowerCase() ?? '';

      final payment = data['paymentMethod']?.toString().toLowerCase() ?? '';

      final itemNames = _itemPreview(data).toLowerCase();

      return doc.id.toLowerCase().contains(query) ||
          customer.contains(query) ||
          phone.contains(query) ||
          address.contains(query) ||
          payment.contains(query) ||
          status.toLowerCase().contains(query) ||
          itemNames.contains(query);
    }).toList();

    result.sort((a, b) {
      final aDate = _date(a.data()['createdAt']);

      final bDate = _date(b.data()['createdAt']);

      if (aDate == null && bDate == null) {
        return 0;
      }

      if (aDate == null) {
        return 1;
      }

      if (bDate == null) {
        return -1;
      }

      return bDate.compareTo(aDate);
    });

    return result;
  }

  Map<String, int> _summary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int active = 0;
    int delivered = 0;
    int cancelled = 0;

    for (final doc in docs) {
      final status = doc.data()['status']?.toString() ?? 'Placed';

      if (_normalise(status) == 'delivered') {
        delivered++;
      } else if (_normalise(status) == 'cancelled') {
        cancelled++;
      } else {
        active++;
      }
    }

    return {
      'all': docs.length,
      'active': active,
      'delivered': delivered,
      'cancelled': cancelled,
    };
  }

  // ==========================================================
  // STATUS UPDATE
  // ==========================================================

  Future<void> _assignRider(
    QueryDocumentSnapshot<Map<String, dynamic>> orderDoc,
  ) async {
    final orderId = orderDoc.id;
    final orderData = orderDoc.data();
    final currentRiderId = orderData['riderId']?.toString().trim() ?? '';
    final currentStatus =
        orderData['status']?.toString().trim().toLowerCase() ?? '';

    if (currentStatus == 'delivered' || currentStatus == 'cancelled') {
      _message(
        'A completed or cancelled order cannot be assigned.',
        error: true,
      );
      return;
    }

    try {
      final riderSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'rider')
          .get();

      if (!mounted) return;

      final riders = riderSnapshot.docs;

      if (riders.isEmpty) {
        _message(
          'No rider accounts are available. Add a user with role "rider" first.',
          error: true,
        );
        return;
      }

      final selectedRiderId = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assign Rider',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Choose who will deliver order #$orderId.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: riders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 7),
                        itemBuilder: (context, index) {
                          final rider = riders[index];
                          final data = rider.data();

                          final name =
                              data['name']?.toString().trim().isNotEmpty == true
                              ? data['name'].toString().trim()
                              : data['email']?.toString().trim().isNotEmpty ==
                                    true
                              ? data['email'].toString().trim()
                              : 'Delivery Rider';

                          final phone = data['phone']?.toString().trim() ?? '';
                          final email = data['email']?.toString().trim() ?? '';
                          final selected = rider.id == currentRiderId;

                          return Material(
                            color: selected
                                ? Colors.green.withValues(alpha: 0.08)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () =>
                                  Navigator.pop(sheetContext, rider.id),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: Color(0xFFE8F5E9),
                                      child: Icon(
                                        Icons.delivery_dining_outlined,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            phone.isNotEmpty ? phone : email,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.green,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (selectedRiderId == null) return;

      final selectedDoc = riders.firstWhere((doc) => doc.id == selectedRiderId);
      final riderData = selectedDoc.data();

      final riderName = riderData['name']?.toString().trim().isNotEmpty == true
          ? riderData['name'].toString().trim()
          : riderData['email']?.toString().trim().isNotEmpty == true
          ? riderData['email'].toString().trim()
          : 'Delivery Rider';

      final riderPhone = riderData['phone']?.toString().trim() ?? '';

      await _firestore.collection('orders').doc(orderId).update({
        'riderId': selectedRiderId,
        'riderName': riderName,
        'riderPhone': riderPhone,
        'status': 'Assigned to Rider',
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _message('$riderName assigned to this order.');
    } catch (e) {
      if (!mounted) return;
      _message('Unable to assign rider: $e', error: true);
    }
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {'status': newStatus, 'updatedAt': Timestamp.now()},
        ]),
      });

      if (!mounted) return;

      _message('Order status updated to $newStatus.');
    } catch (e) {
      if (!mounted) return;

      _message('Unable to update order status.', error: true);
    }
  }

  Future<void> _showStatusSheet(String orderId, String currentStatus) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  const Text(
                    'Update order status',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Choose the next status for this order.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                  ),
                  const SizedBox(height: 13),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 4),
                      itemCount: _statuses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 7),
                      itemBuilder: (context, index) {
                        final status = _statuses[index];

                        final selected =
                            _normalise(status) == _normalise(currentStatus);

                        final color = _statusColor(status);

                        return Material(
                          color: selected
                              ? color.withValues(alpha: 0.08)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(13),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(13),
                            onTap: selected
                                ? () => Navigator.pop(sheetContext)
                                : () async {
                                    Navigator.pop(sheetContext);
                                    await _updateStatus(orderId, status);
                                  },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _statusIcon(status),
                                      color: color,
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      status,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: color,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // DETAILS
  // ==========================================================

  void _openDetails(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OrderDetailsScreen(order: OrderModel.fromFirestore(doc.id, data)),
      ),
    );
  }

  // ==========================================================
  // TRACKING
  // ==========================================================

  void _openTracking(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final latitude = data['customerLatitude'];

    final longitude = data['customerLongitude'];

    if (latitude is! num || longitude is! num) {
      _message('Customer delivery location is unavailable.', error: true);
      return;
    }

    _openDetails(doc);
  }

  // ==========================================================
  // SEARCH BAR
  // ==========================================================

  Widget _buildSearchBar() {
    return Padding(
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
          decoration: InputDecoration(
            hintText: 'Search order, customer, phone or item',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            prefixIcon: const Icon(Icons.search_rounded, color: Colors.green),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();

                      setState(() {
                        _search = '';
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // FILTERS
  // ==========================================================

  Widget _buildFilters(Map<String, int> summary) {
    final filters = <String>['All', 'Active', 'Delivered', 'Cancelled'];

    final counts = <String, int>{
      'All': summary['all'] ?? 0,
      'Active': summary['active'] ?? 0,
      'Delivered': summary['delivered'] ?? 0,
      'Cancelled': summary['cancelled'] ?? 0,
    };

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];

          final selected = _filter == filter;

          return ChoiceChip(
            selected: selected,
            label: Text(
              '$filter ${counts[filter]}',
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            selectedColor: Colors.green,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? Colors.green : Colors.grey.shade200,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            onSelected: (_) {
              setState(() {
                _filter = filter;
              });
            },
          );
        },
      ),
    );
  }

  // ==========================================================
  // SUMMARY
  // ==========================================================

  Widget _buildSummary(Map<String, int> summary) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 9, 16, 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _summaryItem('${summary['all'] ?? 0}', 'Orders'),
          _divider(),
          _summaryItem('${summary['active'] ?? 0}', 'Active'),
          _divider(),
          _summaryItem('${summary['delivered'] ?? 0}', 'Delivered'),
          _divider(),
          _summaryItem('${summary['cancelled'] ?? 0}', 'Cancelled'),
        ],
      ),
    );
  }

  Widget _summaryItem(String value, String title) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 30, color: Colors.white24);
  }

  // ==========================================================
  // ORDER CARD
  // ==========================================================

  Widget _orderCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int index,
  ) {
    final data = doc.data();

    final status = data['status']?.toString().trim().isNotEmpty == true
        ? data['status'].toString()
        : 'Placed';

    final color = _statusColor(status);

    final customer = data['customerName']?.toString().trim().isNotEmpty == true
        ? data['customerName'].toString()
        : 'Customer';

    final phone = data['customerPhone']?.toString().trim() ?? '';

    final payment = data['paymentMethod']?.toString().trim().isNotEmpty == true
        ? data['paymentMethod'].toString()
        : 'Payment unavailable';

    final total = data['grandTotal'];

    final count = _itemCount(data);

    final preview = _itemPreview(data);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index * 35)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 5, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_statusIcon(status), color: color, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                customer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '#${doc.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 11),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '$count ${count == 1 ? 'item' : 'items'} • $preview',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 9,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 11),

              Row(
                children: [
                  Expanded(child: _smallInfo(Icons.payments_outlined, payment)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _smallInfo(
                      Icons.schedule_outlined,
                      _timeAgo(data['createdAt']),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _price(total),
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),

              if (phone.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '📞 $phone',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 9),
                  ),
                ),
              ],

              const SizedBox(height: 11),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _assignRider(doc),
                  icon: const Icon(Icons.delivery_dining_outlined, size: 17),
                  label: Text(
                    data['riderId']?.toString().trim().isNotEmpty == true
                        ? 'CHANGE RIDER'
                        : 'ASSIGN RIDER',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 7),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openDetails(doc),
                      icon: const Icon(Icons.receipt_long_outlined, size: 17),
                      label: const Text(
                        'DETAILS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showStatusSheet(doc.id, status),
                      icon: const Icon(Icons.sync_alt_rounded, size: 17),
                      label: const Text(
                        'STATUS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                  if (_normalise(status) == 'out for delivery') ...[
                    const SizedBox(width: 7),
                    IconButton(
                      tooltip: 'View delivery details',
                      onPressed: () => _openTracking(doc),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.orange.shade50,
                        foregroundColor: Colors.orange,
                      ),
                      icon: const Icon(Icons.location_on_outlined, size: 19),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade500, size: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

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

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7F6),
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Manage Orders',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ordersStream,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to load orders',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final docs =
              snapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          final summary = _summary(docs);

          final filtered = _filtered(docs);

          return RefreshIndicator(
            color: Colors.green,
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 350));

              if (mounted) {
                setState(() {});
              }
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildSearchBar()),
                SliverToBoxAdapter(child: _buildFilters(summary)),
                SliverToBoxAdapter(child: _buildSummary(summary)),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_outlined,
                                color: Colors.green,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'No orders found',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              _search.trim().isNotEmpty
                                  ? 'Try a different search.'
                                  : 'Orders will appear here when customers place them.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
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
                      return _orderCard(filtered[index], index);
                    }, childCount: filtered.length),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 25)),
              ],
            ),
          );
        },
      ),
    );
  }
}
