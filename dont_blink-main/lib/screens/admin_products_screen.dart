import 'package:flutter/material.dart';

class AdminProductsScreen extends StatelessWidget {
  const AdminProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Products"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
        onPressed: () {
          // Next: Add Product Screen
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProductCard("Fresh Apples", "₹120/kg", "Fruits"),
          _buildProductCard("Milk", "₹55", "Dairy"),
          _buildProductCard("Bread", "₹40", "Bakery"),
        ],
      ),
    );
  }

  Widget _buildProductCard(String name, String price, String category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.shopping_bag, color: Colors.white),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("$price\n$category"),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            // Next step:
            // Edit / Delete
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: "edit", child: Text("Edit")),
            PopupMenuItem(value: "delete", child: Text("Delete")),
          ],
        ),
      ),
    );
  }
}
