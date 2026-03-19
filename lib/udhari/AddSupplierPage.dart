// lib/AddSupplierPage.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test1/database_Module/ObjectBoxService.dart';
import 'package:test1/database_Module/supplier_database.dart';
import 'package:test1/utilities.dart';


class AddSupplierPage extends StatefulWidget {
  final Supplier? supplierToEdit;
  final int? editIndex;

  const AddSupplierPage({super.key, this.supplierToEdit, this.editIndex});

  @override
  State<AddSupplierPage> createState() => _AddSupplierPageState();
}

class _AddSupplierPageState extends State<AddSupplierPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _categoryController = TextEditingController();
  final _paymentTermsController = TextEditingController();

  bool get isEditing => widget.supplierToEdit != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.supplierToEdit!.supplierName;
      _mobileController.text = widget.supplierToEdit!.mobileNumber ?? '';
      _addressController.text = widget.supplierToEdit!.address ?? '';
      _gstController.text = widget.supplierToEdit!.gstNumber ?? '';
      _categoryController.text = widget.supplierToEdit!.category ?? '';
      _paymentTermsController.text = widget.supplierToEdit!.paymentTerms ?? '';
    }
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    final objectbox = Provider.of<ObjectBoxService>(context, listen: false);
    final box = objectbox.store.box<Supplier>();

    final supplier = Supplier(
      syid:ganarateID(), 
      supplierName: _nameController.text.trim(),
      mobileNumber: _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      gstNumber: _gstController.text.trim().isEmpty ? null : _gstController.text.trim(),
      category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      paymentTerms: _paymentTermsController.text.trim().isEmpty ? null : _paymentTermsController.text.trim(),
    );

    if (isEditing) {
      supplier.id = widget.supplierToEdit!.id;
    }

    await box.putAsync(supplier);
    
    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Supplier updated successfully!' : 'Supplier added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Supplier' : 'Add New Supplier'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Supplier Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter supplier name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gstController,
                decoration: const InputDecoration(
                  labelText: 'GST Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _paymentTermsController,
                decoration: const InputDecoration(
                  labelText: 'Payment Terms',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payment),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveSupplier,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isEditing ? 'Update Supplier' : 'Add Supplier'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _categoryController.dispose();
    _paymentTermsController.dispose();
    super.dispose();
  }
}