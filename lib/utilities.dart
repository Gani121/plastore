import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


// --- HOW TO STORE ---
Future<void> saveDataAsJson(tableData) async {
  // 1. Convert integer keys to string keys for JSON compatibility
  final Map<String, dynamic> jsonCompatibleData = 
      tableData.map((key, value) => MapEntry(key.toString(), value));
      
  // 2. Encode the map into a JSON string
  String jsonString = jsonEncode(jsonCompatibleData);

  // 3. Save the string using shared_preferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('tableOrdersJson', jsonString);
  print("✅ Data saved as JSON String!");
}

// --- HOW TO RETRIEVE ---
Future<void> loadDataFromJson() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString('tableOrdersJson');

  if (jsonString != null) {
    // 1. Decode the string back into a map
    final Map<String, dynamic> decodedData = jsonDecode(jsonString);

    // 2. Convert string keys back to integers
    final Map<int, List<Map<String, dynamic>>> retrievedData = 
        decodedData.map((key, value) => MapEntry(
            int.parse(key), 
            (value as List).map((item) => item as Map<String, dynamic>).toList()
        ));
    print("✅ Data retrieved from JSON: $retrievedData");
  }
}