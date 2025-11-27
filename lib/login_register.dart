import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pages/main_menu.dart';
import 'pages/config/api_config.dart';
import 'pages/admin/admin_verif_log_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Duration get loginTime => const Duration(milliseconds: 2250);

  // ====== CONFIG API ======
  final String apiBase = ApiConfig.baseUrl;
  String get authUrl => ApiConfig.authUrl;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// Mengecek apakah user sudah login sebelumnya
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!mounted) return;
    if (isLoggedIn) {
      final role = prefs.getString('role') ?? 'user';

      Widget dest;
      if (role == 'admin') {
        dest = const AdminVerifLogPage();
      } else {
        dest = const MainMenu();
      }

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => dest));
    }
  }

  /// Simpan status login & token
  Future<void> _setLoginStatus(bool status, {String? token}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', status);
    if (token != null) {
      await prefs.setString('token', token);
    }
  }

  /// Decode payload JWT (user_id, email, role)
  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final map = jsonDecode(payload);
      if (map is Map<String, dynamic>) {
        return map;
      }
      return Map<String, dynamic>.from(map as Map);
    } catch (_) {
      return null;
    }
  }

  /// LOGIN
  Future<String?> _authUser(LoginData data) async {
    try {
      final response = await http.post(
        Uri.parse('$authUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': data.name, 'password': data.password}),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = result['token'] as String?;
        if (token == null) {
          return 'Token tidak ditemukan di response';
        }

        // decode payload
        final payload = _decodeJwtPayload(token);
        final email = payload?['email']?.toString() ?? data.name;
        final role = payload?['role']?.toString() ?? 'user';
        final userIdRaw = payload?['user_id'];
        final int? userId = userIdRaw is int
            ? userIdRaw
            : (userIdRaw is num ? userIdRaw.toInt() : null);

        // simpan login status + token
        await _setLoginStatus(true, token: token);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_email', email);
        await prefs.setString('user_email', email);
        await prefs.setString('role', role);

        if (userId != null) {
          await prefs.setInt('user_id', userId);
        }

        // optional simpan name kalau nanti mau diisi dari /me
        if (result['user'] != null) {
          await prefs.setString('user_name', result['user']['name'] ?? '');
        }

        return null; // login berhasil
      } else {
        return result['error']?.toString() ?? 'Login gagal';
      }
    } catch (e) {
      return 'Gagal terhubung ke server: $e';
    }
  }

  /// REGISTER (user biasa, bukan admin)
  Future<String?> _signupUser(SignupData data) async {
    try {
      final response = await http.post(
        Uri.parse('$authUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': data.additionalSignupData?['name'],
          'email': data.name,
          'password': data.password,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // auto login setelah register
        final loginRes = await http.post(
          Uri.parse('$authUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': data.name, 'password': data.password}),
        );

        final loginJson = jsonDecode(loginRes.body);
        if (loginRes.statusCode == 200) {
          final token = loginJson['token'] as String?;
          if (token == null) {
            return 'Registrasi berhasil, tapi token login tidak ditemukan';
          }

          await _setLoginStatus(true, token: token);

          final payload = _decodeJwtPayload(token);
          final email = payload?['email']?.toString() ?? (data.name ?? '');
          final role = payload?['role']?.toString() ?? 'user';
          final userIdRaw = payload?['user_id'];
          final int? userId = userIdRaw is int
              ? userIdRaw
              : (userIdRaw is num ? userIdRaw.toInt() : null);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_email', email);
          await prefs.setString('user_email', email);
          await prefs.setString(
            'user_name',
            data.additionalSignupData?['name'] ?? '',
          );
          await prefs.setString('role', role);

          if (userId != null) {
            await prefs.setInt('user_id', userId);
          }

          return null; // registrasi + login sukses
        } else {
          return loginJson['error']?.toString() ??
              'Registrasi ok, tapi auto-login gagal';
        }
      } else {
        return result['error']?.toString() ?? 'Registrasi gagal';
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
  final Color primaryColorUI = Colors.blue;
  final Color colorBG = Colors.white;

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
              surface: Colors.white,
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          child: FlutterLogin(
            title: 'E-Signature',
            logo: const AssetImage('assets/logobiru.png'),
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
              primaryColor: primaryColorUI,
              accentColor: primaryColorUI,
              errorColor: Colors.white,
              titleStyle: GoogleFonts.montserrat(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 32,
                letterSpacing: 1.2,
              ),
              cardTheme: CardTheme(
                color: primaryColorUI,
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
                splashColor: Colors.white70,
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
              final prefs = await SharedPreferences.getInstance();
              final role = prefs.getString('role') ?? 'user';

              Widget dest;
              if (role == 'admin') {
                dest = const AdminVerifLogPage();
              } else {
                dest = const MainMenu();
              }

              Navigator.of(
                context,
              ).pushReplacement(MaterialPageRoute(builder: (_) => dest));
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
