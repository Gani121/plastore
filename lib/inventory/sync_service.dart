import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database_Module/cunsuption.dart'; // Adjust path
import '../database_Module/menu_item.dart'; // Adjust path
import '../objectbox.g.dart';

class SyncService {
  final String apiUrl = "https://api2.nextorbitals.in/api/inventory_api.php";

  // --- FETCH DATA (GET) ---
  Future<void> fetchFromServer(Store store) async {
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode != 200) {
        print("Sync failed: ${response.statusCode}");
        return;
      }

      final data = jsonDecode(response.body);

      final inventoryBox = store.box<InventoryItem>();
      final consumptionBox = store.box<ItemConsumption>();
      final menuBox = store.box<MenuItem>();

      // ---------------------------
      // 1️⃣ SYNC INVENTORY
      // ---------------------------

      for (var item in data['inventory']) {
        final name = item['name'];
        final unit = item['unit'];
        final stock = double.tryParse(item['stock_quantity'].toString()) ?? 0.0;

        final query =
            inventoryBox.query(InventoryItem_.name.equals(name)).build();
        final existing = query.findFirst();
        query.close();

        if (existing != null) {
          existing.unit = unit;
          existing.stockQuantity = stock;
          inventoryBox.put(existing);
        } else {
          inventoryBox.put(
            InventoryItem(
              name: name,
              unit: unit,
              stockQuantity: stock,
            ),
          );
        }
      }

      print("Inventory Sync Complete");

      // ---------------------------
      // 2️⃣ CLEAR OLD CONSUMPTION
      // ---------------------------

      consumptionBox.removeAll();

      // ---------------------------
      // 3️⃣ SYNC CONSUMPTION
      // ---------------------------

      for (var item in data['consumption']) {
        final menuName = item['menu_item_name'];
        final inventoryName = item['inventory_item_name'];
        final qty =
            double.tryParse(item['quantity_used'].toString()) ?? 0.0;

        // Find related menu item
        final menuQuery =
            menuBox.query(MenuItem_.name.equals(menuName)).build();
        final menuItem = menuQuery.findFirst();
        menuQuery.close();

        // Find related inventory item
        final invQuery =
            inventoryBox.query(InventoryItem_.name.equals(inventoryName)).build();
        final inventoryItem = invQuery.findFirst();
        invQuery.close();

        if (menuItem != null && inventoryItem != null) {
          final consumption = ItemConsumption(quantityUsed: qty);

          consumption.menuItem.target = menuItem;
          consumption.inventoryItem.target = inventoryItem;

          consumptionBox.put(consumption);
        }
      }

      print("Consumption Sync Complete");
      print("FULL SYNC SUCCESS");
    } catch (e) {
      print("Sync Error: $e");
    }
  }

  // --- SYNC SALE (POST) - Updated to use inventory_name ---
  Future<void> syncSale(String inventoryName, double deduction) async {
    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "update_stock",
          "inventory_name": inventoryName, // Changed from inventory_id
          "deduction": deduction
        }),
      );
    } catch (e) {
      print("Stock Push Failed: $e");
    }
  }

  // --- ADD NEW ITEM (POST) ---
  Future<void> addNewStock(String name, String unit, double qty) async {
    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "add_inventory",
          "name": name,
          "unit": unit,
          "stock_quantity": qty
        }),
      );
    } catch (e) {
      print("Add Inventory Failed: $e");
    }
  }

  // --- SAVE RECIPE (POST) - Updated to use Names ---
  Future<void> saveRecipeToServer(String menuItemName, List<ItemConsumption> consumptions) async {
    // Prepare the list of items using inventory_name
    print("consumptions $consumptions");
    List<Map<String, dynamic>> itemsList = consumptions.map((c) {
      return {
        "inventory_name": c.inventoryItem.target?.name ?? "Unknown", // Get name from target
        "quantity_used": c.quantityUsed,
      };
    }).toList();
    print("items maped are ${itemsList} menuItemName $menuItemName");
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "save_recipe",
          "menu_item_name": menuItemName, // Changed from menu_item_id
          "items": itemsList,
        }),
      );

      if (response.statusCode == 200) {
        print("Server Response: ${response.body}");
      } else {
        print("HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Network Error: $e");
    }
  }
  Future<void> deleteInventory(String name) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "action": "delete_inventory",
        "name": name,
      }),
    );

    print(response.body);
  }
}