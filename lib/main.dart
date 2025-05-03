import 'dart:convert';  // For base64 decoding
import 'dart:typed_data';  // For Uint8List
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'package:google_fonts/google_fonts.dart';  // Add this import
import 'records_page.dart';
import 'dashboard_page.dart';


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
        textTheme: GoogleFonts.latoTextTheme(
          Theme.of(context).textTheme,
        ).copyWith(
          // For backward compatibility
          bodyLarge: GoogleFonts.lato(),
          bodyMedium: GoogleFonts.lato(),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.latoTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: const DashboardPage(),
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
  List<Map<String, dynamic>> _imageResults = [];
  bool _isUploading = false;

  // Color scheme matching dashboard
  static const Color primaryDarkBlue = Color(0xFF0A1F3D);
  static const Color secondaryBlue = Color(0xFF1A3A6A);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  // static const Color textDark = Color(0xFF2D3748);
  static const Color textLight = Color(0xFF718096);
  static const Color successGreen = Color(0xFF38A169);

  Future<void> pickAndUploadImages() async {
    final List<XFile>? imageFiles = await _picker.pickMultiImage();

    if (imageFiles != null && imageFiles.isNotEmpty) {
      setState(() {
        _isUploading = true;
      });

      try {
        final results = await ApiService.uploadImages(imageFiles);

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
          SnackBar(
            content: Text('Failed to upload images: $e'),
            backgroundColor: Colors.red[400],
          ),
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
      backgroundColor: lightBackground,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'logo-dark.png',
              height: 30,
              errorBuilder: (context, error, stackTrace) => 
                  Icon(Icons.security, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Landmine Detection',
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryDarkBlue, secondaryBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 800),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Thermal Image Analysis',
                    style: GoogleFonts.lato(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primaryDarkBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Upload thermal images for landmine detection using our AI system',
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      color: textLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildActionButton(
                        icon: Icons.upload_file,
                        label: 'Upload Images',
                        onPressed: pickAndUploadImages,
                        color: accentOrange,
                      ),
                      const SizedBox(width: 20),
                      _buildActionButton(
                        icon: Icons.history,
                        label: 'View Records',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RecordsPage()),
                        ),
                        color: secondaryBlue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  if (_isUploading)
                    Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(
                          'Analyzing thermal patterns...',
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            color: textLight,
                          ),
                        ),
                      ],
                    ),
                  if (_imageResults.isNotEmpty)
                    Column(
                      children: _imageResults.map((result) {
                        final imageBytes = result['image_bytes'] as Uint8List?;
                        final numMines = result['num_mines'] as int? ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cardWhite,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    imageBytes!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: numMines > 0 
                                        ? Colors.red.shade50 
                                        : successGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        numMines > 0 
                                            ? Icons.warning_amber_rounded 
                                            : Icons.check_circle,
                                        color: numMines > 0 
                                            ? Colors.red.shade700 
                                            : successGreen,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        numMines > 0
                                            ? '$numMines potential landmine(s) detected'
                                            : 'No landmines detected',
                                        style: GoogleFonts.lato(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: numMines > 0 
                                              ? Colors.red.shade700 
                                              : successGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  if (_imageResults.isEmpty && !_isUploading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.thermostat_auto,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Upload thermal images to begin analysis',
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              color: textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: 180,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.2),
        ),
      ),
    );
  }
}
