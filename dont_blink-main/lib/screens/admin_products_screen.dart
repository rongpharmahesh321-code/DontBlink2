import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/subcategory.dart';
import '../widgets/cached_product_image.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _productsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _categoriesStream;

  String _search = '';
  String _filter = 'All';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _productsStream = _firestore.collection('products').snapshots();
    _categoriesStream = _firestore.collection('categories').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _integer(dynamic value) {
    return _number(value).toInt();
  }

  String _price(dynamic value) {
    final number = _number(value);
    if (number == number.roundToDouble()) {
      return '₹${number.toInt()}';
    }
    return '₹${number.toStringAsFixed(2)}';
  }

  String _string(
    Map<String, dynamic> data,
    String key, {
    String fallback = '',
  }) {
    final value = data[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  bool _bool(Map<String, dynamic> data, String key, {bool fallback = false}) {
    final value = data[key];
    if (value is bool) return value;
    if (value == null) return fallback;
    return value.toString().toLowerCase() == 'true';
  }

  String _statusLabel(Map<String, dynamic> data) {
    final available = _bool(data, 'isAvailable', fallback: true);
    final stock = _integer(data['stock']);

    if (!available) return 'Hidden';
    if (stock <= 0) return 'Out of stock';
    if (stock <= 5) return 'Low stock';
    return 'Live';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Live':
        return const Color(0xFF10B981);
      case 'Low stock':
        return const Color(0xFFF59E0B);
      case 'Out of stock':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _category(Map<String, dynamic> data) {
    return _string(
      data,
      'category',
      fallback: _string(data, 'categoryName', fallback: 'Uncategorised'),
    );
  }

  // ==========================================================
  // IN-MEMORY FILTERING (ZERO FLICKER)
  // ==========================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtered(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final query = _search.trim().toLowerCase();

    final result = docs.where((doc) {
      final data = doc.data();
      final available = _bool(data, 'isAvailable', fallback: true);
      final stock = _integer(data['stock']);
      final cat = _category(data);

      if (_selectedCategory != 'All' &&
          cat.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }

      if (_filter == 'Live' && (!available || stock <= 0)) {
        return false;
      }
      if (_filter == 'Low stock' && (!available || stock <= 0 || stock > 5)) {
        return false;
      }
      if (_filter == 'Out of stock' && stock > 0) {
        return false;
      }
      if (_filter == 'Hidden' && available) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final name = _string(data, 'name').toLowerCase();
      final category = cat.toLowerCase();
      final weight = _string(data, 'weight').toLowerCase();
      final subcategory = _string(
        data,
        'subCategory',
        fallback: _string(data, 'subcategory'),
      ).toLowerCase();

      return doc.id.toLowerCase().contains(query) ||
          name.contains(query) ||
          category.contains(query) ||
          subcategory.contains(query) ||
          weight.contains(query);
    }).toList();

    result.sort((a, b) {
      final aName = _string(a.data(), 'name').toLowerCase();
      final bName = _string(b.data(), 'name').toLowerCase();
      return aName.compareTo(bName);
    });

    return result;
  }

  Map<String, int> _summary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int live = 0;
    int low = 0;
    int out = 0;
    int hidden = 0;

    for (final doc in docs) {
      final data = doc.data();
      final available = _bool(data, 'isAvailable', fallback: true);
      final stock = _integer(data['stock']);

      if (!available) {
        hidden++;
      } else if (stock <= 0) {
        out++;
      } else if (stock <= 5) {
        low++;
      } else {
        live++;
      }
    }

    return {
      'all': docs.length,
      'live': live,
      'low': low,
      'out': out,
      'hidden': hidden,
    };
  }

  // ==========================================================
  // ADD / EDIT PRODUCT MODAL
  // ==========================================================

  Future<void> _openProductEditor({
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
  }) async {
    final data = existing?.data();

    final nameController = TextEditingController(
      text: _string(data ?? {}, 'name'),
    );
    final priceController = TextEditingController(
      text: _string(data ?? {}, 'price').replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    final stockController = TextEditingController(
      text: '${_integer(data?['stock'])}',
    );
    final discountController = TextEditingController(
      text: '${_number(data?['discount'])}',
    );
    final ratingController = TextEditingController(
      text: '${_number(data?['rating'])}',
    );
    final weightController = TextEditingController(
      text: _string(data ?? {}, 'weight'),
    );
    final deliveryController = TextEditingController(
      text: '${_integer(data?['deliveryTime'] ?? 10)}',
    );
    final descriptionController = TextEditingController(
      text: _string(data ?? {}, 'description'),
    );

    String imageUrl = _string(data ?? {}, 'image');
    bool uploadingImage = false;
    bool available = _bool(data ?? {}, 'isAvailable', fallback: true);
    bool popular = _bool(data ?? {}, 'isPopular', fallback: false);

    String category = _category(data ?? {});
    if (category == 'Uncategorised') {
      category = '';
    }

    String subcategory = _string(data ?? {}, 'subCategory');
    if (subcategory.isEmpty) {
      subcategory = _string(data ?? {}, 'subcategory');
    }

    final categoriesSnapshot = await _firestore.collection('categories').get();
    final subcategoriesSnapshot =
        await _firestore.collection('subcategories').get();

    final allSubcategories = subcategoriesSnapshot.docs
        .map((doc) => SubcategoryModel.fromFirestore(doc.id, doc.data()))
        .toList();

    final categoryNames = <String>[];
    for (final doc in categoriesSnapshot.docs) {
      final categoryData = doc.data();
      final categoryName = _string(categoryData, 'name');
      if (categoryName.isNotEmpty && !categoryNames.contains(categoryName)) {
        categoryNames.add(categoryName);
      }
    }

    if (category.isNotEmpty && !categoryNames.contains(category)) {
      categoryNames.insert(0, category);
    }

    if (!mounted) {
      nameController.dispose();
      priceController.dispose();
      stockController.dispose();
      discountController.dispose();
      ratingController.dispose();
      weightController.dispose();
      deliveryController.dispose();
      descriptionController.dispose();
      return;
    }

    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickAndUploadImage() async {
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                  maxWidth: 1000,
                  maxHeight: 1000,
                );

                if (picked == null) return;

                setSheetState(() => uploadingImage = true);

                final file = File(picked.path);
                final fileName =
                    'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
                final storageRef = FirebaseStorage.instance.ref().child(
                  'products/$fileName',
                );

                final uploadTask = await storageRef.putFile(
                  file,
                  SettableMetadata(
                    contentType: 'image/jpeg',
                    cacheControl: 'public,max-age=31536000,immutable',
                  ),
                );

                final url = await uploadTask.ref.getDownloadURL();
                setSheetState(() {
                  imageUrl = url;
                  uploadingImage = false;
                });
              } catch (e) {
                setSheetState(() => uploadingImage = false);
                if (mounted) {
                  _message('Image upload failed: $e', error: true);
                }
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.92,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 14, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F9D58).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              existing == null
                                  ? Icons.add_circle_outline
                                  : Icons.edit_note_rounded,
                              color: const Color(0xFF0F9D58),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  existing == null
                                      ? 'Add New Product'
                                      : 'Edit Product Details',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  existing == null
                                      ? 'Publish item to store catalogue'
                                      : 'Update pricing, stock & attributes',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext, false),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    Expanded(
                      child: Form(
                        key: formKey,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                          children: [
                            _formSectionHeader('BASIC INFORMATION'),
                            const SizedBox(height: 8),
                            _field(
                              controller: nameController,
                              label: 'Product Name',
                              hint: 'e.g. Fresh Whole Milk',
                              icon: Icons.shopping_bag_outlined,
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Enter a product name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _field(
                                    controller: weightController,
                                    label: 'Unit / Weight',
                                    hint: 'e.g. 500 ml / 1 kg',
                                    icon: Icons.scale_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _field(
                                    controller: deliveryController,
                                    label: 'Delivery (mins)',
                                    hint: '10',
                                    icon: Icons.bolt_outlined,
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      final minutes = int.tryParse(
                                        (value ?? '').trim(),
                                      );
                                      if (minutes == null || minutes <= 0) {
                                        return 'Invalid mins';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _formSectionHeader('CATEGORIES & TAXONOMY'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: category.isEmpty ? null : category,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                prefixIcon: const Icon(
                                  Icons.category_outlined,
                                  color: Color(0xFF0F9D58),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                              items: categoryNames.map((name) {
                                return DropdownMenuItem<String>(
                                  value: name,
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: categoryNames.isEmpty
                                  ? null
                                  : (value) {
                                      setSheetState(() {
                                        category = value ?? '';
                                        final available = allSubcategories
                                            .where((s) =>
                                                s.categoryName.trim().toLowerCase() ==
                                                category.trim().toLowerCase())
                                            .toList();
                                        if (!available.any((s) => s.name == subcategory)) {
                                          subcategory = '';
                                        }
                                      });
                                    },
                            ),
                            const SizedBox(height: 12),
                            Builder(
                              builder: (context) {
                                final availableSubcategories = allSubcategories
                                    .where((s) =>
                                        s.categoryName.trim().toLowerCase() ==
                                        category.trim().toLowerCase())
                                    .toList();

                                final hasCurrentSub = subcategory.isNotEmpty &&
                                    availableSubcategories
                                        .any((s) => s.name == subcategory);

                                return DropdownButtonFormField<String>(
                                  initialValue: hasCurrentSub
                                      ? subcategory
                                      : (subcategory.isEmpty ? '' : null),
                                  decoration: InputDecoration(
                                    labelText: 'Subcategory (Optional)',
                                    prefixIcon: const Icon(
                                      Icons.subdirectory_arrow_right_rounded,
                                      color: Color(0xFF0F9D58),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    helperText: category.isEmpty
                                        ? 'Select a category first'
                                        : (availableSubcategories.isEmpty
                                            ? 'No subcategories created for this category'
                                            : null),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: '',
                                      child: Text('None (General)'),
                                    ),
                                    if (subcategory.isNotEmpty && !hasCurrentSub)
                                      DropdownMenuItem<String>(
                                        value: subcategory,
                                        child: Text(subcategory),
                                      ),
                                    ...availableSubcategories.map((sub) {
                                      return DropdownMenuItem<String>(
                                        value: sub.name,
                                        child: Text(
                                          sub.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) {
                                    setSheetState(() {
                                      subcategory = value ?? '';
                                    });
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _formSectionHeader('PRICING & STOCK'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _field(
                                    controller: priceController,
                                    label: 'Selling Price (₹)',
                                    hint: 'e.g. 45',
                                    icon: Icons.currency_rupee_rounded,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: (value) {
                                      final price = double.tryParse(
                                        (value ?? '').trim(),
                                      );
                                      if (price == null || price < 0) {
                                        return 'Enter valid price';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _field(
                                    controller: discountController,
                                    label: 'Discount %',
                                    hint: '0',
                                    icon: Icons.local_offer_outlined,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: (value) {
                                      final discount = double.tryParse(
                                        (value ?? '').trim(),
                                      );
                                      if (discount == null ||
                                          discount < 0 ||
                                          discount > 99) {
                                        return '0–99%';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _field(
                                    controller: stockController,
                                    label: 'Stock Quantity',
                                    hint: '0',
                                    icon: Icons.inventory_2_outlined,
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      final stock = int.tryParse(
                                        (value ?? '').trim(),
                                      );
                                      if (stock == null || stock < 0) {
                                        return 'Invalid stock';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _field(
                                    controller: ratingController,
                                    label: 'Rating (0-5)',
                                    hint: '4.5',
                                    icon: Icons.star_outline_rounded,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: (value) {
                                      final rating = double.tryParse(
                                        (value ?? '').trim(),
                                      );
                                      if (rating == null ||
                                          rating < 0 ||
                                          rating > 5) {
                                        return '0.0–5.0';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _formSectionHeader('PRODUCT MEDIA'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: imageUrl.isNotEmpty
                                            ? CachedProductImage(
                                                url: imageUrl,
                                                fit: BoxFit.contain,
                                              )
                                            : const Icon(
                                                Icons.image_outlined,
                                                color: Color(0xFF0F9D58),
                                                size: 26,
                                              ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: const [
                                            Text(
                                              'Product Photo',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Upload clear image on white background',
                                              style: TextStyle(
                                                color: Color(0xFF64748B),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: uploadingImage
                                            ? null
                                            : pickAndUploadImage,
                                        icon: uploadingImage
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.cloud_upload_outlined,
                                                size: 16,
                                              ),
                                        label: Text(
                                          uploadingImage
                                              ? 'Uploading'
                                              : imageUrl.isEmpty
                                              ? 'Upload'
                                              : 'Change',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0F9D58),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (imageUrl.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 140,
                                        width: double.infinity,
                                        color: Colors.white,
                                        child: CachedProductImage(
                                          url: imageUrl,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: uploadingImage
                                            ? null
                                            : () => setSheetState(() => imageUrl = ''),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 16,
                                          color: Color(0xFFEF4444),
                                        ),
                                        label: const Text(
                                          'Remove Image',
                                          style: TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _formSectionHeader('DETAILS & VISIBILITY'),
                            const SizedBox(height: 8),
                            _field(
                              controller: descriptionController,
                              label: 'Description',
                              hint: 'Detailed product description, ingredients, storage...',
                              icon: Icons.description_outlined,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 10),
                            _switchCard(
                              title: 'Visible to Customers',
                              subtitle:
                                  'Product is visible in customer catalog and search',
                              value: available,
                              onChanged: (value) => setSheetState(() => available = value),
                            ),
                            const SizedBox(height: 8),
                            _switchCard(
                              title: 'Featured / Popular',
                              subtitle:
                                  'Pin this product in the Popular & Best Sellers widgets',
                              value: popular,
                              onChanged: (value) => setSheetState(() => popular = value),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }

                                  if (uploadingImage) {
                                    _message(
                                      'Please wait for image upload to complete.',
                                      error: true,
                                    );
                                    return;
                                  }

                                  final navigator = Navigator.of(sheetContext);

                                  final payload = <String, dynamic>{
                                    'name': nameController.text.trim(),
                                    'price': priceController.text.trim(),
                                    'stock': int.parse(
                                      stockController.text.trim(),
                                    ),
                                    'discount': double.parse(
                                      discountController.text.trim(),
                                    ),
                                    'rating': double.parse(
                                      ratingController.text.trim(),
                                    ),
                                    'image': imageUrl,
                                    'imageUrl': imageUrl,
                                    'weight': weightController.text.trim(),
                                    'deliveryTime': int.parse(
                                      deliveryController.text.trim(),
                                    ),
                                    'description': descriptionController.text
                                        .trim(),
                                    'category': category.trim(),
                                    'categoryName': category.trim(),
                                    'subCategory': subcategory.trim(),
                                    'subcategory': subcategory.trim(),
                                    'isAvailable': available,
                                    'isPopular': popular,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  };

                                  try {
                                    if (existing == null) {
                                      payload['createdAt'] =
                                          FieldValue.serverTimestamp();
                                      await _firestore
                                          .collection('products')
                                          .add(payload);
                                    } else {
                                      await _firestore
                                          .collection('products')
                                          .doc(existing.id)
                                          .update(payload);
                                    }

                                    if (!mounted) return;
                                    navigator.pop(true);
                                  } catch (e) {
                                    if (!mounted) return;
                                    _message(
                                      'Could not save product: $e',
                                      error: true,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F9D58),
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shadowColor: const Color(0xFF0F9D58).withValues(alpha: 0.35),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  existing == null
                                      ? 'PUBLISH PRODUCT'
                                      : 'UPDATE PRODUCT',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
    discountController.dispose();
    ratingController.dispose();
    weightController.dispose();
    deliveryController.dispose();
    descriptionController.dispose();

    if (saved == true && mounted) {
      _message(
        existing == null
            ? 'Product published successfully'
            : 'Product updated successfully',
      );
    }
  }

  Widget _formSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: Color(0xFF64748B),
        letterSpacing: 0.8,
      ),
    );
  }

  // ==========================================================
  // DELETE PRODUCT
  // ==========================================================

  Future<void> _deleteProduct(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final name = _string(doc.data(), 'name', fallback: 'this product');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Delete Product?',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: Text(
            '“$name” will be permanently deleted from the store catalogue.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('products').doc(doc.id).delete();
      if (mounted) _message('$name deleted from catalogue');
    } catch (e) {
      if (mounted) _message('Could not delete product.', error: true);
    }
  }

  // ==========================================================
  // QUICK STOCK
  // ==========================================================

  Future<void> _quickStock(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int delta,
  ) async {
    final current = _integer(doc.data()['stock']);
    final next = (current + delta).clamp(0, 999999);

    try {
      await _firestore.collection('products').doc(doc.id).update({
        'stock': next,
        'isAvailable':
            next > 0 && _bool(doc.data(), 'isAvailable', fallback: true),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) _message('Could not update stock.', error: true);
    }
  }

  // ==========================================================
  // VISIBILITY TOGGLE
  // ==========================================================

  Future<void> _toggleAvailability(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final current = _bool(doc.data(), 'isAvailable', fallback: true);

    try {
      await _firestore.collection('products').doc(doc.id).update({
        'isAvailable': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) _message('Could not update visibility.', error: true);
    }
  }

  // ==========================================================
  // FORM WIDGETS
  // ==========================================================

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF0F9D58), size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0F9D58), width: 1.5),
        ),
      ),
    );
  }

  Widget _switchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        activeTrackColor: const Color(0xFF0F9D58),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
        onChanged: onChanged,
      ),
    );
  }

  // ==========================================================
  // TOP STATS & KPI BAR
  // ==========================================================

  Widget _buildSummaryKpis(Map<String, int> summary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          _kpiTile(
            label: 'Total',
            count: summary['all'] ?? 0,
            color: const Color(0xFF0F172A),
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(width: 8),
          _kpiTile(
            label: 'Live',
            count: summary['live'] ?? 0,
            color: const Color(0xFF10B981),
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(width: 8),
          _kpiTile(
            label: 'Low Stock',
            count: summary['low'] ?? 0,
            color: const Color(0xFFF59E0B),
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(width: 8),
          _kpiTile(
            label: 'Out / Hidden',
            count: (summary['out'] ?? 0) + (summary['hidden'] ?? 0),
            color: const Color(0xFFEF4444),
            icon: Icons.error_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _kpiTile({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // SEARCH BAR (ZERO-FLICKER REALTIME)
  // ==========================================================

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _search = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search products by name, category, or weight...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF0F9D58),
              size: 20,
            ),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _search = '';
                      });
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // STATUS FILTER CHIPS
  // ==========================================================

  Widget _buildFilters(Map<String, int> summary) {
    final filters = <String>[
      'All',
      'Live',
      'Low stock',
      'Out of stock',
      'Hidden',
    ];

    final counts = <String, int>{
      'All': summary['all'] ?? 0,
      'Live': summary['live'] ?? 0,
      'Low stock': summary['low'] ?? 0,
      'Out of stock': summary['out'] ?? 0,
      'Hidden': summary['hidden'] ?? 0,
    };

    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _filter == filter;

          return Material(
            color: selected ? const Color(0xFF0F9D58) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _filter = filter),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF0F9D58)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filter,
                      style: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF475569),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.22)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${counts[filter] ?? 0}',
                        style: TextStyle(
                          color: selected ? Colors.white : const Color(0xFF64748B),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // CATEGORY FILTER BAR
  // ==========================================================

  Widget _buildCategorySelector() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _categoriesStream,
      builder: (context, snapshot) {
        final categories = <String>['All'];
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final name = _string(doc.data(), 'name');
            if (name.isNotEmpty && !categories.contains(name)) {
              categories.add(name);
            }
          }
        }

        if (categories.length <= 1) return const SizedBox.shrink();

        return SizedBox(
          height: 36,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();

              return ActionChip(
                backgroundColor: isSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                label: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _selectedCategory = cat;
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  // ==========================================================
  // PRODUCT CARD
  // ==========================================================

  Widget _productCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = _string(data, 'name', fallback: 'Unnamed product');
    final stock = _integer(data['stock']);
    final discount = _number(data['discount']);
    final rating = _number(data['rating']);
    final category = _category(data);
    final subcategory = _string(
      data,
      'subCategory',
      fallback: _string(data, 'subcategory'),
    );
    final weight = _string(data, 'weight');
    final status = _statusLabel(data);
    final statusColor = _statusColor(status);
    final available = _bool(data, 'isAvailable', fallback: true);
    final imageUrl = _string(data, 'image');

    return Container(
      key: ValueKey(doc.id),
      margin: const EdgeInsets.fromLTRB(16, 5, 16, 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // THUMBNAIL WITH BADGE
              Stack(
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: imageUrl.isNotEmpty
                        ? CachedProductImage(
                            url: imageUrl,
                            fit: BoxFit.contain,
                            placeholder: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0F9D58),
                              ),
                            ),
                            errorWidget: const Icon(
                              Icons.broken_image_outlined,
                              color: Color(0xFF94A3B8),
                              size: 28,
                            ),
                          )
                        : const Icon(
                            Icons.inventory_2_outlined,
                            color: Color(0xFF0F9D58),
                            size: 32,
                          ),
                  ),
                  if (discount > 0)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(14),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          '${discount.toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // DETAILS
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              height: 1.25,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            size: 20,
                            color: Color(0xFF64748B),
                          ),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _openProductEditor(existing: doc);
                            } else if (value == 'delete') {
                              _deleteProduct(doc);
                            } else if (value == 'toggle') {
                              _toggleAvailability(doc);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit product'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Row(
                                children: [
                                  Icon(
                                    available
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(available ? 'Hide product' : 'Show product'),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFEF4444),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete product',
                                    style: TextStyle(color: Color(0xFFEF4444)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subcategory.isNotEmpty
                          ? '$category • $subcategory'
                          : category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          _price(data['price']),
                          style: const TextStyle(
                            color: Color(0xFF0F9D58),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (weight.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              weight,
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (rating > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF59E0B),
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // DIRECT IN-CARD STOCK CONTROLLER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF0F9D58),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Inventory: $stock units',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
                const Spacer(),
                _stockStepperButton(
                  icon: Icons.remove,
                  onTap: stock > 0 ? () => _quickStock(doc, -1) : null,
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '$stock',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _stockStepperButton(
                  icon: Icons.add,
                  onTap: () => _quickStock(doc, 1),
                  filled: true,
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _toggleAvailability(doc),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: available
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : const Color(0xFF64748B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          available
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 13,
                          color: available
                              ? const Color(0xFF10B981)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          available ? 'Visible' : 'Hidden',
                          style: TextStyle(
                            color: available
                                ? const Color(0xFF10B981)
                                : const Color(0xFF64748B),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockStepperButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    final enabled = onTap != null;
    return Material(
      color: filled
          ? const Color(0xFF0F9D58)
          : (enabled ? Colors.white : const Color(0xFFF1F5F9)),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: filled
                ? null
                : Border.all(
                    color: enabled
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFFE2E8F0),
                  ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: filled
                ? Colors.white
                : (enabled ? const Color(0xFF334155) : const Color(0xFF94A3B8)),
            size: 16,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // NOTIFICATIONS / SNACKBAR
  // ==========================================================

  void _message(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor:
              error ? const Color(0xFFEF4444) : const Color(0xFF0F9D58),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ==========================================================
  // BUILD METHOD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Store Catalogue',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            Text(
              'Dark-store products & inventory',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _openProductEditor(),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text(
                'ADD PRODUCT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F9D58),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F9D58),
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () => _openProductEditor(),
        icon: const Icon(Icons.add),
        label: const Text(
          'NEW PRODUCT',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _productsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F9D58)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load products',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final docs =
              snapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final summary = _summary(docs);
          final filtered = _filtered(docs);

          return RefreshIndicator(
            color: const Color(0xFF0F9D58),
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 250));
            },
            child: CustomScrollView(
              key: const PageStorageKey('admin_products_scroll'),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildSummaryKpis(summary)),
                SliverToBoxAdapter(child: _buildSearch()),
                SliverToBoxAdapter(child: _buildFilters(summary)),
                const SliverToBoxAdapter(child: SizedBox(height: 6)),
                SliverToBoxAdapter(child: _buildCategorySelector()),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F9D58).withValues(alpha: 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: Color(0xFF0F9D58),
                                size: 38,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No products found',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _search.isNotEmpty
                                  ? 'No product matches "$_search".'
                                  : 'No products in this category/filter.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _openProductEditor(),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('ADD FIRST PRODUCT'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F9D58),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _productCard(filtered[index]);
                      },
                      childCount: filtered.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 95)),
              ],
            ),
          );
        },
      ),
    );
  }
}
