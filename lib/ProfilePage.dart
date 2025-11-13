import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _image;
  final picker = ImagePicker();

  // Dropdown
  String selectedIndustry = '';
  bool _showBusinessDetails = false;
  bool _showOnlinePaymentDetails = false;

  // Controllers for text fields
  final businessNameController = TextEditingController();
  final contactNameController = TextEditingController();
  final contactPhoneController = TextEditingController();
  final contactEmailController = TextEditingController();
  final businessAddressController = TextEditingController();
  final postalCodeController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  final gstController = TextEditingController();
  final fssaiController = TextEditingController();
  final licenseController = TextEditingController();
  final panController = TextEditingController();
  final upiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _getImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('imagePath', _image?.path ?? '');
    await prefs.setString('industry', selectedIndustry);
    await prefs.setString('businessName', businessNameController.text);
    await prefs.setString('contactName', contactNameController.text);
    await prefs.setString('contactPhone', contactPhoneController.text);
    await prefs.setString('contactEmail', contactEmailController.text);
    await prefs.setString('businessAddress', businessAddressController.text);
    await prefs.setString('postalCode', postalCodeController.text);
    await prefs.setString('city', cityController.text);
    await prefs.setString('state', stateController.text);
    await prefs.setString('gst', gstController.text);
    await prefs.setString('fssai', fssaiController.text);
    await prefs.setString('license', licenseController.text);
    await prefs.setString('pan', panController.text);
    await prefs.setString('upi', upiController.text);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved successfully!')),
    );
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      final imagePath = prefs.getString('imagePath') ?? '';
      if (imagePath.isNotEmpty) _image = File(imagePath);

      selectedIndustry = prefs.getString('industry') ?? '';
      businessNameController.text = prefs.getString('businessName') ?? '';
      contactNameController.text = prefs.getString('contactName') ?? '';
      contactPhoneController.text = prefs.getString('contactPhone') ?? '';
      contactEmailController.text = prefs.getString('contactEmail') ?? '';
      businessAddressController.text = prefs.getString('businessAddress') ?? '';
      postalCodeController.text = prefs.getString('postalCode') ?? '';
      cityController.text = prefs.getString('city') ?? '';
      stateController.text = prefs.getString('state') ?? '';
      gstController.text = prefs.getString('gst') ?? '';
      fssaiController.text = prefs.getString('fssai') ?? '';
      licenseController.text = prefs.getString('license') ?? '';
      panController.text = prefs.getString('pan') ?? '';
      upiController.text = prefs.getString('upi') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [Text("Profile", style: TextStyle(fontSize: 20))],
        ),
        backgroundColor: const Color(0xFF6A48FF),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Picture
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _image != null
                            ? FileImage(_image!)
                            : null,
                        backgroundColor: Colors.grey[300],
                        child: _image == null
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white70,
                              )
                            : null,
                      ),
                      // Positioned(
                      //   right: 0,
                      //   top: 0,
                      //   child: CircleAvatar(
                      //     radius: 12,
                      //     backgroundColor: Colors.red,
                      //     child: const Icon(
                      //       Icons.notifications,
                      //       size: 14,
                      //       color: Colors.white,
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Profile",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: _getImage,
                    child: const Text(
                      "Change",
                      style: TextStyle(color: Colors.deepPurple),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            // const Text(
            //   "Parking Ticket",
            //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            // ),

            const SizedBox(height: 20),

            // Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "Select Industry",
                border: OutlineInputBorder(),
              ),
              value: selectedIndustry.isEmpty ? null : selectedIndustry,
              items: ['Hotel', 'Restaurant', 'Retail']
                  .map(
                    (industry) => DropdownMenuItem(
                      value: industry,
                      child: Text(industry),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedIndustry = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Input fields
            _buildTextField("Business Name", businessNameController, Icons.mic),
            _buildTextField(
              "Contact Person Name",
              contactNameController,
              Icons.mic,
            ),
            // _buildTextField("Contact Person Phone", contactPhoneController),
            TextFormField(
              controller: contactPhoneController,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: "Contact Person Phone",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            // _buildTextField("Contact Person Email", contactEmailController),
            TextFormField(
              controller: contactEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Contact Person Email",
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty && !value.contains('@')) {
                  return "Enter a valid email";
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Panels
            ExpansionPanelList(
              expansionCallback: (int index, bool isExpanded) {
                setState(() {
                  if (index == 0) _showBusinessDetails = !_showBusinessDetails;
                  if (index == 1) {
                    _showOnlinePaymentDetails = !_showOnlinePaymentDetails;
                  }
                });
              },
              expandedHeaderPadding: EdgeInsets.zero,
              elevation: 1,
              children: [
                ExpansionPanel(
                  isExpanded: _showBusinessDetails,
                  headerBuilder: (_, __) => const ListTile(
                    title: Text(
                      "BUSINESS DETAILS",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  body: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        _buildTextField(
                          "Business Address",
                          businessAddressController,
                        ),
                        // _buildTextField("Postal Code", postalCodeController),
                        // _buildTextField("City", cityController),
                        // _buildTextField("State", stateController),
                        _buildTextField("GST Number", gstController),
                        _buildTextField("FSSAI Number", fssaiController),
                        _buildTextField("License Number", licenseController),
                        _buildTextField("PAN Number", panController),
                      ],
                    ),
                  ),
                ),
                ExpansionPanel(
                  isExpanded: _showOnlinePaymentDetails,
                  headerBuilder: (_, __) => ListTile(
                    title: Text(
                      "ONLINE PAYMENT DETAILS",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                  body: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: _buildTextField("UPI ID", upiController),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: ElevatedButton(
          onPressed: _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text("SAVE", style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold,  // Makes text bold
                            color: Colors.white,)),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, [
    IconData? suffixIcon,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
