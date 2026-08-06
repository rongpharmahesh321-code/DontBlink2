import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/cart.dart';
import '../models/wishlist.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    int quantity = Cart.getQuantity(widget.product);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        backgroundColor: Colors.green,
        elevation: 0,
        title: Text(widget.product.name),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                Wishlist.toggle(widget.product);
                print("Wishlist items:${Wishlist.items.length}");
              });
            },
            icon: Icon(
              Wishlist.contains(widget.product)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: Colors.white,
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                widget.product.image,
                style: const TextStyle(fontSize: 130),
              ),
            ),
          ),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ListView(
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Row(
                    children: [
                      Icon(Icons.star, color: Colors.orange),
                      SizedBox(width: 5),
                      Text(
                        "4.8 (2,341 reviews)",
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Text(
                        widget.product.price,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),

                      const SizedBox(width: 15),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "20% OFF",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  const ListTile(
                    leading: Icon(Icons.delivery_dining, color: Colors.green),
                    title: Text("Delivery"),
                    subtitle: Text("10–15 minutes"),
                  ),

                  ListTile(
                    leading: const Icon(Icons.category, color: Colors.blue),
                    title: const Text("Category"),
                    subtitle: Text(widget.product.category),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Description",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Fresh premium quality product sourced directly from trusted farms. Carefully packed to ensure maximum freshness and delivered to your doorstep in minutes.",
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(15),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: quantity == 0
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: () {
                  setState(() {
                    Cart.add(widget.product);
                  });
                },
                child: const Text(
                  "ADD TO CART",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle, size: 40),
                    onPressed: () {
                      setState(() {
                        Cart.remove(widget.product);
                      });
                    },
                  ),

                  Text(
                    "$quantity",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.add_circle, size: 40),
                    onPressed: () {
                      setState(() {
                        Cart.add(widget.product);
                      });
                    },
                  ),
                ],
              ),
      ),
    );
  }
}
