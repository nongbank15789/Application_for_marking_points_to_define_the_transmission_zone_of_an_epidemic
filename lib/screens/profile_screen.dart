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
      body: Container(
        color: Color(0xFFe6f5fc),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Color(0xFF0277BD),
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
                    color: Color(0xFF0277BD),
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

                      // Avatar
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 70,
                            backgroundColor: Colors.white,
                            backgroundImage:
                                _avatarFile != null
                                    ? FileImage(_avatarFile!)
                                    : (userData!['stf_avatar'] != null
                                            ? NetworkImage(
                                              "http://10.0.2.2/api/${userData!['stf_avatar']}",
                                            )
                                            : null)
                                        as ImageProvider?,
                            child:
                                (_avatarFile == null &&
                                        userData!['stf_avatar'] == null)
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
                                decoration: const BoxDecoration(
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

                      // Info box
                      Container(
                        width: size.width * 0.85,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Color(0xFFE6F5FC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Color.fromRGBO(
                              155,
                              210,
                              230,
                              1,
                            ).withOpacity(0.75), // ขอบฟ้าอ่อน
                            width: 1.5, // ความหนาของขอบ
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildInfoField(
                              "ชื่อ",
                              "${userData!['stf_fname']} ${userData!['stf_lname']}",
                              icon: Icons.person,
                            ),
                            _buildInfoField(
                              "บทบาท",
                              userData!['role'] ?? "ผู้ใช้งาน",
                              icon: Icons.badge,
                            ),
                            _buildInfoField(
                              "Username",
                              userData!['stf_username'] ?? "-",
                              icon: Icons.account_circle,
                            ),
                            _buildInfoField(
                              "Email",
                              userData!['stf_email'] ?? "-",
                              icon: Icons.email,
                            ),
                            _buildInfoField(
                              "รหัสผ่าน",
                              "********",
                              obscureText: true,
                              icon: Icons.lock,
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

  // สร้าง TextField แบบ Read-only + Icon
  Widget _buildInfoField(
    String label,
    String value, {
    IconData? icon,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        enabled: false,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: Colors.blue) : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Color.fromRGBO(
                              155,
                              210,
                              230,
                              1,
                            )),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Color.fromRGBO(
                              155,
                              210,
                              230,
                              1,
                            )),
          ),
        ),
        controller: TextEditingController(text: value),
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
    );
  }
}
