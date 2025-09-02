import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'map_screen.dart';

// Model class to represent a history record
class HistoryRecord {
  final String? name;
  final String? disease;
  final String? startDate;
  final String? endDate;
  final String? phoneNumber;
  final String? dangerLevel;

  HistoryRecord({
    this.name,
    this.disease,
    this.startDate,
    this.endDate,
    this.phoneNumber,
    this.dangerLevel,
  });

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    return HistoryRecord(
      name: json['name'],
      disease: json['disease'],
      startDate: json['startDate'],
      endDate: json['endDate'],
      phoneNumber: json['phoneNumber'],
      dangerLevel: json['dangerLevel'],
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Use a TextEditingController to manage the text field input
  final TextEditingController _searchController = TextEditingController();
  late Future<List<HistoryRecord>> futureHistory;

  @override
  void initState() {
    super.initState();
    // Fetch initial data when the screen loads
    futureHistory = fetchHistory();
  }

  // Dispose the controller when the state is removed
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Function to fetch data with an optional search query
  Future<List<HistoryRecord>> fetchHistory([String? query]) async {
    final Map<String, dynamic> queryParameters = {};
    if (query != null && query.isNotEmpty) {
      queryParameters['search'] = query;
    }
    final uri = Uri.http('10.0.2.2:80', '/api/get_history.php', queryParameters); // REPLACE with your server URL

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => HistoryRecord.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load history');
    }
  }

  // Function to perform search and refresh the UI
  void _performSearch() {
    setState(() {
      futureHistory = fetchHistory(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0077C2), Color(0xFF4FC3F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MapScreen()),
                    );
                  },
                ),
                centerTitle: true,
                title: const Text(
                  'ประวัติ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController, // Link the controller
                        decoration: const InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(color: Colors.blueGrey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 13.0),
                        ),
                        style: const TextStyle(color: Colors.black87),
                        onSubmitted: (value) => _performSearch(), // Trigger search on enter
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.blueGrey),
                      onPressed: _performSearch, // Trigger search on icon press
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<HistoryRecord>>(
                  future: futureHistory,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (snapshot.hasData) {
                      if (snapshot.data!.isEmpty) {
                        return const Center(child: Text('ไม่พบข้อมูลประวัติ'));
                      }
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            ...snapshot.data!.map((record) => Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildHistoryCard(
                                size,
                                name: record.name ?? 'ไม่ระบุ',
                                disease: record.disease ?? 'ไม่ระบุ',
                                startDate: record.startDate ?? 'ไม่ระบุ',
                                endDate: record.endDate,
                                phoneNumber: record.phoneNumber ?? 'ไม่ระบุ',
                                dangerLevel: record.dangerLevel,
                              ),
                            )),
                            const SizedBox(height: 20),
                          ],
                        ),
                      );
                    } else {
                      return const Center(child: Text('ไม่พบข้อมูลประวัติ'));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
      Size size, {
        required String name,
        required String disease,
        required String startDate,
        String? endDate,
        required String phoneNumber,
        String? dangerLevel,
      }) {
    return Container(
      width: size.width * 0.9,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ชื่อ: $name',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0077C2)),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.location_on, color: Color(0xFF4FC3F7), size: 24),
                    onPressed: () {
                      // TODO: Implement location view action
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen, color: Color(0xFF4FC3F7), size: 24),
                    onPressed: () {
                      // TODO: Implement full screen view action
                    },
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Color(0xFFB0BEC5), thickness: 1, height: 20),

          _buildInfoRow('โรคที่ติด', disease),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildInfoRow('ติดวันที่', startDate),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildInfoRow('หายวันที่', endDate ?? '-'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow('เบอร์', phoneNumber),
          const SizedBox(height: 8),
          if (dangerLevel != null && dangerLevel.isNotEmpty)
            _buildInfoRow('ระดับความอันตราย', dangerLevel),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4FC3F7)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ],
    );
  }
}