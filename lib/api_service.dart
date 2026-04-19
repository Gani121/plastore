// services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database_Module/video_model.dart';
import 'package:test1/utilities.dart';

class ApiService {
  
  Future<List<TrainingVideo>> getVideos() async {
    try {


      final response = await apiCalls('gv', "hotelname", {});
      if (response == null) {
        return [];
      }
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['success'] == true) {
          List<dynamic> videosJson = data['data'];
          // print(videosJson);
          return videosJson.map((json) => TrainingVideo.fromJson(json)).toList();
        } else {
          // print('API returned error: ${data['error']}');
          throw Exception('API returned error: ${data['error']}');
        }
      } else {
        // print('Failed to load videos. Status: ${response.statusCode}');
        throw Exception('Failed to load videos. Status: ${response.statusCode}');
      }
    } catch (e) {
      // print('Network error: $e');
      throw Exception('Network error: $e');
    }
  }
}