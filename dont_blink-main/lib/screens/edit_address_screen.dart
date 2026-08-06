import 'package:flutter/material.dart';

import '../models/address.dart';
import '../services/address_service.dart';

class EditAddressScreen extends StatefulWidget {
  final Address address;

  const EditAddressScreen({super.key, required this.address});

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController fullNameController;
  late TextEditingController phoneController;
  late TextEditingController houseController;
  late TextEditingController areaController;
  late TextEditingController cityController;
  late TextEditingController stateController;
  late TextEditingController pincodeController;

  late bool isDefault;

  final AddressService addressService = AddressService();

  bool loading = false;

  @override
  void initState() {
    super.initState();

    fullNameController = TextEditingController(text: widget.address.fullName);

    phoneController = TextEditingController(text: widget.address.phone);

    houseController = TextEditingController(text: widget.address.house);

    areaController = TextEditingController(text: widget.address.area);

    cityController = TextEditingController(text: widget.address.city);

    stateController = TextEditingController(text: widget.address.state);

    pincodeController = TextEditingController(text: widget.address.pincode);

    isDefault = widget.address.isDefault;
  }

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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
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

  Future<void> updateAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    try {
      final updatedAddress = Address(
        id: widget.address.id,
        fullName: fullNameController.text.trim(),
        phone: phoneController.text.trim(),
        house: houseController.text.trim(),
        area: areaController.text.trim(),
        city: cityController.text.trim(),
        state: stateController.text.trim(),
        pincode: pincodeController.text.trim(),
        isDefault: isDefault,
      );

      await addressService.updateAddress(updatedAddress);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Address updated successfully!"),
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
        title: const Text("Edit Address"),
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
                onPressed: loading ? null : updateAddress,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "UPDATE ADDRESS",
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
