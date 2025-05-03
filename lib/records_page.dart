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
  String _searchQuery = '';

  // Color scheme
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
        title: Text(
          'Detection Records',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
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
          ? const LoadingIndicator()
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'Search by detection ID...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: cardWhite,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                hintStyle: GoogleFonts.lato(color: textLight),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: filteredRecords.length,
              itemBuilder: (context, index) {
                final record = filteredRecords[index];
                return RecordCard(record: record);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get filteredRecords {
    if (_searchQuery.isEmpty) return landmineRecords;
    return landmineRecords.where((record) {
      final id = record['detection_id'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return id.contains(query);
    }).toList();
  }
}

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Loading detection records...',
            style: GoogleFonts.lato(
              fontSize: 16,
              color: _RecordsPageState.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

class RecordCard extends StatelessWidget {
  final Map<String, dynamic> record;

  const RecordCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final hasMines = record['mines_detected'] > 0;
    final mineDetails = (record['mine_details'] as List<dynamic>)
        .map((detail) =>
    'Mine #${detail['mine_number']}: ${detail['detection_percentage']}%')
        .join('\n');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: Card(
        color: _RecordsPageState.cardWhite,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.only(bottom: 16),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(14),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasMines
                      ? Colors.red.shade50
                      : _RecordsPageState.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasMines ? Icons.warning_amber_rounded : Icons.check_circle,
                  color: hasMines ? Colors.red.shade700 : _RecordsPageState.successGreen,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record #${record['detection_id']}',
                      style: GoogleFonts.lato(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: _RecordsPageState.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record['mines_detected']} mines detected',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: _RecordsPageState.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: hasMines
                      ? Colors.red.shade50
                      : _RecordsPageState.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  hasMines ? 'DANGER' : 'SAFE',
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: hasMines
                        ? Colors.red.shade700
                        : _RecordsPageState.successGreen,
                  ),
                ),
              ),
            ],
          ),
          children: [
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Detection Details:',
              style: GoogleFonts.lato(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: _RecordsPageState.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _RecordsPageState.secondaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                mineDetails.isEmpty
                    ? 'No mine details available.'
                    : mineDetails,
                style: GoogleFonts.lato(
                  color: _RecordsPageState.textDark,
                  height: 1.6,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
