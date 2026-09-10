import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
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

  Stream<QuerySnapshot<Map<String, dynamic>>> get _bannersStream =>
      _firestore.collection('banners').snapshots();

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

    return fallbackId.hashCode.abs();
  }

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

      final aTitle = _string(a.data(), 'title').toLowerCase();

      final bTitle = _string(b.data(), 'title').toLowerCase();

      return aTitle.compareTo(bTitle);
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

      final title = _string(data, 'title').toLowerCase();

      final subtitle = _string(data, 'subtitle').toLowerCase();

      final imageUrl = _string(data, 'imageUrl').toLowerCase();

      return title.contains(query) ||
          subtitle.contains(query) ||
          imageUrl.contains(query) ||
          doc.id.toLowerCase().contains(query);
    }).toList();

    return _sorted(result);
  }

  Map<String, int> _summary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int active = 0;
    int hidden = 0;
    int withImage = 0;

    for (final doc in docs) {
      final data = doc.data();

      if (_bool(data, 'isActive', fallback: true)) {
        active++;
      } else {
        hidden++;
      }

      if (_string(data, 'imageUrl').isNotEmpty) {
        withImage++;
      }
    }

    return {
      'all': docs.length,
      'active': active,
      'hidden': hidden,
      'withImage': withImage,
    };
  }

  // ==========================================================
  // IMAGE UPLOAD
  // ==========================================================

  Future<Map<String, String>?> _pickAndUploadImage({
    String? existingPath,
    required String bannerId,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1800,
      );

      if (picked == null) {
        return null;
      }

      final extension = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';

      final path = 'banners/$bannerId.$extension';

      final reference = _storage.ref().child(path);

      final bytes = await picked.readAsBytes();

      final metadata = SettableMetadata(
        contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
        cacheControl: 'public,max-age=31536000',
      );

      await reference.putData(bytes, metadata);

      final url = await reference.getDownloadURL();

      if (existingPath != null &&
          existingPath.trim().isNotEmpty &&
          existingPath.trim() != path) {
        try {
          await _storage.ref().child(existingPath.trim()).delete();
        } catch (_) {}
      }

      return {'url': url, 'path': path};
    } catch (e) {
      if (mounted) {
        _message('Image upload failed: $e', error: true);
      }

      return null;
    }
  }

  Future<void> _deleteStorageImage(Map<String, dynamic> data) async {
    final imagePath = _string(data, 'imagePath');

    if (imagePath.isEmpty) {
      return;
    }

    try {
      await _storage.ref().child(imagePath).delete();
    } catch (_) {}
  }

  // ==========================================================
  // ADD / EDIT BANNER
  // ==========================================================

  Future<void> _openBannerEditor({
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
    int? suggestedOrder,
  }) async {
    final data = existing?.data() ?? <String, dynamic>{};

    final titleController = TextEditingController(text: _string(data, 'title'));

    final subtitleController = TextEditingController(
      text: _string(data, 'subtitle'),
    );

    final orderController = TextEditingController(
      text:
          '${existing != null ? _sortOrder(data, existing.id) : (suggestedOrder ?? 1)}',
    );

    final actionTextController = TextEditingController(
      text: _string(data, 'actionText'),
    );

    final actionValueController = TextEditingController(
      text: _string(data, 'actionValue'),
    );

    String imageUrl = _string(data, 'imageUrl');

    String imagePath = _string(data, 'imagePath');

    bool active = _bool(data, 'isActive', fallback: true);

    bool uploading = false;

    final formKey = GlobalKey<FormState>();

    final bannerId =
        existing?.id ?? 'banner_${DateTime.now().millisecondsSinceEpoch}';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                              color: Colors.deepOrange.shade50,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.view_carousel_outlined,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              existing == null
                                  ? 'Add home banner'
                                  : 'Edit home banner',
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
                          padding: const EdgeInsets.fromLTRB(18, 7, 18, 30),
                          children: [
                            // IMAGE
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(17),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Banner image',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Use a wide landscape image for the Blinkit-style Home slider.',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 9,
                                    ),
                                  ),
                                  const SizedBox(height: 11),
                                  Container(
                                    height: 165,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrange.shade50,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) {
                                              return const Center(
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                  color: Colors.grey,
                                                  size: 40,
                                                ),
                                              );
                                            },
                                          )
                                        : const Center(
                                            child: Icon(
                                              Icons
                                                  .add_photo_alternate_outlined,
                                              color: Colors.deepOrange,
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
                                                    bannerId: bannerId,
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
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.deepOrange,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.photo_library_outlined,
                                              size: 19,
                                            ),
                                      label: Text(
                                        uploading
                                            ? 'UPLOADING...'
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
                                                  imagePath = '';
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

                            const SizedBox(height: 11),

                            _field(
                              controller: titleController,
                              label: 'Banner title',
                              hint: 'e.g. Fresh groceries at great prices',
                              icon: Icons.title_rounded,
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Enter a banner title';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 10),

                            _field(
                              controller: subtitleController,
                              label: 'Subtitle',
                              hint: 'Optional supporting text',
                              icon: Icons.subtitles_outlined,
                              maxLines: 2,
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: _field(
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
                                        return 'Use 1 or higher';
                                      }

                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _switchBox(
                                    title: 'Visible',
                                    subtitle: 'Show on Home',
                                    value: active,
                                    onChanged: (value) {
                                      setSheetState(() {
                                        active = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            _field(
                              controller: actionTextController,
                              label: 'Button text',
                              hint: 'e.g. SHOP NOW',
                              icon: Icons.smart_button_outlined,
                            ),

                            const SizedBox(height: 10),

                            _field(
                              controller: actionValueController,
                              label: 'Action value',
                              hint: 'Optional category/product ID',
                              icon: Icons.link_rounded,
                            ),

                            const SizedBox(height: 12),

                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.orange.shade100,
                                ),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.deepOrange,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'The Home slider reads imageUrl, title, subtitle, isActive and sortOrder. Extra action fields are also saved so you can wire banner buttons later.',
                                      style: TextStyle(
                                        color: Colors.deepOrange,
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
                                onPressed: uploading
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) {
                                          return;
                                        }

                                        if (imageUrl.trim().isEmpty) {
                                          _message(
                                            'Please choose a banner image.',
                                            error: true,
                                          );
                                          return;
                                        }

                                        final order = int.parse(
                                          orderController.text.trim(),
                                        );

                                        final payload = <String, dynamic>{
                                          'title': titleController.text.trim(),
                                          'subtitle': subtitleController.text
                                              .trim(),
                                          'imageUrl': imageUrl,
                                          'image': imageUrl,
                                          'imagePath': imagePath,
                                          'sortOrder': order,
                                          'isActive': active,
                                          'actionText': actionTextController
                                              .text
                                              .trim(),
                                          'actionValue': actionValueController
                                              .text
                                              .trim(),
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        };

                                        try {
                                          if (existing == null) {
                                            payload['createdAt'] =
                                                FieldValue.serverTimestamp();

                                            await _firestore
                                                .collection('banners')
                                                .doc(bannerId)
                                                .set(payload);
                                          } else {
                                            await _firestore
                                                .collection('banners')
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
                                            'Could not save banner: $e',
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
                                      ? 'ADD BANNER'
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

    titleController.dispose();
    subtitleController.dispose();
    orderController.dispose();
    actionTextController.dispose();
    actionValueController.dispose();

    if (saved == true && mounted) {
      _message(
        existing == null
            ? 'Banner added successfully.'
            : 'Banner updated successfully.',
      );
    }
  }

  // ==========================================================
  // DELETE
  // ==========================================================

  Future<void> _deleteBanner(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();

    final title = _string(data, 'title', fallback: 'this banner');

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
              Expanded(child: Text('Delete banner?')),
            ],
          ),
          content: Text('“$title” will be removed from the Home slider.'),
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
      await _deleteStorageImage(data);

      await _firestore.collection('banners').doc(doc.id).delete();

      if (mounted) {
        _message('Banner deleted.');
      }
    } catch (e) {
      if (mounted) {
        _message('Could not delete banner: $e', error: true);
      }
    }
  }

  // ==========================================================
  // TOGGLE
  // ==========================================================

  Future<void> _toggleBanner(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final current = _bool(doc.data(), 'isActive', fallback: true);

    try {
      await _firestore.collection('banners').doc(doc.id).update({
        'isActive': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        _message('Could not update banner.', error: true);
      }
    }
  }

  // ==========================================================
  // REORDER
  // ==========================================================

  Future<void> _moveBanner(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> banners,
    int index,
    int direction,
  ) async {
    final target = index + direction;

    if (target < 0 || target >= banners.length) {
      return;
    }

    final current = banners[index];

    final other = banners[target];

    final currentOrder = _sortOrder(current.data(), current.id);

    final otherOrder = _sortOrder(other.data(), other.id);

    try {
      final batch = _firestore.batch();

      batch.update(_firestore.collection('banners').doc(current.id), {
        'sortOrder': otherOrder,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(_firestore.collection('banners').doc(other.id), {
        'sortOrder': currentOrder,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      if (mounted) {
        _message('Could not reorder banners.', error: true);
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
            hintText: 'Search banners',
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
          _summaryItem('${summary['all'] ?? 0}', 'Banners'),
          _summaryDivider(),
          _summaryItem('${summary['active'] ?? 0}', 'Active'),
          _summaryDivider(),
          _summaryItem('${summary['withImage'] ?? 0}', 'With image'),
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
  // BANNER CARD
  // ==========================================================

  Widget _bannerCard({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required int index,
    required int total,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> allBanners,
  }) {
    final data = doc.data();

    final title = _string(data, 'title', fallback: 'Untitled banner');

    final subtitle = _string(data, 'subtitle');

    final imageUrl = _string(data, 'imageUrl');

    final active = _bool(data, 'isActive', fallback: true);

    final order = _sortOrder(data, doc.id);

    final actionText = _string(data, 'actionText');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 5, 16, 9),
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 165,
                width: double.infinity,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            color: Colors.deepOrange.shade50,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.deepOrange,
                                size: 42,
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.deepOrange.shade50,
                        child: const Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: Colors.deepOrange,
                            size: 42,
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ORDER $order',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: active ? Colors.green : Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    active ? 'VISIBLE' : 'HIDDEN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openBannerEditor(existing: doc);
                        } else if (value == 'toggle') {
                          _toggleBanner(doc);
                        } else if (value == 'delete') {
                          _deleteBanner(doc);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit banner'),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(active ? 'Hide banner' : 'Show banner'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete banner',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                      icon: const Icon(Icons.more_vert_rounded),
                    ),
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 9,
                      height: 1.3,
                    ),
                  ),
                ],
                if (actionText.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'BUTTON: $actionText',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: index > 0
                            ? () => _moveBanner(allBanners, index, -1)
                            : null,
                        icon: const Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'MOVE UP',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
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
                            ? () => _moveBanner(allBanners, index, 1)
                            : null,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'MOVE DOWN',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
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

  Widget _switchBox({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(13),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        value: value,
        activeColor: Colors.green,
        title: Text(
          title,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 7)),
        onChanged: onChanged,
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
          'Home Banners',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Add banner',
            onPressed: () => _openBannerEditor(),
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: () => _openBannerEditor(),
        icon: const Icon(Icons.add),
        label: const Text(
          'ADD BANNER',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _bannersStream,
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
                  'Unable to load banners.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final docs =
              snapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          final sorted = _sorted(docs);

          final filtered = _filtered(docs);

          final summary = _summary(docs);

          final indexById = <String, int>{};

          for (int i = 0; i < sorted.length; i++) {
            indexById[sorted[i].id] = i;
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
                if (filtered.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final doc = filtered[index];

                      final globalIndex = indexById[doc.id] ?? index;

                      return _bannerCard(
                        doc: doc,
                        index: globalIndex,
                        total: sorted.length,
                        allBanners: sorted,
                      );
                    }, childCount: filtered.length),
                  )
                else
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
                                color: Colors.deepOrange.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.view_carousel_outlined,
                                color: Colors.deepOrange,
                                size: 50,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'No banners found',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              _search.isNotEmpty
                                  ? 'Try a different search.'
                                  : 'Add your first Home slider banner.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 17),
                            ElevatedButton.icon(
                              onPressed: () => _openBannerEditor(
                                suggestedOrder: docs.length + 1,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('ADD BANNER'),
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
      ),
    );
  }
}
