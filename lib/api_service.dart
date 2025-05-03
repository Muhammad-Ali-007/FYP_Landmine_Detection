// lib/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart'; // Add this import

 
class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5000/flutter';

  static Future<List<dynamic>> getRecords() async {
    final response = await http.get(Uri.parse('$baseUrl/records'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load records');
    }
  }

  static Future<Map<String, dynamic>> processVideo(File videoFile) async {
  final uri = Uri.parse('$baseUrl/process_video');
  
  try {
    // Create multipart request
    var request = http.MultipartRequest('POST', uri);
    
    // Add video file
    request.files.add(await http.MultipartFile.fromPath(
      'video', // This should match the field name expected by your Flask API
      videoFile.path,
      contentType: MediaType('video', 'mp4'), // Ensure this matches your video type
    ));

    // Send request and get response
    final response = await request.send();

    // Check status code
    if (response.statusCode == 200) {
      // Read response as bytes
      final responseBytes = await response.stream.toBytes();
      
      // Check content type to determine if it's a video or JSON response
      final contentType = response.headers['content-type']?.toLowerCase();
      
      if (contentType?.contains('video') ?? false) {
        // Save processed video
        final tempDir = await Directory.systemTemp.createTemp();
        final processedFile = File('${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await processedFile.writeAsBytes(responseBytes);

        return {
          'success': true,
          'processedPath': processedFile.path,
          'contentType': contentType,
        };
      } else {
        // Handle JSON response if API returns data instead of video
        final responseString = utf8.decode(responseBytes);
        final jsonResponse = json.decode(responseString);
        return {
          'success': true,
          'data': jsonResponse,
        };
      }
    } else {
      // Handle error response
      final responseString = await response.stream.bytesToString();
      try {
        final errorData = json.decode(responseString);
        throw Exception(errorData['message'] ?? 'Video processing failed with status ${response.statusCode}');
      } catch (_) {
        throw Exception('Video processing failed with status ${response.statusCode}: $responseString');
      }
    }
  } catch (e) {
    print('Error processing video: $e');
    rethrow;
  }
}

static Future<List<Map<String, dynamic>>> uploadImages(List<XFile> imageFiles) async {
  final uri = Uri.parse('http://127.0.0.1:5000/flutter/upload');

  try {
    final request = http.MultipartRequest('POST', uri);
    
    // Add all files
    for (var imageFile in imageFiles) {
      final bytes = await imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'file', 
        bytes,
        filename: imageFile.name,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(responseBody) as List;
      return jsonResponse.map((item) => {
        'original_filename': item['original_filename'],
        'image_data': item['image_data'],
        'num_mines': item['num_mines']
      }).toList();
    } else {
      // Parse error message if available
      final errorData = json.decode(responseBody);
      throw Exception(errorData['message'] ?? 'Upload failed with status ${response.statusCode}');
    }
  } catch (e) {
    print('Upload Error: $e');
    rethrow;
  }
}
}
