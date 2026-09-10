import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/category.dart';
import '../services/category_service.dart';
import '../services/section_service.dart';

class EditProductScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> product;

  const EditProductScreen({
    super.key,
    required this.productId,
    required this.product,
  });

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  late TextEditingController nameController;
  late TextEditingController priceController;
  late TextEditingController stockController;
  late TextEditingController descriptionController;

  // ============================================================
  // SERVICES
  // ============================================================

  final CategoryService categoryService = CategoryService();
  final SectionService sectionService = SectionService();

  final ImagePicker _imagePicker = ImagePicker();

  // ============================================================
  // IMAGE
  // ============================================================

  File? selectedImage;

  String existingImageUrl = '';

  // ============================================================
  // VALUES
  // ============================================================

  String? selectedSection;
  String? selectedCategory;

  String selectedUnit = 'piece';
  String selectedSize = '1 piece';

  bool loading = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.product['name']?.toString() ?? '',
    );

    priceController = TextEditingController(
      text: _priceToString(widget.product['price']),
    );

    stockController = TextEditingController(
      text: widget.product['stock']?.toString() ?? '0',
    );

    descriptionController = TextEditingController(
      text: widget.product['description']?.toString() ?? '',
    );

    selectedSection = widget.product['section']?.toString();

    selectedCategory = widget.product['category']?.toString();

    // ==========================================================
    // EXISTING IMAGE
    // ==========================================================

    existingImageUrl = widget.product['image']?.toString() ?? '';

    // ==========================================================
    // WEIGHT / UNIT
    // ==========================================================

    final weight = widget.product['weight']?.toString() ?? '1 piece';

    selectedSize = weight;

    selectedUnit = _detectUnit(weight);
  }

  // ============================================================
  // PRICE
  // ============================================================

  String _priceToString(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is num) {
      return value.toString();
    }

    return value.toString();
  }

  // ============================================================
  // DETECT UNIT
  // ============================================================

  String _detectUnit(String weight) {
    final lower = weight.toLowerCase();

    if (lower.contains('kg')) {
      return 'kg';
    }

    if (lower.contains(' g')) {
      return 'gram';
    }

    if (lower.contains('litre')) {
      return 'litre';
    }

    if (lower.contains('ml')) {
      return 'ml';
    }

    if (lower.contains('packet')) {
      return 'packet';
    }

    if (lower.contains('pack')) {
      return 'pack';
    }

    if (lower.contains('bottle')) {
      return 'bottle';
    }

    if (lower.contains('box')) {
      return 'box';
    }

    if (lower.contains('dozen')) {
      return 'dozen';
    }

    return 'piece';
  }

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
  // PICK NEW IMAGE
  // ============================================================

  Future<void> pickProductImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 62,
        maxWidth: 720,
        maxHeight: 720,
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
  // REMOVE NEW IMAGE
  // ============================================================

  void removeSelectedImage() {
    setState(() {
      selectedImage = null;
    });
  }

  // ============================================================
  // DELETE OLD STORAGE IMAGE
  // ============================================================

  Future<void> deleteOldStorageImage(String imageUrl) async {
    if (imageUrl.trim().isEmpty) {
      return;
    }

    try {
      final reference = FirebaseStorage.instance.refFromURL(imageUrl);

      await reference.delete();

      debugPrint('Old product image deleted.');
    } catch (e) {
      // Don't fail the entire product update if the old
      // image cannot be deleted.
      debugPrint('Unable to delete old product image: $e');
    }
  }

  // ============================================================
  // UPLOAD NEW IMAGE
  // ============================================================

  Future<String> uploadNewProductImage() async {
    if (selectedImage == null) {
      return existingImageUrl;
    }

    final file = selectedImage!;

    final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final storageReference = FirebaseStorage.instance
        .ref()
        .child('products')
        .child(widget.productId)
        .child(fileName);

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      cacheControl: 'public,max-age=31536000,immutable',
    );

    final uploadTask = storageReference.putFile(file, metadata);

    await uploadTask;

    final downloadUrl = await storageReference.getDownloadURL();

    return downloadUrl;
  }

  // ============================================================
  // UPDATE PRODUCT
  // ============================================================

  Future<void> updateProduct() async {
    final name = nameController.text.trim();

    final priceText = priceController.text.trim();

    final stockText = stockController.text.trim();

    final description = descriptionController.text.trim();

    // ==========================================================
    // VALIDATION
    // ==========================================================

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

    setState(() {
      loading = true;
    });

    try {
      // ========================================================
      // REMEMBER OLD IMAGE
      // ========================================================

      final oldImageUrl = existingImageUrl;

      // ========================================================
      // UPLOAD NEW IMAGE IF SELECTED
      // ========================================================

      String imageUrl = oldImageUrl;

      if (selectedImage != null) {
        imageUrl = await uploadNewProductImage();
      }

      // ========================================================
      // UPDATE FIRESTORE
      // ========================================================

      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update({
            'name': name,

            'price': price,

            'category': selectedCategory,

            'section': selectedSection,

            'weight': selectedSize,

            'description': description,

            'stock': stock,

            'isAvailable': stock > 0,

            'image': imageUrl,

            'updatedAt': FieldValue.serverTimestamp(),
          });

      // ========================================================
      // DELETE OLD IMAGE
      // ONLY AFTER FIRESTORE UPDATE SUCCEEDS
      // ========================================================

      if (selectedImage != null &&
          oldImageUrl.trim().isNotEmpty &&
          imageUrl != oldImageUrl) {
        await deleteOldStorageImage(oldImageUrl);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating product: $e'),
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
  // FIELD DECORATION
  // ============================================================

  InputDecoration decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,

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
  // IMAGE UI
  // ============================================================

  Widget buildImagePicker() {
    final hasNewImage = selectedImage != null;

    final hasExistingImage = existingImageUrl.trim().isNotEmpty;

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

            child: hasNewImage
                ? _newImagePreview()
                : hasExistingImage
                ? _existingImagePreview()
                : _emptyImagePreview(),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // NEW IMAGE PREVIEW
  // ============================================================

  Widget _newImagePreview() {
    return Stack(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

            decoration: BoxDecoration(
              color: Colors.black54,

              borderRadius: BorderRadius.circular(10),
            ),

            child: const Text(
              'New image selected • Tap to change',
              textAlign: TextAlign.center,

              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EXISTING IMAGE PREVIEW
  // ============================================================

  Widget _existingImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(17),

          child: Image.network(
            existingImageUrl,

            width: double.infinity,

            height: 220,

            fit: BoxFit.cover,

            errorBuilder: (_, __, ___) {
              return _emptyImagePreview();
            },
          ),
        ),

        Positioned(
          bottom: 10,
          left: 10,
          right: 10,

          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

            decoration: BoxDecoration(
              color: Colors.black54,

              borderRadius: BorderRadius.circular(10),
            ),

            child: const Text(
              'Tap to replace product image',
              textAlign: TextAlign.center,

              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY IMAGE
  // ============================================================

  Widget _emptyImagePreview() {
    return Column(
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

          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 5),

        const Text(
          'Tap to choose from gallery',

          style: TextStyle(color: Colors.grey, fontSize: 12),
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
        title: const Text('Edit Product'),

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

              final sizeOptions = getSizeOptions(selectedUnit);

              if (!sizeOptions.contains(selectedSize)) {
                selectedSize = sizeOptions.first;
              }

              return ListView(
                padding: const EdgeInsets.all(20),

                children: [
                  // ==================================================
                  // IMAGE
                  // ==================================================
                  buildImagePicker(),

                  const SizedBox(height: 20),

                  // ==================================================
                  // NAME
                  // ==================================================
                  TextField(
                    controller: nameController,

                    decoration: decoration(
                      'Product Name',
                      Icons.shopping_bag_outlined,
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

                    decoration: decoration('Price', Icons.currency_rupee),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // SECTION
                  // ==================================================
                  DropdownButtonFormField<String>(
                    value: sections.contains(selectedSection)
                        ? selectedSection
                        : null,

                    isExpanded: true,

                    decoration: decoration('Section', Icons.view_list),

                    items: sections.map((section) {
                      return DropdownMenuItem<String>(
                        value: section,

                        child: Text(section),
                      );
                    }).toList(),

                    onChanged: (value) {
                      setState(() {
                        selectedSection = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // CATEGORY
                  // ==================================================
                  DropdownButtonFormField<String>(
                    value:
                        categories.any(
                          (category) => category.name == selectedCategory,
                        )
                        ? selectedCategory
                        : null,

                    isExpanded: true,

                    decoration: decoration('Category', Icons.category),

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
                  // UNIT
                  // ==================================================
                  DropdownButtonFormField<String>(
                    value: selectedUnit,

                    isExpanded: true,

                    decoration: decoration('Selling Unit', Icons.straighten),

                    items:
                        const [
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
                        ].map((unit) {
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
                    value: sizeOptions.contains(selectedSize)
                        ? selectedSize
                        : sizeOptions.first,

                    isExpanded: true,

                    decoration: decoration('Product Size', Icons.straighten),

                    items: sizeOptions.map((size) {
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

                    decoration: decoration('Stock Quantity', Icons.inventory_2),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // DESCRIPTION
                  // ==================================================
                  TextField(
                    controller: descriptionController,

                    maxLines: 4,

                    decoration: decoration('Description', Icons.description),
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // SAVE
                  // ==================================================
                  SizedBox(
                    height: 56,

                    child: ElevatedButton.icon(
                      onPressed: loading ? null : updateProduct,

                      icon: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,

                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save),

                      label: Text(loading ? 'UPLOADING...' : 'SAVE CHANGES'),

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

    super.dispose();
  }
}
