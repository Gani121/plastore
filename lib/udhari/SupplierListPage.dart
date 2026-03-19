// lib/SupplierListPage.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test1/database_Module/ObjectBoxService.dart';
import 'package:test1/database_Module/supplier_database.dart';
import 'package:test1/udhari/AddSupplierPage.dart';
import 'package:test1/udhari/SupplierDetailsPage.dart';
import '../objectbox.g.dart';

class SupplierListPage extends StatefulWidget {
  const SupplierListPage({super.key});

  @override
  State<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends State<SupplierListPage> {
  List<Supplier> _suppliers = [];
  List<Supplier> _filteredSuppliers = [];
  final TextEditingController _searchController = TextEditingController();
  late Store _store;

  @override
  void initState() {
    super.initState();
    _store = Provider.of<ObjectBoxService>(context, listen: false).store;
    _loadSuppliers();
    _searchController.addListener(_filterSuppliers);
  }

  Future<void> _loadSuppliers() async {
    final box = _store.box<Supplier>();
    final suppliers = box.getAll();
    suppliers.sort((a, b) => b.syid.compareTo(a.syid));
    setState(() {
      _suppliers = suppliers;
      _filteredSuppliers = suppliers;
    });
  }

  void _filterSuppliers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSuppliers = List.from(_suppliers);
      } else {
        _filteredSuppliers = _suppliers.where((supplier) {
          return supplier.supplierName.toLowerCase().contains(query) ||
              (supplier.mobileNumber?.toLowerCase().contains(query) ?? false) ||
              (supplier.category?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text('Are you sure you want to delete "${supplier.supplierName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final box = _store.box<Supplier>();
              box.remove(supplier.id);
              await _loadSuppliers();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${supplier.supplierName} deleted')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   // title: const Text('Suppliers'),
      //   backgroundColor: Colors.orange.shade800,
      //   foregroundColor: Colors.white,
      //   bottom: PreferredSize(
      //     preferredSize: const Size.fromHeight(60),
      //     child: Padding(
      //       padding: const EdgeInsets.all(8.0),
      //       child: TextField(
      //         controller: _searchController,
      //         decoration: InputDecoration(
      //           hintText: 'Search suppliers...',
      //           hintStyle: const TextStyle(color: Colors.white70),
      //           prefixIcon: const Icon(Icons.search, color: Colors.white),
      //           border: OutlineInputBorder(
      //             borderRadius: BorderRadius.circular(8),
      //             borderSide: BorderSide.none,
      //           ),
      //           filled: true,
      //           fillColor: Colors.white.withOpacity(0.2),
      //         ),
      //         style: const TextStyle(color: Colors.white),
      //       ),
      //     ),
      //   ),
      // ),
      body: _filteredSuppliers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    _suppliers.isEmpty
                        ? 'No suppliers added yet'
                        : 'No matching suppliers found',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _filteredSuppliers.length,
              itemBuilder: (context, index) {
                final supplier = _filteredSuppliers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: Text(
                        supplier.supplierName[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      supplier.supplierName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (supplier.mobileNumber != null)
                          Text(supplier.mobileNumber!),
                        if (supplier.category != null)
                          Text('Category: ${supplier.category}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddSupplierPage(
                                  supplierToEdit: supplier,
                                  editIndex: supplier.id,
                                ),
                              ),
                            );
                            if (result == true) {
                              _loadSuppliers();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteSupplier(supplier),
                        ),
                      ],
                    ),
                    onTap: () async {
                      final shouldRefresh = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SupplierDetailsPage(supplier: supplier),
                        ),
                      );
                      if (shouldRefresh == true) {
                        _loadSuppliers();
                      }
                    },
                  ),
                );
              },
            ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () async {
      //     final result = await Navigator.push(
      //       context,
      //       MaterialPageRoute(builder: (context) => const AddSupplierPage()),
      //     );
      //     if (result == true) {
      //       _loadSuppliers();
      //     }
      //   },
      //   backgroundColor: Colors.orange.shade800,
      //   child: const Icon(Icons.add, color: Colors.white),
      // ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}