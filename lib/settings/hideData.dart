import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test1/utilities.dart';

const Map<String, String> switchPreferenceKeys = {
"1. Hide Sales Report": "hide_sales_report",
"2. Hide Transections": "hide_transections",
"3. Hide Total": "hide_total",
"4. Hide Udhari": "hide_udhari",
"5. Hide Expence": "hide_expence",
"6. Hide Cash Sale": "hide_cash_sale",
"7. Hide UPI Sale": "hide_upi_sell",
"8. Hide1": "hide1",
"9. Hide2": "hide2",
};

class hideData extends StatefulWidget {
  const hideData({super.key});

  @override
  State<hideData> createState() => _hideDataState();
}

class _hideDataState extends State<hideData> {
  String selectedStyle = 'Restaurant With Image Half Full Style';
  Map<String, bool> switches = {};
  String? billingType = 'REGULAR';

  // 1. Initialize the list here
  List<String> order_type =  [];
  String? selectedOrderType;

  @override
  void initState() {
    super.initState();
    loadSwitchValues().then((loaded) {
      setState(() {
        switches = loaded;
      });
    });
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

















  Future<void> saveSwitchValue(String title, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = switchPreferenceKeys[title];
    if (key != null) {
      await prefs.setBool(key, value);
      print_log("$key value $value");
    }
  }

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
        padding: const EdgeInsets.all(0),
        children: [
          sectionTitle("HIDE DATA"),
          toggleTile("1. Hide Sales Report", ""),
          toggleTile("2. Hide Transections", ""),
          toggleTile("3. Hide Total", ""),
          toggleTile("4. Hide Udhari", ""),
          toggleTile("5. Hide Expence", ""),
          toggleTile("6. Hide Cash Sale", ""),
          toggleTile("7. Hide UPI Sale", ""),
          toggleTile("8. Hide", ""),
          toggleTile("9. Hide2", ""),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget sectionTitle(String title) {
    return 
    Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
          ),
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
        // Padding(
        //   padding: const EdgeInsets.only(left: 0.0, bottom: 0.0),
        //   child: Text(subtitle, style: const TextStyle(color: Colors.green)),
        // ),
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
          onChanged: (_) {

          },
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
