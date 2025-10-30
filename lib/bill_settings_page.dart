import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, String> switchPreferenceKeys = {
  "2.1 Enable Fast Billing": "enable_fast_billing",
  "2.2 Item Barcode Scanner": "item_barcode_scanner",
  "2.3 Calculator Billing For Retail": "calculator_in_billing_retail",
  "2.4 Cash Sale by Default": "cash_sale_by_default",
  "2.5 Amount Received by Default": "amount_received_by_default",
  "2.6 Next Bill after Save": "next_bill_after_save",
  "2.7 Sort by Item Code (Item Selector)": "sort_items_by_item_code",
  "2.8 Show Bookmark List (Item Selector)": "auto_print_after_save",
  "2.9 Sell Price Lock (Item Selector)": "edit_delete_item_in_bill",
  "2.10 Negative Stock Lock (Item Selector)": "enable_item_images",
  "2.11 View Stock in Billing": "view_stock_in_billing",
  "2.12 Merge Same Items in Bill": "merge_same_items_in_bill",
  "2.13 Enable Discount in Bill": "enable_discount_in_bill",
  "2.14 Item Price - Multiple Options": "enable_gst_in_bill",
  "2.15 Alpha Numeric Barcodes": "allow_negative_stock",
  "2.16 Round Off Total Amount": "hide_party_mobile_in_bill",
  "2.17 Always Show Previous Balance": "hide_bill_no_in_bill",
  "2.18 Enable SMS Notification": "enable_sms_notification",
  "2.19 Party wise Item price": "enable_email_notification",
  "2.20 Hide out of stock items": "enable_whatsapp_share",
  "2.21 Bill Quick save": "enable_bill_rounding",
  "2.22 show current stock in bill": "show_purchase_price",
  "2.23 Enable Multi-Language Bill": "enable_multi_language_bill",
  "2.24 Restrict Payment mode ": "enable_loyalty_points",
  "2.25 Pin Access": "ask_for_bill_confirmation",
  "2.26 Fixed login otp": "save_last_party_selection",
  "2.27 Enable Dark Mode": "enable_dark_mode",
  "2.28 Auto Backup to Drive": "auto_backup_to_drive",
  "2.29 Show Item Code in Bill": "show_item_code_in_bill",
  "2.30 Show QR on Bill": "show_qr_on_bill",
  "3.1 Landscape mode ": "3.1 Landscape mode ",
  "3.2 Powered by Orbipay": "3.2 Powered by Orbipay",
  "3.3 domain by Orbipay": "3.3 domain by Orbipay",
  "3.4 Bill Amount Sound": "3.4 Bill Amount Sound",
  "3.5 Pending KOT Sound": "3.5 Pending KOT Sound",
  "3.6 Printer instruction Sound": "3.6 Printer instruction Sound",
  "3.7 Configure App Colors": "3.7 Configure App Colors",
  "3.8 Cut off day status": "3.8 Cut off day status",
  "3.9 Item selection Sound": "3.9 Item selection Sound",
  "4.1 Send bill to customer on whatsapp":
      "4.1 Send bill to customer on whatsapp",
  "4.2 Send bill to owner on whatsapp": "4.2 Send bill to owner on whatsapp",
  "4.3 choose days for reminder Message":
      "4.3 choose days for reminder Message",
};

class billSettingsPage extends StatefulWidget {
  const billSettingsPage({super.key});

  @override
  State<billSettingsPage> createState() => _billSettingsPageState();
}

class _billSettingsPageState extends State<billSettingsPage> {
  String selectedStyle = 'Restaurant With Image Half Full Style';
  Map<String, bool> switches = {};
  String? billingType = 'REGULAR';

  @override
  void initState() {
    super.initState();
    _loadSelectedStyle();
    get_billing_type();
    loadSwitchValues().then((loaded) {
      setState(() {
        switches = loaded;
      });
    });
  }

  Widget _buildDropdown(String label, List<String> options) {
    // Ensure value exists in options to prevent the "exactly one item" error
    if (!options.contains(billingType)) {
      billingType = null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: billingType,
        decoration: InputDecoration(
          labelText: "Price To Display",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: options
            .toSet() // removes duplicates
            .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
            .toList(),
        onChanged: (value) {
          setState(() {
            billingType = value;
          });
          save_billing_type(value);
        },
        validator: (value) =>
            value == null || value.isEmpty ? "Select $label" : null,
      ),
    );
  }


  void save_billing_type(String? billingType) async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedBillingType', billingType ?? 'REGULAR');
  }

  Future<String> get_billing_type() async{
    final prefs = await SharedPreferences.getInstance();
    billingType =  await prefs.getString('selectedBillingType') ?? "REGULAR";
    return billingType ?? 'REGULAR';
  }

  Future<void> saveSwitchValue(String title, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = switchPreferenceKeys[title];
    if (key != null) {
      await prefs.setBool(key, value);
    }
  }

  Future<Map<String, bool>> loadSwitchValues() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, bool> values = {};

    for (var title in switchPreferenceKeys.keys) {
      final key = switchPreferenceKeys[title];
      if (key != null) {
        values[title] = prefs.getBool(key) ?? false;
      }
    }

    return values;
  }

  // Map<String, bool> switches = {
  //   "2.4 Cash Sale by Default":false,
  //   'Cash Sale by Default': true,
  //   'Amount Received by Default': true,
  //   'Next Bill after Save': true,
  // };

  int selectedColumns = 3;
  String barcodeSpeed = "FAST";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF5F4DF6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [Text("Orbipay", style: TextStyle(fontSize: 20))],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          sectionTitle("1. CURRENT PROFILE"),
          currentProfileBox(),
          const SizedBox(height: 20),
          sectionTitle("2. BILL SETTINGS"),
          itemSelector(),
          const SizedBox(height: 20),
          _buildDropdown("Billing Type", ["REGULAR", "AC","Non-Ac","online-sale","online Delivery Price (parcel)"]),
          const SizedBox(height: 20),
          toggleTile("2.2 Item Barcode Scanner", ""),
          toggleTile("2.3 Calculator Billing For Retail", ""),
          toggleTile(
            "2.4 Cash Sale by Default",
            "No need to select party for new bills.",
          ),
          toggleTile(
            "2.5 Amount Received by Default",
            "No need to manually enter money in for new bills.",
          ),
          toggleTile(
            "2.6 Next Bill after Save",
            "App will be ready for next bill as soon as one is created or printed.",
          ),
          toggleTile("2.7 Sort by Item Code (Item Selector)", ""),
          toggleTile(
            "2.8 Show Bookmark List (Item Selector)",
            "Categories will be shown on left side for easy selection.",
          ),
          toggleTile(
            "2.9 Sell Price Lock (Item Selector)",
            "Sell Price will not be able change while creating Bills. It can be done from item list only.",
          ),
          toggleTile(
            "2.10 Negative Stock Lock (Item Selector)",
            "You will not be able to select items where quantity is less than zero.",
          ),

          const SizedBox(height: 12),
          const Text("2.11 Restaurant Item Selector Columns"),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButton<int>(
              value: selectedColumns,
              isExpanded: true,
              underline: SizedBox(),
              onChanged: (val) {
                setState(() {
                  selectedColumns = val!;
                });
              },
              items: [1, 2, 3, 4, 5]
                  .map(
                    (val) => DropdownMenuItem<int>(
                      value: val,
                      child: Text(val.toString()),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          const Text("2.12 Barcode Scanner Speed"),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(barcodeSpeed, style: TextStyle(fontSize: 16)),
          ),

          buildDropdownTile(
            "2.13 Item Category List Width (Item Selector)",
            "20%",
          ),

          // buildSwitchTile(
          //   title: "2.21 Item Price - Multiple Options",
          //   subtitle: "Disabled",
          //   value: false,
          // ),
          toggleTile("2.14 Item Price - Multiple Options", "Enabled"),
          toggleTile("2.15 Alpha Numeric Barcodes", "Enabled"),
          toggleTile("2.16 Round Off Total Amount", "Enabled"),

          toggleTile("2.17 Always Show Previous Balance", ""),
          buildInlineInputTile(
            "   2.18 Service Charge (%)",
            "e.g. 5.00",
            "service_charge_key",
          ),
          buildInlineInputTile("image height", "e.g 100", "imageheight_key"),
          buildInlineInputTile("box height", "e.g 0.40", "boxheight_key"),
          buildInlineInputTile("box Text", "e.g 15", "boxtext_key"),

          //2.18 is textbox
          toggleTile("2.19 Party wise Item price", ""),
          toggleTile("2.20 Hide out of stock items", ""),
          toggleTile("2.21 Bill Quick save", ""),

          toggleTile("2.22 show current stock in bill", ""),

          itemSelectorforfilter(),
          const SizedBox(height: 20),
          toggleTile("2.24 Restrict Payment mode ", ""),
          toggleTile("2.25 Pin Access", ""),
          toggleTile("2.26 Fixed login otp", ""),
          // 🔵 Section 2: App Settings
          const Text(
            "3.App Settings",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          //const SizedBox(height: 10),
          toggleTile("3.1 Landscape mode ", "useful for tablet/big screen"),

          toggleTile("3.2 Powered by Orbipay", "Print tagline on bill"),
          toggleTile("3.3 domain by Orbipay", "Print tagline on bill"),
          toggleTile("3.4 Bill Amount Sound", "Print tagline on bill"),

          toggleTile("3.5 Pending KOT Sound", "it play sound"),
          toggleTile(
            "3.6 Printer instruction Sound",
            "play sound for printer connection",
          ),
          toggleTile("3.7 Configure App Colors", "Choose your fav color"),
          toggleTile("3.8 Cut off day status", ""),
          toggleTile("3.9 Item selection Sound", ""),
          const Text(
            "4.Other Settings",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          //const SizedBox(height: 10),
          toggleTile("4.1 Send bill to customer on whatsapp", ""),
          toggleTile("4.2 Send bill to owner on whatsapp", ""),
          toggleTile("4.3 choose days for reminder Message", ""),

          // buildSwitchTile(
          //   title: "2.24 Always Show Previous Balance",
          //   subtitle: "Enabled",
          //   value: true,
          // ),
          // const SizedBox(height: 40),
          const SizedBox(height: 24),
          // ElevatedButton(
          //   style: ElevatedButton.styleFrom(
          //     minimumSize: Size(double.infinity, 48),
          //     backgroundColor: const Color(0xFF3F35F4),
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(8),
          //     ),
          //   ),
          //   onPressed: () {
          //     // Save logic
          //   },
          //   child: const Text(
          //     "SAVE",
          //     style: TextStyle(
          //       color: Colors.white,
          //       fontWeight: FontWeight.bold,
          //       letterSpacing: 1.1,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
    );
  }

  Widget currentProfileBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Beyond Foam",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text("Phone Unavailable", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[800],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text("BUY Orbipay"),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSelectedStyle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedStyle =
          prefs.getString('selectedStyle') ??
          'Restaurant With Image Half Full Style';
    });
  }

  Future<void> _saveSelectedStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedStyle', style);
  }

  final List<String> styles = [
    'List Style',
    'List Style Half Full',
    'Restaurant Style',
    'Restaurant With Image Style',
    'Restaurant With Image Half Full Style',
    'half-Full View',
    'Clothing Store Style',
  ];
  Widget itemSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "2.1 Item Selector Style",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Column(
          children: styles.map((style) {
            final selected = selectedStyle == style;
            return GestureDetector(
              onTap: () {
                setState(() => selectedStyle = style);
                _saveSelectedStyle(style); // save selection
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected ? Colors.blue : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 8,
                    backgroundColor: selected
                        ? Color(0xFF3F35F4)
                        : Colors.grey.shade400,
                  ),
                  title: Text(style),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget itemSelectorforfilter() {
    final styles = ['start with', 'contains'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "2.23 Select item filter priority",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Column(
          children: styles.map((style) {
            final selected = selectedStyle == style;
            return GestureDetector(
              onTap: () => setState(() => selectedStyle = style),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected ? Colors.blue : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 8,
                    backgroundColor: selected
                        ? const Color(0xFF3F35F4)
                        : Colors.grey.shade400,
                  ),
                  title: Text(style),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget toggleTile(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(title),
          value: switches[title] ?? false, // ✅ Safe null check
          activeColor: const Color(0xFF3F35F4),
          onChanged: (val) {
            setState(() {
              switches[title] = val;
            });
            saveSwitchValue(title, val);
          },
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 12),
          child: Text(subtitle, style: const TextStyle(color: Colors.green)),
        ),
      ],
    );
  }

  Widget disabledTile(String title) {
    return ListTile(
      title: Text(title),
      subtitle: const Text("Disabled", style: TextStyle(color: Colors.grey)),
      trailing: const Switch(value: false, onChanged: null),
    );
  }
}

Widget buildSwitchTile({
  required String title,
  required String subtitle,
  required bool value,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: value ? Colors.green : Colors.grey),
        ),
        value: value,
        onChanged: (_) {},
      ),
      const Divider(),
    ],
  );
}

Widget buildDropdownTile(String title, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          underline: const SizedBox(),
          items: [value].map((String val) {
            return DropdownMenuItem<String>(value: val, child: Text(val));
          }).toList(),
          onChanged: (_) {},
        ),
      ),
      const SizedBox(height: 16),
    ],
  );
}

Widget buildInlineInputTile(String label, String hint, String key) {
  final TextEditingController controller = TextEditingController();

  // Load existing value from SharedPreferences when widget builds
  SharedPreferences.getInstance().then((prefs) {
    final savedValue = prefs.getString(key);
    if (savedValue != null && controller.text.isEmpty) {
      controller.text = savedValue;
    }
  });

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onChanged: (value) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(key, value);
              print("key $key  value $value");
            },
          ),
        ),
      ],
    ),
  );
}

Future<void> saveData(String key, dynamic value) async {
  final prefs = await SharedPreferences.getInstance();
  if (value is bool) {
    await prefs.setBool(key, value);
  }
}
