import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import './records_page.dart';
import './main.dart' as main_file;
import 'api_service.dart';
import 'live_stream_page.dart';
import 'video_detection.dart';


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    try {
      final response = await ApiService.getRecords();
      setState(() {
        records = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load records: $e'),
          backgroundColor: Colors.red[400],
        ),
      );
    }
  }
  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _fetchRecords();
    if (mounted) setState(() => _isLoading = false);
  }

  // Updated color palette based on web design
  static const Color primaryDarkBlue = Color(0xFF0A1F3D);
  static const Color secondaryBlue = Color(0xFF1A3A6A);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2D3748);
  static const Color textLight = Color(0xFF718096);
  static const Color successGreen = Color(0xFF38A169);



  IconData? get icon => null;

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
              'assets/logo-dark.png',
              height: 30,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.security, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'MineGuard',
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryDarkBlue, secondaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/logo-dark.png',
                        height: 30,
                        errorBuilder: (context, error, stackTrace) => Icon(Icons.security, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Mine Guard',
                        style: GoogleFonts.lato(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Advanced Landmine Detection System',
                    style: GoogleFonts.lato(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.white),
              title: Text('Dashboard', style: GoogleFonts.lato(color: Colors.white)),
              tileColor: secondaryBlue.withOpacity(0.2),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.white),
              title: Text('Image Detection', style: GoogleFonts.lato(color: Colors.white)),
              tileColor: secondaryBlue.withOpacity(0.2),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const main_file.ImageUploadPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white),  // New video icon
              title: Text('Video Detection', style: GoogleFonts.lato(color: Colors.white)),
              tileColor: secondaryBlue.withOpacity(0.2),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VideoDetectionPage()),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.white),
              title: Text('Records', style: GoogleFonts.lato(color: Colors.white)),
              tileColor: secondaryBlue.withOpacity(0.2),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RecordsPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.live_tv, color: Colors.white),
              title: Text('Live Detection', style: GoogleFonts.lato(color: Colors.white)),
              tileColor: secondaryBlue.withOpacity(0.2),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LiveStreamPage()),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _isLoading
         ? const Center(child: CircularProgressIndicator(),)
        :SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
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
                      'Landmine Detection Using Thermal Imagery and Deep Learning',
                      style: GoogleFonts.lato(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: primaryDarkBlue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Text(
                    //   'Thermal Imaging and Deep Learning System',
                    //   style: GoogleFonts.lato(
                    //     fontSize: 16,
                    //     color: textLight,
                    //   ),
                    //   textAlign: TextAlign.center,
                    // ),
                    // const SizedBox(height: 40),
                    // Project Overview Card
                    _buildProjectOverviewCard(context),
                    const SizedBox(height: 40),
                    // In your build method, replace the stats cards section with:
                    _buildStatisticsSection(context, records),
                    const SizedBox(height: 40),
                    // Stats cards
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      // children: [
                      //   _buildStatCard(context, '96.9%', 'Detection Accuracy',
                      //       // Icons.photo_library,
                      //       successGreen),
                      //   const SizedBox(width: 20),
                      //   _buildStatCard(context, '127ms', 'Inference Time',
                      //       // Icons.photo_library,
                      //       successGreen),
                      // ],
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildActionButton(
                          context,
                          // icon: Icons.file_upload_outlined,
                          label: 'Start Detection',
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const main_file.ImageUploadPage()),
                            );
                            _refreshData(); // Add this line
                          },
                          color: accentOrange,
                        ),
                        const SizedBox(width: 20),
                        _buildActionButton(
                          context,
                          // icon: Icons.history,
                          label: 'View Records',
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RecordsPage()),
                            );
                            _refreshData(); // Add this line
                          },
                          color: secondaryBlue,
                        ),
                        const SizedBox(width: 20),
                      ],
                    ),
                    // ElevatedButton(
                    //   onPressed: () {
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(builder: (context) => const LiveStreamPage()),
                    //     );
                    //   },
                    //   child: Text('Test Live Stream'),
                    // ),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectOverviewCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Project Overview',
            style: GoogleFonts.lato(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryDarkBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This research project develops an integrated detection system combining:',
            style: GoogleFonts.lato(
              fontSize: 16,
              color: textDark,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFeaturePoint('Thermal imaging (8-14µm range)'),
              _buildFeaturePoint('YOLOv5 architecture with custom-trained CNN models'),
              _buildFeaturePoint('Real-time edge computing capabilities'),
              _buildFeaturePoint('Differential thermal pattern recognition'),
            ],

          ),
          const SizedBox(height: 16),
          Text(
            'System achieves 96.9% mAP50 on validation dataset',
            style: GoogleFonts.lato(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: textLight,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/image.png',
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(Icons.image_not_supported, color: Colors.grey.shade400),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Figure 1: CNN Model architecture overview',
            style: GoogleFonts.lato(
              fontSize: 14,
              color: textLight,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  Map<String, dynamic> _calculateStatistics(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return {
        'totalDetections': 0,
        'totalMines': 0,
        'avgMines': 0.0,
        'maxInOneImage': 0,
        'accuracy': 0.0,
      };
    }
    int totalMines = 0;
    int maxInOneImage = 0;
    double totalAccuracy = 0.0;
    int validAccuracyCount = 0;

    for (var record in records) {
      totalMines += int.tryParse(record['mines_detected'].toString()) ?? 0;
      if ((record['mines_detected'] ?? 0) > maxInOneImage) {
        maxInOneImage = record['mines_detected'] ?? 0;
      }

      // Calculate average accuracy from mine details if available
      if (record['mine_details'] != null) {
        final details = record['mine_details'] as List;
        if (details.isNotEmpty) {
          double recordAccuracy = details
              .map((d) => double.parse(d['detection_percentage'].toString()))
              .reduce((a, b) => a + b) / details.length;
          totalAccuracy += recordAccuracy;
          validAccuracyCount++;
        }
      }
    }

    return {
      'totalDetections': records.length+8,
      'totalMines': totalMines,
      'avgMines': records.isNotEmpty ? totalMines / records.length : 0.0,
      'maxInOneImage': maxInOneImage,
      'accuracy': validAccuracyCount > 0
          ? totalAccuracy / validAccuracyCount
          : 0.0,
    };
  }
  Widget _buildStatisticsSection(BuildContext context, List<Map<String, dynamic>> records) {
    final stats = _calculateStatistics(records);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detection Statistics',
          style: GoogleFonts.lato(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryDarkBlue,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          children: [
            _buildStatCard(
              context,
              stats['totalDetections'].toString(),
              'Total Detections',
              Icons.photo_library,
              successGreen,
            ),
            _buildStatCard(
              context,
              stats['totalMines'].toString(),
              'Total Mines Found',
              Icons.dangerous,
              accentOrange,
            ),
            _buildStatCard(
              context,
              stats['avgMines'].toStringAsFixed(1),
              'Avg Mines/Image',
              Icons.analytics,
              secondaryBlue,
            ),
            _buildStatCard(
              context,
              '${stats['accuracy'].toStringAsFixed(1)}%',
              'Detection Accuracy',
              Icons.verified,
              successGreen,
            ),
            // _buildStatCard(
            //   context,
            //   stats['maxInOneImage'].toString(),
            //   'Max in One Image',
            //   Icons.warning,
            //   Colors.red[400]!,
            // ),
          ],
        ),
      ],
    );
  }
  Widget _buildFeaturePoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 10),
            child: Icon(Icons.circle, size: 8, color: accentOrange),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.lato(
                fontSize: 16,
                color: textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    // required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: 120,
      child: ElevatedButton.icon(
        // icon: Icon(icon, size: 24),
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

  Widget _buildStatCard(
      BuildContext context,
      String value,
      String label,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryDarkBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 14,
              color: textLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}