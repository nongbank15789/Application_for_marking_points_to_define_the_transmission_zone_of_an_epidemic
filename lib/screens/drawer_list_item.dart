import 'package:flutter/material.dart';

class DrawerListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const DrawerListItem({
    Key? key,
    required this.icon,
    required this.title,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color.fromARGB(255, 135, 179, 214).withOpacity(0.1),
        highlightColor: Colors.transparent, // ใช้ Container คุมสีเอง
        child: Container(
          width: 240, // 👈 กำหนดความกว้าง
          height: 50, // 👈 กำหนดความสูง
          margin: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(0),
                child: Icon(
                  icon,
                  color: const Color(0xFF0E47A1),
                  size: 26, // ลดนิดนึง
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18, // ลดลงเล็กน้อย
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0E47A1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
