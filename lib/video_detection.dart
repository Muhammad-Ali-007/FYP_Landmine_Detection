import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

class VideoDetectionPage extends StatefulWidget {
  const VideoDetectionPage({super.key});

  @override
  _VideoDetectionPageState createState() => _VideoDetectionPageState();
}

class _VideoDetectionPageState extends State<VideoDetectionPage> {
  // Color scheme matching dashboard
  static const Color primaryDarkBlue = Color(0xFF0A1F3D);
  static const Color secondaryBlue = Color(0xFF1A3A6A);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2D3748);
  static const Color textLight = Color(0xFF718096);
  static const Color successGreen = Color(0xFF38A169);

  File? _inputVideo;
  File? _processedVideo;
  VideoPlayerController? _inputController;
  VideoPlayerController? _processedController;
  bool _isProcessing = false;
  bool _hasResults = false;
  int? _minesDetected;
  String _processingStatus = 'Select a video to begin analysis';

  @override
  void initState() {
    super.initState();
    _processingStatus = 'Select a video to begin analysis';
  }

  @override
  void dispose() {
    _inputController?.dispose();
    _processedController?.dispose();
    super.dispose();
  }

Future<void> _pickVideo() async {
  print('Picking video from gallery...');
  print('Platform: ${Platform.operatingSystem}');
  try {
    final pickedFile = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    
    if (pickedFile != null) {
      // Verify the file exists and is accessible
      final videoFile = File(pickedFile.path);
      final fileExists = await videoFile.exists();
      
      if (!fileExists) {
        throw Exception('The selected video file is not accessible');
      }

      // Check file size (optional)
      final fileSize = await videoFile.length();
      if (fileSize > 100 * 1024 * 1024) { // 100MB limit
        throw Exception('Video file is too large (max 100MB)');
      }

      // Initialize controllers
      final newController = VideoPlayerController.file(videoFile);
      await newController.initialize();

      setState(() {
        _inputController?.dispose();
        _inputController = newController;
        _inputVideo = videoFile;
        _hasResults = false;
        _minesDetected = null;
        _processedVideo = null;
        _processingStatus = 'Video selected. Ready to process.';
      });
    }
  } on PlatformException catch (e) {
    setState(() {
      _processingStatus = 'Error: ${e.message ?? 'Failed to access video'}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video selection failed: ${e.message}'),
        backgroundColor: Colors.red,
      ),
    );
  } catch (e) {
    setState(() {
      _processingStatus = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

 Future<void> _processVideo() async {
    if (_inputVideo == null) {
      setState(() => _processingStatus = 'Please select a video first');
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Processing video...';
    });

    try {
      final result = await ApiService.processVideo(_inputVideo!);
      
      if (result['success'] == true) {
        final processedPath = result['processed_path'];
        if (processedPath != null && await File(processedPath).exists()) {
          setState(() {
            _processedVideo = File(processedPath);
            _minesDetected = result['mines_detected'] ?? 0;
            _hasResults = true;
            _processingStatus = 'Analysis complete. ${_minesDetected} mines detected.';
          });
          await _initializeVideoPlayer(_processedVideo!, isInput: false);
        } else {
          throw Exception('Processed video file not found');
        }
      } else {
        throw Exception(result['message'] ?? 'Video processing failed');
      }
    } catch (e) {
      setState(() {
        _processingStatus = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processing failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

Future<void> _initializeVideoPlayer(File file, {required bool isInput}) async {
  try {
    final controller = VideoPlayerController.file(file);
    await controller.initialize().then((_) {
      if (mounted) {
        setState(() {
          if (isInput) {
            _inputController?.dispose();
            _inputController = controller;
          } else {
            _processedController?.dispose();
            _processedController = controller;
          }
        });
      }
    });
  } catch (e) {
    if (mounted) {
      setState(() {
        _processingStatus = 'Error initializing video player: ${e.toString()}';
      });
    }
    rethrow;
  }
}

  Widget _buildVideoPlayer(VideoPlayerController? controller, String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              label,
              style: GoogleFonts.lato(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: controller != null && controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  )
                : Center(
                    child: Icon(
                      Icons.videocam_off,
                      size: 50,
                      color: Colors.grey.shade400,
                    ),
                  ),
          ),
          if (controller != null)
            VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: accentOrange,
                bufferedColor: Colors.grey.shade600,
                backgroundColor: Colors.grey.shade800,
              ),
            ),
        ],
      ),
    );
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
                'Video Detection',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                // Status Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isProcessing
                            ? Icons.hourglass_top
                            : _hasResults
                                ? Icons.check_circle
                                : Icons.info_outline,
                        color: _isProcessing
                            ? accentOrange
                            : _hasResults
                                ? successGreen
                                : primaryDarkBlue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _processingStatus,
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            color: textDark,
                          ),
                        ),
                      ),
                      if (_minesDetected != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _minesDetected! > 0
                                ? Colors.red.shade50
                                : successGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _minesDetected! > 0
                                    ? Icons.warning_amber_rounded
                                    : Icons.check_circle,
                                color: _minesDetected! > 0
                                    ? Colors.red.shade700
                                    : successGreen,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _minesDetected! > 0
                                    ? '$_minesDetected mines detected'
                                    : 'No mines detected',
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _minesDetected! > 0
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
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(
                      icon: Icons.upload_file,
                      label: 'Select Video',
                      onPressed: _pickVideo,
                      color: secondaryBlue,
                    ),
                    const SizedBox(width: 20),
                    _buildActionButton(
                      icon: Icons.play_arrow,
                      label: 'Process Video',
                      onPressed: _isProcessing ? null : _processVideo,
                      color: accentOrange,
                      isDisabled: _isProcessing || _inputVideo == null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Video Comparison
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Video Analysis',
                        style: GoogleFonts.lato(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryDarkBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildVideoPlayer(
                                  _inputController, 'Original Footage'),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildVideoPlayer(
                                  _processedController, 'Processed Results'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_inputController != null ||
                          _processedController != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(Icons.play_arrow,
                                  color: primaryDarkBlue),
                              onPressed: () {
                                _inputController?.play();
                                _processedController?.play();
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.pause, color: primaryDarkBlue),
                              onPressed: () {
                                _inputController?.pause();
                                _processedController?.pause();
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.replay, color: primaryDarkBlue),
                              onPressed: () {
                                _inputController?.seekTo(Duration.zero);
                                _processedController?.seekTo(Duration.zero);
                                _inputController?.pause();
                                _processedController?.pause();
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
    bool isDisabled = false,
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
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? Colors.grey : color,
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