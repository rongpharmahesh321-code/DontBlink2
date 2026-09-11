import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'admin_subcategories_screen.dart';
import '../widgets/cached_product_image.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  String _filter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================================
  // FIRESTORE
  // ==========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> get _categoriesStream =>
      _firestore.collection('categories').snapshots();

  // Sections are read directly from Firestore.
  // Therefore, adding a section in AdminSectionsScreen
  // automatically makes it available here.
  Stream<QuerySnapshot<Map<String, dynamic>>> get _sectionsStream =>
      _firestore.collection('sections').snapshots();

  // ==========================================================
  // HELPERS
  // ==========================================================

  String _string(
    Map<String, dynamic> data,
    String key, {
    String fallback = '',
  }) {
    final value = data[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  bool _bool(Map<String, dynamic> data, String key, {bool fallback = true}) {
    final value = data[key];

    if (value is bool) return value;
    if (value == null) return fallback;

    return value.toString().toLowerCase() == 'true';
  }

  String _section(Map<String, dynamic> data) {
    return _string(data, 'section', fallback: 'General');
  }

  String _imageUrl(Map<String, dynamic> data) {
    return _string(data, 'imageUrl', fallback: _string(data, 'image'));
  }

  int _sectionSortOrder(Map<String, dynamic> data, String fallbackId) {
    final value = data['sortOrder'];

    if (value is num) return value.toInt();

    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;

    return fallbackId.hashCode.abs();
  }

  // ==========================================================
  // SORT SECTIONS
  // ==========================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortedSections(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final result = docs.where((doc) {
      return _bool(doc.data(), 'isActive', fallback: true);
    }).toList();

    result.sort((a, b) {
      final aOrder = _sectionSortOrder(a.data(), a.id);
      final bOrder = _sectionSortOrder(b.data(), b.id);

      if (aOrder != bOrder) {
        return aOrder.compareTo(bOrder);
      }

      final aName = _string(a.data(), 'name').toLowerCase();
      final bName = _string(b.data(), 'name').toLowerCase();

      return aName.compareTo(bName);
    });

    return result;
  }

  // ==========================================================
  // FILTER CATEGORIES
  // ==========================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtered(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final query = _search.trim().toLowerCase();

    final result = docs.where((doc) {
      final data = doc.data();

      final active = _bool(data, 'isActive', fallback: true);

      if (_filter == 'Active' && !active) return false;
      if (_filter == 'Hidden' && active) return false;

      if (query.isEmpty) return true;

      final name = _string(data, 'name').toLowerCase();
      final section = _section(data).toLowerCase();

      return name.contains(query) ||
          section.contains(query) ||
          doc.id.toLowerCase().contains(query);
    }).toList();

    result.sort((a, b) {
      final aData = a.data();
      final bData = b.data();

      final sectionCompare = _section(
        aData,
      ).toLowerCase().compareTo(_section(bData).toLowerCase());

      if (sectionCompare != 0) {
        return sectionCompare;
      }

      return _string(
        aData,
        'name',
      ).toLowerCase().compareTo(_string(bData, 'name').toLowerCase());
    });

    return result;
  }

  Map<String, int> _summary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int active = 0;
    int hidden = 0;
    final sections = <String>{};

    for (final doc in docs) {
      final data = doc.data();

      if (_bool(data, 'isActive', fallback: true)) {
        active++;
      } else {
        hidden++;
      }

      final section = _section(data).trim();

      if (section.isNotEmpty && section != 'General') {
        sections.add(section.toLowerCase());
      }
    }

    return {
      'all': docs.length,
      'active': active,
      'hidden': hidden,
      'sections': sections.length,
    };
  }

  // ==========================================================
  // IMAGE PICKER + STORAGE
  // ==========================================================

  Future<Map<String, String>?> _pickAndUploadImage({
    required String categoryId,
    String existingPath = '',
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
      );

      if (picked == null || !mounted) return null;

      _message('Uploading category image...');

      final file = File(picked.path);

      final extension = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';

      final safeId = categoryId.isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : categoryId;

      final storagePath = 'categories/$safeId.$extension';
      final ref = _storage.ref(storagePath);

      await ref.putFile(
        file,
        SettableMetadata(
          contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
        ),
      );

      final url = await ref.getDownloadURL();

      if (existingPath.isNotEmpty && existingPath != storagePath) {
        try {
          await _storage.ref(existingPath).delete();
        } catch (_) {}
      }

      return {'url': url, 'path': storagePath};
    } catch (e) {
      if (mounted) {
        _message('Image upload failed: $e', error: true);
      }
      return null;
    }
  }

  Future<void> _deleteStorageImage(Map<String, dynamic> data) async {
    final path = _string(data, 'imagePath');

    if (path.isEmpty) return;

    try {
      await _storage.ref(path).delete();
    } catch (_) {}
  }

  // ==========================================================
  // ADD / EDIT CATEGORY
  // ==========================================================

  Future<void> _openCategoryEditor({
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
  }) async {
    final existingData = existing?.data();

    final nameController = TextEditingController(
      text: _string(existingData ?? {}, 'name'),
    );

    String selectedSection = _string(existingData ?? {}, 'section');

    String imageUrl = _imageUrl(existingData ?? {});
    String imagePath = _string(existingData ?? {}, 'imagePath');

    bool active = _bool(existingData ?? {}, 'isActive', fallback: true);

    bool uploading = false;

    final categoryId =
        existing?.id ?? 'cat_${DateTime.now().millisecondsSinceEpoch}';

    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _sectionsStream,
          builder: (context, sectionSnapshot) {
            if (sectionSnapshot.connectionState == ConnectionState.waiting &&
                !sectionSnapshot.hasData) {
              return _editorLoadingSheet();
            }

            if (sectionSnapshot.hasError) {
              return _editorErrorSheet(
                'Unable to load sections.\n\n${sectionSnapshot.error}',
              );
            }

            final sectionDocs =
                sectionSnapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];

            final sections = _sortedSections(sectionDocs);

            final sectionNames = sections
                .map((doc) => _string(doc.data(), 'name'))
                .where((name) => name.isNotEmpty)
                .toList();

            if (selectedSection.isNotEmpty &&
                !sectionNames.contains(selectedSection)) {
              final matching = sections.where(
                (doc) => _string(doc.data(), 'name') == selectedSection,
              );

              if (matching.isEmpty) {
                selectedSection = '';
              }
            }

            return StatefulBuilder(
              builder: (context, setSheetState) {
                return Container(
                  height: MediaQuery.of(context).size.height * 0.88,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        const SizedBox(height: 9),
                        Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  existing == null
                                      ? 'Add category'
                                      : 'Edit category',
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: uploading
                                    ? null
                                    : () => Navigator.pop(sheetContext, false),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Form(
                            key: formKey,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(18, 5, 18, 28),
                              children: [
                                _field(
                                  controller: nameController,
                                  label: 'Category name',
                                  hint: 'e.g. Vegetables & Fruits',
                                  icon: Icons.category_outlined,
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Enter a category name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 11),

                                // =================================================
                                // AUTOMATIC SECTION DROPDOWN
                                // =================================================
                                Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    13,
                                    4,
                                    8,
                                    4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    initialValue:
                                        selectedSection.isNotEmpty &&
                                            sectionNames.contains(
                                              selectedSection,
                                            )
                                        ? selectedSection
                                        : null,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Home section',
                                      hintText: 'Select a section',
                                      prefixIcon: Icon(
                                        Icons.view_quilt_outlined,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.green,
                                    ),
                                    items: sections.map((doc) {
                                      final name = _string(doc.data(), 'name');

                                      return DropdownMenuItem<String>(
                                        value: name,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.view_quilt_outlined,
                                                color: Colors.green,
                                                size: 17,
                                              ),
                                            ),
                                            const SizedBox(width: 9),
                                            Expanded(
                                              child: Text(
                                                name,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: sections.isEmpty
                                        ? null
                                        : (value) {
                                            setSheetState(() {
                                              selectedSection = value ?? '';
                                            });
                                          },
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Select a home section';
                                      }
                                      return null;
                                    },
                                  ),
                                ),

                                const SizedBox(height: 8),

                                if (sections.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                        color: Colors.orange.shade100,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.orange.shade800,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'No active sections exist yet. Go to Manage Sections and add a section first.',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 9,
                                              height: 1.4,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.sync_rounded,
                                          color: Colors.green,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${sections.length} active section${sections.length == 1 ? '' : 's'} available from Firestore.',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 11),

                                // =================================================
                                // IMAGE
                                // =================================================
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Category image',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Use a square image for the best Blinkit-style appearance.',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 9,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        height: 145,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: imageUrl.isNotEmpty
                                            ? CachedProductImage(
                                                url: imageUrl,
                                                fit: BoxFit.cover,
                                                cacheWidth: 300,
                                                cacheHeight: 300,
                                                errorWidget: const Center(
                                                  child: Icon(
                                                    Icons
                                                        .broken_image_outlined,
                                                    color: Colors.grey,
                                                    size: 38,
                                                  ),
                                                ),
                                              )
                                            : const Center(
                                                child: Icon(
                                                  Icons
                                                      .add_photo_alternate_outlined,
                                                  color: Colors.green,
                                                  size: 42,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 45,
                                        child: OutlinedButton.icon(
                                          onPressed: uploading
                                              ? null
                                              : () async {
                                                  setSheetState(() {
                                                    uploading = true;
                                                  });

                                                  final result =
                                                      await _pickAndUploadImage(
                                                        categoryId: categoryId,
                                                        existingPath: imagePath,
                                                      );

                                                  if (result != null) {
                                                    setSheetState(() {
                                                      imageUrl =
                                                          result['url'] ?? '';
                                                      imagePath =
                                                          result['path'] ?? '';
                                                    });
                                                  }

                                                  if (mounted) {
                                                    setSheetState(() {
                                                      uploading = false;
                                                    });
                                                  }
                                                },
                                          icon: uploading
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.green,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.photo_library_outlined,
                                                  size: 19,
                                                ),
                                          label: Text(
                                            uploading
                                                ? 'Uploading...'
                                                : imageUrl.isEmpty
                                                ? 'CHOOSE IMAGE'
                                                : 'CHANGE IMAGE',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (imageUrl.isNotEmpty)
                                        Center(
                                          child: TextButton.icon(
                                            onPressed: uploading
                                                ? null
                                                : () {
                                                    setSheetState(() {
                                                      imageUrl = '';
                                                    });
                                                  },
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 17,
                                            ),
                                            label: const Text('Remove image'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // =================================================
                                // VISIBILITY
                                // =================================================
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: SwitchListTile.adaptive(
                                    value: active,
                                    activeColor: Colors.green,
                                    title: const Text(
                                      'Visible on store',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Show this category on the customer Home screen.',
                                      style: TextStyle(fontSize: 9),
                                    ),
                                    onChanged: (value) {
                                      setSheetState(() {
                                        active = value;
                                      });
                                    },
                                  ),
                                ),

                                const SizedBox(height: 18),

                                // =================================================
                                // SAVE
                                // =================================================
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: uploading || sections.isEmpty
                                        ? null
                                        : () async {
                                            if (!formKey.currentState!
                                                .validate()) {
                                              return;
                                            }

                                            final selectedDocs = sections.where(
                                              (doc) =>
                                                  _string(doc.data(), 'name') ==
                                                  selectedSection,
                                            );

                                            final selectedSectionId =
                                                selectedDocs.isNotEmpty
                                                ? selectedDocs.first.id
                                                : '';

                                            final payload = <String, dynamic>{
                                              'name': nameController.text
                                                  .trim(),
                                              'section': selectedSection,
                                              'sectionId': selectedSectionId,
                                              'imageUrl': imageUrl,
                                              'image': imageUrl,
                                              'imagePath': imagePath,
                                              'isActive': active,
                                              'updatedAt':
                                                  FieldValue.serverTimestamp(),
                                            };

                                            try {
                                              if (existing == null) {
                                                payload['createdAt'] =
                                                    FieldValue.serverTimestamp();

                                                await _firestore
                                                    .collection('categories')
                                                    .doc(categoryId)
                                                    .set(payload);
                                              } else {
                                                await _firestore
                                                    .collection('categories')
                                                    .doc(existing.id)
                                                    .update(payload);
                                              }

                                              if (!mounted) return;

                                              Navigator.pop(sheetContext, true);
                                            } catch (e) {
                                              if (!mounted) return;

                                              _message(
                                                'Could not save category: $e',
                                                error: true,
                                              );
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Text(
                                      existing == null
                                          ? 'ADD CATEGORY'
                                          : 'SAVE CHANGES',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
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
      },
    );

    nameController.dispose();

    if (saved == true && mounted) {
      _message(
        existing == null
            ? 'Category added successfully.'
            : 'Category updated successfully.',
      );
    }
  }

  // ==========================================================
  // EDITOR LOADING / ERROR
  // ==========================================================

  Widget _editorLoadingSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.green),
      ),
    );
  }

  Widget _editorErrorSheet(String message) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // DELETE
  // ==========================================================

  Future<void> _deleteCategory(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();

    final name = _string(data, 'name', fallback: 'this category');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.red),
              SizedBox(width: 8),
              Expanded(child: Text('Delete category?')),
            ],
          ),
          content: Text(
            '“$name” will be removed from the catalogue. Products already using this category will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _deleteStorageImage(data);

      await _firestore.collection('categories').doc(doc.id).delete();

      if (mounted) {
        _message('$name deleted.');
      }
    } catch (e) {
      if (mounted) {
        _message('Could not delete category.', error: true);
      }
    }
  }

  // ==========================================================
  // TOGGLE
  // ==========================================================

  Future<void> _toggleCategory(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();

    final current = _bool(data, 'isActive', fallback: true);

    try {
      await _firestore.collection('categories').doc(doc.id).update({
        'isActive': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        _message('Could not update category.', error: true);
      }
    }
  }

  // ==========================================================
  // SEARCH
  // ==========================================================

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _search = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search categories or sections',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            prefixIcon: const Icon(Icons.search_rounded, color: Colors.green),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();

                      setState(() {
                        _search = '';
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // FILTERS
  // ==========================================================

  Widget _buildFilters(Map<String, int> summary) {
    final filters = <String>['All', 'Active', 'Hidden'];

    final counts = <String, int>{
      'All': summary['all'] ?? 0,
      'Active': summary['active'] ?? 0,
      'Hidden': summary['hidden'] ?? 0,
    };

    return SizedBox(
      height: 47,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _filter == filter;

          return ChoiceChip(
            selected: selected,
            label: Text(
              '$filter ${counts[filter]}',
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            selectedColor: Colors.green,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? Colors.green : Colors.grey.shade200,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onSelected: (_) {
              setState(() {
                _filter = filter;
              });
            },
          );
        },
      ),
    );
  }

  // ==========================================================
  // SUMMARY
  // ==========================================================

  Widget _buildSummary(Map<String, int> summary) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _summaryItem('${summary['all'] ?? 0}', 'Categories'),
          _summaryDivider(),
          _summaryItem('${summary['active'] ?? 0}', 'Active'),
          _summaryDivider(),
          _summaryItem('${summary['hidden'] ?? 0}', 'Hidden'),
          _summaryDivider(),
          _summaryItem('${summary['sections'] ?? 0}', 'Sections'),
        ],
      ),
    );
  }

  Widget _summaryItem(String value, String title) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 7,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(width: 1, height: 27, color: Colors.white24);
  }

  // ==========================================================
  // CATEGORY CARD
  // ==========================================================

  Widget _categoryCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final name = _string(data, 'name', fallback: 'Unnamed category');

    final section = _section(data);
    final imageUrl = _imageUrl(data);

    final active = _bool(data, 'isActive', fallback: true);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 5, 16, 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(15),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? CachedProductImage(
                    url: imageUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 240,
                    cacheHeight: 240,
                    placeholder: _placeholder(),
                    errorWidget: _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.view_quilt_outlined,
                      color: Colors.green,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        section,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: active ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    active ? 'VISIBLE' : 'HIDDEN',
                    style: TextStyle(
                      color: active
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'subcategories') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminSubcategoriesScreen(initialCategory: name),
                  ),
                );
              } else if (value == 'edit') {
                _openCategoryEditor(existing: doc);
              } else if (value == 'toggle') {
                _toggleCategory(doc);
              } else if (value == 'delete') {
                _deleteCategory(doc);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'subcategories',
                child: Row(
                  children: const [
                    Icon(Icons.account_tree_outlined, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Subcategories'),
                  ],
                ),
              ),
              const PopupMenuItem(value: 'edit', child: Text('Edit category')),
              PopupMenuItem(
                value: 'toggle',
                child: Text(active ? 'Hide category' : 'Show category'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete category',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return const Center(
      child: Icon(Icons.category_outlined, color: Colors.green, size: 34),
    );
  }

  // ==========================================================
  // FIELD
  // ==========================================================

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.green, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void _message(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
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
      backgroundColor: const Color(0xffF5F7F6),
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Manage Categories',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Add category',
            onPressed: () => _openCategoryEditor(),
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        onPressed: () => _openCategoryEditor(),
        icon: const Icon(Icons.add),
        label: const Text(
          'ADD CATEGORY',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _categoriesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load categories.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
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
            color: Colors.green,
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 300));

              if (mounted) {
                setState(() {});
              }
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildSearch()),
                SliverToBoxAdapter(child: _buildFilters(summary)),
                SliverToBoxAdapter(child: _buildSummary(summary)),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 105,
                              height: 105,
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.category_outlined,
                                color: Colors.green,
                                size: 50,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'No categories found',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              _search.isNotEmpty
                                  ? 'Try a different search.'
                                  : 'Add your first category to build the store catalogue.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 17),
                            ElevatedButton.icon(
                              onPressed: () => _openCategoryEditor(),
                              icon: const Icon(Icons.add),
                              label: const Text('ADD CATEGORY'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return _categoryCard(filtered[index]);
                    }, childCount: filtered.length),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
    );
  }
}
