import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LiveStreamPage extends StatelessWidget {
  const LiveStreamPage({super.key});

  static const String processedStreamUrl = 'http://127.0.0.1:5000/flutter/live_stream';
  static const String originalStreamUrl = 'http://127.0.0.1:5000/flutter/live_original_stream';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Live Detection',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0A1F3D),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            'Original Video Feed',
            style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            // child: Image.network(
            //   'https://picsum.photos/500/300',
            //   fit: BoxFit.cover,
            // ),
            child: Image.network(
              originalStreamUrl,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) =>
              const Center(child: Text('Failed to load original stream')),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Processed Detection Feed',
            style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            // child: Image.network(
            //   'https://picsum.photos/500/300',
            //   fit: BoxFit.cover,
            // ),
            child: Image.network(
              processedStreamUrl,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) =>
              const Center(child: Text('Failed to load detection stream')),
            ),
          ),
        ],
      ),
    );
  }
}
