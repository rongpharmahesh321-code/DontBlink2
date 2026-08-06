import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../services/order_service.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String paymentMethod = "Cash on Delivery";

  final OrderService orderService = OrderService();

  @override
  Widget build(BuildContext context) {
    double subtotal = 0;

    for (var item in Cart.items) {
      subtotal +=
          double.parse(item.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) *
          item.quantity;
    }

    const double deliveryFee = 25;
    const double platformFee = 5;

    final double total = subtotal + deliveryFee + platformFee;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Checkout"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: const ListTile(
              leading: Icon(Icons.location_on, color: Colors.green),
              title: Text(
                "Select Delivery Address",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Tap to choose an address"),
              trailing: Icon(Icons.chevron_right),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "Order Summary",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          ...Cart.items.map(
            (item) => Card(
              child: ListTile(
                leading: Image.network(
                  item.product.image,
                  width: 55,
                  height: 55,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image),
                ),
                title: Text(item.product.name),
                subtitle: Text("Qty: ${item.quantity}"),
                trailing: Text(
                  item.product.price,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
                  _billRow("Subtotal", "₹${subtotal.toStringAsFixed(0)}"),
                  const SizedBox(height: 10),
                  _billRow("Delivery Fee", "₹25"),
                  const SizedBox(height: 10),
                  _billRow("Platform Fee", "₹5"),
                  const Divider(),
                  _billRow(
                    "Grand Total",
                    "₹${total.toStringAsFixed(0)}",
                    bold: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "Payment Method",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          RadioListTile<String>(
            value: "Cash on Delivery",
            groupValue: paymentMethod,
            onChanged: (value) {
              setState(() {
                paymentMethod = value!;
              });
            },
            title: const Text("Cash on Delivery"),
          ),

          RadioListTile<String>(
            value: "UPI",
            groupValue: paymentMethod,
            onChanged: (value) {
              setState(() {
                paymentMethod = value!;
              });
            },
            title: const Text("UPI"),
          ),

          RadioListTile<String>(
            value: "Razorpay",
            groupValue: paymentMethod,
            onChanged: (value) {
              setState(() {
                paymentMethod = value!;
              });
            },
            title: const Text("Razorpay"),
          ),

          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                await orderService.placeOrder(
                  customerName: "Mahesh",
                  address: "Diphu, Assam",
                  paymentMethod: paymentMethod,
                );

                Cart.items.clear();

                if (!mounted) return;

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrderSuccessScreen(),
                  ),
                );
              },
              child: const Text(
                "PLACE ORDER",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
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
