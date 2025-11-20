import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../objectbox.g.dart';
import 'package:objectbox/objectbox.dart';
import 'add_item_page.dart';
import 'package:test1/l10n/app_localizations.dart';

class ItemLedgerPage extends StatefulWidget {
  final MenuItem item;
  final Store store;

  const ItemLedgerPage({super.key, required this.item, required this.store});

  @override
  State<ItemLedgerPage> createState() => _ItemLedgerPageState();
}

class _ItemLedgerPageState extends State<ItemLedgerPage> {
  late MenuItem currentItem;
  late List<Map<String, dynamic>> transactions;

  @override
  void initState() {
    super.initState();
    currentItem = widget.item;
    _generateTransactions();
  }

  void _generateTransactions() {
    transactions = List.generate(6, (index) {
      return {
        'type': 'Sale',
        'date': '2024-12-${10 + index}',
        'quantity': index + 1,
        'stock': (currentItem.adjustStock ?? 0) - index,
      };
    });
  }

  void _refreshItem() {
    final box = widget.store.box<MenuItem>();
    final updated = box.get(currentItem.id);
    if (updated != null) {
      setState(() {
        currentItem = updated;
        _generateTransactions();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var item = currentItem; // ✅ always use this reference
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 25,
              ),
            ),
            Row(
              children: [
                Text(
                  "ID: ${item.id}",
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(width: 16),
                Text(
                  "Barcode: ${item.barCode ?? 'N/A'}",
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.purple.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              final updatedItem = await Navigator.push<MenuItem?>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddItemPage(store: widget.store, item: item),
                ),
              );

              if (updatedItem != null) {
                final box = widget.store.box<MenuItem>();
                final freshItem = box.get(updatedItem.id);
                //print('🔥 Fresh Item Fetched: $freshItem');

                if (freshItem != null) {
                  setState(() {
                    item = freshItem;
                    _generateTransactions();
                    //print('✅ setState called with: ${item.name}');
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {});
                  });
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title:  Text(AppLocalizations.of(context)!.deleteItem),
                  content:  Text(
                    AppLocalizations.of(context)!.deleteNote,
                  ),
                  actions: [
                    TextButton(
                      child:  Text(AppLocalizations.of(context)!.cancel),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: Text(AppLocalizations.of(context)!.delete),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                final box = widget.store.box<MenuItem>();
                final query = box
                    .query(MenuItem_.name.equals(item.name))
                    .build();
                final itemsToDelete = query.find();

                for (var target in itemsToDelete) {
                  box.remove(target.id);
                }

                query.close();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.deleteItemSuccess)),
                );
              }
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📦 Summary Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${AppLocalizations.of(context)!.stock}: ${item.adjustStock ?? 0}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // 📜 Transactions List
            Text(
              AppLocalizations.of(context)!.recent_tran,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            // const SizedBox(height: 12),
            // ListView.builder(
            //   shrinkWrap: true,
            //   physics: const NeverScrollableScrollPhysics(),
            //   itemCount: transactions.length,
            //   itemBuilder: (context, index) {
            //     final tx = transactions[index];
            //     return Card(
            //       margin: const EdgeInsets.only(bottom: 10),
            //       child: ListTile(
            //         leading: Icon(
            //           tx['type'] == 'Sale'
            //               ? Icons.check_circle
            //               : Icons.arrow_circle_up,
            //           color: tx['type'] == 'Sale' ? Colors.green : Colors.blue,
            //         ),
            //         title: Text("${tx['type']} - Qty: ${tx['quantity']}"),
            //         subtitle: Text("Date: ${tx['date']}"),
            //         trailing: Text("Stock: ${tx['stock']}"),
            //       ),
            //     );
            //   },
            // ),
          ],
        ),
      ),
    );
  }
}
