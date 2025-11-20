import 'package:flutter/material.dart';
import 'add_item_page.dart';
import 'item_ledger_page.dart';
import 'dart:io';
import '../objectbox.g.dart';
import 'package:objectbox/objectbox.dart';
import '../models/menu_item.dart';
import 'package:test1/cartprovier/ObjectBoxService.dart';
import 'package:provider/provider.dart';
import '../theme_setting/theme_provider.dart';
import 'package:test1/l10n/app_localizations.dart';

class InventoryPage extends StatefulWidget {
  //final Store store;

  const InventoryPage({super.key});

  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final Box<MenuItem> _menuItemBox;
  List<MenuItem> _items = [];
  List<MenuItem> _filteredItems = []; // To hold search results
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    final store = Provider.of<ObjectBoxService>(context, listen: false).store;
    _menuItemBox = store.box<MenuItem>();
    _loadItems();
    _searchController.addListener(_filterItems);
    _filterItems();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = _menuItemBox.getAll();
    setState(() {
      _items = items;
    });
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items
          .where((item) => item.name.toLowerCase().contains(query))
          .toList();
    });
  }


    Future<void> _showAdjustStockDialog(BuildContext context, MenuItem item) async {
    final TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("${AppLocalizations.of(context)!.print} ${item.name}"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.enter_qty_add,
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final store = Provider.of<ObjectBoxService>(context, listen: false).store;
                final Box<MenuItem> menuItemBox = store.box<MenuItem>();

                final int addValue = int.tryParse(controller.text) ?? 0;
                if (addValue <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.enter_valid_number)),
                  );
                  return;
                }

                // Update the stock
                int currentStock = item.adjustStock ?? 0;
                item.adjustStock = currentStock + addValue;

                // Save to database
                menuItemBox.put(item);

                Navigator.pop(context); // Close dialog

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("✅ Stock updated to ${item.adjustStock}")),
                );
                // _filteredItems
                setState(() {});
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
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
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              )
            :  Text(AppLocalizations.of(context)!.itemList),
        backgroundColor: themeProvider.primaryColor, // Colors.purple.shade700,
        actions: _isSearching
            ? [
                IconButton(
                  icon: const Icon(Icons.clear),
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
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
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
                      Expanded(
                        child: TextButton(
                          onPressed: () {},
                          child: Text(
                            "${AppLocalizations.of(context)!.inventoryHeader} (${_items.length})",
                            style: const TextStyle(color: Colors.purple),
                          ),
                        ),
                      ),
                      //   Expanded(
                      //     child: TextButton(
                      //       onPressed: () {},
                      //       child: const Text(
                      //         "CATEGORIES",
                      //         style: TextStyle(color: Colors.grey),
                      //       ),
                      //     ),
                      //   ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _filteredItems.isEmpty && _isSearching
          ? Center(
              child: Text(
                _isSearching
                    ? AppLocalizations.of(context)!.noItemMatch
                    : AppLocalizations.of(context)!.noItemFound,
              ),
            )
          : ListView.builder(
              itemCount: _filteredItems.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                String safeName = item.name;


                String fileName = "${safeName}.jpeg";
                String imagePath = "/storage/emulated/0/Android/data/com.orbipay.test6/files/pictures/menu_images/$fileName";
                File imageFile = File(imagePath);
                bool hasImage = imageFile.existsSync();
                    // Check if the file exists
                if (!hasImage) {
                  String fileName = "${safeName}.jpg";
                  imagePath = "/storage/emulated/0/Android/data/com.orbipay.test6/files/pictures/menu_images/$fileName";
                  File imageFile = File(imagePath);
                  hasImage = imageFile.existsSync();
                }
                

                return GestureDetector(
                  onTap: () {
                    // Clear search and reset state before navigating
                    if (_isSearching) {
                      setState(() {
                        _searchController.clear();
                      });
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ItemLedgerPage(item: item, store: store),
                      ),
                    ).then((_) => _loadItems()); // Refresh after returning
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          File(imagePath).existsSync()
                              ? Image.file(
                                  File(imagePath),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.fill,
                                )
                              : Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.grey,
                                  ),
                                ),

                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "${AppLocalizations.of(context)!.barcode}: ${item.barCode ?? 'N/A'}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  "₹ ${item.f_price}",
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Text(
                                  "${AppLocalizations.of(context)!.currentStock}: ${item.adjustStock}",
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                ElevatedButton(
                                  onPressed: () async {
                                    await _showAdjustStockDialog(context, item);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
                                    minimumSize: const Size(100, 20),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                  child: Text(AppLocalizations.of(context)!.adjustStock),
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
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddItemPage(store: store)),
          );
          _loadItems(); // Refresh after adding new item
        },
        label: Text(AppLocalizations.of(context)!.newItem),
        icon: const Icon(Icons.add),
        backgroundColor: themeProvider.primaryColor, //Colors.purple.shade700,
      ),
    );
  }
}
