import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_service.dart';
// import 'dashboard_page.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  _RecordsPageState createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  List<Map<String, dynamic>> landmineRecords = [];
  bool _isLoading = true;

  // Color scheme matching dashboard
  static const Color primaryDarkBlue = Color(0xFF0A1F3D);
  static const Color secondaryBlue = Color(0xFF1A3A6A);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2D3748);
  static const Color textLight = Color(0xFF718096);
  static const Color successGreen = Color(0xFF38A169);

  @override
  void initState() {
    super.initState();
    fetchRecords();
  }

  Future<void> fetchRecords() async {
    try {
      final response = await ApiService.getRecords();
      setState(() {
        landmineRecords = List<Map<String, dynamic>>.from(response);
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
                'Detection Records',
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
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    'Loading detection records...',
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      color: textLight,
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
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
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        cardTheme: CardTheme(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        dataTableTheme: DataTableThemeData(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          dataRowColor: MaterialStateProperty.resolveWith<Color>(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.selected)) {
                                return secondaryBlue.withOpacity(0.2);
                              }
                              return cardWhite;
                            },
                          ),
                          headingRowColor: MaterialStateProperty.resolveWith<Color>(
                            (Set<MaterialState> states) => secondaryBlue,
                          ),
                        ),
                      ),
                      child: DataTable(
                        columnSpacing: 24.0,
                        horizontalMargin: 24.0,
                        headingTextStyle: GoogleFonts.lato(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        dataTextStyle: GoogleFonts.lato(
                          color: textDark,
                        ),
                        columns: [
                          DataColumn(
                            label: Text('ID'),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text('Image'),
                          ),
                          DataColumn(
                            label: Text('Mines'),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text('Details'),
                          ),
                          DataColumn(
                            label: Text('Status'),
                          ),
                        ],
                        rows: landmineRecords.map((record) {
                          final mineDetails = (record['mine_details'] as List<dynamic>)
                              .map((detail) =>
                                  'Mine #${detail['mine_number']}: ${detail['detection_percentage']}%')
                              .join('\n');
                          final hasMines = record['mines_detected'] > 0;
                          
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(record['detection_id'].toString()),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    record['image_path'] ?? 'No path',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  record['mines_detected'].toString(),
                                  style: GoogleFonts.lato(
                                    fontWeight: FontWeight.bold,
                                    color: hasMines ? Colors.red : successGreen,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 200,
                                  child: Text(
                                    mineDetails,
                                    style: GoogleFonts.lato(),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: hasMines
                                        ? Colors.red.shade50
                                        : successGreen.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        hasMines
                                            ? Icons.warning_amber_rounded
                                            : Icons.check_circle,
                                        color: hasMines
                                            ? Colors.red.shade700
                                            : successGreen,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        hasMines ? 'Danger' : 'Safe',
                                        style: GoogleFonts.lato(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: hasMines
                                              ? Colors.red.shade700
                                              : successGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}