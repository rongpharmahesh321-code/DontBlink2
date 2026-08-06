import 'package:flutter/material.dart';

import '../models/address.dart';
import '../services/address_service.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  final houseController = TextEditingController();
  final areaController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  final pincodeController = TextEditingController();

  bool isDefault = false;
  bool loading = false;

  final AddressService addressService = AddressService();

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    houseController.dispose();
    areaController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    super.dispose();
  }

  Widget buildField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "Please enter $label";
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    try {
      final address = Address(
        id: "",
        fullName: fullNameController.text.trim(),
        phone: phoneController.text.trim(),
        house: houseController.text.trim(),
        area: areaController.text.trim(),
        city: cityController.text.trim(),
        state: stateController.text.trim(),
        pincode: pincodeController.text.trim(),
        isDefault: isDefault,
      );

      await addressService.addAddress(address);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Address saved successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Address"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            buildField(controller: fullNameController, label: "Full Name"),
            buildField(
              controller: phoneController,
              label: "Phone Number",
              keyboardType: TextInputType.phone,
            ),
            buildField(controller: houseController, label: "House / Flat No."),
            buildField(controller: areaController, label: "Area / Locality"),
            buildField(controller: cityController, label: "City"),
            buildField(controller: stateController, label: "State"),
            buildField(
              controller: pincodeController,
              label: "PIN Code",
              keyboardType: TextInputType.number,
            ),
            SwitchListTile(
              value: isDefault,
              activeColor: Colors.green,
              title: const Text("Set as Default Address"),
              onChanged: (value) {
                setState(() {
                  isDefault = value;
                });
              },
            ),
            const SizedBox(height: 25),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: loading ? null : saveAddress,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "SAVE ADDRESS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
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
