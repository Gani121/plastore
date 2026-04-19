// lib/quotation/quotation_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:test1/database_Module/ObjectBoxService.dart';
import 'package:test1/utilities.dart';
import '../objectbox.g.dart';
import 'quotation_model.dart';
import 'package:test1/database_Module/quotation_database.dart';
import 'add_edit_quotation_page.dart';
import 'quotation_pdf.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'package:test1/theme_setting/theme_provider.dart';


class QuotationPage extends StatefulWidget {
  const QuotationPage({super.key});

  @override
  State<QuotationPage> createState() => _QuotationPageState();
}

class _QuotationPageState extends State<QuotationPage> {
  late Store _store;
  List<Quotation> _quotations = [];
  List<Quotation> _filteredQuotations = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  QuotationStatus? _selectedStatus;
  String _sortBy = 'date'; // 'date', 'party', 'amount'
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _store = Provider.of<ObjectBoxService>(context, listen: false).store;
    _loadQuotations();
    _searchController.addListener(_filterQuotations);
  }

  Future<void> _loadQuotations() async {
    setState(() => _isLoading = true);
    try {
      final box = _store.box<QuotationEntity>();
      final entities = box.getAll();
      final quotations = <Quotation>[];

      for (final entity in entities) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(entity.quotationData));
          quotations.add(Quotation.fromMap(map));
        } catch (e) {
          print_log('Error parsing quotation: $e');
        }
      }

      setState(() {
        _quotations = quotations;
        _applyFiltersAndSort();
      });
    } catch (e) {
      print_log('Error loading quotations: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterQuotations() {
    _applyFiltersAndSort();
  }

  void _applyFiltersAndSort() {
    var filtered = List<Quotation>.from(_quotations);

    // Apply status filter
    if (_selectedStatus != null) {
      filtered = filtered.where((q) => q.status == _selectedStatus).toList();
    }

    // Apply search
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((q) {
        return q.quotationNumber.toLowerCase().contains(query) ||
               q.partyName.toLowerCase().contains(query) ||
               (q.eventName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'date':
        filtered.sort((a, b) => _sortAscending
            ? a.quotationDate.compareTo(b.quotationDate)
            : b.quotationDate.compareTo(a.quotationDate));
        break;
      case 'party':
        filtered.sort((a, b) => _sortAscending
            ? a.partyName.compareTo(b.partyName)
            : b.partyName.compareTo(a.partyName));
        break;
      case 'amount':
        filtered.sort((a, b) => _sortAscending
            ? a.totalAmount.compareTo(b.totalAmount)
            : b.totalAmount.compareTo(a.totalAmount));
        break;
      case 'event':
        filtered.sort((a, b) {
          if (a.eventDate == null && b.eventDate == null) return 0;
          if (a.eventDate == null) return 1;
          if (b.eventDate == null) return -1;
          return _sortAscending
              ? a.eventDate!.compareTo(b.eventDate!)
              : b.eventDate!.compareTo(a.eventDate!);
        });
        break;
    }

    setState(() {
      _filteredQuotations = filtered;
    });
  }

  Future<void> _deleteQuotation(Quotation quotation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: Text('Delete quotation ${quotation.quotationNumber} for ${quotation.partyName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final box = _store.box<QuotationEntity>();
        final entities = box.getAll();
        
        for (final entity in entities) {
          final map = jsonDecode(entity.quotationData);
          if (map['id'] == quotation.id) {
            box.remove(entity.id);
            if (quotation.pdfPath != null) {
              final file = File(quotation.pdfPath!);
              if (await file.exists()) await file.delete();
            }
            break;
          }
        }
        
        await _loadQuotations();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Quotation ${quotation.quotationNumber} deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print_log('Error deleting quotation: $e');
      }
    }
  }

  Future<void> _saveAndShareQuotation(Quotation quotation) async {
  try {
    // Show options dialog
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quotation Actions'),
        content: const Text('What would you like to do with this quotation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'share'),
            child: const Text('Share'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save to Device'),
          ),
        ],
      ),
    );
    
    if (action == null) return;
    
    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processing PDF...'),
        ),
      );
    }
    
    // Generate PDF
    final pdf = await QuotationPDF.generate(quotation);
    final bytes = await pdf.save();
    
    // Handle different actions
    if (action == 'share') {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'Quotation_${quotation.quotationNumber}.pdf';
      final filePath = '${tempDir.path}/$fileName';
      
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      final p = ShareParams(files: [XFile(filePath)],
      text: 'Quotation: ${quotation.quotationNumber}\n'
              'Party: ${quotation.partyName}\n'
              'Date: ${quotation.formattedQuotationDate}\n'
              'Total: ${quotation.formattedTotal}',
      subject: 'Quotation ${quotation.quotationNumber}',
      title: fileName,
      );
      await SharePlus.instance.share(p);
    }
    
    if (action == 'save') {
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: 'Quotation_${quotation.quotationNumber}',
      );
    }
  } catch (e) {
    print_log('Error processing quotation: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


  Future<void> _shareQuotation(Quotation quotation) async {
    try {
      // final pdfFile = await QuotationPDF.generate(quotation);
      // final tempDir = await getTemporaryDirectory();
      // final filePath = '${tempDir.path}/Quotation_${quotation.quotationNumber}.pdf';
      // await pdfFile.saveTo(filePath);
      

      
    final pdf = await QuotationPDF.generate(quotation);
    final bytes = await pdf.save();
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/Quotation_${quotation.quotationNumber}.pdf';

    final file = File(filePath);
    await file.writeAsBytes(bytes);
  
    await SharePlus.instance.share(
      ShareParams(
        text: 'Purchase Order: ${quotation.id}',
        subject: 'Purchase Order PDF',
        files: [XFile(filePath)],
      ),
    );
    } catch (e) {
      print_log('Error sharing quotation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotations'),
        backgroundColor: themeProvider.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Filter by status
          PopupMenuButton<QuotationStatus>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              setState(() {
                _selectedStatus = _selectedStatus == status ? null : status;
                _applyFiltersAndSort();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Quotations'),
              ),
              ...QuotationStatus.values.map((status) => PopupMenuItem(
                value: status,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getStatusColor(status),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_getStatusText(status)),
                  ],
                ),
              )),
            ],
          ),
          
          // Sort options
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                if (_sortBy == value) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = value;
                  _sortAscending = value == 'date' ? false : true;
                }
                _applyFiltersAndSort();
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(_sortBy == 'date' 
                        ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                        : Icons.calendar_today),
                    const SizedBox(width: 8),
                    Text('Date ${_sortBy == 'date' ? (_sortAscending ? '↑' : '↓') : ''}'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'event',
                child: Row(
                  children: [
                    Icon(_sortBy == 'event'
                        ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                        : Icons.event),
                    const SizedBox(width: 8),
                    Text('Event Date ${_sortBy == 'event' ? (_sortAscending ? '↑' : '↓') : ''}'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'party',
                child: Row(
                  children: [
                    Icon(_sortBy == 'party'
                        ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                        : Icons.person),
                    const SizedBox(width: 8),
                    Text('Party ${_sortBy == 'party' ? (_sortAscending ? '↑' : '↓') : ''}'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'amount',
                child: Row(
                  children: [
                    Icon(_sortBy == 'amount'
                        ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                        : Icons.attach_money),
                    const SizedBox(width: 8),
                    Text('Amount ${_sortBy == 'amount' ? (_sortAscending ? '↑' : '↓') : ''}'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by number, party, event...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredQuotations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _quotations.isEmpty
                            ? 'No quotations yet'
                            : 'No matching quotations found',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      if (_quotations.isEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _navigateToAddQuotation(),
                          icon: const Icon(Icons.add),
                          label: const Text('Create First Quotation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade800,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _filteredQuotations.length,
                  itemBuilder: (context, index) {
                    final quotation = _filteredQuotations[index];
                    return _buildQuotationCard(quotation);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddQuotation,
        backgroundColor: themeProvider.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _copyQuotation(Quotation originalQuotation) async {
  // Show options dialog for copy
  final options = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Copy Quotation Options'),
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          bool keepEventDate = true;
          bool keepSignature = true;
          bool resetStatus = true;
          
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('Keep Event Date'),
                value: keepEventDate,
                onChanged: (value) {
                  setDialogState(() {
                    keepEventDate = value ?? true;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Keep Signature'),
                value: keepSignature,
                onChanged: (value) {
                  setDialogState(() {
                    keepSignature = value ?? true;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Reset Status to Draft'),
                value: resetStatus,
                onChanged: (value) {
                  setDialogState(() {
                    resetStatus = value ?? true;
                  });
                },
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'keepEventDate': true,
            'keepSignature': true,
            'resetStatus': true,
          }),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade800,
          ),
          child: const Text('Copy'),
        ),
      ],
    ),
  );

  if (options == null) return;

  setState(() => _isLoading = true);

  try {
    // Generate new quotation number
    final prefs = await SharedPreferences.getInstance();
    int counter = prefs.getInt('quotation_counter') ?? 1000;
    counter++;
    await prefs.setInt('quotation_counter', counter);
    final newQuotationNumber = 'Q-${DateFormat('yyyyMM').format(DateTime.now())}-$counter';
    final int _syid = ganarateID();

    // Create copy based on options
    final copiedQuotation = Quotation(
      syid: _syid,
      synced: false,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      quotationNumber: newQuotationNumber,
      quotationDate: DateTime.now(),
      validUntil: DateTime.now().add(const Duration(days: 15)),
      partyId: originalQuotation.partyId,
      partyName: originalQuotation.partyName,
      partyMobile: originalQuotation.partyMobile,
      partyEmail: originalQuotation.partyEmail,
      partyAddress: originalQuotation.partyAddress,
      partyGst: originalQuotation.partyGst,
      eventName: originalQuotation.eventName,
      eventDate: options['keepEventDate'] ? originalQuotation.eventDate : null,
      eventVenue: originalQuotation.eventVenue,
      expectedGuests: originalQuotation.expectedGuests,
      plates: List.from(originalQuotation.plates),
      banquetItems: List.from(originalQuotation.banquetItems),
      additionalItems: List.from(originalQuotation.additionalItems),
      platesSubtotal: originalQuotation.platesSubtotal,
      banquetSubtotal: originalQuotation.banquetSubtotal,
      additionalSubtotal: originalQuotation.additionalSubtotal,
      discountAmount: originalQuotation.discountAmount,
      taxAmount: originalQuotation.taxAmount,
      totalAmount: originalQuotation.totalAmount,
      serviceCharge: originalQuotation.serviceCharge,
      packagingCharge: originalQuotation.packagingCharge,
      deliveryCharge: originalQuotation.deliveryCharge,
      status: options['resetStatus'] ? QuotationStatus.draft : originalQuotation.status,
      termsAndConditions: originalQuotation.termsAndConditions,
      cancellationPolicy: originalQuotation.cancellationPolicy,
      paymentTerms: originalQuotation.paymentTerms,
      specialInstructions: originalQuotation.specialInstructions,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'current_user',
      pdfPath: null,
      signaturePath: options['keepSignature'] ? originalQuotation.signaturePath : null,
    );

    // Save to database
    final box = _store.box<QuotationEntity>();
    final entity = QuotationEntity(
      syid: _syid,
      quotationData: jsonEncode(copiedQuotation.toMap()),
      signaturePath: copiedQuotation.signaturePath,
      quotationNumber: copiedQuotation.quotationNumber,
      partyName: copiedQuotation.partyName,
      statusIndex: copiedQuotation.status.index,
      quotationDate: copiedQuotation.quotationDate,
      eventDate: copiedQuotation.eventDate,
    );
    
    await box.put(entity);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quotation copied successfully: ${copiedQuotation.quotationNumber}'),
          backgroundColor: Colors.green,
        ),
      );
      _loadQuotations();
    }
  } catch (e) {
    print_log('Error copying quotation: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error copying quotation: $e'), backgroundColor: Colors.red),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  Widget _buildQuotationCard(Quotation quotation) {
    final isExpired = quotation.validUntil != null && 
                      quotation.validUntil!.isBefore(DateTime.now()) &&
                      quotation.status == QuotationStatus.sent;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isExpired ? BorderSide(color: Colors.orange.shade400) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _navigateToViewQuotation(quotation),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: quotation.statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getStatusIcon(quotation.status),
                            color: quotation.statusColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quotation.quotationNumber,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                quotation.formattedQuotationDate,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: quotation.statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      quotation.statusText,
                      style: TextStyle(
                        color: quotation.statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Party info
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      quotation.partyName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              
              if (quotation.eventName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.event, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        quotation.eventName!,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
              
              if (quotation.eventDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(quotation.formattedEventDate),
                  ],
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Items summary
              Row(
                children: [
                  if (quotation.plates.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${quotation.plates.length} Plates',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (quotation.banquetItems.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${quotation.banquetItems.length} Hall',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (quotation.additionalItems.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${quotation.additionalItems.length} Items',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Validity warning
              if (isExpired) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 14, color: Colors.orange.shade800),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Expired on ${quotation.formattedValidUntil}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Total and actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        quotation.formattedTotal,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade800,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy_all, color: Colors.red),
                        onPressed: () => _copyQuotation(quotation),
                        tooltip: 'Create Copy',
                      ),
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        onPressed: () => _saveAndShareQuotation(quotation),
                        tooltip: 'Share PDF',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _navigateToEditQuotation(quotation),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteQuotation(quotation),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon(QuotationStatus status) {
    switch (status) {
      case QuotationStatus.draft: return Icons.edit_note;
      case QuotationStatus.sent: return Icons.send;
      case QuotationStatus.accepted: return Icons.check_circle;
      case QuotationStatus.expired: return Icons.timer_off;
      case QuotationStatus.rejected: return Icons.cancel;
    }
  }

  Color _getStatusColor(QuotationStatus status) {
    switch (status) {
      case QuotationStatus.draft: return Colors.grey;
      case QuotationStatus.sent: return Colors.blue;
      case QuotationStatus.accepted: return Colors.green;
      case QuotationStatus.expired: return Colors.orange;
      case QuotationStatus.rejected: return Colors.red;
    }
  }

  String _getStatusText(QuotationStatus status) {
    switch (status) {
      case QuotationStatus.draft: return 'Draft';
      case QuotationStatus.sent: return 'Sent';
      case QuotationStatus.accepted: return 'Accepted';
      case QuotationStatus.expired: return 'Expired';
      case QuotationStatus.rejected: return 'Rejected';
    }
  }

  Future<void> _navigateToAddQuotation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditQuotationPage(),
      ),
    );
    if (result == true) {
      await _loadQuotations();
    }
  }

  Future<void> _navigateToEditQuotation(Quotation quotation) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditQuotationPage(quotation: quotation),
      ),
    );
    if (result == true) {
      await _loadQuotations();
    }
  }

  Future<void> _navigateToViewQuotation(Quotation quotation) async {
    _navigateToEditQuotation(quotation);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}