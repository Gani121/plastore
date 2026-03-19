// lib/purchase_order/purchase_order_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:test1/database_Module/ObjectBoxService.dart';
import 'package:test1/database_Module/supplier_database.dart';
import '../objectbox.g.dart';
import 'purchase_order_model.dart';
import 'package:test1/database_Module/purchase_order_database.dart';
import 'add_edit_purchase_order_page.dart';
import 'purchase_order_pdf.dart';
import 'dart:io';
import 'package:test1/utilities.dart';

class PurchaseOrderPage extends StatefulWidget {
  const PurchaseOrderPage({super.key});

  @override
  State<PurchaseOrderPage> createState() => _PurchaseOrderPageState();
}

class _PurchaseOrderPageState extends State<PurchaseOrderPage> {
  late Store _store;
  List<PurchaseOrder> _orders = [];
  List<PurchaseOrder> _filteredOrders = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  PurchaseOrderStatus? _selectedStatus;
  String _sortBy = 'date'; // 'date', 'supplier', 'amount'
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _store = Provider.of<ObjectBoxService>(context, listen: false).store;
    _loadOrders();
    _searchController.addListener(_filterOrders);
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final box = _store.box<PurchaseOrderEntity>();
      final entities = box.getAll();
      final orders = <PurchaseOrder>[];

      for (final entity in entities) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(entity.orderData));
          orders.add(PurchaseOrder.fromMap(map));
        } catch (e) {
          print('Error parsing order: $e');
        }
      }

      setState(() {
        _orders = orders;
        _applyFiltersAndSort();
      });
    } catch (e) {
      print('Error loading orders: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterOrders() {
    _applyFiltersAndSort();
  }

  void _applyFiltersAndSort() {
    var filtered = List<PurchaseOrder>.from(_orders);

    // Apply status filter
    if (_selectedStatus != null) {
      filtered = filtered.where((o) => o.status == _selectedStatus).toList();
    }

    // Apply search
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((o) {
        return o.orderNumber.toLowerCase().contains(query) ||
               o.supplierName.toLowerCase().contains(query);
      }).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'date':
        filtered.sort((a, b) => _sortAscending
            ? a.orderDate.compareTo(b.orderDate)
            : b.orderDate.compareTo(a.orderDate));
        break;
      case 'supplier':
        filtered.sort((a, b) => _sortAscending
            ? a.supplierName.compareTo(b.supplierName)
            : b.supplierName.compareTo(a.supplierName));
        break;
      case 'amount':
        filtered.sort((a, b) => _sortAscending
            ? a.totalAmount.compareTo(b.totalAmount)
            : b.totalAmount.compareTo(a.totalAmount));
        break;
    }

    setState(() {
      _filteredOrders = filtered;
    });
  }

  Future<void> _deleteOrder(PurchaseOrder order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text('Delete purchase order ${order.orderNumber}?'),
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
        final box = _store.box<PurchaseOrderEntity>();
        final entities = box.getAll();
        
        for (final entity in entities) {
          final map = jsonDecode(entity.orderData);
          if (map['id'] == order.id) {
            box.remove(entity.id);
            break;
          }
        }
        
        await _loadOrders();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order ${order.orderNumber} deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('Error deleting order: $e');
      }
    }
  }

  Future<void> _shareOrder(PurchaseOrder order) async {
    try {
    final pdf = await PurchaseOrderPDF.generate(order);
    final bytes = await pdf.save();

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/PO_${order.orderNumber}.pdf';

    final file = File(filePath);
    await file.writeAsBytes(bytes);
  
    await SharePlus.instance.share(
      ShareParams(
        text: 'Purchase Order: ${order.orderNumber}',
        subject: 'Purchase Order PDF',
        files: [XFile(filePath)],
      ),
    );
    } catch (e) {
      print('Error sharing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        actions: [
          // Filter by status
          PopupMenuButton<PurchaseOrderStatus>(
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
                child: Text('All Orders'),
              ),
              ...PurchaseOrderStatus.values.map((status) => PopupMenuItem(
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
                value: 'supplier',
                child: Row(
                  children: [
                    Icon(_sortBy == 'supplier'
                        ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                        : Icons.business),
                    const SizedBox(width: 8),
                    Text('Supplier ${_sortBy == 'supplier' ? (_sortAscending ? '↑' : '↓') : ''}'),
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
                hintText: 'Search by order # or supplier...',
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
          : _filteredOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _orders.isEmpty
                            ? 'No purchase orders yet'
                            : 'No matching orders found',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      if (_orders.isEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _navigateToAddOrder(),
                          icon: const Icon(Icons.add),
                          label: const Text('Create First Order'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade800,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = _filteredOrders[index];
                    return _buildOrderCard(order);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddOrder,
        backgroundColor: Colors.teal.shade800,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildOrderCard(PurchaseOrder order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToViewOrder(order),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: order.statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getStatusIcon(order.status),
                          color: order.statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.orderNumber,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            order.formattedOrderDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: order.statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.statusText,
                      style: TextStyle(
                        color: order.statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Supplier info
              Row(
                children: [
                  Icon(Icons.business, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.supplierName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              
              if (order.supplierMobile != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(order.supplierMobile!),
                  ],
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Items summary
              Row(
                children: [
                  Icon(Icons.shopping_bag, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text('${order.items.length} items'),
                  const SizedBox(width: 16),
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(order.formattedExpectedDate),
                ],
              ),
              
              const SizedBox(height: 12),
              
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
                        order.formattedTotal,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        onPressed: () => _shareOrder(order),
                        tooltip: 'Share PDF',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _navigateToEditOrder(order),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteOrder(order),
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

  IconData _getStatusIcon(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.draft:
        return Icons.edit_note;
      case PurchaseOrderStatus.sent:
        return Icons.send;
      case PurchaseOrderStatus.confirmed:
        return Icons.check_circle;
      case PurchaseOrderStatus.received:
        return Icons.inventory;
      case PurchaseOrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.draft:
        return Colors.grey;
      case PurchaseOrderStatus.sent:
        return Colors.blue;
      case PurchaseOrderStatus.confirmed:
        return Colors.green;
      case PurchaseOrderStatus.received:
        return Colors.purple;
      case PurchaseOrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.draft:
        return 'Draft';
      case PurchaseOrderStatus.sent:
        return 'Sent';
      case PurchaseOrderStatus.confirmed:
        return 'Confirmed';
      case PurchaseOrderStatus.received:
        return 'Received';
      case PurchaseOrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Future<void> _navigateToAddOrder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditPurchaseOrderPage(),
      ),
    );
    if (result == true) {
      await _loadOrders();
    }
  }

  Future<void> _navigateToEditOrder(PurchaseOrder order) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditPurchaseOrderPage(order: order),
      ),
    );
    if (result == true) {
      await _loadOrders();
    }
  }

  Future<void> _navigateToViewOrder(PurchaseOrder order) async {
    // Implement view details page if needed
    _navigateToEditOrder(order);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}