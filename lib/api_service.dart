// lib/api_service.dart
import 'dart:convert';
// import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

Future<List<Map<String, dynamic>>> uploadImages(List<XFile> imageFiles) async {
  final uri = Uri.parse('http://127.0.0.1:5000/flutter/upload');  // Update if needed

  try {
    final request = http.MultipartRequest('POST', uri);

    for (XFile imageFile in imageFiles) {
      final bytes = await imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: imageFile.name));
    }

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseBody) as List<dynamic>;

      return jsonResponse.map((item) {
        return {
          'original_filename': item['original_filename'],
          'image_data': item['image_data'],
          'num_mines': item['num_mines'] // Add this line
        };
      }).toList();
    } else {
      print('Upload failed with status: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    print('Error uploading images: $e');
    return [];
  }
}

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
}
