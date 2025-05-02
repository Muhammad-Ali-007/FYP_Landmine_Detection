import 'dart:convert';  // For base64 decoding
import 'dart:typed_data';  // For Uint8List
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'package:google_fonts/google_fonts.dart';  // Add this import
import 'records_page.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Landmine Detection',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: GoogleFonts.latoTextTheme(Theme.of(context).textTheme),  // Apply Google Font
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: GoogleFonts.lato(fontSize: 16),
          ),
        ),
      ),
      home: const ImageUploadPage(),
    );
  }
}

class ImageUploadPage extends StatefulWidget {
  const ImageUploadPage({super.key});

  @override
  _ImageUploadPageState createState() => _ImageUploadPageState();
}

class _ImageUploadPageState extends State<ImageUploadPage> {
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _imageResults = [];  // Updated to store additional data
  bool _isUploading = false;

  Future<void> pickAndUploadImages() async {
    final List<XFile>? imageFiles = await _picker.pickMultiImage();

    if (imageFiles != null && imageFiles.isNotEmpty) {
      setState(() {
        _isUploading = true;
      });

      try {
        final results = await uploadImages(imageFiles);

        setState(() {
          _imageResults = results.map((result) {
            final imageData = result['image_data'];
            final numMines = result['num_mines'];
            return {
              'image_bytes': imageData != null ? base64Decode(imageData) : null,
              'num_mines': numMines
            };
          }).toList();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload images: $e')),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Landmine Detection', style: GoogleFonts.lato()),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 600),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 4,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Upload images for landmine detection',
                    style: GoogleFonts.lato(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: pickAndUploadImages,
                    child: const Text('Pick and Upload Images'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RecordsPage()),
                      );
                    },
                    child: const Text('View Detection Records'),
                  ),
                  if (_isUploading)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  if (_imageResults.isNotEmpty)
                    Column(
                      children: _imageResults.map((result) {
                        final imageBytes = result['image_bytes'] as Uint8List?;
                        final numMines = result['num_mines'] as int? ?? 0;
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  imageBytes!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Number of Mines: $numMines',
                                style: GoogleFonts.lato(fontSize: 18, color: Colors.black87),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  if (_imageResults.isEmpty && !_isUploading)
                    Text(
                      'No images selected',
                      style: GoogleFonts.lato(fontSize: 18, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
