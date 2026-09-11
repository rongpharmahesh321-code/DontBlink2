import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/category_service.dart';
import '../widgets/cached_product_image.dart';

class AddEditCategoryScreen extends StatefulWidget {
  final CategoryModel? category;

  const AddEditCategoryScreen({super.key, this.category});

  bool get isEditing => category != null;

  @override
  State<AddEditCategoryScreen> createState() => _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends State<AddEditCategoryScreen> {
  final _formKey = GlobalKey<FormState>();

  final CategoryService categoryService = CategoryService();

  late final TextEditingController nameController;
  late final TextEditingController sectionController;
  late final TextEditingController filterController;
  late final TextEditingController imageUrlController;
  late final TextEditingController sortOrderController;

  bool isActive = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    final category = widget.category;

    nameController = TextEditingController(text: category?.name ?? '');

    sectionController = TextEditingController(
      text: category?.section ?? 'Grocery & Kitchen',
    );

    filterController = TextEditingController(
      text: category?.filter ?? 'Groceries',
    );

    imageUrlController = TextEditingController(text: category?.imageUrl ?? '');

    sortOrderController = TextEditingController(
      text: (category?.sortOrder ?? 1).toString(),
    );

    isActive = category?.isActive ?? true;
  }

  @override
  void dispose() {
    nameController.dispose();
    sectionController.dispose();
    filterController.dispose();
    imageUrlController.dispose();
    sortOrderController.dispose();

    super.dispose();
  }

  // ==========================================
  // TEXT FIELD
  // ==========================================

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ==========================================
  // SAVE CATEGORY
  // ==========================================

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = nameController.text.trim();

    final section = sectionController.text.trim();

    final filter = filterController.text.trim();

    final imageUrl = imageUrlController.text.trim();

    final sortOrder = int.tryParse(sortOrderController.text.trim()) ?? 1;

    setState(() {
      saving = true;
    });

    try {
      // ========================================
      // CHECK DUPLICATE NAME
      // ========================================

      final exists = await categoryService.categoryNameExists(
        name,
        excludeId: widget.category?.id,
      );

      if (exists) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A category with this name already exists.'),
            backgroundColor: Colors.red,
          ),
        );

        setState(() {
          saving = false;
        });

        return;
      }

      // ========================================
      // CREATE MODEL
      // ========================================

      final category = CategoryModel(
        id: widget.category?.id ?? '',
        name: name,
        section: section,
        imageUrl: imageUrl,
        filter: filter,
        sortOrder: sortOrder,
        isActive: isActive,
      );

      // ========================================
      // UPDATE
      // ========================================

      if (widget.isEditing) {
        await categoryService.updateCategory(category);
      }
      // ========================================
      // ADD
      // ========================================
      else {
        await categoryService.addCategory(category);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Category updated successfully!'
                : 'Category added successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save category:\n$e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  // ==========================================
  // IMAGE PREVIEW
  // ==========================================

  Widget _buildImagePreview() {
    final imageUrl = imageUrlController.text.trim();

    if (imageUrl.isEmpty) {
      return Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 55, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text('No image added', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedProductImage(
        url: imageUrl,
        fit: BoxFit.cover,
        cacheWidth: 600,
        cacheHeight: 320,
        errorWidget: Container(
          color: Colors.grey.shade100,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 45, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'Unable to load image',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      // ========================================
      // APP BAR
      // ========================================
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Category' : 'Add Category'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),

      // ========================================
      // BODY
      // ========================================
      body: Form(
        key: _formKey,

        child: ListView(
          padding: const EdgeInsets.all(16),

          children: [
            // ====================================
            // CATEGORY NAME
            // ====================================
            _buildField(
              controller: nameController,
              label: 'Category Name',
              hint: 'Example: Vegetables & Fruits',
              icon: Icons.category,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter category name';
                }

                return null;
              },
            ),

            // ====================================
            // SECTION
            // ====================================
            _buildField(
              controller: sectionController,
              label: 'Section',
              hint: 'Example: Grocery & Kitchen',
              icon: Icons.dashboard,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter section name';
                }

                return null;
              },
            ),

            // ====================================
            // PRODUCT FILTER
            // ====================================
            _buildField(
              controller: filterController,
              label: 'Product Category Filter',
              hint: 'Example: Groceries',
              icon: Icons.filter_alt,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter product filter';
                }

                return null;
              },
            ),

            // ====================================
            // SORT ORDER
            // ====================================
            _buildField(
              controller: sortOrderController,
              label: 'Display Order',
              hint: 'Example: 1',
              icon: Icons.sort,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter display order';
                }

                final number = int.tryParse(value.trim());

                if (number == null) {
                  return 'Enter a valid number';
                }

                return null;
              },
            ),

            // ====================================
            // IMAGE URL
            // ====================================
            _buildField(
              controller: imageUrlController,
              label: 'Image URL',
              hint: 'Paste image URL here',
              icon: Icons.image,
              keyboardType: TextInputType.url,
            ),

            // ====================================
            // IMAGE PREVIEW
            // ====================================
            const SizedBox(height: 2),

            const Text(
              'Image Preview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            _buildImagePreview(),

            const SizedBox(height: 20),

            // ====================================
            // ACTIVE SWITCH
            // ====================================
            Card(
              child: SwitchListTile(
                value: isActive,
                activeColor: Colors.green,

                title: const Text(
                  'Active Category',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                subtitle: Text(
                  isActive ? 'Visible to customers' : 'Hidden from customers',
                ),

                onChanged: (value) {
                  setState(() {
                    isActive = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 25),

            // ====================================
            // SAVE BUTTON
            // ====================================
            SizedBox(
              height: 55,

              child: ElevatedButton.icon(
                onPressed: saving ? null : _saveCategory,

                icon: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),

                label: Text(
                  saving
                      ? 'Saving...'
                      : widget.isEditing
                      ? 'UPDATE CATEGORY'
                      : 'ADD CATEGORY',

                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
