import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart'; // 1. Import the package
import 'udharicustomer.dart';
import '../cartprovier/ObjectBoxService.dart';

class AddCustomerPage extends StatefulWidget {
  const AddCustomerPage({super.key});

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
  
  // 2. Add the function to pick a contact
  Future<void> _pickContact() async {
    // First, request permission
    if (await FlutterContacts.requestPermission()) {
      // If permission is granted, pick a contact
      Contact? contact = await FlutterContacts.openExternalPick();

      if (contact != null) {
        String phoneNumber = (contact.phones.isNotEmpty) ? contact.phones.first.number : '';
        // Update the text controllers with the contact's details
        setState(() {
          _nameController.text = contact.displayName;
          _phoneController.text = phoneNumber;
        });
      }
    } else {
        // Handle the case where permission is denied
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission to access contacts was denied.')),
        );
    }
  }


  void _saveCustomer() {
    if (_formKey.currentState!.validate()) {
      final newCustomer = udhariCustomer(
        name: _nameController.text,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text : '',
      );

      final store = Provider.of<ObjectBoxService>(context, listen: false).store;
      final box = store.box<udhariCustomer>();
      box.put(newCustomer);

      List<udhariCustomer> customername = box.getAll(); // Refresh the list
      print("All Customers: ${customername.map((c) => c.id).toList()}");

      Navigator.pop(context); // Go back to dashboard
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_nameController.text} added successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New Customer"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Manually add a new customer by filling the details below.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              // 3. Add the new button to select from contacts
              ElevatedButton.icon(
                onPressed: _pickContact,
                icon: const Icon(Icons.contacts),
                label: const Text("Select from Contacts"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  // Optional: style it differently from the save button
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _saveCustomer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Save Customer"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}