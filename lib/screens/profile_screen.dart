import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'map_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String errorMessage = "";
  File? _avatarFile;

  @override
  void initState() {
    super.initState();
    fetchUser(widget.userId);
  }

  Future<void> _uploadAvatar() async {
    if (_avatarFile == null) return;

    var request = http.MultipartRequest(
      'POST',
      Uri.parse("http://10.0.2.2/api/upload_avatar.php"),
    );
    request.fields['stf_id'] = widget.userId.toString();
    request.files.add(
      await http.MultipartFile.fromPath('stf_avatar', _avatarFile!.path),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      var respStr = await response.stream.bytesToString();
      var data = jsonDecode(respStr);

      if (data['success'] == true) {
        setState(() {
          userData!['stf_avatar'] = data['stf_avatar'];
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _avatarFile = File(pickedFile.path);
      });

      await _uploadAvatar();
    }
  }

  Future<void> fetchUser(int id) async {
    try {
      final response = await http.get(
        Uri.parse("http://10.0.2.2/api/get_user.php?stf_id=$id"),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is List && data.isNotEmpty) {
          setState(() {
            userData = Map<String, dynamic>.from(data[0]);
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = "ไม่พบข้อมูลผู้ใช้";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = "โหลดข้อมูลล้มเหลว (${response.statusCode})";
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
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: Column(
          children: [
            // AppBar (เหมือนเดิม)
            AppBar(
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Color(0xFF0E47A1),
                  size: 25,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapScreen()),
                  );
                },
              ),
              title: const Text(
                'โปรไฟล์',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0E47A1),
                ),
              ),
              centerTitle: true,
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 40,
                ),
                child: Column(
                  children: [
                    // Avatar (modern style)
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFd6eeff), // light purple
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 70,
                            backgroundColor: const Color(0xFFedf8ff),
                            backgroundImage:
                                _avatarFile != null
                                    ? FileImage(_avatarFile!)
                                    : (userData!['stf_avatar'] != null &&
                                                userData!['stf_avatar']
                                                    .toString()
                                                    .isNotEmpty
                                            ? NetworkImage(
                                              "http://10.0.2.2/api/${userData!['stf_avatar']}",
                                            )
                                            : null)
                                        as ImageProvider?,
                            child:
                                (_avatarFile == null &&
                                        (userData!['stf_avatar'] == null ||
                                            userData!['stf_avatar']
                                                .toString()
                                                .isEmpty))
                                    ? const Icon(
                                      Icons.person,
                                      size: 80,
                                      color: Color.fromARGB(200, 14, 70, 161),
                                    ) // ✅ ถ้าไม่มีรูป → แสดง icon
                                    : null,
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Material(
                            color: Colors.transparent, // ให้พื้นหลังโปร่งใส
                            shape: const CircleBorder(),
                            elevation: 1, // เงาเบา ๆ
                            child: InkWell(
                              customBorder:
                                  const CircleBorder(), // ✅ Ripple เป็นวงกลม
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color.fromARGB(
                                    200,
                                    8,
                                    77,
                                    197,
                                  ), // พื้นหลังน้ำเงิน
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Info fields
                    _styledInfoField(
                      "ชื่อ",
                      "${userData!['stf_fname']} ${userData!['stf_lname']}",
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    _styledInfoField(
                      "บทบาท",
                      userData!['stf_role'] ?? "-",
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 12),
                    _styledInfoField(
                      "Username",
                      userData!['stf_username'] ?? "-",
                      icon: Icons.account_circle_outlined,
                    ),
                    const SizedBox(height: 12),
                    _styledInfoField(
                      "Email",
                      userData!['stf_email'] ?? "-",
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 12),
                    _styledInfoField(
                      "เบอร์โทรศัพท์",
                      userData!['stf_phone'] != null
                          ? "0${userData!['stf_phone']}" // ✅ เติม 0 ข้างหน้า
                          : "-",
                      icon: Icons.phone_outlined,
                    ),
                    const SizedBox(height: 12),
                    _styledInfoField(
                      "รหัสผ่าน",
                      "********",
                      icon: Icons.lock_outline,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Custom reusable styled field
  Widget _styledInfoField(String label, String value, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F6F9),
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Row(
            children: [
              if (icon != null) Icon(icon, size: 25, color: Color(0xFF0E47A1)),
              if (icon != null) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  overflow: TextOverflow.visible, // ✅ ไม่ตัด
                  softWrap: true, // ✅ ขึ้นบรรทัดใหม่ได้
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
