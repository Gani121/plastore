import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony_sms/telephony_sms.dart';
import 'package:url_launcher/url_launcher.dart';
import '../cartprovier/ObjectBoxService.dart';
import 'udharicustomer.dart';
import '../objectbox.g.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart'; // Added for Date formatting

class CustomerTransactionsPage extends StatefulWidget {
  final udhariCustomer customer;
  const CustomerTransactionsPage({super.key, required this.customer});

  @override
  State<CustomerTransactionsPage> createState() =>
      _CustomerTransactionsPageState();
}

class _CustomerTransactionsPageState extends State<CustomerTransactionsPage> {
  late Stream<udhariCustomer?> _customerStream;
  bool _isSmsEnabled = false;
  final _telephonySMS = TelephonySMS();
  
  // Controllers moved inside the dialog function to avoid state conflicts during edits
  
  @override
  void initState() {
    super.initState();
    _loadSmsPreference();
    final objectbox = Provider.of<ObjectBoxService>(context, listen: false);

    _customerStream = objectbox.store
        .box<udhariCustomer>()
        .query(udhariCustomer_.id.equals(widget.customer.id))
        .watch(triggerImmediately: true)
        .map((query) => query.findFirst());
  }

  Future<void> _loadSmsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSmsEnabled = prefs.getBool('sms_enabled_${widget.customer.id}') ?? false;
    });
  }

  Future<void> _saveSmsPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sms_enabled_${widget.customer.id}', value);
    _telephonySMS.requestPermission();
  }

  void _sendTransactionSms(udhariCustomer customer, TransactionUdhari newTransaction) async {
    if (!_isSmsEnabled) return;

    double totalBalance = 0;
    for (var txn in customer.transactions) {
      if (txn.type == TransactionType.gave) {
        totalBalance -= txn.amount;
      } else {
        totalBalance += txn.amount;
      }
    }

    final typeString = newTransaction.type == TransactionType.gave ? "Got" : "Gave";
    final balanceText = totalBalance >= 0 
        ? "You will get ${totalBalance.round()}" 
        : "You have to give ${(-totalBalance).round()}";
    
    final message = "Hi ${customer.name} you $typeString Amount ${newTransaction.amount.round()} and Total $balanceText";

    try {
      final pho_nu = "+91${extractLast10Digits((customer.phone).toString())}";
      await _telephonySMS.sendSMS(phone: pho_nu, message: message);
    } catch (error) {
      debugPrint("Error sending SMS: $error");
    }
  }

  String extractLast10Digits(String phone) {
    String digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length > 10) {
      return digitsOnly.substring(digitsOnly.length - 10);
    }
    return digitsOnly;
  }

 Future<void>  _launchWhatsApp(udhariCustomer customer) async {
    double totalBalance = 0;
    for (var txn in customer.transactions) {
      if (txn.type == TransactionType.gave) {
        totalBalance -= txn.amount;
      } else {
        totalBalance += txn.amount;
      }
    }

    final balanceText = totalBalance >= 0
        ? "${totalBalance.round()}"
        : "${(-totalBalance).round()}";
    
    final message = "Dear ${customer.name}, your outstanding balance is $balanceText. We kindly request you to settle this amount at your earliest convenience.";

    String mobileNumber = extractLast10Digits((customer.phone).toString());
   
    if (mobileNumber.startsWith('+')) {
        mobileNumber = mobileNumber.substring(1);
    }

    if (mobileNumber.length == 10) {
        mobileNumber = '91$mobileNumber';
    } else if (mobileNumber.length == 11 && mobileNumber.startsWith('0')) {
        mobileNumber = '91${mobileNumber.substring(1)}';
    }
    
    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl = Uri.parse("https://wa.me/$mobileNumber?text=$encodedMessage");

    try {
      await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint("Error launching WhatsApp: $e");
    }
  }

Future<void> _sendReminderSms(udhariCustomer customer) async {
  double totalBalance = 0;
  customer.transactions.forEach((txn) {
    if (txn.type == TransactionType.gave) {
      totalBalance -= txn.amount;
    } else {
      totalBalance += txn.amount;
    }
  });

  final balanceText = totalBalance >= 0
      ? "${totalBalance.round()}"
      : "${(-totalBalance).round()}";
  
  final message = "Dear ${customer.name}, your outstanding balance is $balanceText. Please settle ASAP.";

  final phoneNumber =  "+91${extractLast10Digits((customer.phone).toString())}";

  final Uri smsUri = Uri(
    scheme: 'sms',
    path: phoneNumber,
    queryParameters: <String, String>{
      'body': message,
    },
  );

  try {
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  } catch (e) {
    debugPrint("Error launching SMS: $e");
  }
}

  void _showReminderOptions(BuildContext context, udhariCustomer customer) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext bc) {
      return SafeArea(
        child: Container(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 30.0),
                title: Text('WhatsApp'),
                onTap: () {
                  Navigator.pop(context);
                  _launchWhatsApp(customer);
                },
              ),
              ListTile(
                leading: Icon(Icons.sms, color: Colors.orange),
                title: Text('SMS'),
                onTap: () {
                  Navigator.pop(context);
                  _sendReminderSms(customer);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

  void _showSmsSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("SMS Notifications"),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Send SMS for new entries?"),
                  Switch(
                    value: _isSmsEnabled,
                    onChanged: (newValue) {
                      setDialogState(() {
                        _isSmsEnabled = newValue;
                      });
                      setState(() {});
                      _saveSmsPreference(newValue);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Done"),
                ),
              ],
            );
          },
        );
      },
    );
  }

Future<void> _makePhoneCall(udhariCustomer customer) async {
  final phoneNumber = ((customer.phone).toString().replaceAll('+91', "")).replaceAll(" ", "");
  final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri);
  }
}

// ==========================================
// NEW: Logic to Delete a Transaction
// ==========================================
// Update this function signature to accept 'udhariCustomer'
void _deleteTransaction(int transactionId, udhariCustomer customer) {
  final objectbox = Provider.of<ObjectBoxService>(context, listen: false);
  
  // 1. Remove the transaction from the DB
  objectbox.store.box<TransactionUdhari>().remove(transactionId);
  
  // 2. CRITICAL FIX: "Touch" the customer to trigger the StreamBuilder to refresh
  // We don't change data, we just save the customer again to force an update event.
  objectbox.store.box<udhariCustomer>().put(customer);
  
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Entry deleted successfully")),
  );
}

// ==========================================
// NEW: Options Bottom Sheet (Edit/Delete)
// ==========================================
void _showOptionsBottomSheet(BuildContext context, TransactionUdhari transaction, udhariCustomer customer) {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit Entry'),
              onTap: () {
                Navigator.pop(context); // Close sheet
                // Open Dialog in Edit Mode
                _showTransactionDialog(
                  context, 
                  customer, 
                  type: transaction.type, 
                  transactionToEdit: transaction
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Entry'),
              onTap: () {
                Navigator.pop(context); // Close sheet
                // Show confirmation dialog
                 showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Delete Entry?"),
                    content: const Text("Are you sure you want to delete this transaction? This cannot be undone."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteTransaction(transaction.id, customer);
                        },
                        child: const Text("Delete", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<udhariCustomer?>(
      stream: _customerStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final currentCustomer = snapshot.data;

        if (currentCustomer == null) {
          return const Scaffold(
            body: Center(child: Text("Customer not found.")),
          );
        }

        final sortedTransactions = currentCustomer.transactions.toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        return Scaffold(
          appBar: AppBar(
            title: Text(currentCustomer.name),
            actions: [
              IconButton(
                icon: Icon(Icons.message_outlined ),
                tooltip: "Send Reminder",
                onPressed: () {
                  _showReminderOptions(context, currentCustomer);
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.notifications_active_outlined,color: _isSmsEnabled ? Colors.blue : null,
                ),
                tooltip: "SMS Settings",
                onPressed: _showSmsSettingsDialog,
              ),
              IconButton(icon: const Icon(Icons.call),
                        onPressed: () {_makePhoneCall(currentCustomer);}, 
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.blue.shade50,
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  "🔒 Only you and ${currentCustomer.name} can see these entries.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blue.shade800),
                ),
              ),
              Expanded(
                child: sortedTransactions.isEmpty
                    ? const Center(child: Text("No transactions yet."))
                    : ListView.builder(
                        itemCount: sortedTransactions.length,
                        itemBuilder: (context, index) {
                          final transaction = sortedTransactions[index];
                          final isGave = transaction.type == TransactionType.gave;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              // ==========================================
                              // MODIFIED: Added onTap to show Options
                              // ==========================================
                              onTap: () {
                                _showOptionsBottomSheet(context, transaction, currentCustomer);
                              },
                              title: Text(
                                '₹${transaction.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isGave ? Colors.red : Colors.green,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'On ${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
                                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                                  ),
                                  if (transaction.description != null &&
                                      transaction.description.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        transaction.description,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    isGave ? 'You Gave' : 'You Got',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isGave ? Colors.red.shade300 : Colors.green.shade300,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Icon(Icons.more_horiz, size: 16, color: Colors.grey), // Hint that more options exist
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),


              _buildActionButtons(context, currentCustomer),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // MODIFIED: Unified Dialog for ADD and EDIT
  // ==========================================
  void _showTransactionDialog(BuildContext context, udhariCustomer currentCustomer, {required TransactionType type, TransactionUdhari? transactionToEdit}) {
    final formKey = GlobalKey<FormState>();

    // ✅ FIX 1: Get the ObjectBoxService HERE, before the dialog opens.
    // This prevents the "deactivated widget" error because we capture the service
    // while the context is definitely stable.
    final objectbox = Provider.of<ObjectBoxService>(context, listen: false);

    // Create controllers inside the function
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    // If Editing, Pre-fill data
    if (transactionToEdit != null) {
      amountController.text = transactionToEdit.amount.toString();
      descriptionController.text = transactionToEdit.description;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            transactionToEdit != null
                ? "Edit Entry" // Title change for Edit
                : (type == TransactionType.gave ? "Add Entry: You Gave" : "Add Entry: You Got"),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Enter Amount (₹)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty || double.tryParse(value) == null) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'E.g. Paid for groceries, advance, etc.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final amount = double.parse(amountController.text);
                  final description = descriptionController.text.trim();

                  // ✅ FIX 2: We use the 'objectbox' variable we captured at the top.
                  // We do NOT call Provider.of(context) here.

                  if (transactionToEdit != null) {
                    // ============================
                    // LOGIC FOR EDITING
                    // ============================
                    transactionToEdit.amount = amount;
                    transactionToEdit.description = description.isEmpty ? '' : description;

                    // Update in DB
                    objectbox.store.box<TransactionUdhari>().put(transactionToEdit);

                    // Force refresh current customer relations
                    currentCustomer.transactions.add(transactionToEdit);
                    objectbox.store.box<udhariCustomer>().put(currentCustomer);

                    // ✅ FIX 3: Check if context is mounted before showing SnackBar
                    // because the parent widget might be rebuilding.
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaction updated!')),
                      );
                    }
                  } else {
                    // ============================
                    // LOGIC FOR ADDING (Existing)
                    // ============================
                    final newTransaction = TransactionUdhari.create(
                      amount: amount,
                      type: type,
                      date: DateTime.now(),
                      description: description.isEmpty ? '' : description,
                    );

                    newTransaction.customer.target = currentCustomer;

                    objectbox.store.box<TransactionUdhari>().put(newTransaction);
                    currentCustomer.transactions.add(newTransaction);
                    objectbox.store.box<udhariCustomer>().put(currentCustomer);

                    // Note: _sendTransactionSms is part of the class, so we can call it.
                    // However, if this is inside a State class, make sure the method is available.
                     _sendTransactionSms(currentCustomer, newTransaction);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaction added successfully!')),
                      );
                    }
                  }

                  Navigator.pop(dialogContext);
                }
              },
              child: Text(transactionToEdit != null ? "Update" : "Save"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(
      BuildContext context, udhariCustomer currentCustomer) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              // Call generic dialog with Type
              onPressed: () => _showTransactionDialog(
                  context, currentCustomer, type: TransactionType.gave),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('You Gave ₹'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              // Call generic dialog with Type
              onPressed: () => _showTransactionDialog(
                  context, currentCustomer, type: TransactionType.got),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('You Got ₹'),
            ),
          ),
        ],
      ),
    );
  }
}