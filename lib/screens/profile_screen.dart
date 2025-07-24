import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
          child: Stack(
            children: [
              // เนื้อหาทั้งหมดสามารถเลื่อน Scroll ได้
              SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    const Text(
                      'โปรไฟล์',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const CircleAvatar(
                      radius: 70,
                      backgroundColor: Colors.white,
                      // backgroundImage: NetworkImage('...'),
                    ),
                    const SizedBox(height: 30),

                    Container(
                      width: size.width * 0.85,
                      padding: const EdgeInsets.all(20),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildInfoField(context, "ชื่อ", "อนงค์"),
                          _buildInfoField(context, "บทบาท", "ผู้ใช้งาน"),
                          _buildInfoField(context, "Username", "nicalsobank"),
                          _buildInfoField(context, "Email", "nicasio15789@gmail.com"),
                          _buildInfoField(context, "รหัสผ่าน", "1234567890", obscureText: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),

              // ปุ่มย้อนกลับ
              Positioned(
                top: 10,
                left: 16,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoField(BuildContext context, String label, String value, {bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label :",
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            obscureText ? '********' : value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
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
