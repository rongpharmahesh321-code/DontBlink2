import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/category.dart';
import '../services/category_service.dart';
import '../services/section_service.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final CategoryService categoryService = CategoryService();

  final SectionService sectionService = SectionService();

  final ImagePicker imagePicker = ImagePicker();

  // ==========================================================
  // ADD / EDIT CATEGORY
  // ==========================================================

  Future<void> openCategoryDialog({CategoryModel? category}) async {
    final nameController = TextEditingController(text: category?.name ?? '');

    final filterController = TextEditingController(
      text: category?.filter ?? '',
    );

    final sortController = TextEditingController(
      text: category?.sortOrder.toString() ?? '0',
    );

    String? selectedSection = category?.section;

    Uint8List? selectedImageBytes;

    String selectedExtension = 'jpg';

    bool isSaving = false;

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickImage() async {
              try {
                final XFile? file = await imagePicker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                  maxWidth: 1200,
                  maxHeight: 1200,
                );

                if (file == null) {
                  return;
                }

                final bytes = await file.readAsBytes();

                final fileName = file.name.toLowerCase();

                String extension = 'jpg';

                if (fileName.endsWith('.png')) {
                  extension = 'png';
                } else if (fileName.endsWith('.webp')) {
                  extension = 'webp';
                } else if (fileName.endsWith('.gif')) {
                  extension = 'gif';
                }

                setDialogState(() {
                  selectedImageBytes = bytes;
                  selectedExtension = extension;
                });
              } catch (e) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unable to select image: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            Future<void> saveCategory() async {
              if (isSaving) {
                return;
              }

              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }

              if (selectedSection == null || selectedSection!.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a section.')),
                );

                return;
              }

              final name = nameController.text.trim();

              final filter = filterController.text.trim();

              final sortOrder = int.tryParse(sortController.text.trim()) ?? 0;

              setDialogState(() {
                isSaving = true;
              });

              try {
                // ==================================================
                // CHECK DUPLICATE NAME
                // ==================================================

                final exists = await categoryService.categoryNameExists(
                  name,
                  excludeId: category?.id,
                );

                if (exists) {
                  throw Exception('A category with this name already exists.');
                }

                // ==================================================
                // ADD CATEGORY
                // ==================================================

                if (category == null) {
                  final newCategory = CategoryModel(
                    id: '',
                    name: name,
                    section: selectedSection!.trim(),
                    imageUrl: '',
                    filter: filter,
                    sortOrder: sortOrder,
                    isActive: true,
                  );

                  final categoryId = await categoryService.addCategory(
                    newCategory,
                  );

                  // ==================================================
                  // UPLOAD IMAGE AFTER CATEGORY CREATION
                  // ==================================================

                  if (selectedImageBytes != null) {
                    final imageUrl = await categoryService.uploadCategoryImage(
                      categoryId: categoryId,
                      imageBytes: selectedImageBytes!,
                      fileExtension: selectedExtension,
                    );

                    await categoryService.updateCategory(
                      newCategory.copyWith(id: categoryId, imageUrl: imageUrl),
                    );
                  }
                }
                // ==================================================
                // EDIT CATEGORY
                // ==================================================
                else {
                  String imageUrl = category.imageUrl;

                  // ------------------------------------------------
                  // IF NEW IMAGE SELECTED
                  // ------------------------------------------------

                  if (selectedImageBytes != null) {
                    final newImageUrl = await categoryService
                        .uploadCategoryImage(
                          categoryId: category.id,
                          imageBytes: selectedImageBytes!,
                          fileExtension: selectedExtension,
                        );

                    // Delete old image after successful upload.
                    if (category.imageUrl.trim().isNotEmpty) {
                      await categoryService.deleteCategoryImage(
                        category.imageUrl,
                      );
                    }

                    imageUrl = newImageUrl;
                  }

                  final updatedCategory = category.copyWith(
                    name: name,
                    section: selectedSection!.trim(),
                    imageUrl: imageUrl,
                    filter: filter,
                    sortOrder: sortOrder,
                  );

                  await categoryService.updateCategory(updatedCategory);
                }

                if (!context.mounted) {
                  return;
                }

                Navigator.pop(dialogContext, true);
              } catch (e) {
                if (!context.mounted) {
                  return;
                }

                setDialogState(() {
                  isSaving = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unable to save category: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(
                category == null ? 'Add New Category' : 'Edit Category',
              ),

              content: SizedBox(
                width: 500,

                child: StreamBuilder<List<String>>(
                  stream: sectionService.getSections(),

                  builder: (context, snapshot) {
                    final sections = snapshot.data ?? [];

                    // Make sure old category section still appears
                    // even if it is no longer in the section list.
                    final availableSections = List<String>.from(sections);

                    if (selectedSection != null &&
                        selectedSection!.trim().isNotEmpty &&
                        !availableSections.contains(selectedSection)) {
                      availableSections.insert(0, selectedSection!);
                    }

                    return Form(
                      key: formKey,

                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,

                          children: [
                            // ======================================
                            // IMAGE
                            // ======================================
                            GestureDetector(
                              onTap: isSaving ? null : pickImage,

                              child: Container(
                                width: 120,
                                height: 120,

                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                  ),
                                ),

                                clipBehavior: Clip.antiAlias,

                                child: selectedImageBytes != null
                                    ? Image.memory(
                                        selectedImageBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : category != null &&
                                          category.imageUrl.trim().isNotEmpty
                                    ? Image.network(
                                        category.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) {
                                          return const Icon(
                                            Icons.image_not_supported,
                                            size: 45,
                                            color: Colors.grey,
                                          );
                                        },
                                      )
                                    : const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate_outlined,
                                            size: 42,
                                            color: Colors.green,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Add Photo',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            TextButton.icon(
                              onPressed: isSaving ? null : pickImage,

                              icon: const Icon(Icons.photo_library_outlined),

                              label: Text(
                                selectedImageBytes != null
                                    ? 'CHANGE PHOTO'
                                    : category != null &&
                                          category.imageUrl.trim().isNotEmpty
                                    ? 'REPLACE PHOTO'
                                    : 'ADD PHOTO',
                              ),
                            ),

                            const SizedBox(height: 12),

                            // ======================================
                            // CATEGORY NAME
                            // ======================================
                            TextFormField(
                              controller: nameController,

                              enabled: !isSaving,

                              textCapitalization: TextCapitalization.words,

                              decoration: const InputDecoration(
                                labelText: 'Category Name',
                                hintText: 'Example: Vegetables',
                                prefixIcon: Icon(Icons.category_outlined),
                                border: OutlineInputBorder(),
                              ),

                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter category name';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            // ======================================
                            // SECTION
                            // ======================================
                            DropdownButtonFormField<String>(
                              value:
                                  selectedSection != null &&
                                      availableSections.contains(
                                        selectedSection,
                                      )
                                  ? selectedSection
                                  : null,

                              isExpanded: true,

                              decoration: const InputDecoration(
                                labelText: 'Section',
                                prefixIcon: Icon(Icons.view_list_outlined),
                                border: OutlineInputBorder(),
                              ),

                              items: availableSections.map((section) {
                                return DropdownMenuItem<String>(
                                  value: section,
                                  child: Text(section),
                                );
                              }).toList(),

                              onChanged: isSaving
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        selectedSection = value;
                                      });
                                    },

                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Select a section';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            // ======================================
                            // FILTER
                            // ======================================
                            TextFormField(
                              controller: filterController,

                              enabled: !isSaving,

                              decoration: const InputDecoration(
                                labelText: 'Filter',
                                hintText: 'Example: vegetables',
                                prefixIcon: Icon(Icons.filter_alt_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ======================================
                            // SORT ORDER
                            // ======================================
                            TextFormField(
                              controller: sortController,

                              enabled: !isSaving,

                              keyboardType: TextInputType.number,

                              decoration: const InputDecoration(
                                labelText: 'Sort Order',
                                hintText: 'Example: 1',
                                prefixIcon: Icon(Icons.sort),
                                border: OutlineInputBorder(),
                              ),

                              validator: (value) {
                                final number = int.tryParse(
                                  value?.trim() ?? '',
                                );

                                if (number == null) {
                                  return 'Enter a valid number';
                                }

                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('CANCEL'),
                ),

                ElevatedButton.icon(
                  onPressed: isSaving ? null : saveCategory,

                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),

                  label: Text(
                    isSaving
                        ? 'SAVING...'
                        : category == null
                        ? 'ADD CATEGORY'
                        : 'SAVE CHANGES',
                  ),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    filterController.dispose();
    sortController.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            category == null
                ? 'Category added successfully'
                : 'Category updated successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ==========================================================
  // DELETE CATEGORY
  // ==========================================================

  Future<void> deleteCategory(CategoryModel category) async {
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Category?'),

          content: Text(
            'Are you sure you want to delete '
            '"${category.name}"?\n\n'
            'Its category image will also be deleted.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('CANCEL'),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('DELETE', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await categoryService.deleteCategory(category.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete category: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================================
  // ACTIVE / INACTIVE
  // ==========================================================

  Future<void> toggleCategory(CategoryModel category) async {
    try {
      await categoryService.setCategoryActive(
        categoryId: category.id,
        isActive: !category.isActive,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update category: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================================
  // CATEGORY IMAGE
  // ==========================================================

  Widget categoryImage(CategoryModel category) {
    if (category.imageUrl.trim().isEmpty) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.category_outlined,
          color: Colors.green,
          size: 32,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),

      child: Image.network(
        category.imageUrl,

        width: 70,
        height: 70,

        fit: BoxFit.cover,

        errorBuilder: (_, __, ___) {
          return Container(
            width: 70,
            height: 70,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
          );
        },
      ),
    );
  }

  // ==========================================================
  // BUILD CATEGORY CARD
  // ==========================================================

  Widget categoryCard(CategoryModel category) {
    return Card(
      elevation: 2,

      margin: const EdgeInsets.only(bottom: 14),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),

      child: Padding(
        padding: const EdgeInsets.all(14),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,

          children: [
            // ================================================
            // IMAGE
            // ================================================
            categoryImage(category),

            const SizedBox(width: 14),

            // ================================================
            // INFORMATION
            // ================================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.name,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      if (!category.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),

                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),

                          child: const Text(
                            'HIDDEN',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  Text(
                    category.section,

                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),

                  if (category.filter.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),

                    Text(
                      'Filter: ${category.filter}',

                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),

                  Text(
                    'Sort order: ${category.sortOrder}',

                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),

            // ================================================
            // MENU
            // ================================================
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  await openCategoryDialog(category: category);
                }

                if (value == 'toggle') {
                  await toggleCategory(category);
                }

                if (value == 'delete') {
                  await deleteCategory(category);
                }
              },

              itemBuilder: (context) {
                return [
                  const PopupMenuItem<String>(
                    value: 'edit',

                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ],
                    ),
                  ),

                  PopupMenuItem<String>(
                    value: 'toggle',

                    child: Row(
                      children: [
                        Icon(
                          category.isActive
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),

                        const SizedBox(width: 10),

                        Text(category.isActive ? 'Hide' : 'Show'),
                      ],
                    ),
                  ),

                  const PopupMenuDivider(),

                  const PopupMenuItem<String>(
                    value: 'delete',

                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 20),

                        SizedBox(width: 10),

                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F8FA),

      appBar: AppBar(
        title: const Text('Manage Categories'),

        centerTitle: true,

        backgroundColor: Colors.green,

        foregroundColor: Colors.white,
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,

        foregroundColor: Colors.white,

        onPressed: () {
          openCategoryDialog();
        },

        icon: const Icon(Icons.add),

        label: const Text(
          'ADD CATEGORY',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: StreamBuilder<List<CategoryModel>>(
        stream: categoryService.getAllCategories(),

        builder: (context, snapshot) {
          // ================================================
          // LOADING
          // ================================================

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          // ================================================
          // ERROR
          // ================================================

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),

                    const SizedBox(height: 15),

                    const Text(
                      'Unable to load categories',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      '${snapshot.error}',

                      textAlign: TextAlign.center,

                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            );
          }

          final categories = snapshot.data ?? [];

          // ================================================
          // EMPTY
          // ================================================

          if (categories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 90,
                      color: Colors.grey.shade400,
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'No Categories Yet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Create your first category '
                      'using the button below.',
                      textAlign: TextAlign.center,

                      style: TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 25),

                    ElevatedButton.icon(
                      onPressed: () {
                        openCategoryDialog();
                      },

                      icon: const Icon(Icons.add),

                      label: const Text('ADD CATEGORY'),

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ================================================
          // LIST
          // ================================================

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),

            itemCount: categories.length,

            itemBuilder: (context, index) {
              return categoryCard(categories[index]);
            },
          );
        },
      ),
    );
  }
}
