import 'package:flutter/material.dart';
import 'login_register.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'E-Signature',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(), // langsung ke halaman login
    );
  }
}
