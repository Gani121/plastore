import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database_Module/cunsuption.dart'; // Adjust path
import '../database_Module/menu_item.dart'; // Adjust path
import '../objectbox.g.dart';
import 'package:test1/utilities.dart';


class SyncService {
  // --- FETCH DATA (GET) ---
  Future<void> fetchFromServer(Store store) async {
    try {
      http.Response? response = await apiCalls("get_plate", "", {});
        if (response == null) {
          return;
        }

      if (response.statusCode != 200) {
        print_log("Sync failed: ${response.statusCode}");
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

      print_log("Inventory Sync Complete");

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

      print_log("Consumption Sync Complete");
      print_log("FULL SYNC SUCCESS");
    } catch (e) {
      print_log_red("Sync Error: $e");
    }
  }

  // --- SYNC SALE (POST) - Updated to use inventory_name ---
  Future<void> syncSale(String inventoryName, double deduction) async {
    try {

      final payload = {
          "action": "update_stock",
          "inventory_name": inventoryName, // Changed from inventory_id
          "deduction": deduction
        };

      http.Response? response = await apiCalls("set_plate", "", payload);
        if (response == null) {
          return;
        }
    } catch (e) {
      print_log_red("Stock Push Failed: $e");
    }
  }

  // --- ADD NEW ITEM (POST) ---
  Future<void> addNewStock(String name, String unit, double qty) async {
    try {
      final payload = {
          "action": "add_inventory",
          "name": name,
          "unit": unit,
          "stock_quantity": qty
        };
      http.Response? response = await apiCalls("add_plate", "", payload);
        if (response == null) {
          return;
        }
    } catch (e) {
      print_log_red("Add Inventory Failed: $e");
    }
  }

  // --- SAVE RECIPE (POST) - Updated to use Names ---
  Future<void> saveRecipeToServer(String menuItemName, List<ItemConsumption> consumptions) async {
    // Prepare the list of items using inventory_name
    print_log("consumptions $consumptions");
    List<Map<String, dynamic>> itemsList = consumptions.map((c) {
      return {
        "inventory_name": c.inventoryItem.target?.name ?? "Unknown", // Get name from target
        "quantity_used": c.quantityUsed,
      };
    }).toList();
    print_log("items maped are ${itemsList} menuItemName $menuItemName");
    try {
      final payload = {
          "action": "save_recipe",
          "menu_item_name": menuItemName, // Changed from menu_item_id
          "items": itemsList,
        };
      http.Response? response = await apiCalls("save_recipe", "", payload);
        if (response == null) {
          return;
        }

      if (response.statusCode == 200) {
        print_log("Server Response: ${response.body}");
      } else {
        print_log("HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      print_log_red("Network Error: $e");
    }
  }
  
  Future<void> deleteInventory(String name) async {
    final payload = {
        "action": "delete_inventory",
        "name": name,
      };
      
    http.Response? response = await apiCalls("delete_inventory", "", payload);
        if (response == null) {
          return;
        }

    print_log(response.body);
  }


}