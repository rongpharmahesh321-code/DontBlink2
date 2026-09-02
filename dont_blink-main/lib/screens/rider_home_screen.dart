import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'rider_orders_screen.dart';

class RiderHomeScreen extends StatelessWidget {
  const RiderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Dashboard'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'Welcome, Rider 🛵',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(user?.email ?? '', style: const TextStyle(color: Colors.grey)),

            const SizedBox(height: 30),

            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),

              child: ListTile(
                contentPadding: const EdgeInsets.all(18),

                leading: const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.green,

                  child: Icon(
                    Icons.delivery_dining,
                    color: Colors.white,
                    size: 30,
                  ),
                ),

                title: const Text(
                  'My Deliveries',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                subtitle: const Text('View assigned orders'),

                trailing: const Icon(Icons.chevron_right),

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RiderOrdersScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
