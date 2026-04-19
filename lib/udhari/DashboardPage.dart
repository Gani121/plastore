import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test1/purchase/purchase_invoice_page.dart';
import 'AddCustomerPage.dart';
import 'CustomerTransactionsPage.dart';
import '../database_Module/ObjectBoxService.dart';
import '../database_Module/udharicustomer.dart';
import '../utilities.dart';
import './UdhariSyncService.dart';
import 'package:test1/objectbox.g.dart';
import './UdhariSyncService.dart';
import 'dart:async';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // A stream that will emit a new list of customers whenever the data changes.
  late Stream<List<udhariCustomer>> _customerStream;
  StreamSubscription<List<udhariCustomer>>? _customerSubscription;
  late ObjectBoxService objectbox;

  @override
  void initState() {
    super.initState();

    objectbox = Provider.of<ObjectBoxService>(context, listen: false);

    // 1. Setup Stream
    final query = objectbox.store.box<udhariCustomer>().query();

    _customerStream = objectbox.store
      .box<udhariCustomer>()
      .query()
      .watch(triggerImmediately: true)
      .map((q) => q.find())
      .asBroadcastStream();

    final _syncStream = query.watch(triggerImmediately: true).map((q) => q.find());

    // 2. Listen to stream for syncing
    _customerSubscription = _syncStream.listen((customers) async {
      for (var customer in customers) {
        if (!customer.synced) {
          await UdhariSyncService.syncCustomer(customer,objectbox.store.box<udhariCustomer>(),);
        }
      }
    });

    // 3. Optional cloud sync
    _syncWithCloud(objectbox);
  }

  @override
  void dispose() {
    _customerSubscription?.cancel();
    super.dispose();
  }


  // Helper method to check if customer has overdue or due-soon transactions
  Map<String, dynamic> _checkDueStatus(udhariCustomer customer) {
    bool hasOverdue = false;
    bool hasDueTomorrow = false;
    int? dueDays; // Will store days until due (negative for overdue)
    String? dueMessage; // Custom message for due status
    
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime tomorrow = today.add(const Duration(days: 1));
    
    // Check all transactions of this customer
    for (var transaction in customer.transactions) {
      if (transaction.dueDate != null) {
        DateTime dueDate = DateTime( transaction.dueDate!.year, transaction.dueDate!.month,  transaction.dueDate!.day);
        
        if (dueDate.isAtSameMomentAs(today)) {
          hasOverdue = true;
          dueDays = 0;
          dueMessage = 'Today';
          break;
        } else if (dueDate.isAtSameMomentAs(tomorrow)) {
          dueDays = 1;
          hasDueTomorrow = true;
          dueMessage = "Tomorrow";
          break;
        }
      }
    }
    
    return {
      'today': hasOverdue,
      'Tomorrow': hasDueTomorrow,
      'dueDays': dueDays,
      'dueMessage': dueMessage,
    };
  }

  
Future<void> _syncWithCloud(ObjectBoxService ob) async {
  try {
    // 1. Fetch data from server
    List<Map<String, dynamic>> cloudData = await UdhariSyncService.fetchFromCloud();
    final _store = ob.store;
    final customerBox = _store.box<udhariCustomer>();

    for (Map<String, dynamic> cloudCus in cloudData) {
      String ucuniid = cloudCus['external_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      String name = cloudCus['name']?.toString() ?? "Unknown";
      String phone = cloudCus['mobile']?.toString() ?? "";
      String address = cloudCus['adreess']?.toString() ?? "";
      double cloudBalance = double.tryParse(cloudCus['balance']?.toString() ?? '0') ?? 0.0;

      final udhariCustomer currentCustomer = _findOrCreateCustomer(customerBox, ucuniid, name, phone, address);

      if (currentCustomer != null) {
        // ✅ FIX 2: Calculate the difference
        double localBalance = currentCustomer.balance;
        double difference = cloudBalance - localBalance;
        print_log("udhari : ${currentCustomer.name} localBalance $localBalance cloudBalance $cloudBalance difference $difference");

        // ✅ ONLY save if there is a difference
        if (difference.abs() > 0.01) { // Using 0.01 to avoid floating point precision issues
          
          TransactionType type = difference > 0 ? TransactionType.gave : TransactionType.got;
          double transactionAmount = difference.abs();
          String description = "Updated by Admin";

          TransactionUdhari newTransaction = TransactionUdhari.create(
            syid:ganarateID(), 
            amount: transactionAmount,
            type: type,
            date: DateTime.now(),
            description: description,
            synced: true,
          );

          // Link the transaction to the customer
          newTransaction.customer.target = currentCustomer;

          // Save the transaction
          _store.box<TransactionUdhari>().put(newTransaction);
          
          // Update the customer's ToMany relationship
          currentCustomer.transactions.add(newTransaction);
          customerBox.put(currentCustomer);

          print_log("✅ udhari Sync: ${currentCustomer.name} updated. New Balance: $cloudBalance (Adj: $transactionAmount as ${type.name})");
        } else {
          print_log("ℹ️ udhari Sync: ${currentCustomer.name} is already up to date.");
        }
      }
    }
  } catch (e) {
    print_log_red("❌ Error in udhari _syncWithCloud: $e");
  }
}

  udhariCustomer _findOrCreateCustomer(Box<udhariCustomer> customerBox, String ucuniid, String name, String phone,String adreess) {
    //debugPrint("currentCustomer $name ");

    final query = customerBox.query(udhariCustomer_.name.equals(name.trim())).build();
    udhariCustomer? existingCustomer = query.findFirst();
    query.close(); // Always close your queries

    if (existingCustomer != null) {
      // Customer was found, return them
      //debugPrint("Udhari currentCustomer Found existing customer: ${existingCustomer.name}");
      return existingCustomer;
    } else {
      // Customer not found, create a new one
      //debugPrint("Udhari currentCustomer Creating new customer: $name");
      final newCustomer = udhariCustomer(
        syid: int.tryParse(ucuniid) ?? ganarateID(),
        ucuniid : ucuniid,
        name: name.trim(),
        phone: phone.isNotEmpty ? phone.trim() : '',
        adreess: adreess.isNotEmpty ? adreess.trim() : '',
      );
      
      // Save the new customer to the box and return them
      customerBox.put(newCustomer);
      return newCustomer;
    }
  }



  // Method to delete a customer
  void _deleteCustomer(udhariCustomer customer) {
    final objectbox = Provider.of<ObjectBoxService>(context, listen: false);
    objectbox.store.box<udhariCustomer>().remove(customer.id);

    UdhariSyncService.deleteCustomer((customer.ucuniid).toString());

    // Show a confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${customer.name} has been deleted.'),
        backgroundColor: Colors.red,
      ),
    );
  }

// Build the due date indicator on the avatar
Widget _buildDueDateIndicator(udhariCustomer customer) {
  var dueStatus = _checkDueStatus(customer);
  
  if (dueStatus['hasOverdue'] == true) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(
        Icons.warning,
        color: Colors.white,
        size: 10,
      ),
    );
  } else if (dueStatus['hasDueTomorrow'] == true) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        color: Colors.orange,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(
        Icons.alarm,
        color: Colors.white,
        size: 10,
      ),
    );
  } else if (dueStatus['dueDays'] != null && dueStatus['dueDays'] <= 3) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        '${dueStatus['dueDays']}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
  
  return const SizedBox.shrink();
}

// Build warning text for due dates
Widget _buildDueDateWarning(udhariCustomer customer) {
  var dueStatus = _checkDueStatus(customer);
  
  if (dueStatus['today']) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Text(
        dueStatus['dueMessage'] ?? 'Due Today!',
        style: TextStyle(
          color: Colors.orange.shade700,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  } 
  else if (dueStatus['Tomorrow']) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(
        dueStatus['dueMessage'] ?? 'Due Tomorrow',
        style: TextStyle(
          color: Colors.blue.shade700,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  return const SizedBox.shrink();
}

// Simple check if customer has any due transactions (for the warning icon)
bool _hasDueTransaction(udhariCustomer customer) {
  var dueStatus = _checkDueStatus(customer);
  return dueStatus['hasOverdue'] == true || 
         dueStatus['hasDueTomorrow'] == true || 
         dueStatus['dueDays'] != null;
}




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Udhari"),
        centerTitle: true,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download_sharp),
            onPressed: () async {
              await _syncWithCloud(objectbox);
            },
          ),
        ],
      ),
      // StreamBuilder will listen to _customerStream and rebuild the UI on new data.
      body: StreamBuilder<List<udhariCustomer>>(
        stream: _customerStream,
        builder: (context, snapshot) {
          // Show a loading indicator while waiting for data
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final customers = snapshot.data!;

          // Sort customers: High balance (positive) to Low balance (negative)
          customers.sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));

          // Calculate totals based on the current list of customers from the stream
          double totalToGive = 0;
          double totalToGet = 0;
          for (var customer in customers) {
            if (customer.balance > 0) {
              totalToGet += customer.balance;
            } else if (customer.balance < 0) {
              totalToGive += customer.balance.abs();
            }
          }
          
          return Column(
            children: [
              // --- Totals Section ---
              _buildTotalsCard(totalToGive, totalToGet),
              const Divider(),

              // --- Customer List ---
              Expanded(
                child: ListView.builder(
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    final balance = customer.balance;

                    // Wrap ListTile with Dismissible to enable swipe-to-delete
                    return Dismissible(
                      // A unique key is required for each Dismissible item
                      key: Key(customer.id.toString()),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        // This callback is triggered when the item is swiped away
                        _deleteCustomer(customer);
                      },
                      // This is the background that appears when you swipe
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: // In your StreamBuilder, inside ListView.builder
                        ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                child: Text(
                                  (customer.name.isNotEmpty) 
                                      ? customer.name.substring(0, 1).toUpperCase() 
                                      : "?", // Show '?' if name is empty
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              // Due date indicator
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: _buildDueDateIndicator(customer),
                              ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  customer.name, 
                                  style: const TextStyle(fontWeight: FontWeight.bold)
                                ),
                              ),
                              // Due date warning text if needed
                              // _buildDueDateWarning(customer),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${balance.abs().toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: balance > 0 ? Colors.green.shade700 : (balance < 0 ? Colors.red.shade700 : Colors.grey),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              _buildDueDateWarning(customer),
                                // const Icon(  
                                //   Icons.warning_amber_rounded,
                                //   color: Colors.orange,
                                //   size: 16,
                                // ),
                            ],
                          ),
                          subtitle: Text(balance > 0 ? 'You will get' : (balance < 0 ? 'You will give' : 'Settled')),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CustomerTransactionsPage(customer: customer),
                              ),
                            );
                          },
                        )
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddCustomerPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text("Add Customer"),
      ),
    );
  }

  Widget _buildTotalsCard(double totalToGive, double totalToGet) {
    addToPrefs("You_will_give", totalToGive.toString());
    addToPrefs("You_will_get", totalToGet.toString());
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(
                  '₹${totalToGive.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Text('You will give'),
              ],
            ),
            const SizedBox(height: 40, child: VerticalDivider()),
            Column(
              children: [
                Text(
                  '₹${totalToGet.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Text('You will get'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}