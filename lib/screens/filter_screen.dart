import 'package:flutter/material.dart';
import 'map_screen.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  // State variables เพื่อเก็บค่าที่ถูกเลือกในแต่ละหมวดหมู่
  String? _selectedInfectionFilter;
  String? _selectedRecoveryFilter;
  String? _selectedDiseaseFilter;
  String? _selectedDangerFilter;

  // รายการตัวเลือกสำหรับแต่ละหมวดหมู่
  final List<String> _dateOptions = ['วันนี้', 'สัปดาห์นี้', 'เดือนนี้', 'ปีนี้', 'ทั้งหมด']; 
  final List<String> _diseaseOptions = ['ไข้เลือดออก', 'ไข้หวัดใหญ่', 'covid-19', 'ทั้งหมด']; 
  final List<String> _dangerOptions = ['น้อย', 'ปานกลาง', 'มาก', 'ทั้งหมด']; 

  @override
  void initState() {
    super.initState();
    _selectedInfectionFilter = 'ทั้งหมด';
    _selectedRecoveryFilter = 'ทั้งหมด';
    _selectedDiseaseFilter = 'ทั้งหมด';
    _selectedDangerFilter = 'ทั้งหมด';
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
                    Navigator.pop(context);
                  },
                ),
                centerTitle: true,
                title: const Text(
                  'ตัวกรองแผนที่',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // กล่อง Filter Card
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: size.width * 0.9,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F7FA).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFilterCategory(
                          title: 'ติดเชื้อภายใน',
                          options: _dateOptions,
                          selectedValue: _selectedInfectionFilter,
                          onSelected: (value) {
                            setState(() {
                              _selectedInfectionFilter = value;
                            });
                          },
                        ),
                        _buildFilterCategory(
                          title: 'หายจากโรคภายใน',
                          options: _dateOptions,
                          selectedValue: _selectedRecoveryFilter,
                          onSelected: (value) {
                            setState(() {
                              _selectedRecoveryFilter = value;
                            });
                          },
                        ),
                        _buildFilterCategory(
                          title: 'โรคที่ติด',
                          options: _diseaseOptions,
                          selectedValue: _selectedDiseaseFilter,
                          onSelected: (value) {
                            setState(() {
                              _selectedDiseaseFilter = value;
                            });
                          },
                        ),
                        _buildFilterCategory(
                          title: 'ความอันตราย',
                          options: _dangerOptions,
                          selectedValue: _selectedDangerFilter,
                          onSelected: (value) {
                            setState(() {
                              _selectedDangerFilter = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // ปุ่มยืนยัน
              ElevatedButton(
                onPressed: () {
                  final selectedFilters = {
                    'infectedDate': _selectedInfectionFilter,
                    'recoveryDate': _selectedRecoveryFilter,
                    'disease': _selectedDiseaseFilter,
                    'danger': _selectedDangerFilter,
                  };
                  Navigator.pop(context, selectedFilters);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(size.width * 0.5, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0277BD), Color(0xFF00BCD4)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    constraints: BoxConstraints(minWidth: size.width * 0.5, minHeight: 50),
                    child: const Text(
                      'ยืนยัน',
                      style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCategory({
    required String title,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 2,
                  width: 50,
                  color: const Color(0xFF0077C2),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFB2EBF2)),
          ...options.map((option) {
            bool isSelected = selectedValue == option;
            return InkWell(
              onTap: () {
                onSelected(option);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
                color: Colors.transparent,
                child: Text(
                  option,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: isSelected ? Colors.blue.shade900 : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}