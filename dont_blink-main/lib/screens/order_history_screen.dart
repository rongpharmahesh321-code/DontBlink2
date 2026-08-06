import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order.dart';
import 'order_details_screen.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case "Delivered":
        return Colors.green;
      case "Out for Delivery":
        return Colors.orange;
      case "Packed":
        return Colors.blue;
      case "Cancelled":
        return Colors.red;
      default:
        return Colors.deepPurple;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case "Delivered":
        return Icons.check_circle;
      case "Out for Delivery":
        return Icons.delivery_dining;
      case "Packed":
        return Icons.inventory;
      case "Cancelled":
        return Icons.cancel;
      default:
        return Icons.shopping_bag;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Orders"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("orders")
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No Orders Yet",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = OrderModel.fromFirestore(
                orders[index].id,
                orders[index].data() as Map<String, dynamic>,
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(
                      order.status,
                    ).withOpacity(0.15),
                    child: Icon(
                      _statusIcon(order.status),
                      color: _statusColor(order.status),
                    ),
                  ),
                  title: Text(
                    "₹${order.grandTotal.toStringAsFixed(0)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${order.items.length} item(s)\n${order.status}",
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailsScreen(order: order),
                      ),
                    );
                    // Order Details Screen (next)
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
