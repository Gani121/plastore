import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'AddCustomerPage.dart';
import 'CustomerTransactionsPage.dart';
import '../database_Module/ObjectBoxService.dart';
import '../database_Module/udharicustomer.dart';
import '../utilities.dart';
import './UdhariSyncService.dart';
import 'package:test1/objectbox.g.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // A stream that will emit a new list of customers whenever the data changes.
  late Stream<List<udhariCustomer>> _customerStream;

  @override
  void initState() {
    super.initState();
    // Initialize the stream here.
    // We get the ObjectBoxService instance once and set up the stream to watch for changes.
    final objectbox = Provider.of<ObjectBoxService>(context, listen: false);
    
    // 1. Setup Stream
    // .watch() creates a stream. We use .map() to transform the stream of 'Query' objects
    // into a stream of 'List<udhariCustomer>', which is easier to use in StreamBuilder.
    // triggerImmediately: true ensures the stream provides the current data right away.
    _customerStream = objectbox.store.box<udhariCustomer>()
        .query()
        .watch(triggerImmediately: true)
        .map((query) => query.find());

    // 2. Trigger Cloud Sync on Load (Optional but recommended)
    _syncWithCloud(objectbox);
  }

  
Future<void> _syncWithCloud(ObjectBoxService ob) async {
  try {
    // 1. Fetch data from server
    List<Map<String, dynamic>> cloudData = await UdhariSyncService.fetchFromCloud();
    final _store = ob.store;
    final customerBox = _store.box<udhariCustomer>();

    for (Map<String, dynamic> cloudCus in cloudData) {
      String name = cloudCus['name']?.toString() ?? "Unknown";
      String phone = cloudCus['mobile']?.toString() ?? "";
      String address = cloudCus['adreess']?.toString() ?? "";
      
      // ✅ FIX 1: Parse the 'balance' field from the cloud, not 'adreess'
      double cloudBalance = double.tryParse(cloudCus['balance']?.toString() ?? '0') ?? 0.0;

      final udhariCustomer currentCustomer = _findOrCreateCustomer(customerBox, name, phone, address);

      if (currentCustomer != null) {
        // ✅ FIX 2: Calculate the difference
        double localBalance = currentCustomer.balance;
        double difference = cloudBalance - localBalance;
        print_log("udhari : ${currentCustomer.name} localBalance $localBalance cloudBalance $cloudBalance difference $difference");

        // ✅ ONLY save if there is a difference
        if (difference.abs() > 0.01) { // Using 0.01 to avoid floating point precision issues
          
          /* LOGIC CHECK:
            Your getter: balance = (Gave) - (Got)
            If difference > 0: Cloud balance is higher -> We need to ADD a 'Gave' entry.
            If difference < 0: Cloud balance is lower -> We need to ADD a 'Got' entry.
          */
          
          TransactionType type = difference > 0 ? TransactionType.gave : TransactionType.got;
          double transactionAmount = difference.abs();
          String description = "Updated by Admin";

          TransactionUdhari newTransaction = TransactionUdhari.create(
            amount: transactionAmount,
            type: type,
            date: DateTime.now(),
            description: description,
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

  udhariCustomer _findOrCreateCustomer(Box<udhariCustomer> customerBox, String name, String phone,String adreess) {
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

    UdhariSyncService.deleteCustomer((customer.id).toString());

    // Show a confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${customer.name} has been deleted.'),
        backgroundColor: Colors.red,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Udhari"),
        centerTitle: true,
        elevation: 1,
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
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            (customer.name.isNotEmpty) 
                                ? customer.name.substring(0, 1).toUpperCase() 
                                : "?", // Show '?' if name is empty
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Text('₹${balance.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            color: balance > 0 ? Colors.green.shade700 : (balance < 0 ? Colors.red.shade700 : Colors.grey),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
                      ),
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