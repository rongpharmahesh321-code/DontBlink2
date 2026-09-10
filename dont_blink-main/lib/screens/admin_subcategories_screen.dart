import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/category.dart';
import '../models/subcategory.dart';
import '../services/category_service.dart';
import '../services/subcategory_service.dart';
import '../theme/app_colors.dart';

class AdminSubcategoriesScreen extends StatefulWidget {
  final String? initialCategory;

  const AdminSubcategoriesScreen({super.key, this.initialCategory});

  @override
  State<AdminSubcategoriesScreen> createState() =>
      _AdminSubcategoriesScreenState();
}

class _AdminSubcategoriesScreenState extends State<AdminSubcategoriesScreen> {
  final SubcategoryService _subcategoryService = SubcategoryService();
  final CategoryService _categoryService = CategoryService();
  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _selectedCategory = widget.initialCategory!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ==========================================================
  // OPEN SUBCATEGORY EDITOR (ADD / EDIT)
  // ==========================================================

  Future<void> _openSubcategoryEditor({
    SubcategoryModel? existing,
    List<CategoryModel>? categories,
  }) async {
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: existing?.name ?? '');
    final sortController = TextEditingController(
      text: (existing?.sortOrder ?? 1).toString(),
    );

    String chosenCategory = existing?.categoryName ??
        (_selectedCategory != 'All'
            ? _selectedCategory
            : (categories?.isNotEmpty == true ? categories!.first.name : ''));

    String imageUrl = existing?.imageUrl ?? '';
    String imagePath = existing?.imagePath ?? '';
    bool isActive = existing?.isActive ?? true;
    bool isUploading = false;
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickImage() async {
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                  maxWidth: 800,
                  maxHeight: 800,
                );

                if (picked == null) return;

                setSheetState(() => isUploading = true);

                final file = File(picked.path);
                final fileName =
                    'subcat_${DateTime.now().millisecondsSinceEpoch}.jpg';
                final storageRef = FirebaseStorage.instance
                    .ref()
                    .child('subcategories/$fileName');

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
                  imagePath = storageRef.fullPath;
                  isUploading = false;
                });
              } catch (e) {
                setSheetState(() => isUploading = false);
                _message('Image upload failed: $e', error: true);
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              existing == null
                                  ? 'Add Subcategory'
                                  : 'Edit Subcategory',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Form(
                        key: formKey,
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            // Parent Category Dropdown
                            const Text(
                              'Parent Category',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: (categories != null &&
                                      categories.any(
                                          (c) => c.name == chosenCategory))
                                  ? chosenCategory
                                  : (categories?.isNotEmpty == true
                                      ? categories!.first.name
                                      : null),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.category_outlined,
                                  color: AppColors.primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              items: (categories ?? []).map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat.name,
                                  child: Text(
                                    cat.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setSheetState(() => chosenCategory = val);
                                }
                              },
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Please select a parent category';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Subcategory Name
                            const Text(
                              'Subcategory Name',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText: 'e.g. Atta, Rice, Dal, Organic',
                                prefixIcon: const Icon(
                                  Icons.label_outline_rounded,
                                  color: AppColors.primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (val) {
                                if ((val ?? '').trim().isEmpty) {
                                  return 'Enter a subcategory name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Rounded Circular Image Section
                            const Text(
                              'Subcategory Image (Rounded)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  // Circular preview bubble
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(
                                        color: AppColors.primary,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: isUploading
                                          ? const Center(
                                              child: SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            )
                                          : imageUrl.trim().isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: imageUrl,
                                                  fit: BoxFit.cover,
                                                  placeholder: (_, __) =>
                                                      Container(
                                                    color: AppColors.tintGreen,
                                                  ),
                                                  errorWidget: (_, __, ___) =>
                                                      const Icon(
                                                    Icons.broken_image_outlined,
                                                    color: Colors.grey,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.image_outlined,
                                                  color: Colors.grey,
                                                  size: 30,
                                                ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Rounded Circular Bubble',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          imageUrl.isNotEmpty
                                              ? 'Image uploaded'
                                              : 'Choose image from phone',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 10,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        ElevatedButton.icon(
                                          onPressed:
                                              isUploading ? null : pickImage,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.upload_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                            imageUrl.isNotEmpty
                                                ? 'Change'
                                                : 'Upload Image',
                                            style:
                                                const TextStyle(fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Sort Order
                            const Text(
                              'Sort Order (Display order on top bar)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: sortController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '1, 2, 3...',
                                prefixIcon: const Icon(
                                  Icons.sort_rounded,
                                  color: AppColors.primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (val) {
                                final n = int.tryParse((val ?? '').trim());
                                if (n == null || n < 0) {
                                  return 'Enter a valid positive number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Active Switch
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Active Status',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                isActive
                                    ? 'Visible to customers'
                                    : 'Hidden from customer view',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                ),
                              ),
                              value: isActive,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                setSheetState(() => isActive = val);
                              },
                            ),
                            const SizedBox(height: 20),

                            // Save Button
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: (isUploading || isSaving)
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) {
                                          return;
                                        }

                                        setSheetState(() => isSaving = true);

                                        try {
                                          final categoryId = categories
                                                  ?.firstWhere(
                                                    (c) =>
                                                        c.name ==
                                                        chosenCategory,
                                                    orElse: () =>
                                                        CategoryModel(
                                                      id: '',
                                                      name: chosenCategory,
                                                      section: '',
                                                      imageUrl: '',
                                                      filter: '',
                                                      sortOrder: 0,
                                                      isActive: true,
                                                    ),
                                                  )
                                                  .id ??
                                              '';

                                          final sub = SubcategoryModel(
                                            id: existing?.id ?? '',
                                            name: nameController.text.trim(),
                                            categoryId: categoryId,
                                            categoryName: chosenCategory,
                                            imageUrl: imageUrl.trim(),
                                            imagePath: imagePath.trim(),
                                            sortOrder: int.tryParse(
                                                  sortController.text.trim(),
                                                ) ??
                                                1,
                                            isActive: isActive,
                                          );

                                          if (existing == null) {
                                            await _subcategoryService
                                                .addSubcategory(sub);
                                            _message('Subcategory created');
                                          } else {
                                            await _subcategoryService
                                                .updateSubcategory(sub);
                                            _message('Subcategory updated');
                                          }

                                          if (mounted) {
                                            Navigator.pop(sheetContext);
                                          }
                                        } catch (e) {
                                          setSheetState(() => isSaving = false);
                                          _message('Error: $e', error: true);
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        existing == null
                                            ? 'CREATE SUBCATEGORY'
                                            : 'SAVE CHANGES',
                                        style: const TextStyle(
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
  }

  // ==========================================================
  // DELETE CONFIRMATION
  // ==========================================================

  Future<void> _confirmDelete(SubcategoryModel sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subcategory?'),
        content: Text(
          'Are you sure you want to delete "${sub.name}"? Products linked to this subcategory will remain in the main category.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _subcategoryService.deleteSubcategory(sub.id);
      _message('Deleted "${sub.name}"');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CategoryModel>>(
      stream: _categoryService.getAllCategories(),
      builder: (context, catSnapshot) {
        final categories = catSnapshot.data ?? [];
        final categoryNames = categories.map((c) => c.name).toList();

        return StreamBuilder<List<SubcategoryModel>>(
          stream: _subcategoryService.getAllSubcategories(),
          builder: (context, subSnapshot) {
            final allSubs = subSnapshot.data ?? [];

            // Filter by search & category
            final query = _search.trim().toLowerCase();
            final filtered = allSubs.where((sub) {
              if (_selectedCategory != 'All' &&
                  sub.categoryName.toLowerCase() !=
                      _selectedCategory.toLowerCase()) {
                return false;
              }
              if (query.isNotEmpty) {
                return sub.name.toLowerCase().contains(query) ||
                    sub.categoryName.toLowerCase().contains(query);
              }
              return true;
            }).toList();

            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 0.5,
                title: const Text(
                  'Manage Subcategories',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Add subcategory',
                    onPressed: () => _openSubcategoryEditor(
                      categories: categories,
                    ),
                    icon: const Icon(
                      Icons.add_circle_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                onPressed: () => _openSubcategoryEditor(
                  categories: categories,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'ADD SUBCATEGORY',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              body: Column(
                children: [
                  // Category filter bar & Search
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      children: [
                        // Search bar
                        TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _search = val),
                          decoration: InputDecoration(
                            hintText: 'Search subcategories...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _search.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _search = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Horizontal Category Pill Filter
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _buildCategoryChip('All', allSubs.length),
                              for (final name in categoryNames) ...[
                                const SizedBox(width: 8),
                                _buildCategoryChip(
                                  name,
                                  allSubs
                                      .where((s) => s.categoryName == name)
                                      .length,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Subcategory list
                  Expanded(
                    child: subSnapshot.connectionState ==
                            ConnectionState.waiting
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        : filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: AppColors.tintGreen,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.account_tree_outlined,
                                        color: AppColors.primary,
                                        size: 36,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      _selectedCategory == 'All'
                                          ? 'No subcategories yet'
                                          : 'No subcategories for "$_selectedCategory"',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tap "+ Add Subcategory" to create your first one.',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 95),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final sub = filtered[index];
                                  return _buildSubcategoryCard(
                                    sub,
                                    categories,
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryChip(String categoryName, int count) {
    final isSelected = _selectedCategory == categoryName;

    return FilterChip(
      selected: isSelected,
      label: Text('$categoryName ($count)'),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : Colors.black87,
      ),
      backgroundColor: Colors.grey.shade100,
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        setState(() => _selectedCategory = categoryName);
      },
    );
  }

  Widget _buildSubcategoryCard(
    SubcategoryModel sub,
    List<CategoryModel> categories,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sub.isActive ? Colors.grey.shade200 : Colors.red.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        // Rounded circular image bubble
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.tintGreen,
            border: Border.all(
              color: sub.isActive ? AppColors.primary : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: sub.imageUrl.trim().isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: sub.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.tintGreen,
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                  )
                : const Icon(
                    Icons.category_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                sub.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '#${sub.sortOrder}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.tintGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sub.categoryName,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                sub.isActive ? 'Active' : 'Hidden',
                style: TextStyle(
                  color: sub.isActive ? Colors.green.shade700 : Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit',
              onPressed: () => _openSubcategoryEditor(
                existing: sub,
                categories: categories,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: Colors.red),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(sub),
            ),
          ],
        ),
      ),
    );
  }
}
