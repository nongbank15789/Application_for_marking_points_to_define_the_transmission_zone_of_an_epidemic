import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'map_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool showPassword = false;
  bool showConfirmPassword = false;

  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final surnameController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final String baseUrl = 'http://10.0.2.2/api';

  Future<void> loginUser() async {
    if (usernameController.text.isEmpty || passwordController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณากรอก Username และ Password')),
        );
      }
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('กำลังเข้าสู่ระบบ...')));
    final url = Uri.parse('$baseUrl/login.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': usernameController.text,
          'password': passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('เข้าสู่ระบบสำเร็จ!')));
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation1, animation2) => MapScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
      } else {
        if (mounted) {
          final errorBody = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เข้าสู่ระบบไม่สำเร็จ: ${errorBody['message']}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อ: $e')),
        );
      }
    }
  }

  Future<void> registerUser() async {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กำลังลงทะเบียน...')));
      final url = Uri.parse('$baseUrl/register.php');
      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'name': nameController.text,
            'surname': surnameController.text,
            'username': usernameController.text,
            'email': emailController.text,
            'password': passwordController.text,
          }),
        );

        if (response.statusCode == 201) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('ลงทะเบียนสำเร็จ!')));
            nameController.clear();
            surnameController.clear();
            usernameController.clear();
            emailController.clear();
            passwordController.clear();
            confirmPasswordController.clear();

            setState(() {
              isLogin = true;
            });
          }
        } else {
          if (mounted) {
            final errorBody = json.decode(response.body);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('ลงทะเบียนไม่สำเร็จ: ${errorBody['message']}'),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อ: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    surnameController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Container(
              width: size.width * 0.85,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          buildToggle("Log In", isLogin, () {
                            setState(() => isLogin = true);
                          }),
                          buildToggle("Sign Up", !isLogin, () {
                            setState(() => isLogin = false);
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isLogin) buildLoginForm() else buildSignUpForm(),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (isLogin) {
                          loginUser();
                        } else {
                          registerUser();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        padding: const EdgeInsets.all(14),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0277BD), Color(0xFF00BCD4)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Center(
                          child: Text(
                            "Continue",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildToggle(String text, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0277BD) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF0277BD),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTextFormField(
    String label,
    IconData icon,
    TextEditingController controller, {
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        validator: validator,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Icon(icon),
          border: const UnderlineInputBorder(),
        ),
      ),
    );
  }

  Widget buildPasswordFormField(
    String label,
    TextEditingController controller,
    VoidCallback toggleVisibility,
    bool visible, {
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: !visible,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            icon: Icon(visible ? Icons.visibility : Icons.visibility_off),
            onPressed: toggleVisibility,
          ),
          border: const UnderlineInputBorder(),
        ),
      ),
    );
  }

  Widget buildLoginForm() {
    return Column(
      children: [
        buildTextFormField(
          "Username",
          Icons.person,
          usernameController,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอก Username';
            }
            return null;
          },
        ),
        buildPasswordFormField(
          "Password",
          passwordController,
          () {
            setState(() => showPassword = !showPassword);
          },
          showPassword,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอกรหัสผ่าน';
            }
            if (value.length < 6) {
              return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
            }
            return null;
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: const Text(
              "Forgot Password?",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildSignUpForm() {
    final nameRegExp = RegExp(r'^[\u0E00-\u0E7F\sa-zA-Z]+$');
    final usernameEmailRegExp = RegExp(r'^[a-zA-Z0-9_.]+$');

    return Column(
      children: [
        buildTextFormField(
          "ชื่อ",
          Icons.person,
          nameController,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอกชื่อ';
            }
            return null;
          },
          inputFormatters: [FilteringTextInputFormatter.allow(nameRegExp)],
        ),
        buildTextFormField(
          "นามสกุล",
          Icons.person,
          surnameController,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอกนามสกุล';
            }
            return null;
          },
          inputFormatters: [FilteringTextInputFormatter.allow(nameRegExp)],
        ),
        buildTextFormField(
          "Username",
          Icons.person,
          usernameController,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอก Username';
            }
            if (!usernameEmailRegExp.hasMatch(value)) {
              return 'Username ต้องเป็นตัวอักษรภาษาอังกฤษหรือตัวเลขเท่านั้น';
            }
            return null;
          },
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
          ],
        ),
        buildTextFormField(
          "Email",
          Icons.email,
          emailController,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอก Email';
            }
            final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+');
            if (!emailRegExp.hasMatch(value)) {
              return 'กรุณาตรวจสอบรูปแบบ Email';
            }
            return null;
          },
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\w@\.-]')),
          ],
        ),
        buildPasswordFormField(
          "Password",
          passwordController,
          () {
            setState(() => showPassword = !showPassword);
          },
          showPassword,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอกรหัสผ่าน';
            }
            if (value.length < 6) {
              return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
            }
            return null;
          },
        ),
        buildPasswordFormField(
          "Confirm Password",
          confirmPasswordController,
          () {
            setState(() => showConfirmPassword = !showConfirmPassword);
          },
          showConfirmPassword,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอกรหัสผ่านอีกครั้ง';
            }
            if (value != passwordController.text) {
              return 'รหัสผ่านไม่ตรงกัน';
            }
            return null;
          },
        ),
      ],
    );
  }
}
