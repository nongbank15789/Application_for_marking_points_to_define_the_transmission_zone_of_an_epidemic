import 'package:flutter/material.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  // State variables เพื่อเก็บค่าที่ถูกเลือกในแต่ละหมวดหมู่
  String? _selectedDateFilter; // null ถ้ายังไม่ได้เลือก
  String? _selectedTypeFilter;
  String? _selectedDangerFilter;
  String? _selectedSortByFilter;

  // รายการตัวเลือกสำหรับแต่ละหมวดหมู่
  final List<String> _dateOptions = ['วันนี้', 'สัปดาห์นี้', 'เดือนนี้', 'ปีนี้', 'ทั้งหมด']; 
  final List<String> _typeOptions = ['ไข้เลือดออก', 'ไข้หวัดใหญ่', 'covid-19', 'ทั้งหมด']; 
  final List<String> _dangerOptions = ['น้อย', 'ปานกลาง', 'มาก', 'ทั้งหมด']; 
  final List<String> _sortByOptions = ['วันที่', 'ประเภท', 'ความอันตราย']; 

  @override
  void initState() {
    super.initState();
    // แก้ไขตรงนี้: กำหนดค่าเริ่มต้นเป็น 'ทั้งหมด' สำหรับ 3 หมวดหมู่แรก
    _selectedDateFilter = 'ทั้งหมด';
    _selectedTypeFilter = 'ทั้งหมด';
    _selectedDangerFilter = 'ทั้งหมด';
    // สำหรับ 'เรียงตาม' ให้ยังคงเริ่มต้นเป็น 'วันที่' เหมือนเดิม
    _selectedSortByFilter = _sortByOptions.contains('วันที่') ? 'วันที่' : _sortByOptions[0]; 
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
                    Navigator.of(context).pop();
                  },
                ),
                centerTitle: true,
                title: const Text(
                  'ตัวกรอง',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // กล่อง Filter Card
              Expanded( // ใช้ Expanded เพื่อให้ Card ขยายตัวเต็มพื้นที่ที่เหลือและสามารถ Scroll ได้ภายใน
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
                    child: Row( // Row สำหรับจัดเรียง 4 คอลัมน์
                      crossAxisAlignment: CrossAxisAlignment.start, // จัดให้อยู่ด้านบน
                      children: [
                        _buildFilterCategory(
                          title: 'วันที่',
                          options: _dateOptions,
                          selectedValue: _selectedDateFilter,
                          onSelected: (value) {
                            setState(() {
                              _selectedDateFilter = value;
                            });
                          },
                        ),
                        _buildFilterCategory(
                          title: 'ประเภท',
                          options: _typeOptions,
                          selectedValue: _selectedTypeFilter,
                          onSelected: (value) {
                            setState(() {
                              _selectedTypeFilter = value;
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
                        _buildFilterCategory(
                          title: 'เรียงตาม',
                          options: _sortByOptions,
                          selectedValue: _selectedSortByFilter,
                          onSelected: (value) {
                            setState(() {
                              _selectedSortByFilter = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30), // ระยะห่างจาก Card

              // ปุ่มยืนยัน
              ElevatedButton(
                onPressed: () {
                  String message = 'ตัวกรองที่เลือก:\n'
                      'วันที่: ${_selectedDateFilter ?? "ไม่ได้เลือก"}\n'
                      'ประเภท: ${_selectedTypeFilter ?? "ไม่ได้เลือก"}\n'
                      'ความอันตราย: ${_selectedDangerFilter ?? "ไม่ได้เลือก"}\n'
                      'เรียงตาม: ${_selectedSortByFilter ?? "ไม่ได้เลือก"}';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
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
              const SizedBox(height: 20), // ระยะห่างด้านล่าง
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget สำหรับสร้างหมวดหมู่ตัวกรองแต่ละคอลัมน์ (เช่น 'วันที่')
  Widget _buildFilterCategory({
    required String title,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return Expanded(
      child: Column(
        children: [
          // ส่วนหัวของหมวดหมู่ (พร้อมเส้นใต้)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center, // จัดให้ข้อความและเส้นใต้ตรงกลาง
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
                  width: 50, // ความยาวของเส้นใต้
                  color: const Color(0xFF0077C2),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFB2EBF2)), // เส้นแบ่งใต้หัวข้อ

          // รายการตัวเลือก
          ...options.map((option) {
            bool isSelected = selectedValue == option;
            return InkWell(
              onTap: () {
                onSelected(option); // ส่งค่าที่เลือกกลับ
              },
              child: Container(
                width: double.infinity, // ให้กินความกว้างทั้งหมดใน Expanded
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0), // Padding ของแต่ละตัวเลือก
                color: Colors.transparent, // ทำให้พื้นหลังโปร่งใสเสมอ
                child: Text(
                  option,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: isSelected ? Colors.blue.shade900 : Colors.black87, // เปลี่ยนเฉพาะสีข้อความ
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