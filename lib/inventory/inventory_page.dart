import 'package:flutter/material.dart';
import 'add_item_page.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'item_ledger_page.dart';
import 'dart:io';
import '../objectbox.g.dart';
import 'package:objectbox/objectbox.dart';
import '../database_Module/menu_item.dart';
import '../database_Module/cunsuption.dart'; // Adjust path
import 'package:test1/database_Module/ObjectBoxService.dart';
import 'package:provider/provider.dart';
import '../theme_setting/theme_provider.dart';
import 'package:test1/l10n/app_localizations.dart';
import '../utilities.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/inventory/InventoryMasterPage.dart';
import 'package:test1/inventory/sync_service.dart';

class InventoryPage extends StatefulWidget {
  //final Store store;

  const InventoryPage({super.key});

  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final Box<MenuItem> _menuItemBox;
  late Box<InventoryItem> _inventoryBox;
  late Box<ItemConsumption> _consumptionBox;
  List<MenuItem> _items = [];
  List<MenuItem> _filteredItems = []; // To hold search results
  final TextEditingController _searchController = TextEditingController();
  // Replace ScrollController with ItemScrollController and ItemPositionsListener
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  bool _isSearching = false;
  bool _showCategories = false;

  // For the alphabetical scrollbar
  final Map<String, int> _alphabetIndexMap = {};
  final List<String> _alphabets = [];
  String _currentAlphabet = '';
  int? totalItems;
  final sync = SyncService();

  @override
  void initState() {
    super.initState();
    final _store = Provider.of<ObjectBoxService>(context, listen: false).store;
    _menuItemBox = _store.box<MenuItem>();
    _inventoryBox = _store.box<InventoryItem>();
    _consumptionBox = _store.box<ItemConsumption>();
    _searchController.addListener(_filterItems);
    // Add a listener to update the active alphabet while scrolling
    _itemPositionsListener.itemPositions.addListener(_onScroll);
    // Load items after the first frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadItems();
      sync.addNewStock(null, _inventoryBox);
      sync.saveRecipeToServer(null, null, null, _consumptionBox);
      _sendItemsToServer();
      // OR if you want to await it (inside an async function)
      Future.delayed(Duration(seconds: 1), () {
        SyncService().fetchFromServer(_store);
      });
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = _menuItemBox.getAll();
    // Sort items alphabetically by name (case-insensitive)
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _items = items;
      totalItems = items.length;
      _filterItems(); // This will also update the alphabet index
    });
  }

  Future<void> _sendItemsToServer() async {
    final items = _menuItemBox.getAll();
    // Sort items alphabetically by name (case-insensitive)
    for (var item in items) {
      if(!item.synced){
        print_log("sending item to server: ${item.name} ${!item.synced}");
        await sync.sendItemtoServer(item,_menuItemBox);
      }
    }
  }

  Map<String, List<MenuItem>> _getGroupedItems() {
    Map<String, List<MenuItem>> grouped = {};
    for (var item in _filteredItems) {
      String cat = item.category;
      if (!grouped.containsKey(cat)) {
        grouped[cat] = [];
      }
      grouped[cat]!.add(item);
    }
    return grouped;
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems =_items.where((item) => item.name.toLowerCase().contains(query)).toList();
      _updateAlphabetIndex();
    });
  }

  void _updateAlphabetIndex() {
    _alphabetIndexMap.clear();
    _alphabets.clear();
    for (int i = 0; i < _filteredItems.length; i++) {
      // Ensure item name is not empty to prevent errors
      if (_filteredItems[i].name.isNotEmpty) {
        String firstLetter = _filteredItems[i].name[0].toUpperCase();
        if (!_alphabetIndexMap.containsKey(firstLetter)) {
          _alphabetIndexMap[firstLetter] = i;
          _alphabets.add(firstLetter);
        }
      }
    }
    _alphabets.sort(); // Ensure alphabets are in order
  }

  void _onScroll() {
    // Get the index of the first visible item
    final firstVisibleItemIndex = _itemPositionsListener.itemPositions.value
        .where((position) => position.itemLeadingEdge < 1)
        .map((position) => position.index)
        .firstOrNull;

    if (firstVisibleItemIndex != null && firstVisibleItemIndex < _filteredItems.length) {
      // Ensure the name is not empty before accessing its first character
      if (_filteredItems[firstVisibleItemIndex].name.isNotEmpty) {
        final currentFirstLetter = _filteredItems[firstVisibleItemIndex].name[0].toUpperCase();
        if (_currentAlphabet != currentFirstLetter) {
          setState(() => _currentAlphabet = currentFirstLetter);
        }
      }
    }
  }

  void _scrollToIndex(String alphabet) {
    final index = _alphabetIndexMap[alphabet];
    if (index != null) {
      _itemScrollController.jumpTo(index: index,); // duration: const Duration(milliseconds: 100)
    }
  }


Future<void> _showAdjustStockDialog(BuildContext context, MenuItem item) async {
  final TextEditingController controller = TextEditingController();
  bool isOverride = false;

  await showDialog(
    context: context,
    builder: (context) {
      bool _isProcessing = false;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Adjust Stock - ${item.name}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current stock display
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Current Stock:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "${item.adjustStock ?? 0}",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Enter quantity to add/reduce",
                    hintText: "Use -ve for reduction, e.g., -5",
                    border: OutlineInputBorder(),
                    // prefixIcon: Icon(isOverride ? I.edit_note : I.add_box),
                  ),
                ),
                const SizedBox(height: 10),
                // Info text based on mode
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      // Icon(
                      //   // isOverride ? I.warning_amber : I.info,
                      //   size: 16,
                      //   color: isOverride ? Colors.orange : Colors.blue,
                      // ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text( "Add mode: Use positive number(1) to add, negative number(-1) to reduce",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Override switch
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //   children: [
                //     Text(
                //       "Override Mode",
                //       style: TextStyle(
                //         fontWeight: isOverride ? FontWeight.bold : FontWeight.normal,
                //         color: isOverride ? Colors.orange : null,
                //       ),
                //     ),
                //     Switch(
                //       value: isOverride,
                //       activeColor: Colors.orange,
                //       onChanged: (val) {
                //         setDialogState(() {
                //           isOverride = val;
                //           controller.clear(); // Clear input when switching modes
                //         });
                //       },
                //     ),
                //   ],
                // ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _isProcessing ? null : () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                onPressed: _isProcessing ? null : () async {
                  setDialogState(() {
                    _isProcessing = true;
                  });

                  try {

                    final int addValue = int.tryParse(controller.text) ?? 0;
                    int newStock = 0;
                    
                    // Validate input
                    if (controller.text.isEmpty) {
                      throw Exception('Please enter a value');
                    }

                    // Calculate new stock
                    int currentStock = item.adjustStock ?? 0;
                    newStock = currentStock + addValue;

                    print_log("Calculated new stock: $currentStock + $addValue = $newStock");
                    

                    // Validate new stock is not negative
                    if (newStock < 0) {
                      throw Exception('Stock cannot be negative. Current: $currentStock, Change: $addValue');
                    }

                    // Send to server FIRST (to ensure server sync)
                    try {
                      item.synced = false;
                      final b = await sendStockToServer(item, addValue, isOverride:isOverride);
                      if(b){
                        item.synced = true;
                      }
                      
                      // Update local stock only after successful server update
                      item.adjustStock = newStock;
                      
                      // Save to local database
                      // _menuItemBox.get(item.id); // Update the in-memory object
                      _menuItemBox.put(item);
                      print_log("✅ Stock updated locally: ${item.id} -> ${_menuItemBox.get(item.id)?.adjustStock}");

                      if (context.mounted) {
                        Navigator.pop(context); // Close dialog
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("✅ Stock updated to $newStock"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        
                        // Refresh UI
                        setState(() {});
                      }
                    } catch (serverError) {
                      // Server update failed
                      print_log('❌ Server update failed: $serverError');
                      
                      if (context.mounted) {
                        // Ask user if they want to retry or proceed with local only
                        bool? retry = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Server Sync Failed'),
                            content: Text('Failed to update stock on server. Do you want to retry?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('Local Only'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        );

                        if (retry == true) {
                          // Retry server update
                          setDialogState(() {
                            _isProcessing = false;
                          });
                          return; // This will restart the process
                        } else {
                          // Proceed with local update only
                          item.synced = false;
                          item.adjustStock = newStock;
                          _menuItemBox.put(item);
                          print_log("✅ Stock updated locally: ${item.id} -> ${_menuItemBox.get(item.id)?.adjustStock}");
                          
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("⚠️ Stock updated locally only"),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          setState(() {});
                        }
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("❌ Error: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    setDialogState(() {
                      _isProcessing = false;
                    });
                  }
                },
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("UPDATE"),
              ),
            ],
          );
        },
      );
    },
  );
}



  // Future<void> sendItemtoServer(MenuItem item) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   try {
      
  //     final hotelName = prefs.getString(AppConstants.usernameKey);

  //     if (hotelName == null) {
  //       print_log("Error: hotelName not found in SharedPreferences");
  //       if (mounted) {
  //         screen_massage(context, 'Error: Could not find hotel name for API call.');
  //       }
  //       return;
  //     }

  //     final payload = {
  //       'hotel_name': hotelName,
  //       'issingle': true,
  //       'menuItems': [
  //         {
  //           // 'id': item.itemCode?.isNotEmpty == true ? item.itemCode : (item.id != 0 ? item.id.toString() : 'item_${DateTime.now().millisecondsSinceEpoch}'),
  //           'menu': item.category,
  //           'submenu': item.name,
  //           'h_price': double.tryParse(item.h_price ?? '0') ?? 0.0,
  //           'f_price': double.tryParse(item.f_price ?? '0') ?? 0.0,
  //           'ac_price': double.tryParse(item.acSellPrice ?? '0') ?? 0.0,
  //           'ac_price_half': double.tryParse(item.acSellPriceHalf ?? '0') ?? 0.0,
  //           'nonac_price': double.tryParse(item.nonAcSellPrice ?? '0') ?? 0.0,
  //           'nonac_price_half': double.tryParse(item.nonAcSellPriceHalf ?? '0') ?? 0.0,
  //           'online_price': double.tryParse(item.onlineSellPrice ?? '0') ?? 0.0,
  //           'online_price_half': double.tryParse(item.onlineSellPriceHalf ?? '0') ?? 0.0,
  //           'parcel_price': double.tryParse(item.onlineDeliveryPrice ?? '0') ?? 0.0,
  //           'parcel_price_half': double.tryParse(item.onlineDeliveryPriceHalf ?? '0') ?? 0.0,
  //           'purchaseprice': double.tryParse(item.purchasePrice ?? '0') ?? 0.0,
  //           'mrp': double.tryParse(item.mrp ?? '0') ?? 0.0,
  //           'stock': item.adjustStock ?? 0,
  //           'available': item.available ?? 0,
  //           'itemvnv': 0, // This field is not in your MenuItem model
  //           'description': item.reserved_field,
  //           'gst': item.gstRate ,
  //           'itemCode': item.itemCode,
  //           'barCode': item.barCode ,
  //           'hsnCode': item.hsnCode ,
  //         }
  //       ]
  //     };

  //     print_log("Payload to send to server: ${jsonEncode(payload)}");

  //     http.Response? response = await apiCalls("a", hotelName, payload);
  //       if (response == null) {
  //         return;
  //       }

  //     print_log('Server Response: ${response.statusCode} ${response.body}');
  //   } catch (e) {
  //     print_log_red('Error sending item to server: $e');
  //   }
  // }

  Widget _buildItemCard(MenuItem item) {
    // final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;

    // Image path logic
    String safeName = item.name;
    String fileName = "$safeName.jpeg";
    String imagePath =
        "/storage/emulated/0/Android/data/${AppConstants.test_version}/files/pictures/menu_images/$fileName";
    
    if (!File(imagePath).existsSync()) {
      fileName = "$safeName.jpg";
      imagePath =
          "/storage/emulated/0/Android/data/${AppConstants.test_version}/files/pictures/menu_images/$fileName";
    }

    return GestureDetector(
      onTap: () {
        if (_isSearching) {
          setState(() {
            _searchController.clear();
            _isSearching = false;
          });
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemLedgerPage(item: item, store: store),
          ),
        ).then((_) => _loadItems());
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              File(imagePath).existsSync()
                  ? Image.file(File(imagePath),
                      width: 60, height: 60, fit: BoxFit.fill)
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
              const SizedBox(width: 12),
              
              // Item Details Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                        "${AppLocalizations.of(context)!.barcode}: ${item.barCode ?? 'N/A'}",
                        style: const TextStyle(fontSize: 12)),
                    Text("₹ ${item.f_price}",
                        style: const TextStyle(fontSize: 14)),
                    Text(
                        "${AppLocalizations.of(context)!.currentStock}: ${(item.adjustStock ?? 0) < 0 ? 0 : item.adjustStock}",
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 6),
                    ElevatedButton(
                      onPressed: () async {
                        await _showAdjustStockDialog(context, item);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        minimumSize: const Size(100, 20),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: Text(AppLocalizations.of(context)!.adjustStock, 
                            style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check, color: Colors.green),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildCategoryView() {
  final groupedItems = _getGroupedItems();
  final categories = groupedItems.keys.toList()..sort();

  return ListView.builder(
    padding: const EdgeInsets.all(12),
    itemCount: categories.length,
    itemBuilder: (context, index) {
      String category = categories[index];
      List<MenuItem> itemsInCategory = groupedItems[category]!;

      return ExpansionTile(
        title: Text("$category (${itemsInCategory.length})", 
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
        children: itemsInCategory.map((item) => _buildItemCard(item)).toList(),
      );
    },
  );
}

Widget _buildItemView() {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

  if (_filteredItems.isEmpty) {
    return Center(
      child: Text(
        _isSearching
            ? AppLocalizations.of(context)!.noItemMatch
            : AppLocalizations.of(context)!.noItemFound,
      ),
    );
  }

  return ScrollablePositionedList.builder(
    itemScrollController: _itemScrollController,
    itemPositionsListener: _itemPositionsListener,
    itemCount: _filteredItems.length,
    // Add padding to the right to avoid overlapping with the scrollbar
    padding: const EdgeInsets.fromLTRB(12, 12, 30, 12),
    itemBuilder: (context, index) {
      final item = _filteredItems[index];
      
      // Determine if a header should be shown for a new letter
      final bool showHeader = item.name.isNotEmpty &&
          (index == 0 ||
              (_filteredItems[index - 1].name.isEmpty ||
                  item.name[0].toUpperCase() !=
                      _filteredItems[index - 1].name[0].toUpperCase()));

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                item.name[0].toUpperCase(),
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryColor),
              ),
            ),
          _buildItemCard(item), // Uses the reusable card method we created
        ],
      );
    },
  );
}

Widget _buildAlphabetScrollbar() {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

  if (_alphabets.isEmpty || _isSearching) {
    return const SizedBox.shrink();
  }

  return Positioned(
    right: 0,
    top: 0,
    bottom: 0,
    child: Container(
      width: 28,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _alphabets.map((alphabet) {
            final bool isActive = _currentAlphabet == alphabet;
            return GestureDetector(
              onTap: () => _scrollToIndex(alphabet),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Text(
                  alphabet,
                  style: TextStyle(
                    color: isActive ? Colors.white : themeProvider.primaryColor,
                    fontWeight: FontWeight.bold,
                    backgroundColor: isActive
                        ? themeProvider.primaryColor
                        : Colors.transparent,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ),
  );
}











  @override
  Widget build(BuildContext context) {
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    final themeProvider = Provider.of<ThemeProvider>(context);
    //final box = store.box<YourModel>();

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration:  InputDecoration(
                  hintText: '${AppLocalizations.of(context)!.searchItems}...',
                  iconColor: Colors.white,
                  // prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              )
            :  Text(AppLocalizations.of(context)!.itemList,style: TextStyle(color: Colors.white)),
                backgroundColor: themeProvider.primaryColor, // Colors.purple.shade700,
                actions: _isSearching
            ? [
                IconButton(
                  icon: const Icon(Icons.clear,color: Colors.white,),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _isSearching = false;
                    });
                  },
                ),
                
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search,color: Colors.white,),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
                // When not searching, show both sync and search buttons
                IconButton(
                  icon: const Icon(Icons.cloud_download, color: Colors.white),
                  onPressed: () async {
                    // Show loading indicator
                    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Syncing with cloud...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    
                    // Perform sync
                    await SyncService().fetchFromServer(store);
                    
                    // Update UI
                    if (mounted) {
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: Row(
                    children: [
                      // Update the ITEMS button
                          TextButton(
                            onPressed: () => setState(() => _showCategories = false),
                            child: Text(
                              "${AppLocalizations.of(context)!.inventoryHeader} (${_items.length})",
                              style: TextStyle(
                                color: !_showCategories ? Colors.purple : Colors.grey, // Highlight if active
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                          onPressed: () => setState(() => _showCategories = true),
                          child: Text(
                            "CATEGORIES",
                            style: TextStyle(
                              color: _showCategories ? Colors.purple : Colors.grey, // Highlight if active
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InventoryMasterPage(
                                    store: store, // Pass your ObjectBox store here
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              "CUNSUMPTION", 
                              style: TextStyle(
                                color: Color.fromARGB(255, 3, 7, 255),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          _filteredItems.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.noItemFound))
              : _showCategories 
                  ? _buildCategoryView() // New method below
                  : _buildItemView(),    // Move your existing ScrollablePositionedList here
          
          // Alphabetical Scrollbar (Only show for Item View)
          if (_alphabets.isNotEmpty && !_isSearching && !_showCategories)
            _buildAlphabetScrollbar(),
        ],
      ),
      
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddItemPage(store: store,totalItems:totalItems)),
          );
          _loadItems(); // Refresh after adding new item
        },
        label: Text(AppLocalizations.of(context)!.newItem,style: TextStyle(color: Colors.white),),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: themeProvider.primaryColor, //Colors.purple.shade700,
      ),
    );
  }
}
