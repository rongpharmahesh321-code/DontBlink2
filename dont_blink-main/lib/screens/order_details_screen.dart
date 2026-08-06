import 'package:flutter/material.dart';

import '../models/order.dart';

class OrderDetailsScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Order Details"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                Icons.shopping_bag,
                color: _statusColor(order.status),
              ),
              title: Text(
                order.status,
                style: TextStyle(
                  color: _statusColor(order.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text("Order ID: ${order.id}"),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "Items",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          ...order.items.map(
            (item) => Card(
              child: ListTile(
                leading: Image.network(
                  item["image"],
                  width: 55,
                  height: 55,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image),
                ),
                title: Text(item["name"]),
                subtitle: Text("Qty: ${item["quantity"]}"),
                trailing: Text(item["price"]),
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "Delivery Address",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on, color: Colors.green),
              title: Text(order.customerName),
              subtitle: Text(order.address),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "Payment",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: const Icon(Icons.payment, color: Colors.green),
              title: Text(order.paymentMethod),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "Bill Details",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _billRow("Subtotal", "₹${order.subtotal.toStringAsFixed(0)}"),
                  const SizedBox(height: 10),
                  _billRow(
                    "Delivery Fee",
                    "₹${order.deliveryFee.toStringAsFixed(0)}",
                  ),
                  const SizedBox(height: 10),
                  _billRow(
                    "Platform Fee",
                    "₹${order.platformFee.toStringAsFixed(0)}",
                  ),
                  const Divider(),
                  _billRow(
                    "Grand Total",
                    "₹${order.grandTotal.toStringAsFixed(0)}",
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _billRow(String title, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: bold ? 18 : 16,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.green,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: bold ? 18 : 16,
          ),
        ),
      ],
    );
  }
}
