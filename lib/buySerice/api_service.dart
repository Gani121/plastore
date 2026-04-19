import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:test1/utilities.dart';
import 'service_model.dart'; // Ensure this path is correct

class ApiService {
  

  static Future<List<ServiceModel>> fetchServices() async {
    try {
      final response = await apiCalls('gs', "hotelname", {},);
      if(response == null){
        return [];
      }

      if (response.statusCode == 200) {
        // 1. Decode the string into a List
        print_log("Server response: ${response.body}");
        List<dynamic> body = jsonDecode(response.body);

        // 2. Map each item in the list to a ServiceModel object
        List<ServiceModel> services = body .map((dynamic item) => ServiceModel.fromJson(item)).toList();

        return services;
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      // Catch network or parsing errors
      throw Exception("Failed to connect to server: $e");
    }
  }
}