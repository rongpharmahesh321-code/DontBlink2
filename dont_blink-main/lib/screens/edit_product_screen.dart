import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditProductScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> product;

  const EditProductScreen({
    super.key,
    required this.productId,
    required this.product,
  });

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController priceController;
  late TextEditingController imageController;
  late TextEditingController descriptionController;
  late TextEditingController stockController;

  late String category;

  bool loading = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.product["name"] ?? "");

    priceController = TextEditingController(
      text: widget.product["price"]?.toString().replaceAll("₹", "") ?? "",
    );

    imageController = TextEditingController(
      text: widget.product["image"] ?? "",
    );

    descriptionController = TextEditingController(
      text: widget.product["description"] ?? "",
    );

    stockController = TextEditingController(
      text: (widget.product["stock"] ?? 0).toString(),
    );

    category = widget.product["category"] ?? "Groceries";
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    imageController.dispose();
    descriptionController.dispose();
    stockController.dispose();
    super.dispose();
  }

  Future<void> updateProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection("products")
          .doc(widget.productId)
          .update({
            "name": nameController.text.trim(),
            "price": "₹${priceController.text.trim()}",
            "category": category,
            "image": imageController.text.trim(),
            "description": descriptionController.text.trim(),
            "stock": int.tryParse(stockController.text.trim()) ?? 0,
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Product updated successfully"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Product"),
          content: const Text("Are you sure you want to delete this product?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection("products")
        .doc(widget.productId)
        .delete();

    if (!mounted) return;

    Navigator.pop(context);
  }

  Widget buildField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        validator: (value) =>
            value == null || value.trim().isEmpty ? "Enter $label" : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Product"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            buildField(controller: nameController, label: "Product Name"),
            buildField(
              controller: priceController,
              label: "Price",
              keyboard: TextInputType.number,
            ),
            buildField(controller: imageController, label: "Image URL"),
            buildField(
              controller: descriptionController,
              label: "Description",
              maxLines: 3,
            ),
            buildField(
              controller: stockController,
              label: "Stock",
              keyboard: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Category",
              ),
              items: const [
                DropdownMenuItem(value: "Groceries", child: Text("Groceries")),
                DropdownMenuItem(value: "Snacks", child: Text("Snacks")),
                DropdownMenuItem(value: "Drinks", child: Text("Drinks")),
                DropdownMenuItem(value: "Ice Cream", child: Text("Ice Cream")),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    category = value;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: loading ? null : updateProduct,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "UPDATE PRODUCT",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: deleteProduct,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  "DELETE PRODUCT",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
