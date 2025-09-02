import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'map_screen.dart';

class HistoryScreen extends StatefulWidget {
  final int? data;

  const HistoryScreen({super.key, this.data});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> historyData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    try {
      final response = await http.get(
        Uri.parse("http://10.0.2.2/api/get_data.php"), // 👈 เปลี่ยนเป็น IP server ของคุณ
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData["success"]) {
          setState(() {
            historyData = jsonData["data"];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
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

              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: historyData.length,
                        itemBuilder: (context, index) {
                          final item = historyData[index];
                          return Column(
                            children: [
                              _buildHistoryCard(
                                size,
                                name: item['name'] ?? '-',
                                disease: item['disease'] ?? '-',
                                startDate: item['start_date'] ?? '-',
                                endDate: item['end_date'],
                                phoneNumber: item['phone_number'] ?? '-',
                                dangerLevel: item['danger_level'],
                              ),
                              const SizedBox(height: 20),
                            ],
                          );
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
  required String startDate, // infected_date
  String? endDate,           // healing_date
  required String phoneNumber,
  String? dangerLevel,
}) {
  return Container(
    width: size.width * 0.9,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFE0F7FA).withOpacity(0.9),
      borderRadius: BorderRadius.circular(25),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("ชื่อ: $name",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const Divider(color: Colors.blueGrey, thickness: 0.5, height: 15),
        _buildInfoRow('โรคที่ติด:', disease),
        Row(
          children: [
            Expanded(child: _buildInfoRow('ติดวันที่:', startDate)),
            const SizedBox(width: 20),
            Expanded(child: _buildInfoRow('หายวันที่:', endDate ?? '-')),
          ],
        ),
        _buildInfoRow('เบอร์:', phoneNumber),
        if (dangerLevel != null && dangerLevel.isNotEmpty)
          _buildInfoRow('ระดับความอันตราย:', dangerLevel),
      ],
    ),
  );
}


  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
          Text(value, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          const Divider(color: Colors.blueGrey, thickness: 0.2, height: 10),
        ],
      ),
    );
  }
}
