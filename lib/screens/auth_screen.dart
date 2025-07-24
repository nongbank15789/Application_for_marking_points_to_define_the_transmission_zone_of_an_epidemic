import 'package:flutter/material.dart';
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

  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

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
          child: Container(
            width: size.width * 0.85,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
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
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const MapScreen()),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ยังไม่เปิดใช้งาน Sign Up')),
                      );
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
                      child: Text("Continue",
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ),
              ],
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

  Widget buildTextField(String label, IconData icon, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Icon(icon),
          border: const UnderlineInputBorder(),
        ),
      ),
    );
  }

  Widget buildPasswordField(String label, TextEditingController controller, VoidCallback toggleVisibility, bool visible) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: !visible,
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
        buildTextField("Email", Icons.email, emailController),
        buildPasswordField("Password", passwordController, () {
          setState(() => showPassword = !showPassword);
        }, showPassword),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey)),
          ),
        ),
      ],
    );
  }

  Widget buildSignUpForm() {
    return Column(
      children: [
        buildTextField("Username", Icons.person, usernameController),
        buildTextField("Email", Icons.email, emailController),
        buildPasswordField("Password", passwordController, () {
          setState(() => showPassword = !showPassword);
        }, showPassword),
        buildPasswordField("Confirm Password", confirmPasswordController, () {
          setState(() => showConfirmPassword = !showConfirmPassword);
        }, showConfirmPassword),
      ],
    );
  }
}
