import 'package:cloud_firestore/cloud_firestore.dart';

class SectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sectionsCollection =>
      _firestore.collection('sections');

  // ============================================================
  // GET ALL ACTIVE SECTIONS
  // ============================================================

  Stream<List<String>> getSections() {
    return _sectionsCollection.snapshots().map((snapshot) {
      final sections = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Treat missing isActive as active.
        final isActive = _toBool(data['isActive'], defaultValue: true);

        if (!isActive) {
          continue;
        }

        final name = _toString(data['name'] ?? data['title'] ?? doc.id);

        if (name.isEmpty) {
          continue;
        }

        final sortOrder = _toInt(data['sortOrder']);

        sections.add({'name': name, 'sortOrder': sortOrder});
      }

      // Sort locally so we don't need a Firestore
      // composite index.
      sections.sort(
        (a, b) => (a['sortOrder'] as int).compareTo(b['sortOrder'] as int),
      );

      return sections.map((section) => section['name'] as String).toList();
    });
  }

  // ============================================================
  // GET ALL SECTIONS
  // ============================================================

  Stream<List<String>> getAllSections() {
    return _sectionsCollection.snapshots().map((snapshot) {
      final sections = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final name = _toString(data['name'] ?? data['title'] ?? doc.id);

        if (name.isEmpty) {
          continue;
        }

        final sortOrder = _toInt(data['sortOrder']);

        sections.add({'name': name, 'sortOrder': sortOrder});
      }

      sections.sort(
        (a, b) => (a['sortOrder'] as int).compareTo(b['sortOrder'] as int),
      );

      return sections.map((section) => section['name'] as String).toList();
    });
  }

  // ============================================================
  // CREATE SECTION
  // ============================================================
  //
  // IMPORTANT:
  // This keeps the original method signature used by
  // add_product_screen.dart:
  //
  // sectionService.createSection(sectionName)
  //
  // ============================================================

  Future<void> createSection(String name) async {
    final sectionName = name.trim();

    if (sectionName.isEmpty) {
      return;
    }

    // Prevent duplicate sections.
    final existing = await _sectionsCollection
        .where('name', isEqualTo: sectionName)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return;
    }

    // Determine the next sort order.
    final countSnapshot = await _sectionsCollection.get();

    await _sectionsCollection.add({
      'name': sectionName,
      'sortOrder': countSnapshot.docs.length,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // ADD SECTION
  // ============================================================

  Future<String> addSection({
    required String name,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final sectionName = name.trim();

    if (sectionName.isEmpty) {
      throw Exception('Section name cannot be empty.');
    }

    final existing = await _sectionsCollection
        .where('name', isEqualTo: sectionName)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final docRef = await _sectionsCollection.add({
      'name': sectionName,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // ============================================================
  // UPDATE SECTION
  // ============================================================

  Future<void> updateSection({
    required String sectionId,
    required String name,
    int? sortOrder,
    bool? isActive,
  }) async {
    if (sectionId.trim().isEmpty) {
      throw Exception('Section ID cannot be empty.');
    }

    final updates = <String, dynamic>{'name': name.trim()};

    if (sortOrder != null) {
      updates['sortOrder'] = sortOrder;
    }

    if (isActive != null) {
      updates['isActive'] = isActive;
    }

    await _sectionsCollection.doc(sectionId).update(updates);
  }

  // ============================================================
  // DELETE SECTION
  // ============================================================

  Future<void> deleteSection(String sectionId) async {
    if (sectionId.trim().isEmpty) {
      throw Exception('Section ID cannot be empty.');
    }

    await _sectionsCollection.doc(sectionId).delete();
  }

  // ============================================================
  // ENABLE / DISABLE SECTION
  // ============================================================

  Future<void> setSectionActive({
    required String sectionId,
    required bool isActive,
  }) async {
    if (sectionId.trim().isEmpty) {
      throw Exception('Section ID cannot be empty.');
    }

    await _sectionsCollection.doc(sectionId).update({'isActive': isActive});
  }

  // ============================================================
  // UPDATE SORT ORDER
  // ============================================================

  Future<void> updateSortOrder({
    required String sectionId,
    required int sortOrder,
  }) async {
    if (sectionId.trim().isEmpty) {
      throw Exception('Section ID cannot be empty.');
    }

    await _sectionsCollection.doc(sectionId).update({'sortOrder': sortOrder});
  }

  // ============================================================
  // SAFE STRING
  // ============================================================

  String _toString(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  // ============================================================
  // SAFE INTEGER
  // ============================================================

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  // ============================================================
  // SAFE BOOLEAN
  // ============================================================

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
