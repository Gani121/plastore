import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'AddCustomerPage.dart';
import 'CustomerTransactionsPage.dart';
import '../cartprovier/ObjectBoxService.dart';
import 'udharicustomer.dart';

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
    
    // .watch() creates a stream. We use .map() to transform the stream of 'Query' objects
    // into a stream of 'List<udhariCustomer>', which is easier to use in StreamBuilder.
    // triggerImmediately: true ensures the stream provides the current data right away.
    _customerStream = objectbox.store.box<udhariCustomer>()
        .query()
        .watch(triggerImmediately: true)
        .map((query) => query.find());
  }

  // Method to delete a customer
  void _deleteCustomer(udhariCustomer customer) {
    final objectbox = Provider.of<ObjectBoxService>(context, listen: false);
    objectbox.store.box<udhariCustomer>().remove(customer.id);

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
                          child: Text(customer.name.substring(0, 1)),
                        ),
                        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Text(
                          '₹${balance.abs().toStringAsFixed(2)}',
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