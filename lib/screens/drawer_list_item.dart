  import 'package:flutter/material.dart';

  class DrawerListItem extends StatelessWidget {
    const DrawerListItem({
      super.key,
      required this.icon,
      required this.title,
      this.onTap, // onTap เป็น optional เพราะบางรายการอาจจะไม่มีการนำทาง
    });

    final IconData icon;
    final String title;
    final VoidCallback? onTap; // VoidCallback? หมายถึงสามารถเป็น null ได้

    @override
    Widget build(BuildContext context) {
      return ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        onTap: () {
          // หาก onTap ไม่เป็น null ให้เรียกใช้ฟังก์ชัน onTap
          if (onTap != null) {
            Navigator.pop(context); // ปิด Drawer ก่อนทำการนำทาง
            onTap!(); // เรียกใช้ฟังก์ชันที่ถูกส่งเข้ามา
          } else {
            // ถ้า onTap เป็น null (ไม่มีการกำหนด action) ให้แค่ปิด Drawer
            Navigator.pop(context);
          }
        },
      );
    }
  }
