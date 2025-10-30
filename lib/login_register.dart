import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/main_menu.dart';
import 'pages/add_baseline_sign_page.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Duration get loginTime => const Duration(milliseconds: 2250);

  // ====== CONFIG API ======
  final String apiBase = 'http://10.0.2.2:4000';
  String get authBase => '$apiBase/auth';
  String get baselineBase => '$apiBase/baseline';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// Mengecek apakah user sudah login sebelumnya
  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!mounted) return;
    if (isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainMenu()),
      );
    }
  }

  /// Simpan status login & token
  Future<void> _setLoginStatus(bool status, {String? token}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', status);
    if (token != null) {
      await prefs.setString('token', token);
    }
  }

  // decode email dari JWT token
  String? _emailFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final map = jsonDecode(payload);
      return map['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// LOGIN
  Future<String?> _authUser(LoginData data) async {
    try {
      final response = await http.post(
        Uri.parse('$authBase/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': data.name, 'password': data.password}),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = result['token'];
        final email = _emailFromJwt(token) ?? data.name;

        await _setLoginStatus(true, token: token);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_email', email ?? '');

        // simpan user info jika tersedia
        if (result['user'] != null) {
          await prefs.setString('user_name', result['user']['name'] ?? '');
          await prefs.setString('user_email', result['user']['email'] ?? '');
        } else {
          await prefs.setString('user_email', email ?? '');
        }

        return null;
      } else {
        return result['error'] ?? 'Login gagal';
      }
    } catch (e) {
      return 'Gagal terhubung ke server: $e';
    }
  }

  /// REGISTER
  Future<String?> _signupUser(SignupData data) async {
    try {
      final response = await http.post(
        Uri.parse('$authBase/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': data.additionalSignupData?['name'],
          'email': data.name,
          'password': data.password,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final loginRes = await http.post(
          Uri.parse('$authBase/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': data.name, 'password': data.password}),
        );

        final loginJson = jsonDecode(loginRes.body);
        if (loginRes.statusCode == 200) {
          final token = loginJson['token'];
          await _setLoginStatus(true, token: token);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_email', data.name ?? '');
          await prefs.setString(
            'user_name',
            loginJson['user']?['name'] ??
                (data.additionalSignupData?['name'] ?? ''),
          );
          await prefs.setString(
            'user_email',
            loginJson['user']?['email'] ?? (data.name ?? ''),
          );

          return null;
        } else {
          return loginJson['error'] ?? 'Registrasi ok, tapi auto-login gagal';
        }
      } else {
        return result['error'] ?? 'Registrasi gagal';
      }
    } catch (e) {
      return 'Tidak bisa terhubung ke server: $e';
    }
  }

  /// Lupa Password (placeholder)
  Future<String?> _recoverPassword(String email) async {
    return 'Fitur lupa password belum tersedia';
  }

  // warna ui
  final Color primaryRed = const Color(0xFFDA1E28);
  final Color colorBG = Colors.white;

  // CEK BASELINE DARI BACKEND
  Future<bool> _hasAnyBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) return false;

    final res = await http.get(
      Uri.parse('$baselineBase/get'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final count = (json['count'] as num?)?.toInt() ?? 0;
      return count > 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background
        Container(color: colorBG),
        Theme(
          data: ThemeData(
            colorScheme: const ColorScheme.light(
              primary: Colors.white,
              secondary: Colors.black,
              background: Colors.white,
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          child: FlutterLogin(
            title: 'E-Signature',
            logo: const AssetImage('assets/logo.png'),
            onLogin: _authUser,
            onSignup: _signupUser,
            onRecoverPassword: _recoverPassword,
            hideForgotPasswordButton: true,
            userType: LoginUserType.email,
            additionalSignupFields: [
              UserFormField(
                keyName: 'name',
                displayName: 'Name',
                icon: const Icon(Icons.person),
                fieldValidator: _validateUsername,
              ),
            ],
            theme: LoginTheme(
              pageColorLight: colorBG,
              pageColorDark: colorBG,
              primaryColor: primaryRed,
              accentColor: primaryRed,
              errorColor: Colors.white,
              titleStyle: GoogleFonts.montserrat(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 32,
                letterSpacing: 1.2,
              ),
              cardTheme: CardTheme(
                color: primaryRed,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              inputTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                prefixIconColor: Colors.black,
                labelStyle: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                hintStyle: GoogleFonts.inter(
                  color: Colors.black54,
                  fontSize: 13,
                ),
                errorStyle: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),

              buttonTheme: LoginButtonTheme(
                backgroundColor: Colors.white,
                splashColor: Colors.white.withOpacity(0.2),
                highlightColor: Colors.white,
                elevation: 4.0,
              ),
              buttonStyle: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            onSubmitAnimationCompleted: () async {
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainMenu()),
              );
            },
          ),
        ),
      ],
    );
  }

  static String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) return 'Username wajib diisi';
    if (value.length < 3) return 'Minimal 3 karakter';
    return null;
  }
}
