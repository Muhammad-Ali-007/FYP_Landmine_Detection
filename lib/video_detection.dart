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
  // Color scheme
  static const Color primaryDarkBlue = Color(0xFF0A1F3D);
  static const Color secondaryBlue = Color(0xFF1A3A6A);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color cardWhite = Color(0xFFFFFFFF);
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
  void dispose() {
    _inputController?.dispose();
    _processedController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final pickedFile = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (pickedFile != null) {
        final videoFile = File(pickedFile.path);
        final fileExists = await videoFile.exists();
        if (!fileExists) throw Exception('File inaccessible.');

        final fileSize = await videoFile.length();
        if (fileSize > 100 * 1024 * 1024) {
          throw Exception('File exceeds 100MB limit.');
        }

        await _initializeVideoPlayer(videoFile, isInput: true);
        setState(() {
          _inputVideo = videoFile;
          _processedVideo = null;
          _minesDetected = null;
          _hasResults = false;
          _processingStatus = 'Video selected. Ready to process.';
        });
      }
    } catch (e) {
      _showErrorSnack(e.toString());
    }
  }

  Future<void> _processVideo() async {
    if (_inputVideo == null || !await _inputVideo!.exists()) {
      setState(() => _processingStatus = 'Please select a valid video first');
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Processing video...';
    });

    try {
      final result = await ApiService.processVideo(_inputVideo!);
      print('Processing result: $result');

      if (result['success'] == true && result['processed_path'] != null) {
        final processedFile = File(result['processed_path']);

        // Verify file exists and is playable
        if (await processedFile.exists()) {
          final controller = VideoPlayerController.file(processedFile);
          await controller.initialize();

          setState(() {
            _processedController?.dispose();
            _processedController = controller;
            _processedVideo = processedFile;
            _minesDetected = result['mines_detected'] ?? 0;
            _hasResults = true;
            _processingStatus = 'Analysis complete. ${_minesDetected} mines detected.';
          });
        } else {
          throw Exception('Processed video file not found');
        }
      } else {
        throw Exception(result['message'] ?? 'Video processing failed');
      }
    } catch (e) {
      print('Processing error: $e');
      setState(() {
        _processingStatus = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processing failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }


  Future<void> _initializeVideoPlayer(File file, {required bool isInput}) async {
    final controller = VideoPlayerController.file(file);
    await controller.initialize();

    if (isInput) {
      _inputController?.dispose();
      _inputController = controller;
    } else {
      _processedController?.dispose();
      _processedController = controller;
    }

    setState(() {});
  }

  void _showErrorSnack(String message) {
    setState(() {
      _processingStatus = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  bool _bothPlaying = false;
  void _toggleBothVideos() {
    if (_inputController != null && _processedController != null) {
      setState(() {
        if (_bothPlaying) {
          _inputController!.pause();
          _processedController!.pause();
          _bothPlaying = false;
        } else {
          _inputController!.play();
          _processedController!.play();
          _bothPlaying = true;
        }
      });
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
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(label, style: GoogleFonts.lato(color: Colors.white)),
          ),
          if (controller != null && controller.value.isInitialized)
            Column(
              children: [
                AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
                VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: accentOrange,
                    backgroundColor: Colors.grey.shade700,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          controller.value.isPlaying
                              ? controller.pause()
                              : controller.play();
                        });
                      },
                    ),
                    Text(
                      _formatDuration(controller.value.position),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            )
          else
            const Padding(
              padding: EdgeInsets.all(20),
              child: Icon(Icons.videocam_off, size: 50, color: Colors.white30),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration position) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(position.inMinutes.remainder(60));
    final seconds = twoDigits(position.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
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
            child: Text(_processingStatus, style: GoogleFonts.lato(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onPressed, Color color) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _resetAll() {
    _inputController?.dispose();
    _processedController?.dispose();
    setState(() {
      _inputVideo = null;
      _processedVideo = null;
      _minesDetected = null;
      _processingStatus = 'Select a video to begin analysis';
      _hasResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      appBar: AppBar(
        title: Text(
          'Video Detection',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryDarkBlue,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _resetAll),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _statusCard(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionButton(Icons.upload_file, 'Select Video', _pickVideo, secondaryBlue),
                const SizedBox(width: 16),
                _actionButton(Icons.analytics, 'Analyze', _processVideo, accentOrange),
              ],
            ),
            const SizedBox(height: 16),
            // _actionButton(
            //   _bothPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
            //   _bothPlaying ? 'Pause Both' : 'Play Both',
            //   _toggleBothVideos,
            //   primaryDarkBlue,
            // ),
            const SizedBox(height: 24),

            const SizedBox(height: 30),
            if (_inputVideo != null)
              _buildVideoPlayer(_inputController, 'Input Video'),
            const SizedBox(height: 20),
            if (_processedVideo != null)
              _buildVideoPlayer(_processedController, 'Processed Video'),
          ],
        ),
      ),
    );
  }
}
