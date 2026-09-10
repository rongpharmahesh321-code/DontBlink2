import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/store.dart';
import '../models/store_inventory.dart';
import '../services/store_service.dart';
import '../services/store_inventory_service.dart';
import '../widgets/cached_product_image.dart';

class AdminStoreInventoryScreen extends StatefulWidget {
  const AdminStoreInventoryScreen({super.key, this.initialStoreId});

  final String? initialStoreId;

  @override
  State<AdminStoreInventoryScreen> createState() =>
      _AdminStoreInventoryScreenState();
}

class _AdminStoreInventoryScreenState extends State<AdminStoreInventoryScreen> {
  final StoreService _storeService = StoreService();
  final StoreInventoryService _inventoryService = StoreInventoryService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _productsStream;
  Stream<List<StoreInventory>>? _inventoryStream;
  String? _inventoryStreamStoreId;

  String _search = '';
  String? _selectedStoreId;
  String _filter = 'All';

  Stream<List<StoreInventory>> _getInventoryStream(String storeId) {
    if (_inventoryStream == null || _inventoryStreamStoreId != storeId) {
      _inventoryStreamStoreId = storeId;
      _inventoryStream = _inventoryService.streamInventory(storeId);
    }
    return _inventoryStream!;
  }

  @override
  void initState() {
    super.initState();
    _selectedStoreId = widget.initialStoreId;
    _productsStream = _firestore.collection('products').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _string(
    Map<String, dynamic> data,
    String key, {
    String fallback = '',
  }) {
    final value = data[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  double _number(Map<String, dynamic> data, String key) {
    final value = data[key];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _stock(StoreInventory? inventory) {
    return inventory?.stock ?? 0;
  }

  bool _available(StoreInventory? inventory) {
    return inventory?.isAvailable ?? false;
  }

  double? _inventoryPrice(StoreInventory? inventory) {
    return inventory?.price;
  }

  // ==========================================================
  // INVENTORY EDITOR
  // ==========================================================
  //
  // IMPORTANT:
  // This uses a dedicated StatefulWidget inside showDialog.
  // It avoids the old showModalBottomSheet + StatefulBuilder +
  // MediaQuery dependency combination that was causing:
  //
  // '_dependents.isEmpty' is not true
  //
  // ==========================================================

  Future<void> _editInventory(
    Map<String, dynamic> product,
    StoreInventory? inventory,
  ) async {
    final productId = product['id']?.toString().trim() ?? '';
    final storeId = _selectedStoreId?.trim() ?? '';

    if (productId.isEmpty || storeId.isEmpty) {
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _InventoryEditorDialog(
          product: product,
          inventory: inventory,
          storeId: storeId,
          productId: productId,
          inventoryService: _inventoryService,
        );
      },
    );

    if (saved == true && mounted) {
      _message('Inventory updated.');
    }
  }

  Future<void> _removeInventory(Map<String, dynamic> product) async {
    final storeId = _selectedStoreId?.trim() ?? '';
    final productId = product['id']?.toString().trim() ?? '';

    if (storeId.isEmpty || productId.isEmpty) {
      return;
    }

    final name = _string(product, 'name', fallback: 'this product');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Remove from store?',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            '“$name” will no longer have a store inventory record. '
            'The global product will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
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

    if (confirmed != true) {
      return;
    }

    try {
      await _inventoryService.removeInventory(
        storeId: storeId,
        productId: productId,
      );

      if (mounted) {
        _message('Product removed from this store.');
      }
    } catch (e) {
      if (mounted) {
        _message('Could not remove inventory.', error: true);
      }
    }
  }

  // ==========================================================
  // PRODUCT CARD
  // ==========================================================

  Widget _productCard(Map<String, dynamic> product, StoreInventory? inventory) {
    final name = _string(product, 'name', fallback: 'Unnamed product');

    final imageUrl = _string(
      product,
      'imageUrl',
      fallback: _string(product, 'image'),
    );

    final category = _string(
      product,
      'category',
      fallback: _string(product, 'categoryName'),
    );

    final defaultPrice = _number(product, 'price');
    final storePrice = _inventoryPrice(inventory);
    final stock = _stock(inventory);
    final available = _available(inventory);
    final configured = inventory != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 5, 16, 7),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(13),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? CachedProductImage(
                    url: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.green,
                      ),
                    ),
                    errorWidget: const Icon(
                      Icons.image_outlined,
                      color: Colors.grey,
                    ),
                  )
                : const Icon(Icons.inventory_2_outlined, color: Colors.green),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (category.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 8),
                  ),
                ],
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      storePrice != null
                          ? '₹${storePrice.toStringAsFixed(0)}'
                          : defaultPrice > 0
                          ? '₹${defaultPrice.toStringAsFixed(0)}'
                          : 'Price not set',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: !configured
                            ? Colors.grey.shade100
                            : available && stock > 0
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        !configured
                            ? 'NOT ADDED'
                            : available && stock > 0
                            ? '$stock IN STOCK'
                            : 'OUT OF STOCK',
                        style: TextStyle(
                          color: !configured
                              ? Colors.grey
                              : available && stock > 0
                              ? Colors.green
                              : Colors.red,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        !configured
                            ? 'Not configured for this store'
                            : available
                            ? 'Available for sale'
                            : 'Hidden from customers',
                        style: TextStyle(
                          color: available && configured
                              ? Colors.grey.shade600
                              : Colors.red.shade600,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 32,
                      child: OutlinedButton(
                        onPressed: () => _editInventory(product, inventory),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: BorderSide(color: Colors.green.shade200),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text(
                          'EDIT',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    if (configured) ...[
                      const SizedBox(width: 5),
                      SizedBox(
                        height: 32,
                        child: IconButton(
                          tooltip: 'Remove from store',
                          padding: EdgeInsets.zero,
                          onPressed: () => _removeInventory(product),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
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
  // STORE SELECTOR
  // ==========================================================

  Widget _storeSelector(List<StoreModel> stores, String selectedStoreId) {
    final selected = stores.firstWhere(
      (store) => store.id == selectedStoreId,
      orElse: () => stores.first,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 7),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MANAGING STORE INVENTORY',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 7),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected.id,
              isExpanded: true,
              dropdownColor: Colors.white,
              iconEnabledColor: Colors.white,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
              items: stores.map((store) {
                return DropdownMenuItem<String>(
                  value: store.id,
                  child: Text(
                    '${store.name} • ${store.code}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null || value == _selectedStoreId) {
                  return;
                }

                setState(() {
                  _selectedStoreId = value;
                });
              },
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${selected.address} • '
            '${selected.serviceRadiusKm.toStringAsFixed(1)} km delivery radius',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 8),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SEARCH
  // ==========================================================

  Widget _searchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 7),
      child: Container(
        height: 49,
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
            hintText: 'Search products to manage stock',
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

  Widget _filters() {
    const values = [
      'All',
      'Configured',
      'Available',
      'Out of stock',
      'Not added',
    ];

    return SizedBox(
      height: 45,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final value = values[index];
          final selected = _filter == value;

          return ChoiceChip(
            selected: selected,
            label: Text(
              value,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            selectedColor: Colors.green,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? Colors.green : Colors.grey.shade200,
            ),
            onSelected: (_) {
              setState(() {
                _filter = value;
              });
            },
          );
        },
      ),
    );
  }

  // ==========================================================
  // PRODUCTS
  // ==========================================================

  Widget _buildProducts(String storeId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _productsStream,
      builder: (context, productSnapshot) {
        if (productSnapshot.connectionState == ConnectionState.waiting &&
            !productSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        if (productSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Text(
                'Could not load products.\n'
                '${productSnapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final productDocs = productSnapshot.data?.docs ?? [];

        final products = productDocs
            .map((doc) {
              return <String, dynamic>{...doc.data(), 'id': doc.id};
            })
            .where((product) {
              final query = _search.trim().toLowerCase();

              if (query.isEmpty) {
                return true;
              }

              final name = _string(product, 'name').toLowerCase();

              final category = _string(
                product,
                'category',
                fallback: _string(product, 'categoryName'),
              ).toLowerCase();

              return name.contains(query) || category.contains(query);
            })
            .toList();

        return StreamBuilder<List<StoreInventory>>(
          stream: _getInventoryStream(storeId),
          builder: (context, inventorySnapshot) {
            if (inventorySnapshot.connectionState == ConnectionState.waiting &&
                !inventorySnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.green),
              );
            }

            if (inventorySnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Text(
                    'Could not load store inventory.\n'
                    '${inventorySnapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            final inventory = inventorySnapshot.data ?? [];

            final inventoryMap = <String, StoreInventory>{
              for (final item in inventory) item.productId: item,
            };

            final visible = products.where((product) {
              final id = product['id']?.toString();

              if (id == null || id.isEmpty) {
                return false;
              }

              final item = inventoryMap[id];

              switch (_filter) {
                case 'Configured':
                  return item != null;

                case 'Available':
                  return item != null && item.isAvailable && item.stock > 0;

                case 'Out of stock':
                  return item != null && item.stock <= 0;

                case 'Not added':
                  return item == null;

                default:
                  return true;
              }
            }).toList();

            if (visible.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.green,
                        size: 60,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No products found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _search.trim().isNotEmpty
                            ? 'Try another product search.'
                            : 'No products match this inventory filter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              color: Colors.green,
              onRefresh: () async {
                await Future<void>.delayed(const Duration(milliseconds: 250));
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.only(top: 5, bottom: 100),
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final product = visible[index];
                  final id = product['id']?.toString() ?? '';

                  return _productCard(product, inventoryMap[id]);
                },
              ),
            );
          },
        );
      },
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
  // EMPTY
  // ==========================================================

  Widget _emptyStores() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store_outlined, color: Colors.green, size: 64),
            const SizedBox(height: 15),
            const Text(
              'No dark stores yet',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              'Create a dark store first, then you can manage '
              'its inventory here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
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
      backgroundColor: const Color(0xffF5F7F6),
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Store Inventory',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<List<StoreModel>>(
        stream: _storeService.getStores(),
        builder: (context, storeSnapshot) {
          if (storeSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (storeSnapshot.hasError) {
            return Center(
              child: Text(
                'Could not load stores.\n'
                '${storeSnapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final stores = storeSnapshot.data ?? <StoreModel>[];

          if (stores.isEmpty) {
            return _emptyStores();
          }

          // IMPORTANT:
          // Never mutate _selectedStoreId inside build().
          //
          // Calculate the valid ID locally and update state only
          // when absolutely necessary after the frame.
          final selectedExists = stores.any(
            (store) => store.id == _selectedStoreId,
          );

          final selectedStoreId = selectedExists
              ? _selectedStoreId!
              : stores.first.id;

          if (!selectedExists && _selectedStoreId != selectedStoreId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              if (_selectedStoreId != selectedStoreId) {
                setState(() {
                  _selectedStoreId = selectedStoreId;
                });
              }
            });
          }

          return Column(
            children: [
              _storeSelector(stores, selectedStoreId),
              _searchBox(),
              _filters(),
              const SizedBox(height: 2),
              Expanded(child: _buildProducts(selectedStoreId)),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// DEDICATED INVENTORY EDITOR DIALOG
// ============================================================

class _InventoryEditorDialog extends StatefulWidget {
  const _InventoryEditorDialog({
    required this.product,
    required this.inventory,
    required this.storeId,
    required this.productId,
    required this.inventoryService,
  });

  final Map<String, dynamic> product;
  final StoreInventory? inventory;
  final String storeId;
  final String productId;
  final StoreInventoryService inventoryService;

  @override
  State<_InventoryEditorDialog> createState() => _InventoryEditorDialogState();
}

class _InventoryEditorDialogState extends State<_InventoryEditorDialog> {
  late final TextEditingController _stockController;
  late final TextEditingController _priceController;

  late bool _available;

  bool _saving = false;

  String _text(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  @override
  void initState() {
    super.initState();

    _stockController = TextEditingController(
      text: '${widget.inventory?.stock ?? 0}',
    );

    final productPrice = _number(widget.product['price']);

    _priceController = TextEditingController(
      text: widget.inventory?.price != null
          ? widget.inventory!.price!.toStringAsFixed(2)
          : productPrice > 0
          ? productPrice.toStringAsFixed(2)
          : '',
    );

    _available = widget.inventory?.isAvailable ?? false;
  }

  @override
  void dispose() {
    _stockController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final stock = int.tryParse(_stockController.text.trim());

    if (stock == null || stock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid stock quantity.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final priceText = _priceController.text.trim();

    double? price;

    if (priceText.isNotEmpty) {
      price = double.tryParse(priceText);

      if (price == null || price < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid price.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.inventoryService.saveInventory(
        storeId: widget.storeId,
        productId: widget.productId,
        stock: stock,
        isAvailable: _available && stock > 0,
        price: price,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save inventory: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final productName = _text(widget.product['name'], 'Unnamed product');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
      contentPadding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
      actionsPadding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      title: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: Colors.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Store inventory',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: 'Stock quantity',
                hintText: '0',
                prefixIcon: const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.green,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: 'Store price',
                hintText: 'Optional',
                prefixIcon: const Icon(
                  Icons.currency_rupee_rounded,
                  color: Colors.green,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SwitchListTile.adaptive(
                value: _available,
                activeColor: Colors.green,
                title: const Text(
                  'Available for sale',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                ),
                subtitle: const Text(
                  'Turn this off to hide the product from this store.',
                  style: TextStyle(fontSize: 9),
                ),
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() {
                          _available = value;
                        });
                      },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'SAVE INVENTORY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
        ),
      ],
    );
  }
}
