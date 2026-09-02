import 'package:flutter/material.dart';

import '../models/wishlist.dart';
import '../widgets/product_card.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Wishlist")),

      body: ValueListenableBuilder<int>(
        valueListenable: Wishlist.notifier,
        builder: (context, _, __) {
          if (Wishlist.items.isEmpty) {
            return const Center(
              child: Text(
                "No favourite products yet ❤️",
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),

            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),

            itemCount: Wishlist.items.length,

            itemBuilder: (context, index) {
              return ProductCard(product: Wishlist.items[index]);
            },
          );
        },
      ),
    );
  }
}
