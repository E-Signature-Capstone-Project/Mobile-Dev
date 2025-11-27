// lib/utils/logout_helper.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../login_register.dart';

Future<void> performLogout(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();

  // bersihin semua jejak login
  await prefs.remove('token');
  await prefs.remove('isLoggedIn');
  await prefs.remove('user_id');
  await prefs.remove('user_name');
  await prefs.remove('user_email');
  await prefs.remove('current_email');
  await prefs.remove('role');

  // balik ke halaman login (hapus semua route sebelumnya)
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (route) => false,
  );
}
