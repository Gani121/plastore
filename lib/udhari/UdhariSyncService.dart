import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database_Module/udharicustomer.dart';
import '../utilities.dart'; // Import your entity
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class UdhariSyncService {
  static const String baseUrl = "https://your-domain.com/save_udhari.php"; 

  // 1. Sync a Single Customer (Save/Update)
  static Future<void> syncCustomer(udhariCustomer customer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
    final apicall = await prefs.getString("adminPanel") ?? "no";
    bool demo = prefs.getBool('demo') ?? false;   
    
    if (apicall.toLowerCase().contains("no") || demo) {
      print_log("❌ in settel transection adminPanel not yes so Not send transection to the sever $apicall");
      return;
    }
    final loginUser = await prefs.getString(AppConstants.usernameKey) ?? "";
      
      final payload = {
          'login_user': loginUser,
          'id': customer.id.toString(), // ObjectBox ID
          'name': customer.name,
          'mobile': customer.phone ?? "", // Assuming you have a mobile field
          'balance': customer.balance,
        };
       http.Response? response = await apiCalls("ud_save", loginUser, payload);
        if (response == null) {
          return;
        }
      if (response.statusCode != 200) {
        print_log("Failed to sync customer: ${response.body}");
      }
    } catch (e) {
      print_log_red("Error syncing customer: $e");
    }
  }

  // 2. Delete Customer from Cloud
  static Future<void> deleteCustomer(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
    final apicall = await prefs.getString("adminPanel") ?? "no";
    final loginUser = await prefs.getString(AppConstants.usernameKey) ?? "";
    bool demo = prefs.getBool('demo') ?? false;   
    
    if (apicall.toLowerCase().contains("no") || demo) {
      print_log("❌ in settel transection adminPanel not yes so Not send transection to the sever $apicall");
      return;
    }
      http.Response? response = await apiCalls("ud_delete", loginUser, {},id:id);
        if (response == null) {
          return;
        }
    } catch (e) {
      print_log_red("Error deleting cloud customer: $e");
    }
  }

  // 3. Fetch All from Cloud (Restore)
  // This returns a list of maps you can use to populate ObjectBox
  static Future<List<Map<String, dynamic>>> fetchFromCloud() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apicall = await prefs.getString("adminPanel") ?? "no";
      final loginUser = await prefs.getString(AppConstants.usernameKey) ?? "";
      bool demo = prefs.getBool('demo') ?? false;   
      
      if (apicall.toLowerCase().contains("no") || demo) {
        print_log("❌ in settel transection adminPanel not yes so Not send transection to the sever $apicall");
        return [];
      }
      http.Response? response = await apiCalls("ud_get", loginUser, {});
        if (response == null) {
          return [];
        }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // print_log("get data from server ${data}");
        if (data['success'] == true) {
          List<Map<String, dynamic>> list = (data['data'] as List).cast<Map<String, dynamic>>();
          print_log("udhari ${list}");
          return list;
        }
      }
    } catch (e) {
      print_log_red("Error fetching cloud data: $e");
    }
    return [];
  }
}