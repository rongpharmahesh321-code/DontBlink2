import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  Future<void> updateStatus(String id, String status) async {
    await FirebaseFirestore.instance.collection("orders").doc(id).update({
      "status": status,
    });
  }

  Color statusColor(String status) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Orders"),
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
              child: Text("No Orders Found", style: TextStyle(fontSize: 20)),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index].data() as Map<String, dynamic>;

              final id = orders[index].id;

              final status = order["status"] ?? "Placed";

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order["customerName"] ?? "",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(order["address"] ?? ""),

                      const SizedBox(height: 6),

                      Text(
                        "₹${order["grandTotal"]}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 10),

                      Chip(
                        backgroundColor: statusColor(status),
                        label: Text(
                          status,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton(
                            onPressed: () => updateStatus(id, "Packed"),
                            child: const Text("Packed"),
                          ),

                          ElevatedButton(
                            onPressed: () =>
                                updateStatus(id, "Out for Delivery"),
                            child: const Text("Out for Delivery"),
                          ),

                          ElevatedButton(
                            onPressed: () => updateStatus(id, "Delivered"),
                            child: const Text("Delivered"),
                          ),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () => updateStatus(id, "Cancelled"),
                            child: const Text("Cancel"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
