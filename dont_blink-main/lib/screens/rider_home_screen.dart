import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'rider_orders_screen.dart';

class RiderHomeScreen extends StatelessWidget {
  const RiderHomeScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _deliveredOrders() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return FirebaseFirestore.instance
          .collection('orders')
          .where('riderId', isEqualTo: '__no_rider__')
          .where('status', isEqualTo: 'Delivered')
          .snapshots();
    }

    return FirebaseFirestore.instance
        .collection('orders')
        .where('riderId', isEqualTo: uid)
        .where('status', isEqualTo: 'Delivered')
        .snapshots();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rider Dashboard',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _deliveredOrders(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final month = DateTime(now.year, now.month, 1);

          int todayDelivered = 0;
          int monthDelivered = 0;
          double totalCollected = 0;
          double todayCollected = 0;
          double monthCollected = 0;
          double totalEarnings = 0;
          double todayEarnings = 0;
          double monthEarnings = 0;

          for (final doc in docs) {
            final data = doc.data();

            final hasSurcharge = data['hasSurcharge'] == true ||
                _number(data['deliverySurcharge']) > 0 ||
                _number(data['deliveryFee']) > 25;

            final payout = data['riderPayout'] != null
                ? _number(data['riderPayout'])
                : (data['riderEarnings'] != null
                    ? _number(data['riderEarnings'])
                    : (hasSurcharge ? 19.0 : 16.0));

            totalEarnings += payout;

            DateTime? deliveredAt;
            final rawDate =
                data['deliveredAt'] ??
                data['statusUpdatedAt'] ??
                data['updatedAt'];

            if (rawDate is Timestamp) {
              deliveredAt = rawDate.toDate();
            } else if (rawDate is DateTime) {
              deliveredAt = rawDate;
            }

            if (deliveredAt != null) {
              if (!deliveredAt.isBefore(today)) {
                todayDelivered++;
                todayEarnings += payout;
              }

              if (!deliveredAt.isBefore(month)) {
                monthDelivered++;
                monthEarnings += payout;
              }
            }

            final method = (data['paymentMethod'] ?? '')
                .toString()
                .toLowerCase();

            final isPrepaid =
                data['isPrepaid'] == true ||
                data['paymentStatus']?.toString().toLowerCase() == 'paid' ||
                method == 'online' ||
                method == 'online payment';

            if (!isPrepaid) {
              final amount = _number(
                data['amountToCollect'] ?? data['grandTotal'] ?? data['total'],
              );

              totalCollected += amount;

              if (deliveredAt != null && !deliveredAt.isBefore(today)) {
                todayCollected += amount;
              }

              if (deliveredAt != null && !deliveredAt.isBefore(month)) {
                monthCollected += amount;
              }
            }
          }

          String money(double amount) {
            return '₹${amount.toStringAsFixed(0)}';
          }

          return RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 300));
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Welcome, Rider 🛵',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // =====================================================
                // MY EARNINGS (HERO CARD)
                // =====================================================
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                color: Colors.white70,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'My Total Earnings',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              '₹16 (₹19 Rain Surge)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '₹${totalEarnings.toInt()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '₹16 standard rate • ₹19 rain surge rate',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(height: 1, color: Colors.white24),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Today's Earnings",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${todayEarnings.toInt()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$todayDelivered ${todayDelivered == 1 ? 'trip' : 'trips'}',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 42, color: Colors.white24),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "This Month",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${monthEarnings.toInt()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$monthDelivered ${monthDelivered == 1 ? 'trip' : 'trips'}',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // =====================================================
                // CASH TO DEPOSIT (COD STORE COLLECTIONS)
                // =====================================================
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Store Cash Collected (COD)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'To deposit',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              icon: Icons.check_circle_outline,
                              label: 'Total Delivered',
                              value: '${docs.length}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metric(
                              icon: Icons.payments_outlined,
                              label: 'Total Collected',
                              value: money(totalCollected),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              icon: Icons.today_outlined,
                              label: 'Today Trips',
                              value: '$todayDelivered',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metric(
                              icon: Icons.calendar_month_outlined,
                              label: 'Month Trips',
                              value: '$monthDelivered',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Today Collected',
                              value: money(todayCollected),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metric(
                              icon: Icons.savings_outlined,
                              label: 'Month Collected',
                              value: money(monthCollected),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // =====================================================
                // MY DELIVERIES
                // =====================================================
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(18),
                    leading: const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.green,
                      child: Icon(
                        Icons.delivery_dining,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    title: const Text(
                      'My Deliveries',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text('View assigned and available orders'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RiderOrdersScreen(),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // =====================================================
                // QUICK STATS
                // =====================================================
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'COD collection shows only cash collected on completed deliveries. Online/prepaid orders are excluded.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _metric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
