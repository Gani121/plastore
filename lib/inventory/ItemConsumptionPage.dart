import 'package:flutter/material.dart';
import '../database_Module/menu_item.dart'; // Adjust path
import '../database_Module/cunsuption.dart'; // Adjust path
import '../objectbox.g.dart';
import 'package:test1/utilities.dart';
import 'package:test1/inventory/sync_service.dart';

class ItemConsumptionPage extends StatefulWidget {
  final Store store; 
  final MenuItem menuItem;

  const ItemConsumptionPage({Key? key, required this.store, required this.menuItem}) : super(key: key);

  @override
  State<ItemConsumptionPage> createState() => _ItemConsumptionPageState();
}

class _ItemConsumptionPageState extends State<ItemConsumptionPage> {
  late Box<InventoryItem> inventoryBox;
  late Box<ItemConsumption> consumptionBox;

  List<InventoryItem> allInventory = [];
  List<ItemConsumption> currentRecipe = [];
  
  int? selectedInventoryItemId;
  final TextEditingController _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    inventoryBox = widget.store.box<InventoryItem>();
    consumptionBox = widget.store.box<ItemConsumption>();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      allInventory = inventoryBox.getAll();
      // Filter consumption to show only for this specific menu item
      final query = consumptionBox.query(ItemConsumption_.menuItem.equals(widget.menuItem.id)).build();
      currentRecipe = query.find();
      query.close();
    });
  }

  // Dialog to create a brand new Inventory Item (e.g. "Bread")
  void _addNewInventoryItemDialog() {
    String name = '';
    String unit = 'Nos';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Inventory Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Item Name (e.g. Cheese)'),
              onChanged: (value) => name = value,
            ),
            DropdownButtonFormField<String>(
              value: unit,
              items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
              onChanged: (value) => unit = value!,
              decoration: const InputDecoration(labelText: 'Unit'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (name.isNotEmpty) {
                inventoryBox.put(InventoryItem(name: name, unit: unit));
                _refreshData();
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

void _saveConsumption() {
  // 1. Validation
  if (selectedInventoryItemId == null || _quantityController.text.isEmpty) {
    return;
  }

  final qty = double.tryParse(_quantityController.text) ?? 0.0;
  
  // 2. Fix the "Positional Arguments" error here:
  final newItemUsage = ItemConsumption(quantityUsed: qty);
  
  // 3. Link the relations
  newItemUsage.menuItem.target = widget.menuItem;
  newItemUsage.inventoryItem.targetId = selectedInventoryItemId!; 

  // 4. Save to ObjectBox
  consumptionBox.put(newItemUsage);


  _refreshData();
  SyncService().saveRecipeToServer(widget.menuItem.name, currentRecipe);
  
  // 5. Reset UI
  setState(() {
    _quantityController.clear();
    selectedInventoryItemId = null; 
  });
  _refreshData();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Consumption: ${widget.menuItem.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Row to Select Item and Add New
            Row(
              children: [
                Expanded(
                  // ADD THIS KEYWORD: child:
                  child: DropdownButtonFormField<int>( 
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Select Raw Material'),
                    value: selectedInventoryItemId, 
                    items: allInventory.map((item) {
                      return DropdownMenuItem<int>(
                        value: item.id, 
                        child: Text('${item.name} (${item.unit})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedInventoryItemId = val; 
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  onPressed: _addNewInventoryItemDialog,
                )
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Qty used per 1 Sandwich/Item', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _saveConsumption, child: const Text('Add to Recipe')),
            const Divider(height: 30),
            const Text('Current Recipe', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: currentRecipe.length,
                itemBuilder: (context, index) {
                  final consumption = currentRecipe[index];
                  return ListTile(
                    leading: const Icon(Icons.layers),
                    title: Text(consumption.inventoryItem.target?.name ?? 'Unknown'),
                    subtitle: Text('${consumption.quantityUsed} ${consumption.inventoryItem.target?.unit}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        consumptionBox.remove(consumption.id);
                        print("goinnto referesh items ${currentRecipe} ");
                        _refreshData();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}