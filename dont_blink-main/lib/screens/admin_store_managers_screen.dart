import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminStoreManagersScreen extends StatefulWidget {
  const AdminStoreManagersScreen({super.key});

  @override
  State<AdminStoreManagersScreen> createState() =>
      _AdminStoreManagersScreenState();
}

class _AdminStoreManagersScreenState extends State<AdminStoreManagersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _search = '';

  Future<void> _assignManager({
    required DocumentSnapshot<Map<String, dynamic>> user,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> stores,
  }) async {
    final data = user.data() ?? <String, dynamic>{};

    if (stores.isEmpty) {
      _message('Create a dark store first.', error: true);
      return;
    }

    final nameController = TextEditingController(
      text: data['name']?.toString() ?? '',
    );

    String selectedStoreId = data['storeId']?.toString().trim() ?? '';
    if (!stores.any((store) => store.id == selectedStoreId)) {
      selectedStoreId = '';
    }

    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Assign Store Manager',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 420,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Text(
                        data['email']?.toString() ?? 'No email available',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Manager name',
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: Colors.green,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Enter manager name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedStoreId.isEmpty ? null : selectedStoreId,
                        decoration: InputDecoration(
                          labelText: 'Assigned store',
                          prefixIcon: const Icon(
                            Icons.store_outlined,
                            color: Colors.green,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        items: stores.map((store) {
                          final storeData = store.data();
                          final storeName =
                              storeData['name']?.toString() ?? 'Unnamed store';
                          final code = storeData['code']?.toString() ?? '';

                          return DropdownMenuItem<String>(
                            value: store.id,
                            child: Text(
                              code.isEmpty ? storeName : '$storeName • $code',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  selectedStoreId = value ?? '';
                                });
                              },
                        validator: (_) {
                          if (selectedStoreId.isEmpty) {
                            return 'Select a store';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'This will change this customer account to Store Manager and give it access only to the selected store.',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => saving = true);

                          try {
                            await _firestore
                                .collection('users')
                                .doc(user.id)
                                .set({
                                  'name': nameController.text.trim(),
                                  'role': 'storeManager',
                                  'storeId': selectedStoreId,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));

                            if (!mounted) return;
                            Navigator.pop(dialogContext, true);
                          } catch (e) {
                            if (!mounted) return;

                            setDialogState(() => saving = false);
                            _message(
                              'Could not assign manager: $e',
                              error: true,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('ASSIGN'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();

    if (saved == true && mounted) {
      _message('Store manager assigned successfully.');
    }
  }

  Future<void> _removeManager(
    DocumentSnapshot<Map<String, dynamic>> user,
  ) async {
    final data = user.data() ?? <String, dynamic>{};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Remove store manager?',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            '${data['email'] ?? 'This user'} will become a normal customer again.',
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
              ),
              child: const Text('REMOVE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('users').doc(user.id).set({
        'role': 'customer',
        'storeId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        _message('Store Manager access removed.');
      }
    } catch (e) {
      if (mounted) {
        _message('Could not remove manager access.', error: true);
      }
    }
  }

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
        ),
      );
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return true;

    final searchable = [
      data['name'],
      data['email'],
      data['phone'],
      data['storeId'],
    ].map((e) => e?.toString() ?? '').join(' ');

    return searchable.toLowerCase().contains(query);
  }

  String _userName(Map<String, dynamic> data) {
    final name = data['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;

    final email = data['email']?.toString().trim() ?? '';
    if (email.isNotEmpty) return email.split('@').first;

    return 'Customer';
  }

  Widget _customerCard({
    required DocumentSnapshot<Map<String, dynamic>> user,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> stores,
  }) {
    final data = user.data() ?? <String, dynamic>{};
    final email = data['email']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 5, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline_rounded, color: Colors.blue),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName(data),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                  ),
                ],
                const SizedBox(height: 5),
                const Text(
                  'CUSTOMER',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _assignManager(user: user, stores: stores),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: const Text(
              'ASSIGN',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _managerCard({
    required DocumentSnapshot<Map<String, dynamic>> user,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> stores,
    required Map<String, Map<String, dynamic>> storeMap,
  }) {
    final data = user.data() ?? <String, dynamic>{};
    final storeId = data['storeId']?.toString().trim() ?? '';
    final storeData = storeMap[storeId];
    final storeName = storeData?['name']?.toString() ?? 'Store not found';
    final email = data['email']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 5, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.manage_accounts_rounded,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName(data),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                  ),
                const SizedBox(height: 5),
                Text(
                  storeName,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reassign') {
                _assignManager(user: user, stores: stores);
              } else if (value == 'remove') {
                _removeManager(user);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reassign', child: Text('Reassign store')),
              PopupMenuItem(
                value: 'remove',
                child: Text(
                  'Remove manager',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
          'Store Managers',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, usersSnapshot) {
          if (usersSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (usersSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load users.\n${usersSnapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('stores').snapshots(),
            builder: (context, storesSnapshot) {
              if (storesSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.green),
                );
              }

              if (storesSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Unable to load stores.\n${storesSnapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }

              final users = usersSnapshot.data?.docs ?? [];
              final stores = storesSnapshot.data?.docs ?? [];

              final customers = users.where((user) {
                final role =
                    user.data()['role']?.toString().trim().toLowerCase() ??
                    'customer';

                return role == 'customer' && _matchesSearch(user.data());
              }).toList();

              final managers = users.where((user) {
                final role =
                    user.data()['role']?.toString().trim().toLowerCase() ?? '';

                return role == 'storemanager' && _matchesSearch(user.data());
              }).toList();

              final storeMap = <String, Map<String, dynamic>>{
                for (final store in stores) store.id: store.data(),
              };

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: TextField(
                      onChanged: (value) {
                        setState(() => _search = value);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search customers or managers',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Colors.green,
                        ),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  setState(() => _search = '');
                                },
                                icon: const Icon(Icons.close),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade100),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.manage_accounts_outlined,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${managers.length} managers assigned • ${customers.length} customers available',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 30),
                      children: [
                        if (customers.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 7),
                            child: Text(
                              'CUSTOMER ACCOUNTS',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .7,
                              ),
                            ),
                          ),
                          ...customers.map(
                            (user) => _customerCard(user: user, stores: stores),
                          ),
                        ] else
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'No customer accounts found.\nMake sure the test account has a document in the users collection with role = customer.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 14, 16, 7),
                          child: Text(
                            'CURRENT STORE MANAGERS',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .7,
                            ),
                          ),
                        ),
                        if (managers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'No Store Managers assigned yet.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          ...managers.map(
                            (user) => _managerCard(
                              user: user,
                              stores: stores,
                              storeMap: storeMap,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
