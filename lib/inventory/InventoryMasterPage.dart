import 'package:flutter/material.dart';
import '../database_Module/cunsuption.dart'; // Adjust path
import '../objectbox.g.dart';
import 'package:test1/utilities.dart';
import 'package:test1/inventory/sync_service.dart';

class InventoryMasterPage extends StatefulWidget {
  final Store store;

  const InventoryMasterPage({Key? key, required this.store}) : super(key: key);

  @override
  State<InventoryMasterPage> createState() => _InventoryMasterPageState();
}

class _InventoryMasterPageState extends State<InventoryMasterPage> with SingleTickerProviderStateMixin {
  late Box<InventoryItem> inventoryBox;
  // late Box<ItemConsumption> consumptionBox;
  List<InventoryItem> allInventoryList = [];
  List<InventoryItem> materialsList = [];
  List<InventoryItem> premadeList = [];
  
  late TabController _tabController;
  int _selectedTabIndex = 0;
late Stream<bool> _syncStatusStream;
  // Predefined categories
  final String _materialsCategory = 'Materials';
  final String _premadeCategory = 'Premade';
  final sync = SyncService();
   bool _isSynced = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    inventoryBox = widget.store.box<InventoryItem>();
    // consumptionBox = widget.store.box<ItemConsumption>();
    if (mounted) {
      _loadInventory();
      // sync.addNewStock(null,inventoryBox);
      // sync.saveRecipeToServer(null,null, null, consumptionBox);
    }
  }

    // Create a stream for sync status
  Stream<bool> _createSyncStatusStream() async* {
    while (true) {
      yield _isSynced;
      await Future.delayed(const Duration(seconds: 1));
    }
  }


  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    }
  }

  void _loadInventory() {
    setState(() {
      allInventoryList = inventoryBox.getAll();
      
      // Separate items by category
      materialsList = allInventoryList
          .where((item) => item.category == _materialsCategory)
          .toList();
          
      premadeList = allInventoryList
          .where((item) => item.category == _premadeCategory)
          .toList();
    });
  }

  // Optional: Method to reduce stock (for consumption/usage)
Future<bool> _reduceStock(InventoryItem item, double quantity, {String reason = 'consumption'}) async {
  try {
    if (item.stockQuantity < quantity) {
      print_log('❌ Insufficient stock: ${item.stockQuantity} < $quantity');
      return false;
    }

    double oldStock = item.stockQuantity;
    double newStock = oldStock - quantity;

        // Send to server first
    await sync.sendStockToServer(item, quantity, 'reduce');
    
    // Update local after server success
    item.stockQuantity = newStock;
    int id = inventoryBox.put(item);
    
    print_log('✅ Stock reduced: $oldStock → $newStock (Reason: $reason)');
    return true;
    
  } catch (e) {
    print_log('❌ Failed to reduce stock: $e');
    return false;
  }
}

  // Dialog to Add New Item or Add Stock to Existing Item
void _showAddStockDialog({InventoryItem? existingItem}) {
  final nameController = TextEditingController(text: existingItem?.name ?? '');
  final qtyController = TextEditingController();
  String selectedUnit = existingItem?.unit ?? 'Nos';
  String selectedCategory = existingItem?.category ?? 
      (_selectedTabIndex == 0 ? _materialsCategory : _premadeCategory);
  bool isSyncing = false;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(
            existingItem == null 
                ? 'Add New ${selectedCategory == _materialsCategory ? 'Material' : 'Premade Item'}'
                : 'Add Stock: ${existingItem.name}',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existingItem == null) ...[
                  // Category Selector for new items
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Materials'),
                            selected: selectedCategory == _materialsCategory,
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() {
                                  selectedCategory = _materialsCategory;
                                });
                              }
                            },
                            selectedColor: Colors.blue.shade100,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Premade'),
                            selected: selectedCategory == _premadeCategory,
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() {
                                  selectedCategory = _premadeCategory;
                                });
                              }
                            },
                            selectedColor: Colors.orange.shade100,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Item Name
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name (e.g. Cheese)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Unit Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    items: units
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedUnit = v!),
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                
                // Quantity Field (for both new and existing)
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: existingItem == null 
                        ? 'Initial Stock Quantity' 
                        : "Add Stock to reduce '-ve'",
                    border: const OutlineInputBorder(),
                    suffixText: existingItem != null ? selectedUnit : null,
                  ),
                ),
                
                if (existingItem != null && isSyncing)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSyncing ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSyncing ? null : () async {
                final double enteredQty = double.tryParse(qtyController.text) ?? 0.0;

                setDialogState(() {
                  isSyncing = true;
                });

                try {
                  if (existingItem == null) {
                    // Creating a brand new item with category
                    final newItem = InventoryItem(
                      syid: ganarateID(), 
                      name: nameController.text.trim(),
                      unit: selectedUnit,
                      stockQuantity: enteredQty,
                      category: selectedCategory,
                    );
                    
                    // Save locally first
                    int id = inventoryBox.put(newItem);
                    
                    // TODO: Add method to sync new item to server
                    // await _sendNewItemToServer(newItem);
                    
                    print_log('✅ New item added locally: ${newItem.name}');
                    
                  } else {

                    if(enteredQty < 0){
                      
                        // Updating stock of existing item
                      double oldStock = existingItem.stockQuantity;
                      double newStock = oldStock + enteredQty;
                      print_log("massage $oldStock - $enteredQty; $newStock");
                      
                      // Determine operation (add only, since this is add stock dialog)
                      String operation = 'reduce';
                      
                      // Send to server first
                      try {
                        await sync.sendStockToServer(existingItem, enteredQty, operation);
                        
                        // Update local stock after successful server sync
                        existingItem.stockQuantity = newStock;
                        int id = inventoryBox.put(existingItem);
                        
                        print_log('✅ Stock updated locally and synced to server: ${existingItem.name}');
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Stock updated: $oldStock → $newStock ${existingItem.unit}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                        
                      } catch (serverError) {
                        print_log('❌ Server sync failed: $serverError');
                        
                        // Ask user if they want to retry or save locally only
                        if (context.mounted) {
                          bool? retry = await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Sync Failed'),
                              content: Text(
                                'Failed to sync with server. Do you want to retry or save locally only?\n\n'
                                'Item: ${existingItem.name}\n'
                                'Quantity: +$enteredQty ${existingItem.unit}'
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Local Only'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          );

                          if (retry == true) {
                            // Retry server update
                            setDialogState(() {
                              isSyncing = false;
                            });
                            _showAddStockDialog(existingItem: existingItem);
                            return;
                          } else {
                            // Save locally only
                            existingItem.stockQuantity = newStock;
                            int id = inventoryBox.put(existingItem);
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('⚠️ Stock updated locally only: +$enteredQty ${existingItem.unit}'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      }

                    }else{
                      // Updating stock of existing item
                      double oldStock = existingItem.stockQuantity;
                      double newStock = oldStock + enteredQty;
                      
                      // Determine operation (add only, since this is add stock dialog)
                      String operation = 'add';
                      
                      // Send to server first
                      try {
                        await sync.sendStockToServer(existingItem, enteredQty, operation);
                        
                        // Update local stock after successful server sync
                        existingItem.stockQuantity = newStock;
                        int id = inventoryBox.put(existingItem);
                        
                        print_log('✅ Stock updated locally and synced to server: ${existingItem.name}');
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Stock updated: $oldStock → $newStock ${existingItem.unit}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                        
                      } catch (serverError) {
                        print_log('❌ Server sync failed: $serverError');
                        
                        // Ask user if they want to retry or save locally only
                        if (context.mounted) {
                          bool? retry = await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Sync Failed'),
                              content: Text(
                                'Failed to sync with server. Do you want to retry or save locally only?\n\n'
                                'Item: ${existingItem.name}\n'
                                'Quantity: +$enteredQty ${existingItem.unit}'
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Local Only'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          );

                          if (retry == true) {
                            // Retry server update
                            setDialogState(() {
                              isSyncing = false;
                            });
                            _showAddStockDialog(existingItem: existingItem);
                            return;
                          } else {
                            // Save locally only
                            existingItem.stockQuantity = newStock;
                            int id = inventoryBox.put(existingItem);
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('⚠️ Stock updated locally only: +$enteredQty ${existingItem.unit}'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      }
                    }
                  }
                  
                  if (context.mounted) {
                    _loadInventory();
                    Navigator.pop(context);
                  }
                  
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  setDialogState(() {
                    isSyncing = false;
                  });
                }
              },
              child: isSyncing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
}


  // Method to show low stock warning
  bool _isLowStock(InventoryItem item) {
    return item.stockQuantity < 10; // Threshold for low stock
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      title: const Text('Surve Per Plate'),
      actions: [
        // Cloud Sync Status Indicator
        StreamBuilder<bool>(
          stream: _createSyncStatusStream(), // You'll need to create this stream
          initialData: true, // Assume synced initially
          builder: (context, snapshot) {
            final isSynced = snapshot.data ?? true;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  // Sync icon with status
                  Icon(
                    isSynced ? Icons.cloud_done : Icons.cloud_sync,
                    color: isSynced ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isSynced ? 'Synced' : 'Syncing...',
                    style: TextStyle(
                      color: isSynced ? Colors.green : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // Manual sync button
        IconButton(
          icon: const Icon(Icons.sync),
          onPressed: () async {
            // Show loading indicator
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Syncing with cloud...'),
                duration: Duration(seconds: 1),
              ),
            );
            
            // Perform sync
            await SyncService().fetchFromServer(widget.store);
            
            // Update UI
            if(mounted){
            setState(() {});
            }
            
            // Show completion message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sync completed!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: _selectedTabIndex == 0 ? Colors.blue : Colors.orange,
        labelColor: _selectedTabIndex == 0 ? Colors.blue : Colors.orange,
        unselectedLabelColor: Colors.grey,
        tabs: [
          Tab(
            icon: Icon(Icons.inventory, color: _selectedTabIndex == 0 ? Colors.blue : Colors.grey),
            text: 'ROW MATERIALS (${materialsList.length})',
          ),
          Tab(
            icon: Icon(Icons.restaurant, color: _selectedTabIndex == 1 ? Colors.orange : Colors.grey),
            text: 'PREMADE (${premadeList.length})',
          ),
        ],
      ),
    ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          // Materials Tab
          _buildInventoryList(materialsList, Colors.blue),
          
          // Premade Tab
          _buildInventoryList(premadeList, Colors.orange),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStockDialog(),
        backgroundColor: _selectedTabIndex == 0 ? Colors.blue : Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildInventoryList(List<InventoryItem> items, Color themeColor) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedTabIndex == 0 ? Icons.inventory : Icons.restaurant,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${_selectedTabIndex == 0 ? 'Materials' : 'Premade Items'} Found',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add ${_selectedTabIndex == 0 ? 'materials' : 'premade items'}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header Row
        Container(
          color: themeColor.withOpacity(0.1),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('Item Name', style: const TextStyle(fontWeight: FontWeight.bold))),
              Expanded(child: Text('Unit', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              Expanded(child: Text('Stock', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              Expanded(child: Text('Action', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        
        // Data Rows
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isLowStock = _isLowStock(item);
              
              return Dismissible(
                key: ValueKey(item.id),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  final deletedItemName = item.name;
                  inventoryBox.remove(item.id);
                  sync.deleteInventory(deletedItemName);

                  setState(() {
                    _loadInventory(); // Reload all lists
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Deleted $deletedItemName'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                confirmDismiss: (direction) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Delete'),
                      content: Text('Are you sure you want to delete "${item.name}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ) ?? false;
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        children: [
                          // Item Name with low stock indicator
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                if (isLowStock)
                                  Icon(Icons.warning_amber_rounded, 
                                       color: Colors.red, 
                                       size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    softWrap: true,
                                    style: TextStyle(
                                      fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                                      color: isLowStock ? Colors.red : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Unit
                          Expanded(
                            child: Text(
                              item.unit,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          
                          // Stock Quantity
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isLowStock ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item.stockQuantity.toStringAsFixed(2),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isLowStock ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          
                          // Add Stock Button
                          Expanded(
                            child: IconButton(
                              icon: Icon(Icons.add_box, color: themeColor),
                              onPressed: () => _showAddStockDialog(existingItem: item),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}