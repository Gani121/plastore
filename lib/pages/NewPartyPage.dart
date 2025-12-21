import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test1/database_Module/party_database.dart';
import 'package:test1/database_Module/ObjectBoxService.dart';
import 'package:objectbox/objectbox.dart';

// The Party model class is not shown here, assuming it's correctly defined in party_database.dart

class AddPartyPage extends StatefulWidget {
  final Parties? partyToEdit;
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
  
  // Changed visiting_day_controller to a String? variable for Dropdown compatibility
  String? visitingDay;

  late Store store; // Initialize later in initState

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
    // Initialize the store reference
    // Accessing provider in initState requires `listen: false`
    store = Provider.of<ObjectBoxService>(context, listen: false).store;

    // If we're editing, populate the fields with existing data
    if (widget.editIndex != null && widget.partyToEdit != null) {
      _loadPartyData(widget.editIndex!);
    }
  }

  // Dispose controllers to prevent memory leaks
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _dobController.dispose();
    super.dispose();
  }


  Future<void> _loadPartyData(int transactionId) async {
    final box12 = store.box<Parties>();
    // Note: ObjectBox IDs start from 1. widget.editIndex should be the ObjectBox ID (transactionId)
    final party = box12.get(transactionId);

    if (party == null) return;
    
    // Convert DateTime to String for DOB controller
    String dobText = party.bod != null ? "${party.bod!.day.toString().padLeft(2, '0')}-${party.bod!.month.toString().padLeft(2, '0')}-${party.bod!.year}" : "";

    _nameController.text = party.customername;
    _phoneController.text = party.mobilenumber;
    selectedCategory = party.category;
    visitingDay = party.visitingday; // Assign directly to the new variable
    _addressController.text = party.adreess ?? "";
    _gstController.text = party.gstno ?? '';
    billingTerm = party.billingterm;
    billingType = party.billingtype;
    _dobController.text = dobText;
    // sendWhatsApp = party.sendwhatsapp ?? false;
    // isTable = party.istable ?? false;

    setState(() {});
  }

  Future<void> savePartyToPrefs(int? transactionId) async {
    if (!_formKey.currentState!.validate()) return;

    final box12 = store.box<Parties>();
    
    // Parse DOB from controller text
    DateTime? parsedDob = _dobController.text.isNotEmpty 
        ? DateTime.tryParse(_dobController.text.split('-').reversed.join('-')) // Tries to parse DD-MM-YYYY as YYYY-MM-DD
        : DateTime.now(); // Default to now if empty/invalid

    if (transactionId == null) {
      // New party
      final party = Parties(
        customername: _nameController.text.trim(),
        mobilenumber: _phoneController.text.trim(),
        category: selectedCategory ?? '',
        visitingday: visitingDay, // Use the state variable
        adreess: _addressController.text.trim(),
        gstno: _gstController.text.trim(),
        billingterm: billingTerm,
        billingtype: billingType ?? "",
        bod: parsedDob,
        // sendwhatsapp: sendWhatsApp,
        // istable: isTable,
        isCompleted: false, // Initialize new field
        completionDate: null, // Initialize new field
      );

      box12.put(party);

    } else {
      final party = box12.get(transactionId);

      if (party == null) return;
      
      // *** FIX: Corrected missing assignments in the update block ***
      party.customername = _nameController.text.trim();
      party.mobilenumber = _phoneController.text.trim();
      party.category = selectedCategory ?? '';
      party.visitingday = visitingDay; // Use the state variable
      party.adreess = _addressController.text.trim();
      party.gstno = _gstController.text.trim();
      party.billingterm = billingTerm; // Corrected: was `party.billingterm; billingTerm;`
      party.billingtype = billingType ?? ""; // Corrected: was `party.billingtype; billingType;`
      party.bod = parsedDob; // Corrected: was `party.bod; DateTime...`
      // party.sendwhatsapp = sendWhatsApp;
      // party.istable = isTable;
      // Note: We don't update completion status here, as it's handled on the list page.
      // If you want to reset it on edit, you could add:
      // party.isCompleted = false; party.completionDate = null;

      box12.put(party);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Party details saved successfully!")),
    );

    Navigator.pop(context);
  }


  // NOTE: The deleteParty function uses SharedPreferences, but the save function uses ObjectBox. 
  // You should be consistent and update deleteParty to use ObjectBox as well.
  Future<void> deleteParty() async {
    if (widget.editIndex == null) return;
    
    final box12 = store.box<Parties>();
    // ObjectBox deleteById uses the ID (which is assumed to be widget.editIndex)
    bool success = box12.remove(widget.editIndex!);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Party deleted successfully!")),
      );
      Navigator.pop(context);
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting party or party not found!")),
      );
    }
  }


  Widget _buildTextField(String label, TextEditingController controller,
      [IconData? icon,
      TextInputType inputType = TextInputType.text,
      bool isRequired = true]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: isRequired ? "$label *" : label,
          suffixIcon: icon != null ? Icon(icon) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: isRequired
            ? (value) =>
                value == null || value.isEmpty ? "Enter $label" : null
            : null,
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> options,
      Function(String?) onChanged, String? currentValue,
      {bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        decoration: InputDecoration(
          labelText: isRequired ? "$label *" : label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        // All items must have unique, non-null values
        items: options.map((opt) => DropdownMenuItem<String>(value: opt, child: Text(opt))).toList(),
        onChanged: onChanged,
        validator: isRequired ? (value) => value == null || value!.isEmpty ? "Select $label" : null : null,
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    // Initial date should be the date in the controller or today
    DateTime initialDate = _dobController.text.isNotEmpty 
        ? DateTime.tryParse(_dobController.text.split('-').reversed.join('-')) ?? DateTime.now()
        : DateTime.now();
        
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? id = widget.editIndex;
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
                          deleteParty(); // Now uses ObjectBox delete
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
              _buildTextField("Customer/Supplier Name", _nameController, Icons.person, TextInputType.text, true),
              _buildTextField("Phone Number", _phoneController, Icons.phone, TextInputType.phone, true),
              _buildDropdown("Select Party Category", ["Retail", "Wholesale"],
                  (val) => setState(() => selectedCategory = val), selectedCategory, isRequired: false),
              _buildTextField("Billing Address", _addressController, Icons.home, TextInputType.text, false),
              _buildTextField("GST Number", _gstController, Icons.business, TextInputType.text, false),
              _buildDropdown("Billing Term", ["7 Days", "15 Days", "30 Days"],
                  (val) => setState(() => billingTerm = val), billingTerm, isRequired: false),
              _buildDropdown("Billing Type", ["REGULAR", "AC", "Non-Ac", "online-sale", "online Delivery Price (parcel)"],
                  (val) => setState(() => billingType = val), billingType, isRequired: true),
              
              // *** FIXED DROPDOWN IMPLEMENTATION ***
              _buildDropdown(
                "Visiting Day",
                ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday", "No Fixed Day"],
                (val) => setState(() => visitingDay = val), // Update the state variable
                visitingDay, // Use the state variable as the value
                isRequired: false,
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextFormField(
                  controller: _dobController,
                  readOnly: true, // Makes the field not editable
                  onTap: () => _selectDate(context), // Shows date picker on tap
                  decoration: InputDecoration(
                    labelText: "Date of Birth",
                    suffixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),

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
                onPressed: () => savePartyToPrefs(id),
                icon: Icon(Icons.save),
                label: Text(widget.editIndex == null ? "Save Party" : "Update Party"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}