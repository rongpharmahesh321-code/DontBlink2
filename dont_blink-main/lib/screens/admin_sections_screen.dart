import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSectionsScreen extends StatefulWidget {
  const AdminSectionsScreen({super.key});

  @override
  State<AdminSectionsScreen> createState() => _AdminSectionsScreenState();
}

class _AdminSectionsScreenState extends State<AdminSectionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Stream<QuerySnapshot<Map<String, dynamic>>> get _sectionsStream =>
      _firestore.collection('sections').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _categoriesStream =>
      _firestore.collection('categories').snapshots();

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

    if (value is bool) {
      return value;
    }

    if (value == null) {
      return fallback;
    }

    return value.toString().toLowerCase() == 'true';
  }

  int _sortOrder(Map<String, dynamic> data, String fallbackId) {
    final value = data['sortOrder'];

    if (value is num) {
      return value.toInt();
    }

    final parsed = int.tryParse(value?.toString() ?? '');

    if (parsed != null) {
      return parsed;
    }

    // Stable fallback for older documents.
    return fallbackId.hashCode.abs();
  }

  // ==========================================================
  // SORTING
  // ==========================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sorted(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final result = [...docs];

    result.sort((a, b) {
      final aOrder = _sortOrder(a.data(), a.id);

      final bOrder = _sortOrder(b.data(), b.id);

      if (aOrder != bOrder) {
        return aOrder.compareTo(bOrder);
      }

      final aName = _string(a.data(), 'name').toLowerCase();

      final bName = _string(b.data(), 'name').toLowerCase();

      return aName.compareTo(bName);
    });

    return result;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtered(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final query = _search.trim().toLowerCase();

    final result = docs.where((doc) {
      final data = doc.data();

      final active = _bool(data, 'isActive', fallback: true);

      if (_filter == 'Active' && !active) {
        return false;
      }

      if (_filter == 'Hidden' && active) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final name = _string(data, 'name').toLowerCase();

      final description = _string(data, 'description').toLowerCase();

      return name.contains(query) ||
          description.contains(query) ||
          doc.id.toLowerCase().contains(query);
    }).toList();

    return _sorted(result);
  }

  Map<String, int> _summary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int active = 0;
    int hidden = 0;

    for (final doc in docs) {
      if (_bool(doc.data(), 'isActive', fallback: true)) {
        active++;
      } else {
        hidden++;
      }
    }

    return {'all': docs.length, 'active': active, 'hidden': hidden};
  }

  // ==========================================================
  // CATEGORY COUNT FOR EACH SECTION
  // ==========================================================

  int _categoryCount(
    String sectionName,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> categories,
  ) {
    final target = sectionName.trim().toLowerCase();

    if (target.isEmpty) {
      return 0;
    }

    return categories.where((category) {
      final data = category.data();

      final active = _bool(data, 'isActive', fallback: true);

      if (!active) {
        return false;
      }

      final section = _string(data, 'section').toLowerCase();

      return section == target;
    }).length;
  }

  // ==========================================================
  // ADD / EDIT
  // ==========================================================

  Future<void> _openSectionEditor({
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
    int? suggestedOrder,
  }) async {
    final data = existing?.data();

    final nameController = TextEditingController(
      text: _string(data ?? {}, 'name'),
    );

    final descriptionController = TextEditingController(
      text: _string(data ?? {}, 'description'),
    );

    final orderController = TextEditingController(
      text:
          '${existing != null ? _sortOrder(data!, existing.id) : (suggestedOrder ?? 1)}',
    );

    bool active = _bool(data ?? {}, 'isActive', fallback: true);

    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.view_quilt_outlined,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              existing == null ? 'Add section' : 'Edit section',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext, false),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Form(
                        key: formKey,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                          children: [
                            _field(
                              controller: nameController,
                              label: 'Section name',
                              hint: 'e.g. Grocery & Kitchen',
                              icon: Icons.view_quilt_outlined,
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Enter a section name';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 11),
                            _field(
                              controller: descriptionController,
                              label: 'Description',
                              hint: 'Optional short description',
                              icon: Icons.description_outlined,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 11),
                            _field(
                              controller: orderController,
                              label: 'Display order',
                              hint: '1',
                              icon: Icons.sort_rounded,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final order = int.tryParse(
                                  (value ?? '').trim(),
                                );

                                if (order == null || order < 1) {
                                  return 'Enter a number starting from 1';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: SwitchListTile.adaptive(
                                value: active,
                                activeColor: Colors.green,
                                title: const Text(
                                  'Visible on Home',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Only active sections are used to organise the customer Home screen.',
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
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Categories use the same section name. Keep the spelling consistent with the category “Home section” field.',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 9,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }

                                  final name = nameController.text.trim();

                                  final order = int.parse(
                                    orderController.text.trim(),
                                  );

                                  final duplicate = await _firestore
                                      .collection('sections')
                                      .where('name', isEqualTo: name)
                                      .limit(5)
                                      .get();

                                  final duplicateExists = duplicate.docs.any(
                                    (doc) =>
                                        existing == null ||
                                        doc.id != existing.id,
                                  );

                                  if (duplicateExists) {
                                    if (mounted) {
                                      _message(
                                        'A section with this name already exists.',
                                        error: true,
                                      );
                                    }
                                    return;
                                  }

                                  final payload = <String, dynamic>{
                                    'name': name,
                                    'description': descriptionController.text
                                        .trim(),
                                    'sortOrder': order,
                                    'isActive': active,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  };

                                  try {
                                    if (existing == null) {
                                      payload['createdAt'] =
                                          FieldValue.serverTimestamp();

                                      await _firestore
                                          .collection('sections')
                                          .add(payload);
                                    } else {
                                      await _firestore
                                          .collection('sections')
                                          .doc(existing.id)
                                          .update(payload);
                                    }

                                    if (!mounted) {
                                      return;
                                    }

                                    Navigator.pop(sheetContext, true);
                                  } catch (e) {
                                    if (!mounted) {
                                      return;
                                    }

                                    _message(
                                      'Could not save section: $e',
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
                                      ? 'ADD SECTION'
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

    nameController.dispose();
    descriptionController.dispose();
    orderController.dispose();

    if (saved == true && mounted) {
      _message(
        existing == null
            ? 'Section added successfully.'
            : 'Section updated successfully.',
      );
    }
  }

  // ==========================================================
  // DELETE
  // ==========================================================

  Future<void> _deleteSection(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> categories,
  ) async {
    final data = doc.data();

    final name = _string(data, 'name', fallback: 'this section');

    final categoryCount = _categoryCount(name, categories);

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
              Expanded(child: Text('Delete section?')),
            ],
          ),
          content: Text(
            categoryCount > 0
                ? 'This section currently contains $categoryCount active categor${categoryCount == 1 ? 'y' : 'ies'}. Deleting it will NOT delete those categories, but they will no longer match this section in the Home layout.'
                : 'This section has no active categories. It will be permanently removed.',
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

    if (confirmed != true) {
      return;
    }

    try {
      await _firestore.collection('sections').doc(doc.id).delete();

      if (mounted) {
        _message('$name deleted.');
      }
    } catch (e) {
      if (mounted) {
        _message('Could not delete section.', error: true);
      }
    }
  }

  // ==========================================================
  // TOGGLE
  // ==========================================================

  Future<void> _toggleSection(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final current = _bool(doc.data(), 'isActive', fallback: true);

    try {
      await _firestore.collection('sections').doc(doc.id).update({
        'isActive': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        _message('Could not update section.', error: true);
      }
    }
  }

  // ==========================================================
  // MOVE SECTION
  // ==========================================================

  Future<void> _moveSection(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sections,
    int index,
    int direction,
  ) async {
    final target = index + direction;

    if (target < 0 || target >= sections.length) {
      return;
    }

    final current = sections[index];

    final other = sections[target];

    final currentOrder = _sortOrder(current.data(), current.id);

    final otherOrder = _sortOrder(other.data(), other.id);

    try {
      final batch = _firestore.batch();

      batch.update(_firestore.collection('sections').doc(current.id), {
        'sortOrder': otherOrder,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(_firestore.collection('sections').doc(other.id), {
        'sortOrder': currentOrder,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      if (mounted) {
        _message('Could not reorder sections.', error: true);
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
            hintText: 'Search sections',
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
    const filters = <String>['All', 'Active', 'Hidden'];

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
          _summaryItem('${summary['all'] ?? 0}', 'Sections'),
          _summaryDivider(),
          _summaryItem('${summary['active'] ?? 0}', 'Active'),
          _summaryDivider(),
          _summaryItem('${summary['hidden'] ?? 0}', 'Hidden'),
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
              fontSize: 18,
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
  // SECTION CARD
  // ==========================================================

  Widget _sectionCard({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required int index,
    required int total,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> categories,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> allSections,
  }) {
    final data = doc.data();

    final name = _string(data, 'name', fallback: 'Unnamed section');

    final description = _string(data, 'description');

    final active = _bool(data, 'isActive', fallback: true);

    final order = _sortOrder(data, doc.id);

    final categoryCount = _categoryCount(name, categories);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 5, 16, 8),
      padding: const EdgeInsets.all(13),
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.view_quilt_outlined,
                  color: Colors.green,
                  size: 25,
                ),
              ),
              const SizedBox(width: 11),
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
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _openSectionEditor(existing: doc);
                  } else if (value == 'toggle') {
                    _toggleSection(doc);
                  } else if (value == 'delete') {
                    _deleteSection(doc, categories);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit section'),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(active ? 'Hide section' : 'Show section'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete section',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$order',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  '$categoryCount active categor${categoryCount == 1 ? 'y' : 'ies'}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: active ? Colors.green.shade50 : Colors.grey.shade200,
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: index > 0
                      ? () => _moveSection(allSections, index, -1)
                      : null,
                  icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                  label: const Text(
                    'MOVE UP',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: BorderSide(color: Colors.green.shade100),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: index < total - 1
                      ? () => _moveSection(allSections, index, 1)
                      : null,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  label: const Text(
                    'MOVE DOWN',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: BorderSide(color: Colors.green.shade100),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
    if (!mounted) {
      return;
    }

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
          'Manage Sections',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Add section',
            onPressed: () => _openSectionEditor(),
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: () => _openSectionEditor(),
        icon: const Icon(Icons.add),
        label: const Text(
          'ADD SECTION',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _sectionsStream,
        builder: (context, sectionSnapshot) {
          if (sectionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (sectionSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load sections.\n${sectionSnapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final sectionDocs =
              sectionSnapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          final sortedSections = _sorted(sectionDocs);

          final summary = _summary(sectionDocs);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _categoriesStream,
            builder: (context, categorySnapshot) {
              final categories =
                  categorySnapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              final filtered = _filtered(sectionDocs);

              // The up/down buttons operate on the
              // complete ordered section list.
              final orderedIndexById = <String, int>{};

              for (int i = 0; i < sortedSections.length; i++) {
                orderedIndexById[sortedSections[i].id] = i;
              }

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
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 2),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final doc = filtered[index];

                          final globalIndex = orderedIndexById[doc.id] ?? index;

                          return _sectionCard(
                            doc: doc,
                            index: globalIndex,
                            total: sortedSections.length,
                            categories: categories,
                            allSections: sortedSections,
                          );
                        }, childCount: filtered.length),
                      ),
                    ),
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
                                    Icons.view_quilt_outlined,
                                    color: Colors.green,
                                    size: 50,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'No sections found',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  _search.isNotEmpty
                                      ? 'Try a different search.'
                                      : 'Create sections such as Grocery & Kitchen or Snacks & Drinks.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 17),
                                ElevatedButton.icon(
                                  onPressed: () => _openSectionEditor(
                                    suggestedOrder: sectionDocs.length + 1,
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('ADD SECTION'),
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
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
