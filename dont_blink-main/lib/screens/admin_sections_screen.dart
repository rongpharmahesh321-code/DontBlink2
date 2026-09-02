import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/section_service.dart';

class AdminSectionsScreen extends StatefulWidget {
  const AdminSectionsScreen({super.key});

  @override
  State<AdminSectionsScreen> createState() => _AdminSectionsScreenState();
}

class _AdminSectionsScreenState extends State<AdminSectionsScreen> {
  final SectionService sectionService = SectionService();

  // ==========================================================
  // ADD / EDIT SECTION
  // ==========================================================

  Future<void> openSectionDialog({
    String? sectionId,
    String? currentName,
    int? currentSortOrder,
    bool? currentIsActive,
  }) async {
    final nameController = TextEditingController(text: currentName ?? '');

    final sortController = TextEditingController(
      text: (currentSortOrder ?? 0).toString(),
    );

    bool isSaving = false;

    final isEditing = sectionId != null;

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveSection() async {
              if (isSaving) {
                return;
              }

              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }

              final name = nameController.text.trim();

              final sortOrder = int.tryParse(sortController.text.trim()) ?? 0;

              setDialogState(() {
                isSaving = true;
              });

              try {
                if (isEditing) {
                  await sectionService.updateSection(
                    sectionId: sectionId!,
                    name: name,
                    sortOrder: sortOrder,
                    isActive: currentIsActive ?? true,
                  );
                } else {
                  await sectionService.addSection(
                    name: name,
                    sortOrder: sortOrder,
                    isActive: true,
                  );
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
                    content: Text('Unable to save section: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(isEditing ? 'Edit Section' : 'Add New Section'),

              content: Form(
                key: formKey,

                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ==================================================
                      // NAME
                      // ==================================================
                      TextFormField(
                        controller: nameController,

                        enabled: !isSaving,

                        textCapitalization: TextCapitalization.words,

                        decoration: const InputDecoration(
                          labelText: 'Section Name',
                          hintText: 'Example: Grocery & Kitchen',
                          prefixIcon: Icon(Icons.view_list_outlined),
                          border: OutlineInputBorder(),
                        ),

                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter section name';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // ==================================================
                      // SORT ORDER
                      // ==================================================
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
                          final number = int.tryParse(value?.trim() ?? '');

                          if (number == null) {
                            return 'Enter a valid number';
                          }

                          if (number < 0) {
                            return 'Sort order cannot be negative';
                          }

                          return null;
                        },
                      ),
                    ],
                  ),
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
                  onPressed: isSaving ? null : saveSection,

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
                        : isEditing
                        ? 'SAVE CHANGES'
                        : 'ADD SECTION',
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
    sortController.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Section updated successfully'
                : 'Section added successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ==========================================================
  // DELETE
  // ==========================================================

  Future<void> deleteSection({
    required String sectionId,
    required String sectionName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Section?'),

          content: Text(
            'Are you sure you want to delete '
            '"$sectionName"?\n\n'
            'Products and categories using this '
            'section will not be automatically deleted.',
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
      await sectionService.deleteSection(sectionId);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Section deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete section: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================================
  // TOGGLE
  // ==========================================================

  Future<void> toggleSection({
    required String sectionId,
    required bool isActive,
  }) async {
    try {
      await sectionService.setSectionActive(
        sectionId: sectionId,
        isActive: !isActive,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update section: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================================
  // BUILD SECTION CARD
  // ==========================================================

  Widget sectionCard({
    required String sectionId,
    required String name,
    required int sortOrder,
    required bool isActive,
  }) {
    return Card(
      elevation: 2,

      margin: const EdgeInsets.only(bottom: 14),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Row(
          children: [
            // ==================================================
            // ICON
            // ==================================================
            Container(
              width: 58,
              height: 58,

              decoration: BoxDecoration(
                color: isActive ? Colors.green.shade50 : Colors.grey.shade200,

                borderRadius: BorderRadius.circular(16),
              ),

              child: Icon(
                Icons.view_list_rounded,

                color: isActive ? Colors.green : Colors.grey,

                size: 30,
              ),
            ),

            const SizedBox(width: 15),

            // ==================================================
            // INFORMATION
            // ==================================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      if (!isActive)
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

                  const SizedBox(height: 6),

                  Text(
                    'Sort order: $sortOrder',

                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),

            // ==================================================
            // MENU
            // ==================================================
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  await openSectionDialog(
                    sectionId: sectionId,
                    currentName: name,
                    currentSortOrder: sortOrder,
                    currentIsActive: isActive,
                  );
                }

                if (value == 'toggle') {
                  await toggleSection(sectionId: sectionId, isActive: isActive);
                }

                if (value == 'delete') {
                  await deleteSection(sectionId: sectionId, sectionName: name);
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
                          isActive ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),

                        const SizedBox(width: 10),

                        Text(isActive ? 'Hide' : 'Show'),
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
        title: const Text('Manage Sections'),

        centerTitle: true,

        backgroundColor: Colors.green,

        foregroundColor: Colors.white,
      ),

      // ========================================================
      // ADD BUTTON
      // ========================================================
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,

        foregroundColor: Colors.white,

        onPressed: () {
          openSectionDialog();
        },

        icon: const Icon(Icons.add),

        label: const Text(
          'ADD SECTION',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      // ========================================================
      // SECTION LIST
      // ========================================================
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('sections').snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Text(
                  'Unable to load sections:\n\n'
                  '${snapshot.error}',

                  textAlign: TextAlign.center,

                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          final sections = docs.map((doc) {
            final data = doc.data();

            return {
              'id': doc.id,
              'name': data['name'] ?? data['title'] ?? doc.id,
              'sortOrder': _toInt(data['sortOrder']),
              'isActive': _toBool(data['isActive'], defaultValue: true),
            };
          }).toList();

          sections.sort(
            (a, b) => (a['sortOrder'] as int).compareTo(b['sortOrder'] as int),
          );

          if (sections.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Icon(
                      Icons.view_list_outlined,

                      size: 90,

                      color: Colors.grey.shade400,
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'No Sections Yet',

                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Create your first section '
                      'using the button below.',

                      textAlign: TextAlign.center,

                      style: TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 25),

                    ElevatedButton.icon(
                      onPressed: () {
                        openSectionDialog();
                      },

                      icon: const Icon(Icons.add),

                      label: const Text('ADD SECTION'),

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

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),

            itemCount: sections.length,

            itemBuilder: (context, index) {
              final section = sections[index];

              return sectionCard(
                sectionId: section['id'] as String,

                name: section['name'].toString(),

                sortOrder: section['sortOrder'] as int,

                isActive: section['isActive'] as bool,
              );
            },
          );
        },
      ),
    );
  }

  // ==========================================================
  // SAFE INT
  // ==========================================================

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ==========================================================
  // SAFE BOOL
  // ==========================================================

  bool _toBool(dynamic value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();

      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }

      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }

    return defaultValue;
  }
}
