import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_orders_screen.dart';
import 'admin_products_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_sections_screen.dart';
import 'admin_banners_screen.dart';
import 'admin_banners_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: const Text(
            'Logout?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          content: const Text(
            'Are you sure you want to logout from the admin dashboard?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('CANCEL'),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),

              onPressed: () {
                Navigator.pop(dialogContext, true);
              },

              child: const Text('LOGOUT'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    await FirebaseAuth.instance.signOut();

    // AuthGate handles navigation automatically.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        title: const Text("Admin Dashboard"),

        backgroundColor: Colors.green,

        foregroundColor: Colors.white,

        centerTitle: true,

        actions: [
          IconButton(
            tooltip: 'Logout',

            icon: const Icon(Icons.logout),

            onPressed: () {
              _logout(context);
            },
          ),
        ],
      ),

      // ========================================================
      // DASHBOARD
      // ========================================================
      body: Padding(
        padding: const EdgeInsets.all(16),

        child: GridView.count(
          crossAxisCount: 2,

          crossAxisSpacing: 16,

          mainAxisSpacing: 16,

          children: [
            // ==================================================
            // ORDERS
            // ==================================================
            _dashboardCard(
              context,
              icon: Icons.shopping_bag,
              title: "Orders",
              color: Colors.orange,

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminOrdersScreen()),
                );
              },
            ),

            // ==================================================
            // PRODUCTS
            // ==================================================
            _dashboardCard(
              context,
              icon: Icons.inventory,
              title: "Products",
              color: Colors.green,

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminProductsScreen(),
                  ),
                );
              },
            ),

            // ==================================================
            // CATEGORIES
            // ==================================================
            _dashboardCard(
              context,
              icon: Icons.category,
              title: "Categories",
              color: Colors.teal,

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminCategoriesScreen(),
                  ),
                );
              },
            ),

            // ==================================================
            // SECTIONS
            // ==================================================
            _dashboardCard(
              context,
              icon: Icons.view_list,
              title: "Sections",
              color: Colors.indigo,

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminSectionsScreen(),
                  ),
                );
              },
            ),
            // ==================================================
            // BANNERS
            // ==================================================
            _dashboardCard(
              context,
              icon: Icons.view_carousel,
              title: "Banners",
              color: Colors.deepOrange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminBannersScreen()),
                );
              },
            ),
            // ==================================================
            // HOME BANNERS
            // ==================================================
            _dashboardCard(
              context,
              icon: Icons.photo_library_outlined,
              title: "Home Banners",
              color: Colors.pink,

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminBannersScreen()),
                );
              },
            ),

            // ==================================================
            // CUSTOMERS
            // ==================================================
            _dashboardCard(
              context,
              icon: Icons.people,
              title: "Customers",
              color: Colors.blue,

              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Customers module coming soon")),
                );
              },
            ),

            // ==================================================
            // ANALYTICS
            // ==================================================
            _dashboardCard(
              context,
              icon: Icons.bar_chart,
              title: "Analytics",
              color: Colors.purple,

              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Analytics module coming soon")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // DASHBOARD CARD
  // ==========================================================

  Widget _dashboardCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: Card(
        elevation: 5,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            CircleAvatar(
              radius: 34,

              backgroundColor: color.withValues(alpha: 0.15),

              child: Icon(icon, color: color, size: 34),
            ),

            const SizedBox(height: 16),

            Text(
              title,

              textAlign: TextAlign.center,

              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
