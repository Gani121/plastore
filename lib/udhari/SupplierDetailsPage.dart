// lib/SupplierDetailsPage.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:test1/database_Module/supplier_database.dart';

class SupplierDetailsPage extends StatelessWidget {
  final Supplier supplier;

  const SupplierDetailsPage({super.key, required this.supplier});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _sendSms(String phoneNumber) async {
    final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber);
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(supplier.supplierName),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pop(context, true); // Return with edit flag
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Supplier Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    _buildInfoRow('Name', supplier.supplierName),
                    if (supplier.mobileNumber != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow('Mobile', supplier.mobileNumber!),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _makePhoneCall(supplier.mobileNumber!),
                              icon: const Icon(Icons.call),
                              label: const Text('Call'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _sendSms(supplier.mobileNumber!),
                              icon: const Icon(Icons.message),
                              label: const Text('SMS'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (supplier.address != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow('Address', supplier.address!),
                    ],
                    if (supplier.gstNumber != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow('GST', supplier.gstNumber!),
                    ],
                    if (supplier.category != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow('Category', supplier.category!),
                    ],
                    if (supplier.paymentTerms != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow('Payment Terms', supplier.paymentTerms!),
                    ],
                    const SizedBox(height: 8),
                    _buildInfoRow('Added On', _formatDate(supplier.createdDate)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
}