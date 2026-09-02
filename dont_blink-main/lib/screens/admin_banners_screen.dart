import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/banner.dart';
import '../services/firestore_service.dart';

class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
  // ==========================================================
  // SERVICES
  // ==========================================================

  final FirestoreService firestoreService = FirestoreService();

  final FirebaseStorage storage = FirebaseStorage.instance;

  final ImagePicker imagePicker = ImagePicker();

  // ==========================================================
  // ADD / EDIT BANNER
  // ==========================================================

  Future<void> _showBannerDialog({BannerModel? banner}) async {
    final titleController = TextEditingController(text: banner?.title ?? '');

    final subtitleController = TextEditingController(
      text: banner?.subtitle ?? '',
    );

    final orderController = TextEditingController(
      text: '${banner?.sortOrder ?? 0}',
    );

    File? selectedImage;

    bool isActive = banner?.isActive ?? true;

    bool saving = false;

    try {
      await showDialog(
        context: context,
        barrierDismissible: !saving,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              // =================================================
              // PICK IMAGE
              // =================================================

              Future<void> pickImage() async {
                try {
                  final XFile? picked = await imagePicker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 90,
                  );

                  if (picked == null) {
                    return;
                  }

                  setDialogState(() {
                    selectedImage = File(picked.path);
                  });
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Unable to select image: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }

              // =================================================
              // SAVE
              // =================================================

              Future<void> saveBanner() async {
                if (saving) {
                  return;
                }

                // ------------------------------------------------
                // NEW BANNER NEEDS IMAGE
                // ------------------------------------------------

                if (banner == null && selectedImage == null) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a banner image.'),
                      backgroundColor: Colors.red,
                    ),
                  );

                  return;
                }

                int sortOrder = int.tryParse(orderController.text.trim()) ?? 0;

                setDialogState(() {
                  saving = true;
                });

                try {
                  String imageUrl = banner?.imageUrl ?? '';

                  // =============================================
                  // UPLOAD NEW IMAGE
                  // =============================================

                  if (selectedImage != null) {
                    final fileName =
                        'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';

                    final storageRef = storage
                        .ref()
                        .child('banners')
                        .child(fileName);

                    await storageRef.putFile(selectedImage!);

                    imageUrl = await storageRef.getDownloadURL();

                    // ---------------------------------------------
                    // DELETE OLD IMAGE
                    // ---------------------------------------------

                    if (banner != null && banner.imageUrl.trim().isNotEmpty) {
                      try {
                        final oldRef = storage.refFromURL(banner.imageUrl);

                        await oldRef.delete();
                      } catch (_) {
                        // Old image may already be deleted.
                      }
                    }
                  }

                  // =============================================
                  // CREATE
                  // =============================================

                  if (banner == null) {
                    final newBanner = BannerModel(
                      id: '',
                      imageUrl: imageUrl,
                      title: titleController.text.trim(),
                      subtitle: subtitleController.text.trim(),
                      isActive: isActive,
                      sortOrder: sortOrder,
                    );

                    await firestoreService.addBanner(newBanner);
                  }
                  // =============================================
                  // UPDATE
                  // =============================================
                  else {
                    final updatedBanner = banner.copyWith(
                      imageUrl: imageUrl,
                      title: titleController.text.trim(),
                      subtitle: subtitleController.text.trim(),
                      isActive: isActive,
                      sortOrder: sortOrder,
                    );

                    await firestoreService.updateBanner(updatedBanner);
                  }

                  if (!mounted) return;

                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        banner == null
                            ? 'Banner added successfully.'
                            : 'Banner updated successfully.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  setDialogState(() {
                    saving = false;
                  });

                  if (!mounted) return;

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save banner:\n$e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }

              // =================================================
              // DIALOG
              // =================================================

              return AlertDialog(
                title: Text(banner == null ? 'Add Banner' : 'Edit Banner'),

                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 430,

                    child: Column(
                      mainAxisSize: MainAxisSize.min,

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        // =========================================
                        // IMAGE
                        // =========================================
                        GestureDetector(
                          onTap: saving ? null : pickImage,

                          child: Container(
                            width: double.infinity,
                            height: 170,

                            decoration: BoxDecoration(
                              color: Colors.green.shade50,

                              borderRadius: BorderRadius.circular(16),

                              border: Border.all(color: Colors.green.shade100),
                            ),

                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),

                              child: selectedImage != null
                                  ? Image.file(
                                      selectedImage!,
                                      fit: BoxFit.cover,
                                    )
                                  : banner != null &&
                                        banner.imageUrl.trim().isNotEmpty
                                  ? Image.network(
                                      banner.imageUrl,
                                      fit: BoxFit.cover,

                                      errorBuilder: (_, __, ___) {
                                        return const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        );
                                      },
                                    )
                                  : const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,

                                      children: [
                                        Icon(
                                          Icons.cloud_upload_outlined,
                                          size: 48,
                                          color: Colors.green,
                                        ),

                                        SizedBox(height: 8),

                                        Text(
                                          'Tap to select banner image',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // =========================================
                        // TITLE
                        // =========================================
                        TextField(
                          controller: titleController,

                          enabled: !saving,

                          decoration: InputDecoration(
                            labelText: 'Title',

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // =========================================
                        // SUBTITLE
                        // =========================================
                        TextField(
                          controller: subtitleController,

                          enabled: !saving,

                          decoration: InputDecoration(
                            labelText: 'Subtitle',

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // =========================================
                        // SORT ORDER
                        // =========================================
                        TextField(
                          controller: orderController,

                          enabled: !saving,

                          keyboardType: TextInputType.number,

                          decoration: InputDecoration(
                            labelText: 'Sort Order',

                            hintText: '0 = first',

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // =========================================
                        // ACTIVE
                        // =========================================
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,

                          title: const Text('Show on HomeScreen'),

                          subtitle: Text(
                            isActive ? 'Banner is visible' : 'Banner is hidden',
                          ),

                          value: isActive,

                          activeThumbColor: Colors.green,

                          onChanged: saving
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    isActive = value;
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                ),

                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                          },

                    child: const Text('CANCEL'),
                  ),

                  ElevatedButton(
                    onPressed: saving ? null : saveBanner,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,

                      foregroundColor: Colors.white,
                    ),

                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,

                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(banner == null ? 'ADD' : 'SAVE'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      titleController.dispose();
      subtitleController.dispose();
      orderController.dispose();
    }
  }

  // ==========================================================
  // DELETE BANNER
  // ==========================================================

  Future<void> _deleteBanner(BannerModel banner) async {
    final shouldDelete = await showDialog<bool>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Banner?'),

          content: const Text('This banner will be permanently removed.'),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },

              child: const Text('CANCEL'),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },

              child: const Text('DELETE', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      // ========================================================
      // DELETE FIRESTORE
      // ========================================================

      await firestoreService.deleteBanner(banner.id);

      // ========================================================
      // DELETE STORAGE IMAGE
      // ========================================================

      if (banner.imageUrl.trim().isNotEmpty) {
        try {
          final ref = storage.refFromURL(banner.imageUrl);

          await ref.delete();
        } catch (_) {
          // Image may already be deleted.
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Banner deleted successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete banner:\n$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================================
  // TOGGLE ACTIVE
  // ==========================================================

  Future<void> _toggleBanner(BannerModel banner) async {
    try {
      await firestoreService.updateBannerStatus(
        bannerId: banner.id,
        isActive: !banner.isActive,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update banner:\n$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Banners'),

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
          _showBannerDialog();
        },

        icon: const Icon(Icons.add_photo_alternate),

        label: const Text('ADD BANNER'),
      ),

      // ========================================================
      // BANNER LIST
      // ========================================================
      body: StreamBuilder<List<BannerModel>>(
        stream: firestoreService.getAllBanners(),

        builder: (context, snapshot) {
          // ====================================================
          // LOADING
          // ====================================================

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          // ====================================================
          // ERROR
          // ====================================================

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Text(
                  'Unable to load banners.\n\n'
                  '${snapshot.error}',

                  textAlign: TextAlign.center,

                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final banners = snapshot.data ?? [];

          // ====================================================
          // EMPTY
          // ====================================================

          if (banners.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),

                  SizedBox(height: 15),

                  Text(
                    'No Banners Yet',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 8),

                  Text('Tap ADD BANNER to create one.'),
                ],
              ),
            );
          }

          // ====================================================
          // LIST
          // ====================================================

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),

            itemCount: banners.length,

            itemBuilder: (context, index) {
              final banner = banners[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),

                elevation: 3,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),

                clipBehavior: Clip.antiAlias,

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // ==========================================
                    // IMAGE
                    // ==========================================
                    SizedBox(
                      width: double.infinity,

                      height: 190,

                      child: banner.imageUrl.trim().isNotEmpty
                          ? Image.network(
                              banner.imageUrl,

                              fit: BoxFit.cover,

                              errorBuilder: (_, __, ___) {
                                return Container(
                                  color: Colors.grey.shade200,

                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey.shade200,

                              child: const Center(
                                child: Icon(
                                  Icons.image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                    ),

                    // ==========================================
                    // INFORMATION
                    // ==========================================
                    Padding(
                      padding: const EdgeInsets.all(15),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  banner.title.trim().isEmpty
                                      ? 'Untitled Banner'
                                      : banner.title,

                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showBannerDialog(banner: banner);
                                  }

                                  if (value == 'delete') {
                                    _deleteBanner(banner);
                                  }
                                },

                                itemBuilder: (context) {
                                  return const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),

                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ];
                                },
                              ),
                            ],
                          ),

                          if (banner.subtitle.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),

                              child: Text(
                                banner.subtitle,

                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),

                          const SizedBox(height: 12),

                          const Divider(),

                          // ========================================
                          // CONTROLS
                          // ========================================
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),

                                decoration: BoxDecoration(
                                  color: banner.isActive
                                      ? Colors.green.shade50
                                      : Colors.red.shade50,

                                  borderRadius: BorderRadius.circular(20),
                                ),

                                child: Text(
                                  banner.isActive ? 'ACTIVE' : 'HIDDEN',

                                  style: TextStyle(
                                    color: banner.isActive
                                        ? Colors.green
                                        : Colors.red,

                                    fontWeight: FontWeight.bold,

                                    fontSize: 11,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              Text(
                                'Order: ${banner.sortOrder}',

                                style: TextStyle(
                                  color: Colors.grey.shade600,

                                  fontSize: 13,
                                ),
                              ),

                              const Spacer(),

                              Switch(
                                value: banner.isActive,

                                activeThumbColor: Colors.green,

                                onChanged: (_) {
                                  _toggleBanner(banner);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
