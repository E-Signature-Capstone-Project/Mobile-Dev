import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Duration get loginTime => const Duration(milliseconds: 2250);

  final String baseUrl = 'http://10.0.2.2:4000/auth'; // sesuai app.js kamu

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // 🔹 Cek apakah sudah login
  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!mounted) return;
    if (isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  // 🔹 Simpan status login & token JWT
  Future<void> _setLoginStatus(bool status, {String? token}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', status);
    if (token != null) {
      await prefs.setString('token', token);
    }
  }

  // 🔹 Fungsi Login (terhubung ke backend)
  Future<String?> _authUser(LoginData data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': data.name, 'password': data.password}),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _setLoginStatus(true, token: result['token']);
        return null; // sukses
      } else {
        return result['error'] ?? 'Login gagal';
      }
    } catch (e) {
      return 'Gagal terhubung ke server: $e';
    }
  }

  // 🔹 Fungsi Register
  Future<String?> _signupUser(SignupData data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': data.additionalSignupData?['name'] ?? 'User Baru',
          'email': data.name,
          'password': data.password,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return null; // sukses
      } else {
        return result['error'] ?? 'Registrasi gagal';
      }
    } catch (e) {
      return 'Tidak bisa terhubung ke server: $e';
    }
  }

  // 🔹 Lupa password (belum aktif)
  Future<String?> _recoverPassword(String email) async {
    return 'Fitur lupa password belum tersedia';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2A2D3E), Color(0xFF1B1D27)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        FlutterLogin(
          title: 'E-Signature',
          logo: const AssetImage('assets/logo.png'),

          // koneksi backend
          onLogin: _authUser,
          onSignup: _signupUser,
          onRecoverPassword: _recoverPassword,
          hideForgotPasswordButton: true,

          userValidator: (value) {
            if (value == null || value.isEmpty) return 'Email diperlukan';
            if (!value.contains('@')) return 'Email tidak valid';
            return null;
          },

          userType: LoginUserType.email,

          theme: LoginTheme(
            pageColorLight: Colors.transparent,
            pageColorDark: Colors.transparent,
            primaryColor: Colors.black,
            accentColor: Colors.transparent,
            errorColor: Colors.red,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 30.0,
            ),
            cardTheme: const CardTheme(
              color: Color(0xFF93D9FA),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            inputTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Colors.transparent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: Colors.transparent),
              ),
              labelStyle: TextStyle(
                color: Colors.black,
              ),
            ),
            buttonTheme: const LoginButtonTheme(
              backgroundColor: Colors.white,
              splashColor: Colors.white,
              highlightColor: Colors.white,
              elevation: 5.0,
            ),
            buttonStyle: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),

          // 🔹 Ketika animasi login selesai
          onSubmitAnimationCompleted: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          },
        ),
      ],
    );
  }
}
