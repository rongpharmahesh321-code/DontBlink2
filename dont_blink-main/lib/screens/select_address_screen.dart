import 'package:flutter/material.dart';

import '../models/address.dart';
import '../services/address_service.dart';

class SelectAddressScreen extends StatelessWidget {
  SelectAddressScreen({super.key});

  final AddressService addressService = AddressService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Delivery Address"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Address>>(
        stream: addressService.getAddresses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text("No saved addresses", style: TextStyle(fontSize: 18)),
            );
          }

          final addresses = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.green),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          address.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (address.isDefault) const Chip(label: Text("Default")),
                    ],
                  ),
                  subtitle: Text(
                    "${address.house}, ${address.area}\n"
                    "${address.city}, ${address.state} - ${address.pincode}",
                  ),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.pop(context, address);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
