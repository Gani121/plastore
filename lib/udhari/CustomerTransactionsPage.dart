import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NEW
import 'package:telephony_sms/telephony_sms.dart';
import 'package:url_launcher/url_launcher.dart';
import '../cartprovier/ObjectBoxService.dart';
import 'udharicustomer.dart';
import '../objectbox.g.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CustomerTransactionsPage extends StatefulWidget {
  final udhariCustomer customer;
  const CustomerTransactionsPage({super.key, required this.customer});

  @override
  State<CustomerTransactionsPage> createState() =>
      _CustomerTransactionsPageState();
}

class _CustomerTransactionsPageState extends State<CustomerTransactionsPage> {
  late Stream<udhariCustomer?> _customerStream;
  bool _isSmsEnabled = false; // NEW: State for the SMS toggle
  final _telephonySMS = TelephonySMS();

  @override
  void initState() {
    super.initState();
    _loadSmsPreference(); // NEW: Load the setting on page start
    final objectbox = Provider.of<ObjectBoxService>(context, listen: false);

    _customerStream = objectbox.store
        .box<udhariCustomer>()
        .query(udhariCustomer_.id.equals(widget.customer.id)) // MODIFIED: Query by unique ID for reliability
        .watch(triggerImmediately: true)
        .map((query) => query.findFirst());
  }

  // NEW: Method to load the SMS preference from SharedPreferences
  Future<void> _loadSmsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    // We use a unique key for each customer
    setState(() {
      _isSmsEnabled = prefs.getBool('sms_enabled_${widget.customer.id}') ?? false;
    });
  }

  // NEW: Method to save the SMS preference
  Future<void> _saveSmsPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sms_enabled_${widget.customer.id}', value);
    var smspar = _telephonySMS.requestPermission();
    debugPrint("_telephonySMS.requestPermission(); $smspar ");
  }

  // NEW: Method to send SMS
  void _sendTransactionSms(udhariCustomer customer, TransactionUdhari newTransaction) async {
    if (!_isSmsEnabled) {
      // Don't send if SMS is disabled or phone number is missing
      return;
    }

    // 1. Calculate the total balance
    double totalBalance = 0;
    for (var txn in customer.transactions) {
      if (txn.type == TransactionType.gave) {
        totalBalance -= txn.amount; // You gave money, so balance decreases
      } else {
        totalBalance += txn.amount; // You got money, so balance increases
      }
    }

    // 2. Format the message
    final typeString = newTransaction.type == TransactionType.gave ? "Got" : "Gave";
    final balanceText = totalBalance >= 0 
        ? "You will get ${totalBalance.round()}" 
        : "You have to give ${(-totalBalance).round()}";
    
    final message = "Hi ${customer.name} you $typeString Amount ${newTransaction.amount.round()} and Total $balanceText";
    // final message = "Hi ${customer.name},Amount:₹${newTransaction.amount.toStringAsFixed(2)} total balance is: $balanceText.";

    // 3. Send the SMS
    try {
      debugPrint("SMS Send Result:");
      // await _telephonySMS.requestPermission();  ((customer.phone).toString().replaceAll('+91', "")).replaceAll(" ", "")
      final pho_nu = "+91${extractLast10Digits((customer.phone).toString())}";
      
      debugPrint("number to send sms -$pho_nu- ${message.length}");
      await _telephonySMS.sendSMS(phone: pho_nu, message: message);
      debugPrint("SMS Send Result:");
    } catch (error) {
      debugPrint("Error sending SMS: $error");
      // Optionally show a small error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send SMS.'), 
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red,
        ),
      );
    }
  }

  String extractLast10Digits(String phone) {
    // Remove all non-numeric characters
    String digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // If more than 10 digits, take the last 10
    if (digitsOnly.length > 10) {
      return digitsOnly.substring(digitsOnly.length - 10);
    }

    // Otherwise, return as is
    return digitsOnly;
  }

 Future<void>  _launchWhatsApp(udhariCustomer customer) async {
    // 1. Calculate the total balance
    double totalBalance = 0;
    for (var txn in customer.transactions) {
      if (txn.type == TransactionType.gave) {
        totalBalance -= txn.amount; // You gave money, so balance decreases
      } else {
        totalBalance += txn.amount; // You got money, so balance increases
      }
    }

    // 2. Format the message
    final balanceText = totalBalance >= 0
        ? "${totalBalance.round()}"
        : "${(-totalBalance).round()}";
    
    final message = "Dear ${customer.name}, your outstanding balance is $balanceText. We kindly request you to settle this amount at your earliest convenience. For any questions, feel free to contact us.";
    // final message = "Hi ${customer.name},Amount:₹${newTransaction.amount.toStringAsFixed(2)} total balance is: $balanceText.";

    // Do NOT include the '+' or any spaces/hyphens.
    // final phoneNumber = ((customer.phone).toString().replaceAll('+91', "")).replaceAll(" ", "");
    String mobileNumber = await extractLast10Digits((customer.phone).toString());
   
     // --- EDITED: LOGIC TO ADD COUNTRY CODE ---
    // This logic prepares the number for the WhatsApp URL.
    // It assumes the target is an Indian mobile number.
    if (mobileNumber.startsWith('+')) {
        mobileNumber = mobileNumber.substring(1); // Remove '+'
    }

    if (mobileNumber.length == 10) {
        // Standard 10-digit number, prepend India's country code
        mobileNumber = '91$mobileNumber';
    } else if (mobileNumber.length == 11 && mobileNumber.startsWith('0')) {
        // Number starts with a 0, replace it with the country code
        mobileNumber = '91${mobileNumber.substring(1)}';
    }
    debugPrint("number to send sms -$mobileNumber- ${message.length}");

    // Encode the message to be URL-safe
    final encodedMessage = Uri.encodeComponent(message);

    // Create the WhatsApp URL
    final whatsappUrl = Uri.parse("https://wa.me/$mobileNumber?text=$encodedMessage");

    try {
      // Launch the URL
      await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication, // Opens in WhatsApp, not an in-app browser
      );
    } catch (e) {
      // Handle any errors, e.g., WhatsApp not installed
      debugPrint("Error launching WhatsApp: $e");
    }
  }

// Add this function for sending the reminder via SMS
Future<void> _sendReminderSms(udhariCustomer customer) async {
  // 1. Calculate the total balance (same logic as WhatsApp)
  double totalBalance = 0;
  customer.transactions.forEach((txn) {
    if (txn.type == TransactionType.gave) {
      totalBalance -= txn.amount;
    } else {
      totalBalance += txn.amount;
    }
  });

  // 2. Format the message
  final balanceText = totalBalance >= 0
      ? "${totalBalance.round()}"
      : "${(-totalBalance).round()}";
  
  final message = "Dear ${customer.name}, your outstanding balance is $balanceText. We kindly request you to settle this amount at your earliest convenience. For any questions, feel free to contact us.";

  // 3. Create the SMS URI and launch it
  final phoneNumber =  "+91${extractLast10Digits((customer.phone).toString())}"; // Clean up phone number
 

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
// Add this function inside your _CustomerTransactionsPageState class
void _showReminderOptions(BuildContext context, udhariCustomer customer) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext bc) {
      return SafeArea(
        child: Container(
          child: Wrap(
            children: <Widget>[
              ListTile(
                
                leading: FaIcon(
                    FontAwesomeIcons.whatsapp,
                    color: Colors.green,
                    size: 30.0,
                  ),
                title: Text('WhatsApp'),
                onTap: () {
                  Navigator.pop(context); // Close the bottom sheet
                  _launchWhatsApp(customer); // Call your existing WhatsApp function
                },
              ),
              ListTile(
                leading: Icon(Icons.sms, color: Colors.orange),
                title: Text('SMS'),
                onTap: () {
                  Navigator.pop(context); // Close the bottom sheet
                  _sendReminderSms(customer); // Call the new SMS function (see below)
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
  // NEW: Dialog to manage the SMS setting
  void _showSmsSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        // Use a StatefulBuilder so only the dialog UI updates on toggle
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
                      // Also update the main page state and save the preference
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

// Function to launch the phone call
Future<void> _makePhoneCall(udhariCustomer customer) async {

  final phoneNumber = ((customer.phone).toString().replaceAll('+91', "")).replaceAll(" ", "");
  final Uri launchUri = Uri(
    scheme: 'tel',
    path: phoneNumber,
  );
  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri);
  } else {
    // Handle the error here
    debugPrint("Could not launch the phone call.");
  }
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
              // NEW: SMS settings button
              IconButton(
                icon: Icon(Icons.message_outlined ),
                // icon: Icon(
                //   _isSmsEnabled ? Icons.sms : Icons.sms_failed_outlined,
                //   color: _isSmsEnabled ? Colors.blue : null,
                // ),
                tooltip: "Send Reminder",
                onPressed: () {
                  // Call the function to show the popup
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
                              title: Text(
                                '₹${transaction.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isGave ? Colors.red : Colors.green,
                                ),
                              ),

                              // 📅 Show date + 📝 description (if present)
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

                              trailing: Text(
                                isGave ? 'You Gave' : 'You Got',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isGave ? Colors.red.shade300 : Colors.green.shade300,
                                ),
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

  // MODIFIED: Added call to _sendTransactionSms
  void _showAddTransactionDialog(BuildContext context,
      udhariCustomer currentCustomer, TransactionType type) {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          type == TransactionType.gave
              ? "Add Entry: You Gave"
              : "Add Entry: You Got",
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 💰 Amount Field
                TextFormField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Enter Amount (₹)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        double.tryParse(value) == null) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // 📝 Description Field
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

                final objectbox =
                    Provider.of<ObjectBoxService>(context, listen: false);

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

                // Send SMS right after saving
                _sendTransactionSms(currentCustomer, newTransaction);

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaction added successfully!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text("Save"),
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
              onPressed: () => _showAddTransactionDialog(
                  context, currentCustomer, TransactionType.gave),
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
              onPressed: () => _showAddTransactionDialog(
                  context, currentCustomer, TransactionType.got),
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