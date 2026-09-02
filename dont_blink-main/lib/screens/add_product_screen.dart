import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/category.dart';
import '../services/category_service.dart';
import '../services/section_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final stockController = TextEditingController();
  final descriptionController = TextEditingController();
  final customSectionController = TextEditingController();

  // ============================================================
  // SERVICES
  // ============================================================

  final CategoryService categoryService = CategoryService();
  final SectionService sectionService = SectionService();

  // ============================================================
  // IMAGE
  // ============================================================

  final ImagePicker _imagePicker = ImagePicker();

  File? selectedImage;

  // ============================================================
  // VALUES
  // ============================================================

  String? selectedSection;
  String? selectedCategory;

  String selectedUnit = 'piece';
  String selectedSize = '1 piece';

  bool loading = false;

  // ============================================================
  // UNIT LIST
  // ============================================================

  final List<String> units = [
    'kg',
    'gram',
    'litre',
    'ml',
    'piece',
    'pack',
    'packet',
    'bottle',
    'box',
    'dozen',
  ];

  // ============================================================
  // SIZE OPTIONS
  // ============================================================

  List<String> getSizeOptions(String unit) {
    switch (unit) {
      case 'kg':
        return ['1 kg', '2 kg', '5 kg'];

      case 'gram':
        return ['250 g', '500 g', '750 g'];

      case 'litre':
        return ['1 litre', '2 litre', '5 litre'];

      case 'ml':
        return ['250 ml', '450 ml', '500 ml', '700 ml'];

      case 'piece':
        return ['1 piece', '2 pieces', '3 pieces'];

      case 'pack':
        return ['1 pack', '2 packs', '5 packs'];

      case 'packet':
        return ['1 packet', '2 packets', '5 packets'];

      case 'bottle':
        return ['1 bottle', '2 bottles', '5 bottles'];

      case 'box':
        return ['1 box', '2 boxes', '5 boxes'];

      case 'dozen':
        return ['1 dozen', '2 dozen'];

      default:
        return ['1 piece'];
    }
  }

  // ============================================================
  // PICK PRODUCT IMAGE
  // ============================================================

  Future<void> pickProductImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image == null) {
        return;
      }

      setState(() {
        selectedImage = File(image.path);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to select image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // REMOVE SELECTED IMAGE
  // ============================================================

  void removeSelectedImage() {
    setState(() {
      selectedImage = null;
    });
  }

  // ============================================================
  // CREATE SECTION
  // ============================================================

  Future<void> createNewSection() async {
    customSectionController.clear();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create New Section'),

          content: TextField(
            controller: customSectionController,
            autofocus: true,

            decoration: const InputDecoration(
              labelText: 'Section Name',
              hintText: 'Example: Frozen Foods',
              border: OutlineInputBorder(),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: const Text('CANCEL'),
            ),

            ElevatedButton(
              onPressed: () {
                final name = customSectionController.text.trim();

                if (name.isEmpty) {
                  return;
                }

                Navigator.pop(dialogContext, name);
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),

              child: const Text('CREATE'),
            ),
          ],
        );
      },
    );

    if (result == null || result.trim().isEmpty) {
      return;
    }

    try {
      await sectionService.createSection(result);

      if (!mounted) return;

      setState(() {
        selectedSection = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$result created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to create section: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // UPLOAD PRODUCT IMAGE
  // ============================================================

  Future<String> uploadProductImage(String productId) async {
    if (selectedImage == null) {
      return '';
    }

    final file = selectedImage!;

    final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final storageReference = FirebaseStorage.instance
        .ref()
        .child('products')
        .child(productId)
        .child(fileName);

    final metadata = SettableMetadata(contentType: 'image/jpeg');

    final uploadTask = storageReference.putFile(file, metadata);

    await uploadTask;

    final downloadUrl = await storageReference.getDownloadURL();

    return downloadUrl;
  }

  // ============================================================
  // ADD PRODUCT
  // ============================================================

  Future<void> addProduct() async {
    final name = nameController.text.trim();

    final priceText = priceController.text.trim();

    final stockText = stockController.text.trim();

    final description = descriptionController.text.trim();

    // ----------------------------------------------------------
    // VALIDATION
    // ----------------------------------------------------------

    if (name.isEmpty ||
        priceText.isEmpty ||
        stockText.isEmpty ||
        selectedSection == null ||
        selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );

      return;
    }

    final price = double.tryParse(priceText);

    if (price == null || price < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid price')));

      return;
    }

    final stock = int.tryParse(stockText);

    if (stock == null || stock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid stock quantity')),
      );

      return;
    }

    // ----------------------------------------------------------
    // LOADING
    // ----------------------------------------------------------

    setState(() {
      loading = true;
    });

    try {
      // ========================================================
      // CREATE PRODUCT DOCUMENT FIRST
      // ========================================================

      final productReference = FirebaseFirestore.instance
          .collection('products')
          .doc();

      final productId = productReference.id;

      // ========================================================
      // UPLOAD IMAGE
      // ========================================================

      String imageUrl = '';

      if (selectedImage != null) {
        imageUrl = await uploadProductImage(productId);
      }

      // ========================================================
      // SAVE PRODUCT
      // ========================================================

      await productReference.set({
        'name': name,

        'price': price,

        'category': selectedCategory,

        'section': selectedSection,

        'weight': selectedSize,

        'description': description,

        // Firebase Storage download URL
        'image': imageUrl,

        'rating': 4.8,

        'deliveryTime': 10,

        'discount': 0,

        'stock': stock,

        'isAvailable': stock > 0,

        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product added successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration fieldDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,

      hintText: hint,

      prefixIcon: Icon(icon),

      filled: true,

      fillColor: Colors.grey.shade50,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),

        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),

        borderSide: BorderSide(color: Colors.grey.shade200),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),

        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
    );
  }

  // ============================================================
  // IMAGE PICKER UI
  // ============================================================

  Widget buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'Product Image',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        GestureDetector(
          onTap: loading ? null : pickProductImage,

          child: Container(
            width: double.infinity,

            height: 220,

            decoration: BoxDecoration(
              color: Colors.grey.shade50,

              borderRadius: BorderRadius.circular(18),

              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),

            child: selectedImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Container(
                        width: 65,
                        height: 65,

                        decoration: BoxDecoration(
                          color: Colors.green.shade100,

                          shape: BoxShape.circle,
                        ),

                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Colors.green,
                          size: 32,
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Add Product Image',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'Tap to choose from gallery',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(17),

                        child: Image.file(
                          selectedImage!,

                          width: double.infinity,

                          height: 220,

                          fit: BoxFit.cover,
                        ),
                      ),

                      Positioned(
                        top: 10,
                        right: 10,

                        child: GestureDetector(
                          onTap: removeSelectedImage,

                          child: Container(
                            width: 38,
                            height: 38,

                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),

                            child: const Icon(Icons.close, color: Colors.red),
                          ),
                        ),
                      ),

                      Positioned(
                        bottom: 10,
                        left: 10,
                        right: 10,

                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),

                          decoration: BoxDecoration(
                            color: Colors.black54,

                            borderRadius: BorderRadius.circular(10),
                          ),

                          child: const Text(
                            'Tap image to change',
                            textAlign: TextAlign.center,

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
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Product'),

        backgroundColor: Colors.green,

        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<List<String>>(
        stream: sectionService.getSections(),

        builder: (context, sectionSnapshot) {
          final sections = sectionSnapshot.data ?? [];

          return StreamBuilder<List<CategoryModel>>(
            stream: categoryService.getCategories(),

            builder: (context, categorySnapshot) {
              final categories = categorySnapshot.data ?? [];

              return ListView(
                padding: const EdgeInsets.all(20),

                children: [
                  // ==================================================
                  // IMAGE
                  // ==================================================
                  buildImagePicker(),

                  const SizedBox(height: 20),

                  // ==================================================
                  // PRODUCT NAME
                  // ==================================================
                  TextField(
                    controller: nameController,

                    decoration: fieldDecoration(
                      'Product Name',
                      Icons.shopping_bag_outlined,
                      hint: 'Example: Fresh Apples',
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // PRICE
                  // ==================================================
                  TextField(
                    controller: priceController,

                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),

                    decoration: fieldDecoration(
                      'Price',
                      Icons.currency_rupee,
                      hint: 'Example: 120',
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // SECTION
                  // ==================================================
                  DropdownButtonFormField<String>(
                    value: selectedSection,

                    isExpanded: true,

                    decoration: fieldDecoration(
                      'Section',
                      Icons.view_list_outlined,
                    ),

                    items: [
                      ...sections.map((section) {
                        return DropdownMenuItem<String>(
                          value: section,

                          child: Text(section),
                        );
                      }),

                      const DropdownMenuItem<String>(
                        value: '__create__',

                        child: Row(
                          children: [
                            Icon(Icons.add, color: Colors.green),

                            SizedBox(width: 8),

                            Text(
                              'Create New Section',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    onChanged: (value) async {
                      if (value == '__create__') {
                        await createNewSection();
                      } else {
                        setState(() {
                          selectedSection = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // CATEGORY
                  // ==================================================
                  DropdownButtonFormField<String>(
                    value: selectedCategory,

                    isExpanded: true,

                    decoration: fieldDecoration(
                      'Category',
                      Icons.category_outlined,
                    ),

                    items: categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category.name,

                        child: Text(category.name),
                      );
                    }).toList(),

                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // SELLING UNIT
                  // ==================================================
                  DropdownButtonFormField<String>(
                    value: selectedUnit,

                    isExpanded: true,

                    decoration: fieldDecoration(
                      'Selling Unit',
                      Icons.straighten_outlined,
                    ),

                    items: units.map((unit) {
                      return DropdownMenuItem<String>(
                        value: unit,

                        child: Text(unit),
                      );
                    }).toList(),

                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      final options = getSizeOptions(value);

                      setState(() {
                        selectedUnit = value;

                        selectedSize = options.first;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // SIZE
                  // ==================================================
                  DropdownButtonFormField<String>(
                    value: selectedSize,

                    isExpanded: true,

                    decoration: fieldDecoration(
                      'Product Size',
                      Icons.straighten,
                    ),

                    items: getSizeOptions(selectedUnit).map((size) {
                      return DropdownMenuItem<String>(
                        value: size,

                        child: Text(size),
                      );
                    }).toList(),

                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        selectedSize = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // STOCK
                  // ==================================================
                  TextField(
                    controller: stockController,

                    keyboardType: TextInputType.number,

                    decoration: fieldDecoration(
                      'Stock Quantity',
                      Icons.inventory_2_outlined,
                      hint: 'Example: 50',
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // DESCRIPTION
                  // ==================================================
                  TextField(
                    controller: descriptionController,

                    maxLines: 4,

                    decoration: fieldDecoration(
                      'Description',
                      Icons.description_outlined,
                      hint: 'Product description',
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // ADD BUTTON
                  // ==================================================
                  SizedBox(
                    height: 56,

                    child: ElevatedButton.icon(
                      onPressed: loading ? null : addProduct,

                      icon: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,

                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.add),

                      label: Text(loading ? 'UPLOADING...' : 'ADD PRODUCT'),

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,

                        foregroundColor: Colors.white,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
    descriptionController.dispose();
    customSectionController.dispose();

    super.dispose();
  }
}
