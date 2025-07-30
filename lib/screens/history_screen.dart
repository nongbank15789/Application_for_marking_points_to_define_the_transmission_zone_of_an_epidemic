import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0077C2), Color(0xFF4FC3F7)], // สีฟ้าเข้มไปฟ้าอ่อน
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea( // ใช้ SafeArea เพื่อเนื้อหาไม่ทับ Status Bar
          child: Column(
            children: [
              // AppBar สำหรับปุ่มย้อนกลับและ Title
              AppBar(
                backgroundColor: Colors.transparent, // ทำให้ AppBar โปร่งใส
                elevation: 0, // ไม่มีเงา
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
                  onPressed: () {
                    Navigator.of(context).pop(); // กลับไปยังหน้าก่อนหน้า
                  },
                ),
                centerTitle: true, // จัด Title ให้อยู่ตรงกลาง
                title: const Text(
                  'ประวัติ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20), // ระยะห่างจาก AppBar

              // Search Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20), // ระยะห่างซ้ายขวา
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9), // สีขาวโปร่งแสงเล็กน้อย
                  borderRadius: BorderRadius.circular(25), // ขอบมน
                  boxShadow: [ // เงา
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
                    // ลบ IconButton ที่มี Icons.menu ออกไป
                    // IconButton( // Icon Menu
                    //   icon: const Icon(Icons.menu, color: Colors.blueGrey),
                    //   onPressed: () {
                    //     // TODO: Implement menu action
                    //   },
                    // ),
                    // const SizedBox(width: 8), // ลบ SizedBox นี้ด้วยถ้าไม่มี Icon Menu แล้ว
                    const Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search', // ข้อความ Search
                          hintStyle: TextStyle(color: Colors.blueGrey),
                          border: InputBorder.none, // ไม่มีขอบ
                          contentPadding: EdgeInsets.symmetric(vertical: 13.0), // ปรับ padding ข้อความ
                        ),
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                    IconButton( // Icon Search
                      icon: const Icon(Icons.search, color: Colors.blueGrey),
                      onPressed: () {
                        // TODO: Implement search action
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20), // ระยะห่างจาก Search Bar

              // Scrollable List of History Cards
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0), // Padding ซ้ายขวาของลิสต์
                  child: Column(
                    children: [
                      // ตัวอย่าง History Card 1
                      _buildHistoryCard(
                        size,
                        name: 'ธนพล อารามแก้ว',
                        disease: 'ไข้เลือดออก',
                        startDate: '2023/01/15',
                        endDate: '2023/01/25',
                        phoneNumber: '1234567890',
                        dangerLevel: 'สูง',
                      ),
                      const SizedBox(height: 20), // ระยะห่างระหว่าง Card

                      // ตัวอย่าง History Card 2
                      _buildHistoryCard(
                        size,
                        name: 'ธนพล',
                        disease: 'ไข้หวัดใหญ่',
                        startDate: '2023/03/10',
                        endDate: '2023/03/17',
                        phoneNumber: '1234567890',
                        dangerLevel: 'ปานกลาง',
                      ),
                      const SizedBox(height: 20),

                      // ตัวอย่าง History Card 3 (ข้อมูลน้อยลง)
                      _buildHistoryCard(
                        size,
                        name: 'ธนพล',
                        disease: 'covid-19',
                        startDate: '2024/02/01',
                        // endDate: '', // ถ้าไม่มีข้อมูล
                        phoneNumber: '1234567890',
                        // dangerLevel: '', // ถ้าไม่มีข้อมูล
                      ),
                      const SizedBox(height: 20),

                      // สามารถเพิ่ม _buildHistoryCard() ได้อีกตามต้องการ
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget ช่วยสำหรับสร้าง History Card แต่ละใบ
  Widget _buildHistoryCard(
    Size size, {
    required String name,
    required String disease,
    required String startDate,
    String? endDate, // สามารถเป็น null ได้
    required String phoneNumber,
    String? dangerLevel, // สามารถเป็น null ได้
  }) {
    return Container(
      width: size.width * 0.9, // กว้างประมาณ 90% ของหน้าจอ
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7FA).withOpacity(0.9), // สีพื้นหลังของ Card ที่โปร่งแสงเล็กน้อย
        borderRadius: BorderRadius.circular(25), // ขอบมน
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.location_on, color: Colors.blue, size: 20),
                    onPressed: () {
                      // TODO: Implement location view action
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen, color: Colors.blue, size: 20),
                    onPressed: () {
                      // TODO: Implement full screen view action
                    },
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.blueGrey, thickness: 0.5, height: 15), // เส้นแบ่ง

          _buildInfoRow('โรคที่ติด:', disease),
          Row(
            children: [
              Expanded(child: _buildInfoRow('ติดวันที่:', startDate)),
              const SizedBox(width: 20),
              Expanded(child: _buildInfoRow('หายวันที่:', endDate ?? '-')), // ถ้า endDate เป็น null ให้แสดง '-'
            ],
          ),
          _buildInfoRow('เบอร์:', phoneNumber),
          if (dangerLevel != null && dangerLevel.isNotEmpty) // แสดงถ้ามีข้อมูล
            _buildInfoRow('ระดับความอันตราย:', dangerLevel),
        ],
      ),
    );
  }

  // Helper widget สำหรับสร้างแถวข้อมูลแต่ละรายการใน Card
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label',
            style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
          const Divider(color: Colors.blueGrey, thickness: 0.2, height: 10), // เส้นใต้ข้อมูล
        ],
      ),
    );
  }
}