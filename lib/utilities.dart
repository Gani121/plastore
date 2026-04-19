import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../objectbox.g.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

import 'package:test1/database_Module/expensDB.dart';
import 'package:test1/database_Module/ObjectBoxService.dart';
import 'package:test1/database_Module/transaction.dart';
import 'package:test1/database_Module/menu_item.dart';
import 'package:test1/database_Module/cunsuption.dart';
import 'package:test1/database_Module/BillCounter.dart';
import 'package:test1/database_Module/party_database.dart';
import 'package:test1/database_Module/purchase_invoice_DB.dart';
import 'package:test1/database_Module/purchase_order_database.dart';
import 'package:test1/database_Module/quotation_database.dart';
import 'package:test1/database_Module/supplier_database.dart';
import 'package:test1/database_Module/tableCart.dart';
import 'package:test1/database_Module/tabledata.dart';
import 'package:test1/database_Module/udharicustomer.dart';
import 'package:test1/database_Module/video_model.dart';
import 'package:test1/bill_printer.dart'; 



enum keys {
  order_type_list,
  ThemeModeDark,
  ThemeModeSystem,
}




class AppConstants {
  static String test_version = "";
  static String buildNumber = "";
  static String app_version = "1.0.0";
  static String objectbox_path = "";
  static String businessDateKey = 'businessDate';
  static String usernameKey = "username";
  static String username = "";
  static String appPasswordKey = "app_password";
  static DateTime? businessDate;
  static String folderPath = '/storage/emulated/0/Orbipay';
  
  AppConstants._();


  static Future<void> initialize() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      // Automatically gets the ID defined in your build.gradle/versions.properties
      test_version = packageInfo.packageName; 
      app_version = packageInfo.version;
      buildNumber = packageInfo.buildNumber.toString();
      // final dir1 = await getApplicationDocumentsDirectory();
      final dir = await getApplicationDocumentsDirectory();
      // objectbox_path = '${(dir1 ?? dir).path}/objectbox';
      objectbox_path = '${dir.path}/objectbox';
      //debugPrint(packageInfo.toString());
      //debugPrint("✅ AppConstants initialized: $test_version,$buildNumber, $app_version $objectbox_path");
    } catch (e) {
      //debugPrint("⚠️ Failed to load package info: $e");
    }
  }


}

List<String> units = ["Nos","g","ml","Ltr","quart","gallon","peg","unit","pack","box","btl","pkt","bag","carton","crate","tin","can","ton","jar","pouch","sachet","bundle","dozen","gross"];
// List<String> units = ['Nos', 'Grams', "kg", 'Ltr', 'Slices',"mg",];

int ganarateID(){
  return DateTime.now().millisecondsSinceEpoch;
}

void addToPrefs(String key, String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

Future<String> getDatafromPrefs(String key,) async {
  final prefs = await SharedPreferences.getInstance();
   return prefs.getString(key) ?? '';
}

///
/// date in the format dd-mm-yyyy hh/mm/ss
///
String formatDate(DateTime date) {
  return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} ${date.hour.toString().padLeft(2, '0')}/${date.minute.toString().padLeft(2, '0')}/${date.second.toString().padLeft(2, '0')}";
}

///
/// date in the format dd-mm-yyyy
///
String dateformat(DateTime date) {
  return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
}

///
/// date in the format dd MMM yyyy hh:mm AM/PM
///
String formatDateAM_PM(DateTime date) {
  return DateFormat('dd MMM yyyy hh:mm a').format(date);
}

void print_log(String massage){
  debugPrint("$massage");
}

void print_log_red(String massage){
    debugPrint('\x1B[31m $massage \x1B[0m');
}

void screen_massage(BuildContext context,String massage){
  if(context.mounted){
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$massage."),),
    );
  }
}

String getHotelIdentifier(String username) {
  // Split on "_captain" followed by optional digits
  return username.split(RegExp(r'_captain\d*'))[0];
}

String getEpocDatetime() {
  String epoc_datetime =  DateTime.now().millisecondsSinceEpoch.toString();
  return epoc_datetime;
}

// Updated version of saveImageInternalStorageDirectory with better error handling
Future<String?> saveImageInternalStorageDirectory(String path, String foldername, {String? filename}) async {
  try {
    final tempImage = File(path);
    if (!await tempImage.exists()) {
      print_log("Source file does not exist: $path");
      return null;
    }
    
    final extDir = await getApplicationDocumentsDirectory();
    // String dirmedia = await getMediaFolderpath();
    if (extDir == null) {
      print_log("External storage directory not found");
      return null;
    }
    
    final saveDir = Directory("${extDir.path}/$foldername");
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }
    
    String imagename = await getEpocDatetime();
    String fileName = filename == null ? "$imagename.jpeg" : "$filename.jpeg";
    final savedPath = "${saveDir.path}/$fileName";
    
    final savedImage = await tempImage.copy(savedPath);
    String savedImagePath = savedImage.path;

    print_log("File saved at path: $savedImagePath");
    return savedImagePath;
  } catch (e) {
    print_log("Error saving image to storage directory: $e");
    return null;
  }
}

Future<bool> removeFileFromExternalStorage(String filePath) async {
  try {
    // Check if the file exists
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      print_log("File successfully removed: $filePath");
      return true;
    } else {
      print_log("File does not exist: $filePath");
      return false;
    }
  } catch (e) {
    print_log("Error removing file $filePath: $e");
    return false;
  }
}


Future<void> cleanupOrphanedExpenseImages(List<String> currentPhotoPaths,String foldername) async {
  try {
    final extDir = await getApplicationDocumentsDirectory();
    if (extDir == null) return;
    
    final expenseImagesDir = Directory("${extDir.path}/${foldername}");
    if (!await expenseImagesDir.exists()) return;
    
    final List<FileSystemEntity> files = await expenseImagesDir.list().toList();
    
    for (final file in files) {
      if (file is File) {
        final filePath = file.path;
        if (!currentPhotoPaths.contains(filePath)) {
          // This file is not referenced by any expense, delete it
          await file.delete();
          print_log("Removed orphaned image: $filePath");
        }
      }
    }
  } catch (e) {
    print_log("Error cleaning up orphaned images: $e");
  }
}


Future<String?> getDownloadFolder() async {
  try {


    final extDir = await getExternalStorageDirectory();
    if (!await extDir!.exists()) {
      await extDir.create(recursive: true);
    }
    final destinationPath1 = p.join(extDir.path, 'Orbipay');

    final destinationPath = Directory(destinationPath1);
    if (!await destinationPath.exists()) {
      await destinationPath.create(recursive: true);
    }

    
    print_log("File saved to Downloads: ${destinationPath.path}");
    return destinationPath.path;

  } catch (e) {
    print_log("Error saving image to Download folder: $e");
    return null;
  }
}



void sleep(int time,String duration) {
  switch(duration){
    case "s":
      Future.delayed(Duration(seconds: time));
    case "m":
      Future.delayed(Duration(milliseconds: time));
    default:
      Future.delayed(Duration(milliseconds: time));
  }
  
}





/// Checks if all items in a cart-like list have a quantity of zero or less.
///
/// Takes a list of maps, where each map represents an item and should contain a 'qty' key.
///
/// - Returns `true` if the list is empty or if all items have a quantity of 0 or less.
/// - Returns `false` if at least one item in the list has a quantity greater than 0.
bool areAllQuantitiesZero(List<Map<String, dynamic>> cart) {
  // If the cart is empty, then no items have a quantity > 0, so we can return true.
  if (cart.isEmpty) {
    return false;
  }

  // Iterate through each item in the cart.
  for (final item in cart) {
    // Safely parse the quantity, which could be an int, double, or even a string.
    final dynamic rawQty = item['qty'];
    final num qty = rawQty is num ? rawQty : num.tryParse(rawQty?.toString() ?? '0') ?? 0;
    print_log("qty check  ${qty} > 0 for $item");
    // If we find any item with a quantity greater than 0, we can stop and return false.
    if (qty <= 0) {
      return true;
    }
  }

  // If the loop completes without finding any item with qty > 0, it means the cart is effectively empty.
  return false;
}

/// 
/// ApiCalls { t - transection, l - login, a - addItem, m - menu, i - imageFile }
/// 
/// Payload Map<String, Object?>
/// 
/// hotelName 
/// 
Future<http.Response?> apiCalls(
  String apiCalls,
  String hotelName,
  Map<String, Object?>  payload,
  {String? token, String? id,String? start, String? end}
  ) async {
    print_log("apiCalls in utility $apiCalls hotelName $hotelName payload $payload");
    
    final prefs = await SharedPreferences.getInstance();
    final apicall = await prefs.getString("adminPanel") ?? "no";
    bool demo = prefs.getBool('demo') ?? false;   

    if (apicall.toLowerCase().contains("no") || demo) {
      print_log("in settel transection adminPanel not yes so Not send transection to the sever $apicall");
      switch(apiCalls){
        case "get_t":
          final response = await http.get(
            Uri.parse("https://api2.nextorbitals.in/api/save_transaction2.php?login_user=${hotelName}&start=$start&end=$end"),
            headers: {"Content-Type": "application/json"},
          ).timeout(Duration(seconds: 900));
          return response;
        case "m":
          final response = await http.get(
            Uri.parse("https://api2.nextorbitals.in/api/get_menu.php?hotel_name=$hotelName&menutype=ac",),
            headers: {'Content-Type': 'application/json'},
            ).timeout(Duration(seconds:900));
          return response;
        case "a":
          final response = await http.post(
            Uri.parse('https://api2.nextorbitals.in/api/add_item.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          ).timeout(Duration(seconds: 900));
          return response;
        case "delete_item":
          final response = await http.delete(
            Uri.parse('https://api2.nextorbitals.in/api/add_item.php?hotel_name=${AppConstants.username}&delete_type=single&submenu=${payload['item']}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          ).timeout(Duration(seconds: 900));
          return response;
        case "l":
          final response = await http.post(
            Uri.parse("https://api2.nextorbitals.in/api/login.php"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(payload),
          ).timeout(Duration(seconds: 900));
          return response;
        case "gv":
          final response = await http.get(
                Uri.parse("https://api2.nextorbitals.in/api/get_videos.php"),
                headers: {'Content-Type': 'application/json'},
              ).timeout(Duration(seconds: 900));
          return response;
        case "gs":
          final response = await http.get(
                Uri.parse("https://api2.nextorbitals.in/api/get_service.php"),
                headers: {'Content-Type': 'application/json'},
              ).timeout(Duration(seconds: 900));
          return response;
        case "gsp":
          final response = await http.post(
                Uri.parse("https://api2.nextorbitals.in/api/get_service.php"),
                headers: {'Content-Type': 'application/json'},
                body : jsonEncode(payload),
              ).timeout(Duration(seconds: 900));
          return response;
        default:
          return null;
      }
    }
    else {
    switch(apiCalls){
      case "get_t":
        final response = await http.get(
          Uri.parse("https://api2.nextorbitals.in/api/save_transaction2.php?login_user=${hotelName}&start=$start&end=$end"),
          headers: {"Content-Type": "application/json"},
        ).timeout(Duration(seconds: 900));
        return response;
      case "t":
        final response = await http.post(
          Uri.parse("https://api2.nextorbitals.in/api/save_transaction2.php"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        ).timeout(Duration(seconds: 900));
        return response;
      case "m":
        final response = await http.get(
          Uri.parse("https://api2.nextorbitals.in/api/get_menu.php?hotel_name=$hotelName&menutype=ac",),
          headers: {'Content-Type': 'application/json'},
          ).timeout(Duration(seconds:900));
        return response;
      case "a":
        final response = await http.post(
          Uri.parse('https://api2.nextorbitals.in/api/add_item.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(Duration(seconds: 900));
        return response;
      case "delete_item":
        final response = await http.delete(
          Uri.parse('https://api2.nextorbitals.in/api/add_item.php?hotel_name=${AppConstants.username}&delete_type=single&submenu=${payload['item']}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(Duration(seconds: 900));
        return response;
      case "addStock": //"operation": "add", "operation": "reduce","items": [ {"id": 123,"quantity": 2},]
        final response = await http.post(
          Uri.parse('https://api2.nextorbitals.in/api/stock_update.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(Duration(seconds: 900));
        return response;
      case "l":
        final response = await http.post(
          Uri.parse("https://api2.nextorbitals.in/api/login.php"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        ).timeout(Duration(seconds: 900));
        return response;
      case "i":
        final apiUrl = Uri.parse("https://api2.nextorbitals.in/api/menu_filename.php?hotel_name=${hotelName}",);
        http.Response response = await http.get(apiUrl).timeout(Duration(seconds: 900));
        return response;
      case "s":
        final response = await http.post(
              Uri.parse('https://api2.nextorbitals.in/api/sent_fcm1.php'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(payload),
            ).timeout(Duration(seconds: 900));
        return response;
      case "st":
        final String apiUrl = 'https://api2.nextorbitals.in/api/save_token.php?hotel=$hotelName&token=$token';
        final response = await http.get(Uri.parse(apiUrl)).timeout(Duration(seconds: 900));
        return response;
      case "ex_save":
        final response = await http.post(
          Uri.parse("https://api2.nextorbitals.in/api/save_expenses.php"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        ).timeout(Duration(seconds: 900));
        return response;
      case "ex_get":
        final response = await http.get(
          Uri.parse("https://api2.nextorbitals.in/api/save_expenses.php?login_user=$hotelName"),
          headers: {"Content-Type": "application/json"},
        ).timeout(Duration(seconds: 900));
        return response;
      case "ex_delete":
        final response = await http.delete(
          Uri.parse("https://api2.nextorbitals.in/api/save_expenses.php?login_user=$hotelName&id=$id"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        ).timeout(Duration(seconds: 900));
        return response;
        case "ud_save":
        final response = await http.post(
          Uri.parse("https://api2.nextorbitals.in/api/save_udhari.php"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        ).timeout(Duration(seconds: 900));
        return response;
      case "ud_get":
        final response = await http.get(
          Uri.parse("https://api2.nextorbitals.in/api/save_udhari.php?login_user=$hotelName"),
          headers: {"Content-Type": "application/json"},
        ).timeout(Duration(seconds: 900));
        return response;
      case "ud_delete":
        final response = await http.delete(
          Uri.parse("https://api2.nextorbitals.in/api/save_udhari.php?login_user=$hotelName&id=$id"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        ).timeout(Duration(seconds: 900));
        return response;
      case "get_billno":
        final response = await http.get(
          Uri.parse("https://api2.nextorbitals.in/api/get_billno.php?login_user=${hotelName}"),
          headers: {"Content-Type": "application/json"},
        ).timeout(Duration(seconds: 900));
        return response;
      case "get_plate":
        final response = await http.get(
          Uri.parse("https://api2.nextorbitals.in/api/inventory_api.php?login=${AppConstants.username}"),
          headers: {"Content-Type": "application/json"},
        ).timeout(Duration(seconds: 900));
        return response;
      case "set_plate":
        final response = await http.post(
              Uri.parse("https://api2.nextorbitals.in/api/inventory_api.php?login=${AppConstants.username}"),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(payload),
            ).timeout(Duration(seconds: 900));
        return response;
      case "add_plate":
        final response = await http.post(
              Uri.parse("https://api2.nextorbitals.in/api/inventory_api.php?login=${AppConstants.username}"),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(payload),
            ).timeout(Duration(seconds: 900));
        return response;
      case "save_recipe":
        final response = await http.post(
              Uri.parse("https://api2.nextorbitals.in/api/inventory_api.php?login=${AppConstants.username}"),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(payload),
            ).timeout(Duration(seconds: 900));
        return response;
      case "delete_inventory":
        final response = await http.post(
              Uri.parse("https://api2.nextorbitals.in/api/inventory_api.php?login=${AppConstants.username}"),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(payload),
            ).timeout(Duration(seconds: 900));
        return response;
      case "gv":
        final response = await http.get(
              Uri.parse("https://api2.nextorbitals.in/api/get_videos.php"),
              headers: {'Content-Type': 'application/json'},
            ).timeout(Duration(seconds: 900));
        return response;
      case "gs":
        final response = await http.get(
              Uri.parse("https://api2.nextorbitals.in/api/get_service.php"),
              headers: {'Content-Type': 'application/json'},
            ).timeout(Duration(seconds: 900));
        return response;
      case "gsp":
          final response = await http.post(
                Uri.parse("https://api2.nextorbitals.in/api/get_service.php"),
                headers: {'Content-Type': 'application/json'},
                body : jsonEncode(payload),
              ).timeout(Duration(seconds: 900));
          return response;
      default:
        return null;
    }

  }
}


/// 
/// businessDateKey - 'businessDate' dd/mm/yyy hh;mm;ss.sss
/// 
Future<DateTime> getBussinessDateStorage(String date) async {
  final prefs = await SharedPreferences.getInstance();
  final businessDateString = prefs.getString(AppConstants.businessDateKey) ?? DateTime.now().toString();
  final now = DateTime.now();
  final businessDatePart = DateTime.parse(date);
  final fullDateTime = DateTime(
        businessDatePart.year,
        businessDatePart.month,
        businessDatePart.day,
        now.hour,
        now.minute,
        now.second,
      );
  print_log("BUsiness Date is $fullDateTime");
  return fullDateTime;
  
}


/// 
/// businessDateKey - 'businessDate' ddmmyyy 00;00;00
/// 
Future<DateTime> getBussinessDateOnly() async {
  final prefs = await SharedPreferences.getInstance();
  final businessDateString = prefs.getString(AppConstants.businessDateKey) ?? DateTime.now().toString();
  final now = DateTime.now();
  final businessDatePart = DateTime.parse(businessDateString);
  final fullDateTime = DateTime(
        businessDatePart.year,
        businessDatePart.month,
        businessDatePart.day,
      );
  print_log("BUsiness Date is $fullDateTime");
  return fullDateTime;
  
}




  Future<bool> askPassword(BuildContext context) async {
    final TextEditingController _pwdController = TextEditingController();
    bool verified = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Enter Password"),
          content: TextField(
            controller: _pwdController,
            keyboardType: TextInputType.number, // 🔑 Number keypad
            obscureText: true,
            decoration: InputDecoration(
              hintText: "Password",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // cancel
              },
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final savedPwd = await getSavedPassword();
                // print_log("_pwdController.text == savedPwd ${_pwdController.text} $savedPwd}");
                if (_pwdController.text == savedPwd) {
                  // print_log(  "verifyed $verified");
                  verified = true;
                  // print_log(  "verifyed $verified");
                  Navigator.pop(ctx); // ✅ close only if correct
                } else {
                  // print_log(  "verifyed else $verified");
                  await ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text("❌ Password is wrong"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
    print_log(  "verifyed end $verified");
    return verified;
  }

  Future<String?> getSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.appPasswordKey) ?? "1234"; // 🔑 key for password
  }

Map<String, Map<String, dynamic>> getmenyBycart(List<Map<String, dynamic>> cart1, Store store) {
  final _menuItemBox = store.box<MenuItem>();
  
  // 1. Get all items from ObjectBox
  final items = _menuItemBox.getAll();
  
  // 2. Create a lookup dictionary for fast matching
  final menuLookup = {for (var item in items) item.name: item};
  
  // 3. Initialize the Map you want to return
  Map<String, Map<String, dynamic>> matchedItems = {};

  // 4. Loop through the cart and populate the map
  for (var cartItem in cart1) {
    String itemName = cartItem['name']; // Ensure this matches your cart's key
    
    if (menuLookup.containsKey(itemName)) {
      MenuItem matchedMenu = menuLookup[itemName]!;
      
      // Map the cart item name (key) to the menu item's database details (value)
      matchedItems[itemName] = matchedMenu.toMap();
    } else {
      print_log("Warning: $itemName from cart was not found in the database.");
    }
  }

  return matchedItems;
}



/// POST /stock_update_api.php
/// {
///     "hotel_name": "your_hotel_table",
///     "operation": "add",     //////// or "operation": "reduce",
///     "items": [
///         {
///             "submenu": "Pizza",
///             "quantity": 10
///         },
///         {
///             "submenu": "Burger",
///             "quantity": 5
///         }
///     ]
/// }

Future<bool> sendStockToServer(MenuItem item, int addValue, {bool? isOverride}) async {
  try {
    print_log('✅ No stock change needed #$addValue# $item');
    final prefs = await SharedPreferences.getInstance();
    final String? hotelName = prefs.getString(AppConstants.usernameKey);
    
    if (hotelName == null || hotelName.isEmpty) {
      throw Exception('Hotel name not found');
    }

    // Determine operation based on addValue
    String operation;
    int quantity;
    
    // if (isOverride) {
    //   // For override, we need to calculate the difference
    //   int currentStock = item.adjustStock ?? 0;
    //   if (addValue > currentStock) {
    //     operation = 'add';
    //     quantity = addValue - currentStock;
    //   } else if (addValue < currentStock) {
    //     operation = 'reduce';
    //     quantity = currentStock - addValue;
    //   } else {
    //     // No change
    //     print_log('✅ No stock change needed');
    //     return;
    //   }
    // } else {
      // For normal add/reduce using +/- values
      if (addValue > 0) {
        operation = 'add';
        quantity = addValue;
      } else if (addValue < 0) {
        operation = 'reduce';
        quantity = addValue.abs(); // Convert to positive for reduce operation
      } else {
        // No change (addValue == 0)
        print_log('✅ No stock change needed');
        return true;
      }
    // }

    
    final requestBody = {
      'hotel_name': hotelName,
      'operation': operation,
      'items': [
        {
          'submenu': item.name, // Use submenu name as fallback
          'quantity': quantity,
        }
      ]
    };

    print_log('📤 Sending stock update to server: $requestBody');

    http.Response? response = await apiCalls("addStock", hotelName, requestBody);
      if (response == null) {
        return false;
      }

    if (response.statusCode == 200 || response.statusCode == 207) {
      final responseData = json.decode(response.body);
      
      if (responseData['success'] == true) {
        print_log('✅ Stock updated successfully on server: ${responseData['message']}');
        
        // Update local item with server response data if needed
        if (responseData['updated_items'] != null && responseData['updated_items'].isNotEmpty) {
          final updatedItem = responseData['updated_items'][0];
          return true;
          // You can update any additional fields from server if needed
        }
      } else {
        // Partial success or failure
        print_log('⚠️ Server returned partial success: ${responseData['message']}');
        if (responseData['failed_items'] != null && responseData['failed_items'].isNotEmpty) {
          print_log_red('Failed items: ${responseData['failed_items']}');
          // throw Exception();
        }
      }
    } else {
      print_log_red('Server error: ${response.statusCode} - ${response.body}');
      // throw Exception();
    }
  } catch (e) {
    print_log_red('❌ Error sending stock to server: $e');
  }
  return false;
}

  Future<void> loadtransections(http.Response? response, SharedPreferences prefs,Store store,BuildContext context) async {
      final box = store.box<Transaction>();
      final printer = BillPrinter();
      try {
        if (response == null) {
          print_log_red("transection server response GOT NULL");
          return;
        }
        if (response.statusCode == 200) {
          final jsonData = jsonDecode(response.body);
          final dataList = jsonData['data'];
          if (dataList is List) {
            final localTransactions = box.getAll();
            final localBillNos = localTransactions.map((tx) => tx.billNo).toSet();
            int newTransactionsCount = 0;

            for (var serverTxData in dataList) {
              try {
                final serverTxMap = Map<String, dynamic>.from(serverTxData);
                final transactionField = serverTxMap['transaction'];
                Map<String, dynamic> transactionData;
                if (transactionField is String) {
                  final decoded = jsonDecode(transactionField);
                  if (decoded is Map) {
                    transactionData = Map<String, dynamic>.from(decoded);
                  } else {
                    print_log("❌ Decoded data is not a Map");
                    continue;
                  }
                } else if (transactionField is Map) {
                  transactionData = Map<String, dynamic>.from(transactionField);
                } else {
                  print_log("❌ Unexpected transaction field type $transactionField");
                  continue;
                }
                
                
                // SAFELY parse all fields with proper null handling
                final int serverBillNo = _safeParseInt(transactionData['billNo'], defaultValue: 0);
                
                if (serverBillNo != 0) {
                  
                  try {
                    if (localBillNos.contains(serverBillNo)) {
                      final transaction = Transaction.fromMap(transactionData);
                      final tableCart_query = box.query(Transaction_.billNo.equals(serverBillNo)).build();
                      Transaction? existingTx = tableCart_query.findFirst();
                      tableCart_query.close();
                      
                      if (existingTx != null) {
                        existingTx.syid = transaction.syid;
                        existingTx.time = transaction.time;
                        existingTx.total = transaction.total;
                        existingTx.cartData = transaction.cartData; // This should be the current cart
                        existingTx.payment_mode = transaction.payment_mode; // This should be the new payment mode
                        existingTx.status = transaction.status;
                        existingTx.synced = transaction.synced; // Mark as unsynced after modification
                        existingTx.serviceCharge = transaction.serviceCharge; // 1.0
                        existingTx.discount = transaction.discount; // 10.0
                        existingTx.discountPercent = transaction.discountPercent;
                        existingTx.customerName = transaction.customerName; // '28282'
                        existingTx.mobileNo =transaction.mobileNo; // '386838'
                        existingTx.reserved = transaction.reserved;
                        existingTx.orderType = transaction.orderType;
                        existingTx.cashamount = transaction.cashamount;
                        existingTx.upiamount = transaction.upiamount;
                        existingTx.modificationsHistory = transaction.modificationsHistory;
                        existingTx.hotelName = transaction.hotelName;
                        existingTx.reserved_field = transaction.reserved_field;
                        existingTx.reserved_field1 = transaction.reserved_field1;
                        existingTx.reserved_field2 = transaction.reserved_field2;
                        existingTx.reserved_field3 = transaction.reserved_field3;
                        existingTx.reserved_field4 = transaction.reserved_field4;
                        existingTx.reserved_field5 = transaction.reserved_field5;

                        box.put(existingTx);
                        print_log("✅ updated transaction: $serverBillNo");
                      }

                    }else{
                      final transaction = Transaction.fromMap(transactionData);
                      box.put(transaction);
                      printer.setNextBillNo(context, transactionData['billNo']);
                      newTransactionsCount++;
                      print_log("✅ Added transaction: $serverBillNo");
                    }
                  } catch (e) {
                    print_log_red("❌ Error creating transaction: $e");
                    print_log("Transaction data: $transactionData");
                  }
                  
                }
                
              } catch (e) {
                print_log_red("❌ Error processing transaction: $e");
                continue;
              }
            }
            if (newTransactionsCount > 0) {
              print_log("✅ Synced $newTransactionsCount new transactions from server.");
              
            } else {
              print_log("No new transactions found");
            }
          } else {
            print_log_red("❌ 'data' is not a list");
          }
        } else {
          print_log_red('HTTP Error: ${response.statusCode}: ${response.reasonPhrase}');
        }
      } catch (error) {
        screen_massage(context, "Error syncing transactions: $error");
        print_log_red("❌ Error in loadtransections: $error");
      }
    }

  int _safeParseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      if (value.isEmpty) return defaultValue;
      return int.tryParse(value) ?? defaultValue;
    }
    if (value is num) return value.toInt();
    return defaultValue;
  }




  



