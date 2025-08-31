import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'map_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int userId; // รับ userId จาก login

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String errorMessage = "";

  File? _avatarFile; // เก็บรูปจากเครื่อง

  @override
  void initState() {
    super.initState();
    fetchUser(widget.userId); // โหลดข้อมูลผู้ใช้
  }

  Future<void> _uploadAvatar() async {
    if (_avatarFile == null) return;

    var request = http.MultipartRequest(
      'POST',
      Uri.parse("http://10.0.2.2/api/upload_avatar.php"),
    );
    request.fields['user_id'] = widget.userId.toString(); // ส่ง userId ไปด้วย
    request.files.add(
      await http.MultipartFile.fromPath('avatar', _avatarFile!.path),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      var respStr = await response.stream.bytesToString();
      var data = jsonDecode(respStr);

      if (data['success'] == true) {
        setState(() {
          userData!['avatar'] = data['avatar']; // อัปเดต path ใน state
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ อัปโหลดรูปโปรไฟล์สำเร็จ")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ อัปโหลดไม่สำเร็จ: ${data['error']}")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Server error: ${response.statusCode}")),
      );
    }
  }

  // ฟังก์ชันเลือกรูปจาก Gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _avatarFile = File(pickedFile.path);
      });

      // ✅ อัปโหลดรูปไปเซิร์ฟเวอร์
      await _uploadAvatar();
    }
  }

  Future<void> fetchUser(int id) async {
    try {
      final response = await http.get(
        Uri.parse("http://10.0.2.2/api/get_user.php?id=$id"),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is List && data.isNotEmpty) {
          setState(() {
            userData = Map<String, dynamic>.from(data[0]);
            isLoading = false;
          });
        } else if (data is Map && data.containsKey("error")) {
          setState(() {
            errorMessage = data["error"];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = "Invalid data format";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = "Failed to load user (Code ${response.statusCode})";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (userData == null) {
      return Scaffold(
        body: Center(child: Text("❌ ไม่พบข้อมูลผู้ใช้\n$errorMessage")),
      );
    }

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
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MapScreen()),
                    );
                  },
                ),
                centerTitle: true,
                title: const Text(
                  'โปรไฟล์',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Avatar + ปุ่มเปลี่ยนรูป
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 70,
                            backgroundColor: Colors.white,
                            backgroundImage:
                                _avatarFile != null
                                    ? FileImage(_avatarFile!)
                                    : (userData!['avatar'] != null
                                            ? NetworkImage(
                                              "http://10.0.2.2/api/${userData!['avatar']}",
                                            )
                                            : null)
                                        as ImageProvider?,
                            child:
                                (_avatarFile == null &&
                                        userData!['avatar'] == null)
                                    ? const Icon(
                                      Icons.person,
                                      size: 70,
                                      color: Colors.grey,
                                    )
                                    : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // กล่องข้อมูลผู้ใช้
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
                            _buildInfoField(
                              "ชื่อ",
                              "${userData!['f_name']} ${userData!['l_name']}",
                            ),
                            _buildInfoField(
                              "บทบาท",
                              userData!['role'] ?? "ผู้ใช้งาน",
                            ),
                            _buildInfoField(
                              "Username",
                              userData!['username'] ?? "-",
                            ),
                            _buildInfoField("Email", userData!['email'] ?? "-"),
                            _buildInfoField(
                              "รหัสผ่าน",
                              userData!['password'] ?? "-",
                              obscureText: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
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

  // Widget สำหรับแสดงแต่ละช่องข้อมูล
  Widget _buildInfoField(
    String label,
    String value, {
    bool obscureText = false,
  }) {
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