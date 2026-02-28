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
// import 'package:external_path/external_path.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;


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

List<String> units = ["Nos","mg","g","kg","ton","ml","Ltr","quart","gallon","peg","unit","pack","box","btl","pkt","bag","carton","crate","tin","can","jar","pouch","sachet","bundle","dozen","gross"];
// List<String> units = ['Nos', 'Grams', 'Kg', 'Ltr', 'Slices'];


void addToPrefs(String key, String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

Future<String> getDatafromPrefs(String key,) async {
  final prefs = await SharedPreferences.getInstance();
   return prefs.getString(key) ?? '';
}

String formatDate(DateTime date) {
  return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} ${date.hour.toString().padLeft(2, '0')}/${date.minute.toString().padLeft(2, '0')}/${date.second.toString().padLeft(2, '0')}";
}

String formatDateAM_PM(DateTime date) {
  return DateFormat('dd MMM yyyy – hh:mm a').format(date);
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
      SnackBar(content: Text("$massage.")),
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
      print_log("❌ in settel transection adminPanel not yes so Not send transection to the sever $apicall");
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
      default:
        return null;
    }

  }
}


/// 
/// businessDateKey - 'businessDate'
/// 
Future<DateTime> getBussinessDateStorage() async {
  final prefs = await SharedPreferences.getInstance();
  final businessDateString = prefs.getString(AppConstants.businessDateKey) ?? DateTime.now().toString();
  final now = DateTime.now();
  final businessDatePart = DateTime.parse(businessDateString);
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



