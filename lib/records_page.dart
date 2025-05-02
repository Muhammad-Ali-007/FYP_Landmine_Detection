import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_service.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  _RecordsPageState createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  List<Map<String, dynamic>> landmineRecords = [];
  bool _isLoading = true;

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
        SnackBar(content: Text('Failed to load records: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detection Records', style: GoogleFonts.lato()),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
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
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      columnSpacing: 16.0,
                      columns: [
                        DataColumn(
                            label: Text('ID',
                                style: GoogleFonts.lato(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Image Path',
                                style: GoogleFonts.lato(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Mines Detected',
                                style: GoogleFonts.lato(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Mine Details',
                                style: GoogleFonts.lato(fontWeight: FontWeight.bold))),
                      ],
                      rows: landmineRecords.map((record) {
                        final mineDetails = (record['mine_details'] as List<dynamic>)
                            .map((detail) =>
                                'Mine #${detail['mine_number']}: ${detail['detection_percentage']}%')
                            .join('\n');
                        return DataRow(cells: [
                          DataCell(Text(record['detection_id'].toString(),
                              style: GoogleFonts.lato())),
                          DataCell(Text(record['image_path'] ?? '',
                              style: GoogleFonts.lato())),
                          DataCell(Text(record['mines_detected'].toString(),
                              style: GoogleFonts.lato())),
                          DataCell(
                            SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: Text(mineDetails, style: GoogleFonts.lato()),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}