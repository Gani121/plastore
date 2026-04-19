import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database_Module/cunsuption.dart'; // Adjust path
import '../database_Module/menu_item.dart'; // Adjust path
import '../objectbox.g.dart';
import 'package:test1/utilities.dart';

import 'package:shared_preferences/shared_preferences.dart';


class SyncService {
  // --- FETCH DATA (GET) ---
Future<void> fetchFromServer(Store store) async {
  try {
    http.Response? response = await apiCalls("get_plate", "", {});
    if (response == null) {
      print_log("No response from server");
      return;
    }

    if (response.statusCode != 200) {
      print_log("Sync failed: ${response.statusCode}");
      return;
    }

    final data = jsonDecode(response.body);
    print_log("data $data");
    // Validate response structure
    if (data['inventory'] == null || data['consumption'] == null) {
      print_log("Invalid response format: missing inventory or consumption");
      return;
    }

    final inventoryBox = store.box<InventoryItem>();
    final consumptionBox = store.box<ItemConsumption>();
    final menuBox = store.box<MenuItem>();

    await ApiCallPage(menuBox);


    // ---------------------------
    // 1️⃣ SYNC INVENTORY
    // ---------------------------
    await _syncInventory(data['inventory'], inventoryBox);

    // ---------------------------
    // 2️⃣ CLEAR OLD CONSUMPTION
    // ---------------------------
    if(data['consumption'] != null){
      consumptionBox.removeAll();
      print_log("Cleared old consumption data");
    }

    // ---------------------------
    // 3️⃣ SYNC MENU ITEMS
    // ---------------------------
    final menuItemIds = await _syncMenuItems(data['consumption'], menuBox);

    // ---------------------------
    // 4️⃣ SYNC CONSUMPTION FROM JSON MAP
    // ---------------------------
    await _syncConsumption(data['consumption'], menuItemIds, menuBox, inventoryBox, consumptionBox);

    print_log("FULL SYNC SUCCESS");
    
  } catch (e) {
    print_log_red("Sync Error: $e");
  }
}

Future<void> _syncInventory(List<dynamic> inventoryItems, Box<InventoryItem> inventoryBox) async {
  print_log("Syncing ${inventoryItems.length} inventory items");
  
  for (var item in inventoryItems) {
    try {
      final name = item['name'] ?? '';
      final unit = item['unit'] ?? '';
      final category = item['category'] ?? 'General';
      final stock = double.tryParse(item['stock_quantity']?.toString() ?? '0') ?? 0.0;
      
      // FIX: Convert server ID to int safely
      int serverId;
      if (item['id'] is int) {
        serverId = item['id'];
      } else if (item['id'] is String) {
        serverId = int.tryParse(item['id']) ?? 0;
      } else {
        serverId = 0;
      }

      if (name.isEmpty) continue;

      final query = inventoryBox.query(InventoryItem_.name.equals(name)).build();
      final existing = query.findFirst();
      query.close();

      if (existing != null) {
        existing.unit = unit;
        existing.category = category;
        existing.stockQuantity = stock;
        existing.syid = serverId != 0 ? serverId : existing.syid;
        inventoryBox.put(existing);
        print_log("Updated inventory: $name (ID: $serverId)");
      } else {
        inventoryBox.put(
          InventoryItem(
            syid: serverId != 0 ? serverId : ganarateID(),
            name: name,
            unit: unit,
            category: category,
            stockQuantity: stock,
            synced: true,
          ),
        );
        print_log("Added inventory: $name (ID: $serverId)");
      }
    } catch (e) {
      print_log_red("Error syncing inventory item: $e");
    }
  }
  
  print_log("Inventory Sync Complete");
}

Future<Map<String, int>> _syncMenuItems(
  List<dynamic> consumptionData,
  Box<MenuItem> menuBox,
) async {
  final Map<String, int> menuItemIds = {};

  for (var recipe in consumptionData) {
    try {
      final menuName = (recipe['menu_item_name'] ?? '').toString().trim();
      if (menuName.isEmpty) continue;

      // Query menu item
      final menuQuery = menuBox.query(MenuItem_.name.equals(menuName)).build();
      final menuItem = menuQuery.findFirst();
      menuQuery.close();

      print_log("Searched menu item: $menuName => $menuItem");

      // If not found, SKIP (do NOT create)
      if (menuItem == null) {
        print_log_red("Warning: Menu item not found for $menuName");
        continue;
      }

      // Store ID
      menuItemIds[menuName] = menuItem.id;
    } catch (e) {
      print_log_red("Error syncing menu item: $e");
    }
  }

  print_log("Menu items sync complete: ${menuItemIds.length}");
  print_log("Collected Menu IDs: $menuItemIds");

  return menuItemIds;
}

Future<void> _syncConsumption(
  List<dynamic> consumptionData,
  Map<String, int> menuItemIds,
  Box<MenuItem> menuBox,
  Box<InventoryItem> inventoryBox,
  Box<ItemConsumption> consumptionBox,
) async {
  int consumptionCount = 0;
  
  for (var recipe in consumptionData) {
    try {
      final menuName = recipe['menu_item_name'] ?? '';
      final itemsMap = recipe['items_consumed'];
      print_log("menu items $menuName $itemsMap");
      if (menuName.isEmpty || itemsMap == null) continue;
      
      // Get menu item ID
      final menuId = menuItemIds[menuName];
      if (menuId == null) {
        print_log("Warning: Menu item not found for $menuName");
        continue;
      }
      
      final menuItem = menuBox.get(menuId);
      if (menuItem == null) continue;
      
      // Parse the items map
      Map<String, dynamic> consumptionMap;
      if (itemsMap is String) {
        try {
          consumptionMap = jsonDecode(itemsMap);
        } catch (e) {
          print_log("Error decoding JSON for $menuName: $e");
          continue;
        }
      } else if (itemsMap is Map) {
        consumptionMap = Map<String, dynamic>.from(itemsMap);
      } else {
        print_log("Warning: Unexpected items_consumed format for $menuName");
        continue;
      }
      
      // Create consumption entries
      consumptionMap.forEach((inventoryName, quantity) {
        try {
          if (inventoryName.isEmpty) return;
          
          final invQuery = inventoryBox.query(InventoryItem_.name.equals(inventoryName)).build();
          final inventoryItem = invQuery.findFirst();
          invQuery.close();
          
          if (inventoryItem != null) {
            final qty = double.tryParse(quantity.toString()) ?? 0.0;
            
            if (qty > 0) {
              final consumption = ItemConsumption(
                syid: ganarateID(),
                quantityUsed: qty,
                synced: true,
              );
              
              consumption.menuItem.target = menuItem;
              consumption.inventoryItem.target = inventoryItem;
              
              consumptionBox.put(consumption);
              consumptionCount++;
            }
          }
        } catch (e) {
          print_log_red("Error creating consumption for $inventoryName: $e");
        }
      });
      
    } catch (e) {
      print_log_red("Error processing recipe: $e");
    }
  }
  
  print_log("Consumption Sync Complete: $consumptionCount entries added");
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
  Future<void> addNewStock(int? id,Box<InventoryItem> inventoryBox) async {
    try {
      if (id == null) {
        final item = await inventoryBox.getAll();
        for(var item in item){
          if (!item.synced) {
            final payload = {
              "action": "add_inventory",
              "syid": item.syid,
              "name": item.name,
              "unit": item.unit,
              "stock_quantity": item.stockQuantity,
              "category": item.category, // Add c
            };
            print_log("paylod $payload");
            http.Response? response = await apiCalls("add_plate", "", payload);
              if (response != null) {
              // Decode the JSON response body first
              final responseData = json.decode(response.body);
              
              // Now check the status from the decoded data
              if (responseData['status'] == "success") {
                item.synced = true;
                inventoryBox.put(item);
                print_log("Server Response: ${response.body}");
              } else {
                print_log("Server error: ${responseData['error'] ?? 'Unknown error'}");
              }
            }
          }
        }

      }else{
        final item = await inventoryBox.get(id);
        if (item == null) {
          return;
        }
        final payload = {
            "action": "add_inventory",
            "name": item.name,
            "unit": item.unit,
            "stock_quantity": item.stockQuantity,
            "category": item.category, // Add c
          };
          http.Response? response = await apiCalls("add_plate", "", payload);
          if (response != null) {
            // Decode the JSON response body first
            final responseData = json.decode(response.body);
            
            // Now check the status from the decoded data
            if (responseData['status'] == "success") {
              item.synced = true;
              inventoryBox.put(item);
              print_log("Server Response: ${response.body}");
            } else {
              print_log("Server error: ${responseData['error'] ?? 'Unknown error'}");
            }
          }
      }
    } catch (e) {
      print_log_red("Add Inventory Failed: $e");
    }
  }


  // --- SAVE RECIPE (POST) - Using JSON Map in Database ---
  Future<void> saveRecipeToServer(int? id, String? menuItemName, List<ItemConsumption>? consumptions, Box<ItemConsumption> consumptionBox) async {
    if (id == null) {
        print_log("$id");
        List<ItemConsumption> consumptions = consumptionBox.getAll();

        for (var item in consumptions) {
          if (!item.synced) {
            final menuItemName = item.menuItem.target?.name ?? "Unknown Menu";

            print_log("Processing recipe sync for menuItem: $menuItemName");

            // Collect all consumption items for this specific menuItem
            final relatedItems = consumptions.where(
              (c) => c.menuItem.targetId == item.menuItem.targetId,
            );

            // Build items list
            final itemsList = relatedItems.map((c) {
              return {
                "inventory_name": c.inventoryItem.target?.name ?? "Unknown",
                "quantity_used": c.quantityUsed,
              };
            }).toList();

            print_log("Mapped items: $itemsList for menuItemName: $menuItemName");

            try {
              final payload = {
                "action": "save_recipe",
                "syid": item.syid,
                "menu_item_name": menuItemName,
                "items": itemsList,
              };

              http.Response? response = await apiCalls("save_recipe", "", payload);

              if (response == null) {
                print_log_red("Failed to send recipe to server");
                continue;
              }

              if (response.statusCode == 200) {
                print_log("Recipe synced successfully!");

                // Mark ALL related ItemConsumption as synced
                for (var c in relatedItems) {
                  c.synced = true;
                  consumptionBox.put(c);
                }
              } else {
                print_log_red("Server rejected recipe: ${response.body}");
              }
            } catch (e) {
              print_log_red("Error sending recipe: $e");
            }
          }
        }
        return;
    }else{
    
      print_log("consumptions $consumptions");
      
      // Prepare the list of items using inventory_name
      List<Map<String, dynamic>> itemsList = consumptions!.map((c) {
          return {
              "inventory_name": c.inventoryItem.target?.name ?? "Unknown",
              "quantity_used": c.quantityUsed,
          };
      }).toList();
      
      print_log("items mapped are $itemsList for menuItemName: $menuItemName");
      
      try {
          final payload = {
              "action": "save_recipe",
              "menu_item_name": menuItemName,
              "items": itemsList,
          };
          
          http.Response? response = await apiCalls("save_recipe", "", payload);
          if (response == null) {
              return;
          }

          if (response.statusCode == 200) {
              final jsonResponse = json.decode(response.body);
              if (jsonResponse['status'] == 'success') {
                  final item = await consumptionBox.get(id);
                  if (item != null) {
                      item.synced = true;
                      consumptionBox.put(item);
                      print_log("Server Response: ${response.body}");
                  }
              } else {
                  print_log("Server Error: ${jsonResponse['message']}");
              }
          } else {
              print_log("HTTP Error: ${response.statusCode}");
          }
      } catch (e) {
          print_log_red("Network Error: $e");
      }
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





// Method to send stock updates to server
Future<void> sendStockToServer(InventoryItem item, double addedQuantity, String operation) async {
  try {

    // Determine operation type
    String stockOperation = operation; // 'add' or 'reduce'
    
    // If operation not specified, determine based on addedQuantity sign
    if (stockOperation.isEmpty) {
      stockOperation = addedQuantity >= 0 ? 'add' : 'reduce';
    }

    // Prepare API request
    // final apiUrl = 'https://your-server.com/inventory_api.php?login=$username'; // Replace with your actual API URL
    
    final requestBody = {
      'action': 'adjustStock',
      'items': [
        {
          'name': item.name,
          'quantity': addedQuantity.abs(), // Always send positive quantity
          'operation': stockOperation,
        }
      ]
    };

    print_log('📤 Sending stock update to server: $requestBody');

    http.Response? response = await apiCalls("add_plate", AppConstants.username, requestBody);
      if (response == null) {
        return;
      }

    if (response.statusCode == 200 || response.statusCode == 207) {
      final responseData = json.decode(response.body);
      
      if (responseData['status'] == 'success' || responseData['status'] == 'partial_success') {
        print_log('✅ Stock updated successfully on server: ${responseData['message']}');
        
        // Show success message
        if (responseData['updated_items'] != null && responseData['updated_items'].isNotEmpty) {
          final updatedItem = responseData['updated_items'][0];
          print_log('📊 Stock changed from ${updatedItem['previous_stock']} to ${updatedItem['new_stock']}');
        }
        
        // Handle any failed items
        if (responseData['failed_items'] != null && responseData['failed_items'].isNotEmpty) {
          print_log_red('⚠️ Some items failed: ${responseData['failed_items']}');
          // throw Exception('Some items failed to sync: ${responseData['failed_items']}');
        }
      } else {
         print_log_red('Server returned error: ${responseData['message']}');
        // throw Exception();
      }
    } else {
       print_log_red('Server error: ${response.statusCode} - ${response.body}');
      // throw Exception('Server error: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print_log_red('❌ Error sending stock to server: $e');
  }
}


  Future<void> sendItemtoServer(MenuItem item, Box<MenuItem> _menuItemBox) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      
      final hotelName = prefs.getString(AppConstants.usernameKey);

      if (hotelName == null) {
        print_log("Error: hotelName not found in SharedPreferences");
        // if (mounted) {
        //   screen_massage(context, 'Error: Could not find hotel name for API call.');
        // }
        return;
      }

      final payload = {
        'hotel_name': hotelName,
        'issingle': true,
        'ovweridestock': true,
        'menuItems': [
          {
            // 'id': (item.id != 0 ? item.id : DateTime.now().millisecondsSinceEpoch),
            'syid':item.syid,
            'menu': item.category, 
            'submenu': item.name,
            'h_price': double.tryParse(item.h_price ?? '0') ?? 0.0,
            'f_price': double.tryParse(item.f_price ?? '0') ?? 0.0,
            'ac_price': double.tryParse(item.acSellPrice ?? '0') ?? 0.0,
            'ac_price_half': double.tryParse(item.acSellPriceHalf ?? '0') ?? 0.0,
            'nonac_price': double.tryParse(item.nonAcSellPrice ?? '0') ?? 0.0,
            'nonac_price_half': double.tryParse(item.nonAcSellPriceHalf ?? '0') ?? 0.0,
            'online_price': double.tryParse(item.onlineSellPrice ?? '0') ?? 0.0,
            'online_price_half': double.tryParse(item.onlineSellPriceHalf ?? '0') ?? 0.0,
            'parcel_price': double.tryParse(item.onlineDeliveryPrice ?? '0') ?? 0.0,
            'parcel_price_half': double.tryParse(item.onlineDeliveryPriceHalf ?? '0') ?? 0.0,
            'purchaseprice': double.tryParse(item.purchasePrice ?? '0') ?? 0.0,
            'mrp': double.tryParse(item.mrp ?? '0') ?? 0.0,
            'stock': item.adjustStock ?? 0,
            'available': item.available ?? 0,
            'itemvnv': 0, // This field is not in your MenuItem model
            'description': item.reserved_field,
            'gst': item.gstRate ,
            'itemCode': item.itemCode,
            'barCode': item.barCode ,
            'hsnCode': item.hsnCode ,
          }
        ]
      };

      print_log("Payload to send to server: ${jsonEncode(payload)}");

      http.Response? response = await apiCalls("a", hotelName, payload);
      if (response == null) {
        return;
      }
      if (response.statusCode == 200) {
        item.synced = true;
        _menuItemBox.put(item);
        print_log("Server Response: ${response.body} ${_menuItemBox.get(item.id)}");
      }

      print_log('Server Response: ${response.statusCode} ${response.body}');
    } catch (e) {
      print_log_red('Error sending item to server: $e');
    }
  }

Future<void> ApiCallPage(Box<MenuItem> menuBox) async {


      // print("ApiCallPage started...");
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? "";
      final role = prefs.getString('role') ?? "";
      var hotelName='';
      if(role=="captain"){
        hotelName = getHotelIdentifier(username);
        // hotelName = username.split("_").sublist(0, username.split("_").length - 1).join("_");
        print_log("hotelName $hotelName");
      }else{
         hotelName = username;
         print_log("hotelName $hotelName");
      }

      try {
        http.Response? response = await apiCalls("m",hotelName, {});

        if (response == null) {
          return;
        }
        if (response.statusCode == 200) {
          final jsonData = jsonDecode(response.body);
          final dataList = jsonData['data'];

          print_log("server response $dataList");
          if (dataList is List) {
            List<MenuItem> menuItems = dataList.map((item) => MenuItem.fromJson(item)).toList();
            // print_log("menuItems ${menuItems}");
            saveMenuItemsReliably(menuItems,menuBox);
            
            print_log("✅ Menu loaded from server: ${menuItems.length} items");
          } else {
            print_log_red("Device Not Connected response.statusCode -  ${response.statusCode}");
            // screen_massage(context, "$jsonData");
          }
        } else {
          print_log_red('HTTP Error: ${response.statusCode}: ${response.reasonPhrase}');
          // screen_massage(context, 'HTTP Error: ${response.statusCode}: ${response.reasonPhrase}');
        }
      } catch (error) {
        print_log_red("Device Not Connected ${error}");
        // screen_massage(context, "Device Not Connected ${error}");
      }
    
  }

 void saveMenuItemsReliably(List<MenuItem> menuItems, Box<MenuItem>? menuBox) {
  if (menuBox == null) {
    print_log("found menuItemBox is null in setting");
    return;
  }

  for (var newItem in menuItems) {
    // 1. Try to find the existing item by a unique property (syid or name)
    // Using QueryBuilder to find a match
    final query = menuBox.query(MenuItem_.name.equals(newItem.name)).build();
    final MenuItem? existingItem = query.findFirst();
    query.close(); // Always close your queries

    if (existingItem != null) {
      // ✅ UPDATE: Map the new data to the existing ID
      // In ObjectBox, if the ID matches the one in the DB, it updates.
      print_log("Updating existing menu item: ${newItem.id} with ID: ${existingItem.id}");
      newItem.id = existingItem.id; 
    } 
    
    // Set synced status and save (will insert if id is 0, update if id exists)
    newItem.synced = true;
    menuBox.put(newItem);
  }
}

  


}