import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/filter_screen.dart';
import 'screens/history_screen.dart';
import 'screens/add_data_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthScreen(),
    );
  }
}
