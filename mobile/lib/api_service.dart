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
    print('Starting video processing for: ${videoFile.path}');

    try {
      // Verify file exists
      if (!await videoFile.exists()) {
        throw Exception('Video file does not exist');
      }

      // Create request
      var request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath(
          'video',
          videoFile.path,
          contentType: MediaType('video', '*'),
        ));

      print('Sending video to API...');
      final response = await request.send();

      // Handle response
      if (response.statusCode == 200) {
        // Get mines detected from headers
        final minesDetected = int.tryParse(response.headers['mines_detected'] ?? '0') ?? 0;

        // Save processed video
        final tempDir = await Directory.systemTemp.createTemp();
        final processedFile = File('${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.mp4');

        // Write response to file
        await processedFile.writeAsBytes(await response.stream.toBytes());

        if (!await processedFile.exists()) {
          throw Exception('Failed to save processed video');
        }

        return {
          'success': true,
          'processed_path': processedFile.path,
          'mines_detected': minesDetected,
        };
      } else {
        final error = await response.stream.bytesToString();
        throw Exception('API Error ${response.statusCode}: $error');
      }
    } catch (e) {
      print('Video processing error: $e');
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
