import 'package:flutter/material.dart';
import '../database_Module/cunsuption.dart'; // Adjust path
import '../database_Module/menu_item.dart'; // Adjust path
import '../objectbox.g.dart';
import 'package:test1/utilities.dart';
import 'package:test1/inventory/sync_service.dart';

class InventoryMasterPage extends StatefulWidget {
  final Store store;

  const InventoryMasterPage({Key? key, required this.store}) : super(key: key);

  @override
  State<InventoryMasterPage> createState() => _InventoryMasterPageState();
}

class _InventoryMasterPageState extends State<InventoryMasterPage> {
  late Box<InventoryItem> inventoryBox;
  List<InventoryItem> inventoryList = [];

  @override
  void initState() {
    super.initState();
    inventoryBox = widget.store.box<InventoryItem>();
    _loadInventory();
  }

  void _loadInventory() {
    setState(() {
      inventoryList = inventoryBox.getAll();
    });
  }

  // Dialog to Add New Item or Add Stock to Existing Item
  void _showAddStockDialog({InventoryItem? existingItem}) {
    final nameController = TextEditingController(text: existingItem?.name ?? '');
    final qtyController = TextEditingController();
    String selectedUnit = existingItem?.unit ?? 'Nos';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingItem == null ? 'Add New Inventory' : 'Add Stock: ${existingItem.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (existingItem == null) ...[
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name (e.g. Cheese)'),
              ),
              DropdownButtonFormField<String>(
                value: selectedUnit,
                items: units
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => selectedUnit = v!,
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
            ],
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: existingItem == null ? 'Initial Stock' : 'Add Quantity to Stock',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final double enteredQty = double.tryParse(qtyController.text) ?? 0.0;
              
              if (existingItem == null) {
                // Creating a brand new item
                final newItem = InventoryItem(
                  name: nameController.text,
                  unit: selectedUnit,
                  stockQuantity: enteredQty,
                );
                inventoryBox.put(newItem);
                SyncService().addNewStock(nameController.text, selectedUnit, enteredQty);
              } else {
                // Updating stock of existing item
                existingItem.stockQuantity += enteredQty;
                inventoryBox.put(existingItem);
                SyncService().addNewStock(nameController.text, selectedUnit, enteredQty);
              }
              
              _loadInventory();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory & Stock')),
      body: inventoryList.isEmpty
          ? const Center(child: Text('No inventory items found. Add some!'))
          : Column(
              children: [
                // Header Row
                Container(
                  color: Colors.grey.shade100,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: const [
                      Expanded(flex: 3, child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Expanded(child: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Expanded(child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                // Data Rows
                Expanded(
                  child: ListView.builder(
                    itemCount: inventoryList.length,
                    itemBuilder: (context, index) {
                      final item = inventoryList[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          final deletedItemName = item.name;
                          inventoryBox.remove(item.id);
                          SyncService().deleteInventory(deletedItemName);

                          setState(() {
                            inventoryList.removeAt(index);
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Deleted $deletedItemName')),
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
                                  child: const Text('Delete'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                ),
                              ],
                            ),
                          ) ?? false;
                        },
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: Text(item.name, softWrap: true)),
                                  Expanded(child: Text(item.unit, textAlign: TextAlign.center)),
                                  Expanded(
                                    child: Text(
                                      item.stockQuantity.toStringAsFixed(2),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: item.stockQuantity < 10 ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: IconButton(
                                      icon: const Icon(Icons.add_box, color: Colors.blue),
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
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStockDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}