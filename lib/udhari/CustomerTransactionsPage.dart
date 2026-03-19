import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony_sms/telephony_sms.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database_Module/ObjectBoxService.dart';
import '../database_Module/udharicustomer.dart';
import '../objectbox.g.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import './UdhariSyncService.dart';
import 'package:test1/utilities.dart';

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
    await _telephonySMS.requestPermission();
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
    
    // Add due date info to SMS if applicable
    String dueDateText = '';
    if (newTransaction.dueDate != null && newTransaction.type == TransactionType.gave) {
      dueDateText = ' Due by ${DateFormat('dd/MM/yyyy').format(newTransaction.dueDate!)}.';
    }
    
    final message = "Hi ${customer.name} you $typeString Amount ${newTransaction.amount.round()}$dueDateText and Total $balanceText";

    try {
      final pho_nu = "+91${extractLast10Digits((customer.phone).toString())}";
      await _telephonySMS.sendSMS(phone: pho_nu, message: message);
    } catch (error) {
      //debugPrint("Error sending SMS: $error");
    }
  }

  String extractLast10Digits(String phone) {
    String digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length > 10) {
      return digitsOnly.substring(digitsOnly.length - 10);
    }
    return digitsOnly;
  }

  Future<void> _launchWhatsApp(udhariCustomer customer) async {
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
      //debugPrint("Error launching WhatsApp: $e");
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
      //debugPrint("Error launching SMS: $e");
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

  void _deleteTransaction(int transactionId, udhariCustomer customer) {
    final objectbox = Provider.of<ObjectBoxService>(context, listen: false);
    
    objectbox.store.box<TransactionUdhari>().remove(transactionId);
    final udhariCustomer_box = objectbox.store.box<udhariCustomer>();
    udhariCustomer_box.put(customer);
    // UdhariSyncService.syncCustomer(customer,udhariCustomer_box);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Entry deleted successfully")),
    );
  }

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
                  Navigator.pop(context);
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
                  Navigator.pop(context);
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

  // ================ NEW: Due Date Summary Methods ================
  
  Map<String, dynamic> _getDueDateSummary(udhariCustomer customer) {
    final now = DateTime.now();
    double totalDue = 0;
    int overdueCount = 0;
    int upcomingCount = 0;
    double overdueAmount = 0;
    
    for (var txn in customer.transactions) {
      if (txn.type == TransactionType.gave && txn.dueDate != null) {
        totalDue += txn.amount;
        
        if (txn.isOverdue) {
          overdueCount++;
          overdueAmount += txn.amount;
        } else if (txn.dueDate!.difference(now).inDays <= 7) {
          upcomingCount++;
        }
      }
    }
    
    return {
      'totalDue': totalDue,
      'overdueCount': overdueCount,
      'upcomingCount': upcomingCount,
      'overdueAmount': overdueAmount,
    };
  }

  Widget _buildDueDateSummary(udhariCustomer customer) {
    final summary = _getDueDateSummary(customer);
    
    if (summary['totalDue'] == 0) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.red.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📅 Due Date Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Total Due',
                '₹${summary['totalDue'].toStringAsFixed(2)}',
                Icons.account_balance_wallet,
                Colors.blue,
              ),
              if (summary['overdueCount'] > 0)
                _buildSummaryItem(
                  'Overdue',
                  '${summary['overdueCount']} (₹${summary['overdueAmount'].toStringAsFixed(0)})',
                  Icons.warning,
                  Colors.red,
                ),
              if (summary['upcomingCount'] > 0)
                _buildSummaryItem(
                  'Upcoming',
                  '${summary['upcomingCount']}',
                  Icons.upcoming,
                  Colors.orange,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ================ Transaction Dialog with Due Date ================
  
  void _showTransactionDialog(BuildContext context, udhariCustomer currentCustomer, 
      {required TransactionType type, TransactionUdhari? transactionToEdit}) {
    
    final formKey = GlobalKey<FormState>();
    final objectbox = Provider.of<ObjectBoxService>(context, listen: false);

    // Controllers
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    
    // Due date state
    DateTime? selectedDueDate = transactionToEdit?.dueDate;
    bool enableDueDate = transactionToEdit?.dueDate != null;

    // If Editing, Pre-fill data
    if (transactionToEdit != null) {
      amountController.text = transactionToEdit.amount.toString();
      descriptionController.text = transactionToEdit.description;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                transactionToEdit != null
                    ? "Edit Entry"
                    : (type == TransactionType.gave ? "Add Entry: You Gave" : "Add Entry: You Got"),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Amount Field
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Enter Amount (₹)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty || double.tryParse(value) == null) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // Description Field
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'E.g. Paid for groceries, advance, etc.',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note),
                        ),
                      ),
                      
                      // Due Date Section (Only for "You Gave" transactions)
                      ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        
                        // Due Date Toggle
                        SwitchListTile(
                          title: const Text('Set Due Date'),
                          subtitle: const Text('Enable if this payment has a deadline'),
                          value: enableDueDate,
                          onChanged: (value) {
                            setDialogState(() {
                              enableDueDate = value;
                              if (!value) selectedDueDate = null;
                            });
                          },
                        ),
                        
                        // Due Date Picker
                        if (enableDueDate) ...[
                          const SizedBox(height: 8),
                          ListTile(
                            leading: const Icon(Icons.calendar_today, color: Colors.orange),
                            title: Text(
                              selectedDueDate == null
                                  ? 'Select Due Date'
                                  : 'Due: ${DateFormat('dd/MM/yyyy').format(selectedDueDate!)}',
                            ),
                            trailing: selectedDueDate != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setDialogState(() {
                                        selectedDueDate = null;
                                      });
                                    },
                                  )
                                : null,
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedDueDate ?? DateTime.now().add(const Duration(days: 7)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (pickedDate != null) {
                                setDialogState(() {
                                  selectedDueDate = pickedDate;
                                });
                              }
                            },
                          ),
                          
                          // Quick due date options
                          // Padding(
                          //   padding: const EdgeInsets.symmetric(vertical: 8.0),
                          //   child: Wrap(
                          //     spacing: 8,
                          //     children: [
                          //       _buildQuickDueChip('7 days', 7, setDialogState),
                          //       _buildQuickDueChip('15 days', 15, setDialogState),
                          //       _buildQuickDueChip('30 days', 30, setDialogState),
                          //       _buildQuickDueChip('60 days', 60, setDialogState),
                          //     ],
                          //   ),
                          // ),
                        ],
                      ],
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

                      if (transactionToEdit != null) {
                        // EDIT
                        transactionToEdit.amount = amount;
                        transactionToEdit.description = description.isEmpty ? '' : description;
                        transactionToEdit.dueDate = enableDueDate ? selectedDueDate : null;

                        objectbox.store.box<TransactionUdhari>().put(transactionToEdit);
                        final udhariCustomer_box = objectbox.store.box<udhariCustomer>();
                        currentCustomer.transactions.add(transactionToEdit);
                        currentCustomer.synced = false;
                        udhariCustomer_box.put(currentCustomer);

                        // UdhariSyncService.syncCustomer(currentCustomer,udhariCustomer_box);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Transaction updated!')),
                          );
                        }
                      } else {
                        // ADD
                        final newTransaction = TransactionUdhari.create(
                          syid:ganarateID(), 
                          amount: amount,
                          type: type,
                          date: DateTime.now(),
                          description: description.isEmpty ? '' : description,
                          dueDate: enableDueDate ? selectedDueDate : null,
                        );

                        newTransaction.customer.target = currentCustomer;
                        objectbox.store.box<TransactionUdhari>().put(newTransaction);
                        //map that transection to the customer
                        final udhariCustomer_box = objectbox.store.box<udhariCustomer>();
                        currentCustomer.transactions.add(newTransaction);
                        currentCustomer.synced = false;
                        udhariCustomer_box.put(currentCustomer);

                        // UdhariSyncService.syncCustomer(currentCustomer,udhariCustomer_box);

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
      },
    );
  }

  // Helper for quick due date chips
  Widget _buildQuickDueChip(String label, int days, StateSetter setDialogState) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        setDialogState(() {
          // selectedDueDate = DateTime.now().add(Duration(days: days));
        });
      },
      backgroundColor: Colors.blue.shade50,
    );
  }

  // ================ Due Date Badge and Info Widgets ================
  
  Widget _buildDueDateBadge(TransactionUdhari transaction) {
    if (transaction.dueDate == null) {
      return const SizedBox.shrink();
    }
    
    final isOverdue = transaction.dueDate != null;
    final daysLeft = transaction.dueDate!.difference(DateTime.now()).inDays;
    
    Color color;
    String label;
    
    if (isOverdue) {
      color = Colors.red;
      label = dateformat(transaction.dueDate!);
    } else if (daysLeft <= 3) {
      color = Colors.orange;
      label = formatDate(transaction.dueDate!);
    } else {
      color = Colors.green;
      label = formatDate(transaction.dueDate!);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDueDateInfo(TransactionUdhari transaction) {
    if (transaction.dueDate == null) {
      return const SizedBox.shrink();
    }
    
    final isOverdue = transaction.dueDate == null;
    final daysLeft = transaction.dueDate!.difference(DateTime.now()).inDays;
    
    String text;
    IconData icon;
    Color color;
    
    if (isOverdue) {
      text = 'Due on ${DateFormat('dd MMM yyyy').format(transaction.dueDate!)}';
      icon = Icons.warning_amber_rounded;
      color = Colors.red;
    } else if (daysLeft <= 3) {
      text = 'Due on ${DateFormat('dd MMM yyyy').format(transaction.dueDate!)}';
      icon = Icons.access_time;
      color = Colors.orange;
    } else {
      text = 'Due on ${DateFormat('dd MMM yyyy').format(transaction.dueDate!)}';
      icon = Icons.event;
      color = Colors.green;
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================ Overdue Reminders ================
  
  bool _hasOverduePayments(udhariCustomer customer) {
    return customer.transactions.any((txn) => 
        txn.type == TransactionType.gave && 
        txn.dueDate != null && 
        txn.isOverdue &&
        !txn.reminderSent);
  }

  Future<void> _sendOverdueReminders(udhariCustomer customer) async {
    final now = DateTime.now();
    int remindersSent = 0;
    
    for (var txn in customer.transactions) {
      if (txn.type == TransactionType.gave && 
          txn.dueDate != null && 
          txn.isOverdue && 
          !txn.reminderSent) {
        
        // Send reminder
        final message = "Reminder: Payment of ₹${txn.amount.round()} was due on ${DateFormat('dd/MM/yyyy').format(txn.dueDate!)}. Please settle at your earliest convenience.";
        
        final phoneNumber = "+91${extractLast10Digits(customer.phone.toString())}";
        
        try {
          final Uri smsUri = Uri(
            scheme: 'sms',
            path: phoneNumber,
            queryParameters: {'body': message},
          );
          
          if (await canLaunchUrl(smsUri)) {
            await launchUrl(smsUri);
            
            // Mark reminder as sent
            txn.reminderSent = true;
            final objectbox = Provider.of<ObjectBoxService>(context, listen: false);
            objectbox.store.box<TransactionUdhari>().put(txn);
            
            remindersSent++;
          }
        } catch (e) {
          debugPrint("Error sending reminder: $e");
        }
      }
    }
    
    if (remindersSent > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent $remindersSent overdue reminders')),
      );
    }
  }

  // ================ Build Method ================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<udhariCustomer?>(
      stream: _customerStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final currentCustomer = snapshot.data!;

        final sortedTransactions = currentCustomer.transactions.toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        return Scaffold(
          appBar: AppBar(
            title: Text(currentCustomer.name),
            actions: [
              // Overdue reminder button
              if (_hasOverduePayments(currentCustomer))
                IconButton(
                  icon: const Icon(Icons.notifications_active, color: Colors.red),
                  tooltip: "Send Overdue Reminders",
                  onPressed: () => _sendOverdueReminders(currentCustomer),
                ),
              IconButton(
                icon: Icon(Icons.message_outlined),
                tooltip: "Send Reminder",
                onPressed: () {
                  _showReminderOptions(context, currentCustomer);
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.notifications_active_outlined,
                  color: _isSmsEnabled ? Colors.blue : null,
                ),
                tooltip: "SMS Settings",
                onPressed: _showSmsSettingsDialog,
              ),
              IconButton(
                icon: const Icon(Icons.call),
                onPressed: () {_makePhoneCall(currentCustomer);}, 
              ),
            ],
          ),
          body: Column(
            children: [
              // Container(
              //   width: double.infinity,
              //   color: Colors.blue.shade50,
              //   padding: const EdgeInsets.all(12.0),
              //   child: Text(
              //     "🔒 Only you and ${currentCustomer.name} can see these entries.",
              //     textAlign: TextAlign.center,
              //     style: TextStyle(color: Colors.blue.shade800),
              //   ),
              // ),
              
              // Due Date Summary
              _buildDueDateSummary(currentCustomer),
              
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
                              onTap: () {
                                _showOptionsBottomSheet(context, transaction, currentCustomer);
                              },
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '₹${transaction.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isGave ? Colors.red : Colors.green,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  // Due date badge
                                  _buildDueDateBadge(transaction),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'On ${DateFormat('dd/MM/yyyy').format(transaction.date)}',
                                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                                  ),
                                  
                                  // Due date info
                                  // _buildDueDateInfo(transaction),
                                  
                                  if (transaction.description.trim().isNotEmpty)
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
                                  const Icon(Icons.more_horiz, size: 16, color: Colors.grey),
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

  Widget _buildActionButtons(BuildContext context, udhariCustomer currentCustomer) {
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