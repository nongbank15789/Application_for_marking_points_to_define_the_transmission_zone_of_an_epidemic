import 'package:flutter/material.dart';
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ขนาดหน้าจอสำหรับ responsive design
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        // พื้นหลัง Gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0077C2), Color(0xFF4FC3F7)], // สีฟ้าเข้มไปฟ้าอ่อน
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // ปุ่มย้อนกลับ
            Positioned(
              top: MediaQuery.of(context).padding.top + 10, // ปรับตาม safe area
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
                onPressed: () {
                  Navigator.of(context).pop(); // กลับไปยังหน้าก่อนหน้า
                },
              ),
            ),
            // เนื้อหาหลัก (Title, Avatar, Info Card)
            Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 60), // Space for top bar and title
                
                // หัวข้อ "โปรไฟล์"
                const Text(
                  'โปรไฟล์',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // รูปโปรไฟล์วงกลม
                const CircleAvatar(
                  radius: 70, // ขนาดของวงกลม
                  backgroundColor: Colors.white, // สีพื้นหลังถ้าไม่มีรูป
                  // backgroundImage: NetworkImage(
                  //   'https://images.unsplash.com/photo-1594759083236-8a715f0d3b6f?fit=crop&w=800&q=80', // รูปภาพจำลอง
                  // ),
                ),
                const SizedBox(height: 40),

                // กล่องข้อมูลส่วนตัว
                Container(
                  width: size.width * 0.85, // กว้าง 85% ของหน้าจอ
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F7FA).withOpacity(0.9), // สีพื้นหลังของ Card ที่โปร่งแสงเล็กน้อย
                    borderRadius: BorderRadius.circular(25), // ขอบโค้ง
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: const Offset(0, 5), // เงา
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // ใช้พื้นที่เท่าที่จำเป็น
                    children: [
                      _buildInfoField(context, "ชื่อ", "อนงค์"),
                      _buildInfoField(context, "บทบาท", "ผู้ใช้งาน"), // แก้เป็น "บทบาท : ผู้ใช้งาน"
                      _buildInfoField(context, "Username", "nicalsobank"),
                      _buildInfoField(context, "Email", "nicasio15789@gmail.com"),
                      _buildInfoField(context, "รหัสผ่าน", "1234567890", obscureText: true), // รหัสผ่านควรเป็นจุด
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget สำหรับแสดงแต่ละช่องข้อมูล
  Widget _buildInfoField(BuildContext context, String label, String value, {bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label + " :", // เพิ่ม ":" หลัง label
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            obscureText ? '********' : value, // ซ่อนรหัสผ่าน
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          // เส้นใต้
          Container(
            height: 1,
            color: Colors.blue.shade300,
            margin: const EdgeInsets.only(top: 4),
          ),
        ],
      ),
    );
  }
}