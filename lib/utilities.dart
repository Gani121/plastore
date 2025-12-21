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


enum keys {
  order_type_list,
  ThemeModeDark,
  ThemeModeSystem,
}




class AppConstants {
  static String test_version = "";
  static String app_version = "1.0.0";
  static String objectbox_path = "";
  
  AppConstants._();


  static Future<void> initialize() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      // Automatically gets the ID defined in your build.gradle/versions.properties
      test_version = packageInfo.packageName; 
      app_version = packageInfo.version;
      // final dir1 = await getApplicationDocumentsDirectory();
      final dir = await getApplicationDocumentsDirectory();
      // objectbox_path = '${(dir1 ?? dir).path}/objectbox';
      objectbox_path = '${dir.path}/objectbox';

      debugPrint("✅ AppConstants initialized: $test_version, $app_version $objectbox_path");
    } catch (e) {
      debugPrint("⚠️ Failed to load package info: $e");
    }
  }


}


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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("$massage.")),
  );
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

    // 1. Request Storage Permissions (Required for Android 11+)
    // if (!await requestPermission()) {
    //   print_log("Permission denied: Cannot access internal storage.");
    //   return "";
    // }


    // Returns: /storage/emulated/0/Download
    // final downloadPath = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOWNLOAD);
    // final saveDir = Directory(downloadPath);
    // if (!await saveDir.exists()) {
    //   await saveDir.create(recursive: true);
    // }
    // final destinationPath1 = p.join(saveDir.path, 'Orbipay');


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



// Helper function to handle the strict Android 11+ permissions
// Future<bool> requestPermission() async {
//   if (Platform.isAndroid) {
//     // Check for Android 11+ (API 30+)
//     if (await Permission.manageExternalStorage.isDenied) {
//       // 1. Request the permission
//       var status = await Permission.manageExternalStorage.request();
      
//       // 2. If valid but denied, open the specific settings page
//       if (!status.isGranted) {
//         print_log("Opening system settings for All Files Access...");
//         await openAppSettings(); // from permission_handler package
//         // Note: The user has to toggle it manually and come back.
//         // You might need to check status again or restart the action.
//         return await Permission.manageExternalStorage.isGranted;
//       }
//       return status.isGranted;
//     }
//   }
//   return true;
// }



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

// Future<String> getMediaFolderpath() async {
//   try {
//     // 1. Get the Root Storage path (e.g., /storage/emulated/0)
//     final List<String>? paths = await ExternalPath.getExternalStorageDirectories();
//     final String rootPath = paths!.first; // The first one is usually internal storage

//     // 2. Define your package name
//     // You can hardcode it: String packageName = "com.orbipay.test6";
//     // Or get it dynamically (Recommended):
//     PackageInfo packageInfo = await PackageInfo.fromPlatform();
//     String packageName = packageInfo.packageName;

//     // 3. Construct the specific Android/media path
//     // Target: /storage/emulated/0/Android/media/com.orbipay.test6
//     final String mediaPath = "$rootPath/Android/media/$packageName";
    
//     // 4. Create the directory
//     final Directory mediaDir = Directory(mediaPath);
//     if (!await mediaDir.exists()) {
//       await mediaDir.create(recursive: true);
//       // print("Created Media Folder: ${mediaDir.path}");
//     }

//     return mediaDir.path;
//   } catch (e) {
//     print_log_red("Error creating media folder: $e");
//     return "";
//   }
// }
