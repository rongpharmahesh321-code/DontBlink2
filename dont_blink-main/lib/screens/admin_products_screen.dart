import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'add_product_screen.dart';
import 'edit_product_screen.dart';

class AdminProductsScreen extends StatelessWidget {
  const AdminProductsScreen({super.key});

  // ============================================================
  // DELETE PRODUCT
  // ============================================================

  Future<void> deleteProduct(String productId) async {
    await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .delete();
  }

  // ============================================================
  // UPDATE POPULAR STATUS
  // ============================================================

  Future<void> updatePopularStatus({
    required String productId,
    required bool isPopular,
  }) async {
    await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .update({'isPopular': isPopular});
  }

  // ============================================================
  // STOCK COLOR
  // ============================================================

  Color stockColor(int stock) {
    if (stock == 0) {
      return Colors.red;
    }

    if (stock <= 5) {
      return Colors.orange;
    }

    return Colors.green;
  }

  // ============================================================
  // STOCK TEXT
  // ============================================================

  String stockText(int stock) {
    if (stock == 0) {
      return 'OUT OF STOCK';
    }

    if (stock <= 5) {
      return 'LOW STOCK';
    }

    return 'IN STOCK';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Products'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),

      // ========================================================
      // ADD PRODUCT
      // ========================================================
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductScreen()),
          );
        },
      ),

      // ========================================================
      // PRODUCTS
      // ========================================================
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .orderBy('createdAt', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          // ====================================================
          // LOADING
          // ====================================================

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          // ====================================================
          // ERROR
          // ====================================================

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error loading products:\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            );
          }

          // ====================================================
          // EMPTY
          // ====================================================

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),

                  SizedBox(height: 15),

                  Text(
                    'No Products Yet',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 8),

                  Text('Tap + to add your first product.'),
                ],
              ),
            );
          }

          // ====================================================
          // PRODUCT DOCUMENTS
          // ====================================================

          final products = snapshot.data!.docs;

          // ====================================================
          // LIST
          // ====================================================

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,

            itemBuilder: (context, index) {
              final doc = products[index];

              final data = doc.data();

              // ==================================================
              // PRODUCT DATA
              // ==================================================

              final String name = data['name']?.toString() ?? 'Unnamed Product';

              final String price = data['price']?.toString() ?? '0';

              final String category =
                  data['category']?.toString() ?? 'Uncategorized';

              final String image = data['image']?.toString() ?? '';

              final int stock = data['stock'] is int
                  ? data['stock'] as int
                  : int.tryParse(data['stock']?.toString() ?? '') ?? 0;

              final bool isPopular = data['isPopular'] == true;

              // ==================================================
              // CARD
              // ==================================================

              return Card(
                margin: const EdgeInsets.only(bottom: 16),

                elevation: 3,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),

                child: Padding(
                  padding: const EdgeInsets.all(16),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      // ==========================================
                      // TOP
                      // ==========================================
                      Row(
                        children: [
                          // ----------------------------------------
                          // PRODUCT IMAGE
                          // ----------------------------------------
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),

                            child: image.trim().isNotEmpty
                                ? Image.network(
                                    image,
                                    width: 58,
                                    height: 58,
                                    fit: BoxFit.cover,

                                    errorBuilder: (_, __, ___) {
                                      return Container(
                                        width: 58,
                                        height: 58,
                                        color: Colors.green.shade100,
                                        child: const Icon(
                                          Icons.shopping_bag,
                                          color: Colors.green,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    width: 58,
                                    height: 58,
                                    color: Colors.green.shade100,
                                    child: const Icon(
                                      Icons.shopping_bag,
                                      color: Colors.green,
                                    ),
                                  ),
                          ),

                          const SizedBox(width: 14),

                          // ----------------------------------------
                          // NAME + CATEGORY
                          // ----------------------------------------
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,

                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  category,
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),

                          // ----------------------------------------
                          // MENU
                          // ----------------------------------------
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              // ====================================
                              // EDIT
                              // ====================================

                              if (value == 'edit') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditProductScreen(
                                      productId: doc.id,
                                      product: data,
                                    ),
                                  ),
                                );
                              }

                              // ====================================
                              // DELETE
                              // ====================================

                              if (value == 'delete') {
                                final shouldDelete = await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Delete Product?'),

                                      content: Text(
                                        'Are you sure you want to delete $name?',
                                      ),

                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context, false);
                                          },

                                          child: const Text('CANCEL'),
                                        ),

                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context, true);
                                          },

                                          child: const Text(
                                            'DELETE',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (shouldDelete == true) {
                                  await deleteProduct(doc.id);
                                }
                              }
                            },

                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),

                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      const Divider(),

                      const SizedBox(height: 10),

                      // ==========================================
                      // PRICE
                      // ==========================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,

                        children: [
                          const Text(
                            'Price',
                            style: TextStyle(color: Colors.grey),
                          ),

                          Text(
                            '₹$price',

                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // ==========================================
                      // STOCK
                      // ==========================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,

                        children: [
                          const Text(
                            'Stock',
                            style: TextStyle(color: Colors.grey),
                          ),

                          Text(
                            '$stock units',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ==========================================
                      // STOCK STATUS
                      // ==========================================
                      Container(
                        width: double.infinity,

                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),

                        decoration: BoxDecoration(
                          color: stockColor(stock).withValues(alpha: 0.12),

                          borderRadius: BorderRadius.circular(20),
                        ),

                        child: Text(
                          stockText(stock),

                          textAlign: TextAlign.center,

                          style: TextStyle(
                            color: stockColor(stock),

                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ==========================================
                      // POPULAR PRODUCT CONTROL
                      // ==========================================
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),

                        decoration: BoxDecoration(
                          color: isPopular
                              ? Colors.amber.shade50
                              : Colors.grey.shade100,

                          borderRadius: BorderRadius.circular(14),

                          border: Border.all(
                            color: isPopular
                                ? Colors.amber.shade200
                                : Colors.grey.shade300,
                          ),
                        ),

                        child: Row(
                          children: [
                            // --------------------------------------
                            // STAR
                            // --------------------------------------
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),

                              child: Icon(
                                isPopular ? Icons.star : Icons.star_border,

                                key: ValueKey(isPopular),

                                color: isPopular ? Colors.amber : Colors.grey,

                                size: 28,
                              ),
                            ),

                            const SizedBox(width: 12),

                            // --------------------------------------
                            // TEXT
                            // --------------------------------------
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  Text(
                                    isPopular
                                        ? 'Popular Product'
                                        : 'Not a Popular Product',

                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),

                                  const SizedBox(height: 3),

                                  Text(
                                    isPopular
                                        ? 'Shown in Popular Products'
                                        : 'Hidden from Popular Products',

                                    style: TextStyle(
                                      color: Colors.grey.shade600,

                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // --------------------------------------
                            // SWITCH
                            // --------------------------------------
                            Switch(
                              value: isPopular,

                              activeThumbColor: Colors.green,

                              onChanged: (value) async {
                                try {
                                  await updatePopularStatus(
                                    productId: doc.id,
                                    isPopular: value,
                                  );
                                } catch (e) {
                                  if (!context.mounted) {
                                    return;
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Unable to update popular status: $e',
                                      ),

                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
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
