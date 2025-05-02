import 'package:flutter/material.dart';
import 'api_service.dart'; // Assuming you have a service to fetch records

class RecordsPage extends StatefulWidget {
  @override
  _RecordsPageState createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  List<Map<String, dynamic>> landmineRecords = [];

  @override
  void initState() {
    super.initState();
    fetchRecords();
  }

  Future<void> fetchRecords() async {
    final response = await ApiService.getRecords();
    setState(() {
      landmineRecords = List<Map<String, dynamic>>.from(response);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detection Records'),
      ),
      body: landmineRecords.isEmpty
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columnSpacing: 16.0,
                  columns: [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Image Path')),
                    DataColumn(label: Text('Mines Detected')),
                    DataColumn(label: Text('Mine Details')),
                  ],
                  rows: landmineRecords.map((record) {
                    final mineDetails = (record['mine_details']
                            as List<dynamic>)
                        .map((detail) =>
                            'Mine #${detail['mine_number']}: ${detail['detection_percentage']}%')
                        .join('\n'); // Use newline for better readability
                    return DataRow(cells: [
                      DataCell(Text(record['detection_id'].toString())),
                      DataCell(Text(record['image_path'] ?? '')),
                      DataCell(Text(record['mines_detected'].toString())),
                      DataCell(SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Text(mineDetails),
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
    );
  }
}
