import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/auth_screen.dart'; // เปลี่ยนเป็นไฟล์เริ่มต้นของคุณ

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // โหลดข้อมูล locale ไทยสำหรับ intl (ป้องกัน LocaleDataException)
  await initializeDateFormatting('th', null);
  // ตั้ง default locale ให้ DateFormat ทั้งแอป
  Intl.defaultLocale = 'th_TH';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ให้ widget ระบบ (เช่น DatePicker) แปลภาษาไทย
      locale: const Locale('th', 'TH'),
      supportedLocales: const [
        Locale('th', 'TH'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const AuthScreen(),
    );
  }
}
