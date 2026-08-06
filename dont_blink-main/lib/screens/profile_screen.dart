import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'my_addresses_screen.dart';
import 'order_history_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  Widget buildTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Color color = Colors.black,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(icon, color: Colors.green),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final String name =
        (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? user.displayName!
        : "Don't Blink User";

    final String email = user?.email ?? "No Email";

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        title: const Text("My Profile"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 50, color: Colors.green),
                ),
                const SizedBox(height: 15),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          buildTile(
            icon: Icons.shopping_bag_outlined,
            title: "My Orders",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
              );
            },
          ),

          buildTile(
            icon: Icons.location_on_outlined,
            title: "My Addresses",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MyAddressesScreen()),
              );
            },
          ),

          buildTile(
            icon: Icons.favorite_border,
            title: "Wishlist",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Wishlist Coming Soon")),
              );
            },
          ),

          buildTile(
            icon: Icons.settings_outlined,
            title: "Settings",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Settings Coming Soon")),
              );
            },
          ),

          buildTile(
            icon: Icons.logout,
            title: "Logout",
            color: Colors.red,
            onTap: () => logout(context),
          ),
        ],
      ),
    );
  }
}
