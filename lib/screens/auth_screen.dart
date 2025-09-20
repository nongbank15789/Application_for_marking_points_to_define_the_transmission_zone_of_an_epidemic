import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.bypassAutoLogin = false});
  final bool bypassAutoLogin; // << เพิ่มเพื่อปิด auto-login เวลา logout

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // ----- State -----
  bool isLogin = true;
  bool showLoginPassword = false;
  bool showSignupPassword = false;
  bool showConfirmPassword = false;
  bool _busy = false; // กันกดรัว
  bool rememberMe = false; // จำฉัน

  // Secure storage (Android Keystore / iOS Keychain)
  final _secure = const FlutterSecureStorage();

  // ----- Forms (แยกคนละชุด) -----
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();
  AutovalidateMode _loginAV = AutovalidateMode.disabled;
  AutovalidateMode _signupAV = AutovalidateMode.disabled;

  // ----- Controllers (LOGIN) -----
  final loginUsernameController = TextEditingController();
  final loginPasswordController = TextEditingController();

  // ----- Controllers (SIGNUP) -----
  final nameController = TextEditingController();
  final surnameController = TextEditingController();
  final emailController = TextEditingController();
  final signupUsernameController = TextEditingController();
  final signupPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // ----- API base -----
  final String baseUrl = 'http://10.0.2.2/api';

  @override
  void initState() {
    super.initState();
    _loadSavedLogin().then((_) {
      if (!widget.bypassAutoLogin) {
        _tryAutoLogin(); // auto-login แบบเงียบ (ถ้า remember me)
      }
    });
  }

  // เติมค่าที่เคยจำไว้
  Future<void> _loadSavedLogin() async {
    final saved = await _secure.read(key: 'remember_me') == '1';
    if (!mounted) return;
    setState(() => rememberMe = saved);

    if (saved) {
      final u = await _secure.read(key: 'login_username');
      final p = await _secure.read(key: 'login_password');
      if (u != null) loginUsernameController.text = u;
      if (p != null) loginPasswordController.text = p;
    }
  }

  // Auto-login แบบเงียบเมื่อเปิดจอ (ไม่ต้องแก้ backend)
  Future<void> _tryAutoLogin() async {
    if (!isLogin || !rememberMe) return;
    if (loginUsernameController.text.isEmpty ||
        loginPasswordController.text.isEmpty)
      return;
    await loginUser(silent: true);
  }

  // บันทึก/ล้างข้อมูลจำฉัน
  Future<void> _persistLoginChoice() async {
    if (rememberMe) {
      await _secure.write(key: 'remember_me', value: '1');
      await _secure.write(
        key: 'login_username',
        value: loginUsernameController.text,
      );
      await _secure.write(
        key: 'login_password',
        value: loginPasswordController.text,
      );
    } else {
      await _secure.delete(key: 'remember_me');
      await _secure.delete(key: 'login_username');
      await _secure.delete(key: 'login_password');
    }
  }

  // ----- Actions -----
  Future<void> loginUser({bool silent = false}) async {
    if (_busy) return;

    FocusScope.of(context).unfocus();

    if (loginUsernameController.text.isEmpty ||
        loginPasswordController.text.isEmpty) {
      if (mounted && !silent)
        AppSnack.warn(context, 'กรุณากรอก Username และ Password');
      return;
    }

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    if (!silent) AppSnack.loading(context, 'กำลังเข้าสู่ระบบ...');

    final url = Uri.parse('$baseUrl/login.php');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'username': loginUsernameController.text,
              'password': loginPasswordController.text,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (mounted && !silent) messenger.hideCurrentSnackBar();

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final userId = responseData['stf_id'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('userId', userId);

        // บันทึก remember choice
        await _persistLoginChoice();

        if (mounted) {
          if (!silent) AppSnack.success(context, 'เข้าสู่ระบบสำเร็จ!');
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (c, a1, a2) => MapScreen(userId: userId),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
      } else {
        if (mounted && !silent) {
          final errorBody = json.decode(response.body);
          AppSnack.error(
            context,
            'เข้าสู่ระบบไม่สำเร็จ: ${errorBody['message']}',
          );
        }
      }
    } catch (e) {
      if (mounted && !silent) {
        messenger.hideCurrentSnackBar();
        AppSnack.error(context, 'เกิดข้อผิดพลาดในการเชื่อมต่อ: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> registerUser() async {
    if (_busy) return;
    if (!(_signupFormKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    AppSnack.loading(context, 'กำลังลงทะเบียน...');
    final url = Uri.parse('$baseUrl/register.php');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'name': nameController.text,
              'surname': surnameController.text,
              'username': signupUsernameController.text,
              'email': emailController.text,
              'password': signupPasswordController.text,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (mounted) messenger.hideCurrentSnackBar();

      if (response.statusCode == 201) {
        if (mounted) {
          AppSnack.success(context, 'ลงทะเบียนสำเร็จ!');
          _clearSignupControllers();
          setState(() {
            isLogin = true;
            _signupFormKey.currentState?.reset();
            _signupAV = AutovalidateMode.disabled;
          });
        }
      } else {
        if (mounted) {
          final errorBody = json.decode(response.body);
          AppSnack.error(
            context,
            'ลงทะเบียนไม่สำเร็จ: ${errorBody['message']}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.hideCurrentSnackBar();
        AppSnack.error(context, 'เกิดข้อผิดพลาดในการเชื่อมต่อ: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ----- Helpers -----
  void _clearLoginControllers() {
    if (!rememberMe) {
      loginUsernameController.clear();
      loginPasswordController.clear();
    }
  }

  void _clearSignupControllers() {
    nameController.clear();
    surnameController.clear();
    emailController.clear();
    signupUsernameController.clear();
    signupPasswordController.clear();
    confirmPasswordController.clear();
  }

  @override
  void dispose() {
    // LOGIN
    loginUsernameController.dispose();
    loginPasswordController.dispose();
    // SIGNUP
    nameController.dispose();
    surnameController.dispose();
    emailController.dispose();
    signupUsernameController.dispose();
    signupPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // ----- UI -----
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFE4F2FD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ArcBandsHeader(
                height: 280,
                cardRadius: 36,
                title: isLogin ? 'Log In' : 'Sign Up',
                subtitle:
                    isLogin
                        ? 'Welcome back! Please enter your details to continue.'
                        : 'Register to Start Your Exciting Learning Process',
                onBack: _busy ? null : () => Navigator.maybePop(context),
              ),

              // ฟอร์ม
              Padding(
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // Toggle
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            color: Colors.black.withOpacity(0.06),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _tabButton('Log In', isLogin),
                          _tabButton('Sign Up', !isLogin),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ใช้ฟอร์มคนละชุด + autovalidate แยก
                    if (isLogin)
                      Form(
                        key: _loginFormKey,
                        autovalidateMode: _loginAV,
                        child: _buildLoginFormFields(),
                      )
                    else
                      Form(
                        key: _signupFormKey,
                        autovalidateMode: _signupAV,
                        child: _buildSignupFormFields(),
                      ),

                    const SizedBox(height: 16),

                    // ปุ่มส่ง (disabled ตอน busy)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed:
                            _busy
                                ? null
                                : () {
                                  if (isLogin) {
                                    setState(
                                      () =>
                                          _loginAV =
                                              AutovalidateMode
                                                  .onUserInteraction,
                                    );
                                    if (_loginFormKey.currentState
                                            ?.validate() ??
                                        true) {
                                      loginUser();
                                    }
                                  } else {
                                    setState(
                                      () =>
                                          _signupAV =
                                              AutovalidateMode
                                                  .onUserInteraction,
                                    );
                                    if (_signupFormKey.currentState
                                            ?.validate() ??
                                        false) {
                                      registerUser();
                                    }
                                  }
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E47A1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child:
                            _busy
                                ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(
                                  isLogin ? 'Log In' : 'Sign Up',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----- Widgets -----
  Widget _tabButton(String text, bool selected) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap:
            _busy
                ? null
                : () {
                  setState(() {
                    if (text == 'Log In') {
                      isLogin = true;
                      _signupFormKey.currentState?.reset();
                      _signupAV = AutovalidateMode.disabled;
                      _clearSignupControllers();
                    } else {
                      isLogin = false;
                      _loginFormKey.currentState?.reset();
                      _loginAV = AutovalidateMode.disabled;
                      _clearLoginControllers();
                    }
                  });
                },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0E47A1) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF0E47A1),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _roundedDecoration({
    required String label,
    required IconData prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(prefix),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5ECF6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5ECF6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF084cc5), width: 1.6),
      ),
    );
  }

  Widget _buildLoginFormFields() {
    return Column(
      children: [
        TextFormField(
          controller: loginUsernameController,
          validator:
              (v) => (v == null || v.isEmpty) ? 'กรุณากรอก Username' : null,
          decoration: _roundedDecoration(
            label: 'Username',
            prefix: Icons.person,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: loginPasswordController,
          obscureText: !showLoginPassword,
          validator: (v) {
            if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่าน';
            if (v.length < 6) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
            return null;
          },
          decoration: _roundedDecoration(
            label: 'Password',
            prefix: Icons.lock,
            suffix: IconButton(
              onPressed:
                  () => setState(() => showLoginPassword = !showLoginPassword),
              icon: Icon(
                showLoginPassword ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Checkbox(
              value: rememberMe,
              onChanged:
                  _busy ? null : (v) => setState(() => rememberMe = v ?? false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Text('Remember me'),
          ],
        ),
      ],
    );
  }

  Widget _buildSignupFormFields() {
    final nameRegExp = RegExp(r'^[\u0E00-\u0E7F\sa-zA-Z]+$');
    final usernameEmailRegExp = RegExp(r'^[a-zA-Z0-9_.]+$');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: nameController,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(nameRegExp),
                ],
                validator:
                    (v) => (v == null || v.isEmpty) ? 'กรุณากรอกชื่อ' : null,
                decoration: _roundedDecoration(
                  label: 'ชื่อ',
                  prefix: Icons.person_outline,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: surnameController,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(nameRegExp),
                ],
                validator:
                    (v) => (v == null || v.isEmpty) ? 'กรุณากรอกนามสกุล' : null,
                decoration: _roundedDecoration(
                  label: 'นามสกุล',
                  prefix: Icons.person_outline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\w@\.-]')),
          ],
          validator: (v) {
            if (v == null || v.isEmpty) return 'กรุณากรอก Email';
            final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+');
            if (!emailRegExp.hasMatch(v)) return 'กรุณาตรวจสอบรูปแบบ Email';
            return null;
          },
          decoration: _roundedDecoration(
            label: 'Email address',
            prefix: Icons.email_outlined,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: signupUsernameController,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
          ],
          validator: (v) {
            if (v == null || v.isEmpty) return 'กรุณากรอก Username';
            if (!usernameEmailRegExp.hasMatch(v)) {
              return 'Username ต้องเป็น a-z, 0-9, _ หรือ .';
            }
            return null;
          },
          decoration: _roundedDecoration(
            label: 'Username',
            prefix: Icons.alternate_email,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: signupPasswordController,
          obscureText: !showSignupPassword,
          validator: (v) {
            if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่าน';
            if (v.length < 6) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
            return null;
          },
          decoration: _roundedDecoration(
            label: 'Password',
            prefix: Icons.lock_outline,
            suffix: IconButton(
              onPressed:
                  () =>
                      setState(() => showSignupPassword = !showSignupPassword),
              icon: Icon(
                showSignupPassword ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: confirmPasswordController,
          obscureText: !showConfirmPassword,
          validator: (v) {
            if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่านอีกครั้ง';
            if (v != signupPasswordController.text) return 'รหัสผ่านไม่ตรงกัน';
            return null;
          },
          decoration: _roundedDecoration(
            label: 'Confirm Password',
            prefix: Icons.lock_outline,
            suffix: IconButton(
              onPressed:
                  () => setState(
                    () => showConfirmPassword = !showConfirmPassword,
                  ),
              icon: Icon(
                showConfirmPassword ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// =================================================================
/// ArcBandsHeader : หัววงรีโค้งซ้อน 2 ชั้นจากมุมขวาบน
/// =================================================================
class ArcBandsHeader extends StatelessWidget {
  const ArcBandsHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onBack,
    this.height = 280,
    this.cardRadius = 36,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final double height;
  final double cardRadius;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return SizedBox(
      height: height,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cardRadius),
          child: SizedBox(
            width: w * 0.92,
            height: height - 30,
            child: Stack(
              children: [
                CustomPaint(size: Size.infinite, painter: _ArcBandsPainter()),
                Positioned(
                  left: 24,
                  top: 44,
                  right: 90,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 16,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcBandsPainter extends CustomPainter {
  static const Color navy = Color(0xFF0B2A5B); // พื้นหลังเข้ม
  static const Color bandMid = Color(0xFF0E47A1); // แถบกลาง
  static const Color bandBright = Color(0xFF0E7BFF); // แถบสว่าง

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = navy);

    Path ringFromRects(Rect outer, Rect inner) {
      final outerP = Path()..addOval(outer);
      final innerP = Path()..addOval(inner);
      return Path.combine(PathOperation.difference, outerP, innerP);
    }

    final Offset c = Offset(size.width * 1.10, -size.height * 0.10);

    final Rect midOuter = Rect.fromCenter(
      center: c,
      width: size.width * 1.90,
      height: size.height * 1.90,
    );
    final Rect midInner = Rect.fromCenter(
      center: c,
      width: size.width * 1.45,
      height: size.height * 1.45,
    );
    final Path band1 = ringFromRects(midOuter, midInner);
    canvas.drawShadow(band1, Colors.black.withOpacity(.22), 8, false);
    canvas.drawPath(band1, Paint()..color = bandMid);

    final Offset cBright = Offset(size.width * 1.05, size.height * 0.05);
    final Rect brOuter = Rect.fromCenter(
      center: cBright,
      width: size.width * 2.20,
      height: size.height * 2.20,
    );
    final Rect brInner = Rect.fromCenter(
      center: cBright,
      width: size.width * 1.65,
      height: size.height * 1.65,
    );
    final Path band2 = ringFromRects(brOuter, brInner);
    canvas.drawShadow(band2, Colors.black.withOpacity(.26), 10, false);
    canvas.drawPath(band2, Paint()..color = bandBright);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ===============================================================
/// AppSnack : SnackBar แบบลอย มุมมน ไอคอน/โทนสี + โหมด Loading
/// ===============================================================
enum SnackType { info, success, warning, error }

class AppSnack {
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context,
    String message, {
    SnackType type = SnackType.info,
    Duration? duration,
    IconData? icon,
  }) {
    Color bg;
    IconData ic;
    switch (type) {
      case SnackType.success:
        bg = const Color(0xFF22C55E);
        ic = Icons.check_circle_rounded;
        break;
      case SnackType.warning:
        bg = const Color(0xFFF59E0B);
        ic = Icons.warning_amber_rounded;
        break;
      case SnackType.error:
        bg = const Color(0xFFEF4444);
        ic = Icons.error_rounded;
        break;
      default:
        bg = const Color(0xFF0E47A1);
        ic = Icons.info_rounded;
    }
    if (icon != null) ic = icon;

    ScaffoldMessenger.of(context).clearSnackBars();

    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        duration:
            duration ?? Duration(seconds: type == SnackType.error ? 4 : 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.15),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(ic, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap:
                    () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> loading(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).clearSnackBars();
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        duration: const Duration(days: 1),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0E47A1),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.15),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: const [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'กำลังดำเนินการ...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void success(BuildContext c, String m) =>
      show(c, m, type: SnackType.success);
  static void error(BuildContext c, String m) =>
      show(c, m, type: SnackType.error);
  static void warn(BuildContext c, String m) =>
      show(c, m, type: SnackType.warning);
  static void info(BuildContext c, String m) =>
      show(c, m, type: SnackType.info);
}
