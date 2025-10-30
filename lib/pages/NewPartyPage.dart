import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddPartyPage extends StatefulWidget {
  final Party? partyToEdit;
  final int? editIndex;

  const AddPartyPage({super.key, this.partyToEdit, this.editIndex});


  @override
  State<AddPartyPage> createState() => _AddPartyPageState();
}

class _AddPartyPageState extends State<AddPartyPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _dobController = TextEditingController();

  // Dropdown selections
  String? selectedCategory;
  String? billingTerm;
  String? billingType;

  // Switches
  bool sendWhatsApp = false;
  bool isTable = false;

  @override
  void initState() {
    super.initState();
    
    // If we're editing, populate the fields with existing data
    if (widget.editIndex  != null) {
      // _nameController.text = widget.partyToEdit!.name;
      // _phoneController.text = widget.partyToEdit!.phoneNumber;
      // selectedCategory = widget.partyToEdit!.category;
      // _addressController.text = widget.partyToEdit!.billingAddress;
      // _gstController.text = widget.partyToEdit!.gstNumber ?? '';
      // billingTerm = widget.partyToEdit!.billingTerm;
      // billingType = widget.partyToEdit!.billingType;
      // _dobController.text = widget.partyToEdit!.dateOfBirth ?? '';
      // sendWhatsApp = widget.partyToEdit!.sendWhatsAppAlerts;
      // isTable = widget.partyToEdit!.isTable;

       _loadPartyData();
    }

    
  }


  Future<void> _loadPartyData() async {
  final prefs = await SharedPreferences.getInstance();
  final partiesJson = prefs.getStringList('parties') ?? [];
  
  if (widget.editIndex! < partiesJson.length) {
    final party = Party.fromJson(jsonDecode(partiesJson[widget.editIndex!]));
    
         _nameController.text = party.name;
        _phoneController.text =party.phoneNumber;
        selectedCategory = party.category;
        _addressController.text = party.billingAddress;
        _gstController.text = party.gstNumber ?? '';
        billingTerm = party.billingTerm;
        billingType = party.billingType;
        _dobController.text = party.dateOfBirth ?? '';
        sendWhatsApp = party.sendWhatsAppAlerts;
        isTable = party.isTable;

  }
}

Future<void> savePartyToPrefs() async {
  if (!_formKey.currentState!.validate()) return;

  final party = Party(
    name: _nameController.text.trim(),
    phoneNumber: _phoneController.text.trim(),
    category: selectedCategory ?? '',
    billingAddress: _addressController.text.trim(),
    gstNumber: _gstController.text.trim(),
    billingTerm: billingTerm,
    billingType: billingType,
    dateOfBirth: _dobController.text.trim(),
    sendWhatsAppAlerts: sendWhatsApp,
    isTable: isTable,
  );

  final prefs = await SharedPreferences.getInstance();
  final partyJson = jsonEncode(party.toJson());

  List<String> existing = prefs.getStringList('parties') ?? [];
  
  if (widget.editIndex != null) {
    // Update existing party
    existing[widget.editIndex!] = partyJson;
  } else {
    // Add new party
    existing.add(partyJson);
  }
  
  await prefs.setStringList('parties', existing);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("Party details saved successfully!")),
  );

  Navigator.pop(context);
}
 Future<void> deleteParty() async {
  debugPrint('=== DELETE FUNCTION STARTED ==='); // New debug line
  
  if (widget.editIndex == null) {
    debugPrint('Edit index is null - aborting'); // New debug line
    return;
  }

  debugPrint('Attempting to delete party at index: ${widget.editIndex}');
  
  try {
    final prefs = await SharedPreferences.getInstance();
    debugPrint('SharedPreferences instance obtained'); // New debug line
    
    List<String> existing = prefs.getStringList('parties') ?? [];
    debugPrint('Current parties list length: ${existing.length}');
    
    if (widget.editIndex! < existing.length) {
      debugPrint('Index is valid - proceeding with deletion'); // New debug line
      existing.removeAt(widget.editIndex!);
      final result = await prefs.setStringList('parties', existing);
      
      debugPrint('Delete operation result: $result');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Party deleted successfully!")),
      );
      
      Navigator.pop(context);
    } else {
      debugPrint('Index out of bounds - index: ${widget.editIndex}, length: ${existing.length}');
    }
  } catch (e) {
    debugPrint('Error during deletion: $e'); // New error handling
  }
}

  Widget _buildTextField(String label, TextEditingController controller,
      [IconData? icon, TextInputType inputType = TextInputType.text]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: icon != null ? Icon(icon) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: (value) =>
            value == null || value.isEmpty ? "Enter $label" : null,
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> options, Function(String?) onChanged, String? currentValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: options
            .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
            .toList(),
        onChanged: onChanged,
        validator: (value) =>
            value == null || value.isEmpty ? "Select $label" : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.partyToEdit == null ? "Add Party" : "Edit Party"),
        actions: [
          if (widget.partyToEdit != null)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text("Delete Party"),
                    content: Text("Are you sure you want to delete this party?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          deleteParty();
                        },
                        child: Text("Delete", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField("Customer/Supplier Name", _nameController, Icons.person),
              _buildTextField("Phone Number", _phoneController, Icons.phone, TextInputType.phone),
              _buildDropdown("Select Party Category", ["Retail", "Wholesale"],
                  (val) => setState(() => selectedCategory = val), selectedCategory),
              _buildTextField("Billing Address", _addressController, Icons.home),
              _buildTextField("GST Number", _gstController, Icons.business),
              _buildDropdown("Billing Term", ["7 Days", "15 Days", "30 Days"],
                  (val) => setState(() => billingTerm = val), billingTerm),
              _buildDropdown("Billing Type", ["REGULAR", "AC","Non-Ac","online-sale","online Delivery Price (parcel)"],
                  (val) => setState(() => billingType = val), billingType),
              _buildTextField("Date of Birth", _dobController, Icons.calendar_today),



              // Switches
              SwitchListTile(
                value: sendWhatsApp,
                onChanged: (val) => setState(() => sendWhatsApp = val),
                title: Text("Send WhatsApp Alerts"),
              ),
              SwitchListTile(
                value: isTable,
                onChanged: (val) => setState(() => isTable = val),
                title: Text("Is Table"),
              ),

              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: savePartyToPrefs,
                icon: Icon(Icons.save),
                label: Text(widget.partyToEdit == null ? "Save Party" : "Update Party"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Party model with toString override
class Party {
  final String name;
  final String phoneNumber;
  final String category;
  final String billingAddress;
  final String? gstNumber;
  final String? billingTerm;
  final String? billingType;
  final String? dateOfBirth;
  final bool sendWhatsAppAlerts;
  final bool isTable;

  Party({
    required this.name,
    required this.phoneNumber,
    required this.category,
    required this.billingAddress,
    this.gstNumber,
    this.billingTerm,
    this.billingType,
    this.dateOfBirth,
    this.sendWhatsAppAlerts = false,
    this.isTable = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phoneNumber,
        'category': category,
        'billingAddress': billingAddress,
        'gstNumber': gstNumber,
        'billingTerm': billingTerm,
        'billingType': billingType,
        'dateOfBirth': dateOfBirth,
        'sendWhatsAppAlerts': sendWhatsAppAlerts,
        'isTable': isTable,
      };

  factory Party.fromJson(Map<String, dynamic> json) => Party(
        name: json['name'],
        phoneNumber: json['phone'],
        category: json['category'],
        billingAddress: json['billingAddress'],
        gstNumber: json['gstNumber'],
        billingTerm: json['billingTerm'],
        billingType: json['billingType'],
        dateOfBirth: json['dateOfBirth'],
        sendWhatsAppAlerts: json['sendWhatsAppAlerts'] ?? false,
        isTable: json['isTable'] ?? false,
      );

  @override
  String toString() {
    return 'Party(name: $name, phone: $phoneNumber, category: $category, address: $billingAddress, gst: $gstNumber, term: $billingTerm, type: $billingType, dob: $dateOfBirth, whatsapp: $sendWhatsAppAlerts, table: $isTable)';
  }
}