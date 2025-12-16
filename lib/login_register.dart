import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/config/api_config.dart';
import 'pages/main_menu.dart';
import 'pages/admin/admin_main_menu.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ====== CONFIG API ======
  String get authUrl => ApiConfig.authUrl;
  final Color primaryColorUI = const Color(0xFF003E9C);
  final Color bgColor = const Color(0xFFF4FAFE);

  bool _isLoginMode = true;
  bool _isLoading = false;

  // form keys
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // controllers login
  final _loginEmailC = TextEditingController();
  final _loginPassC = TextEditingController();

  // controllers register
  final _regNameC = TextEditingController();
  final _regEmailC = TextEditingController();
  final _regPassC = TextEditingController();
  bool _registerAsAdmin = false;

  // visibilitas password
  bool _loginPassObscure = true;
  bool _regPassObscure = true;

  String? _loginError;
  String? _registerError;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _loginEmailC.dispose();
    _loginPassC.dispose();
    _regNameC.dispose();
    _regEmailC.dispose();
    _regPassC.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!mounted || !isLoggedIn) return;

    final role = prefs.getString('role') ?? 'user';

    // tentukan halaman tujuan
    final Widget dest = (role == 'admin')
        ? const AdminMainMenu()
        : const MainMenu();

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => dest));
  }

  Future<void> _setLoginStatus(bool status, {String? token}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', status);
    if (token != null) {
      await prefs.setString('token', token);
    }
  }

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final map = jsonDecode(payload);
      if (map is Map<String, dynamic>) return map;
      return Map<String, dynamic>.from(map as Map);
    } catch (_) {
      return null;
    }
  }

  // =====================================================
  //                ANIMASI + DIALOG POPUP
  // =====================================================

  // Animasi transisi halaman (fade + slide + sedikit scale)
  PageRouteBuilder _buildPageTransition(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (_, animation, secondaryAnimation) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1), // naik dikit dari bawah
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  // DIALOG SUKSES LOGIN (USER & ADMIN)
  Future<void> _showLoginSuccessDialog(String role) async {
    if (!mounted) return;
    final isAdmin = role == 'admin';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColorUI.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAdmin
                      ? Icons.admin_panel_settings_outlined
                      : Icons.check_circle_rounded,
                  color: primaryColorUI,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isAdmin ? 'Masuk sebagai Admin' : 'Login Berhasil',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAdmin
                    ? 'Anda berhasil masuk sebagai admin.\nSilakan kelola verifikasi dokumen.'
                    : 'Selamat datang kembali!\nKamu sudah berhasil masuk ke akunmu.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: Colors.black87),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColorUI,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Lanjut',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // DIALOG SUKSES REGISTER USER BIASA (AUTO LOGIN)
  Future<void> _showRegisterSuccessDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColorUI.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: primaryColorUI,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Registrasi Berhasil',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Akunmu sudah dibuat dan kamu otomatis masuk.\nSiap mulai mengelola dokumen.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Colors.black87),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColorUI,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Masuk ke Beranda',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== LOGIN =====================
  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _loginError = null;
    });

    try {
      final res = await http.post(
        Uri.parse('$authUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _loginEmailC.text.trim(),
          'password': _loginPassC.text,
        }),
      );

      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        final token = body['token'] as String?;
        if (token == null) {
          setState(() => _loginError = 'Token tidak ditemukan dari server.');
          return;
        }

        final payload = _decodeJwtPayload(token);
        final email = payload?['email']?.toString() ?? _loginEmailC.text.trim();
        final role = payload?['role']?.toString() ?? 'user';
        final userIdRaw = payload?['user_id'];
        final int? userId = userIdRaw is int
            ? userIdRaw
            : (userIdRaw is num ? userIdRaw.toInt() : null);

        await _setLoginStatus(true, token: token);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_email', email);
        await prefs.setString('user_email', email);
        await prefs.setString('role', role);
        if (userId != null) {
          await prefs.setInt('user_id', userId);
        }

        if (!mounted) return;

        // POPUP LOGIN BERHASIL (USER / ADMIN)
        await _showLoginSuccessDialog(role);

        // TRANSISI DENGAN ANIMASI KE HALAMAN BERIKUTNYA
        Widget dest = role == 'admin'
            ? const AdminMainMenu()
            : const MainMenu();

        Navigator.of(context).pushReplacement(_buildPageTransition(dest));
      } else {
        setState(() {
          _loginError = body['error']?.toString() ?? 'Login gagal.';
        });
      }
    } catch (e) {
      setState(() => _loginError = 'Gagal terhubung ke server: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===================== REGISTER =====================
  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _registerError = null;
    });

    try {
      final name = _regNameC.text.trim();
      final email = _regEmailC.text.trim();
      final pass = _regPassC.text;

      final res = await http.post(
        Uri.parse('$authUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': pass,
          'request_admin': _registerAsAdmin,
        }),
      );

      final body = jsonDecode(res.body);

      if (res.statusCode == 201) {
        // Jika daftar sebagai admin → tidak auto login
        if (_registerAsAdmin) {
          if (!mounted) return;
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColorUI.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: primaryColorUI,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Pengajuan Admin Terkirim',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (body['message'] ??
                              'Registrasi sebagai admin berhasil.\nTolong tunggu persetujuan admin sebelum bisa login.')
                          .toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColorUI,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Mengerti',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          // balik ke tab login dan kosongkan field
          setState(() {
            _isLoginMode = true;
          });
          _regPassC.clear();
          return;
        }

        // === user biasa → auto login ===
        final loginRes = await http.post(
          Uri.parse('$authUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': pass}),
        );

        final loginJson = jsonDecode(loginRes.body);
        if (loginRes.statusCode == 200) {
          final token = loginJson['token'] as String?;
          if (token == null) {
            setState(
              () => _registerError =
                  'Registrasi sukses, tapi token login tidak ditemukan.',
            );
            return;
          }

          await _setLoginStatus(true, token: token);

          final payload = _decodeJwtPayload(token);
          final emailAfter = payload?['email']?.toString() ?? email;
          final role = payload?['role']?.toString() ?? 'user';
          final userIdRaw = payload?['user_id'];
          final int? userId = userIdRaw is int
              ? userIdRaw
              : (userIdRaw is num ? userIdRaw.toInt() : null);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_email', emailAfter);
          await prefs.setString('user_email', emailAfter);
          await prefs.setString('user_name', name);
          await prefs.setString('role', role);
          if (userId != null) {
            await prefs.setInt('user_id', userId);
          }

          if (!mounted) return;

          // POPUP REGISTRASI BERHASIL
          await _showRegisterSuccessDialog();

          // TRANSISI ANIMASI KE MAIN MENU
          Navigator.of(
            context,
          ).pushReplacement(_buildPageTransition(const MainMenu()));
        } else {
          setState(() {
            _registerError =
                loginJson['error']?.toString() ??
                'Registrasi berhasil, tapi auto-login gagal.';
          });
        }
      } else {
        setState(() {
          _registerError = body['error']?.toString() ?? 'Registrasi gagal.';
        });
      }
    } catch (e) {
      setState(() => _registerError = 'Tidak bisa terhubung ke server: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =====================================================
  //                          UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // Logo + title
                Image.asset('assets/logo.png', width: 150, height: 150),
                const SizedBox(height: 10),
                const Text(
                  'E-Signature',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Masuk untuk mengelola dan menandatangani dokumenmu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 24),

                // Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildTabSwitcher(),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) {
                          final curved = CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          );

                          return FadeTransition(
                            opacity: curved,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.98,
                                end: 1.0,
                              ).animate(curved),
                              child: child,
                            ),
                          );
                        },
                        child: _isLoginMode
                            ? KeyedSubtree(
                                key: const ValueKey('login-form'),
                                child: _buildLoginForm(),
                              )
                            : KeyedSubtree(
                                key: const ValueKey('register-form'),
                                child: _buildRegisterForm(),
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

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          _buildTabButton(
            title: 'Masuk',
            isActive: _isLoginMode,
            onTap: () {
              setState(() => _isLoginMode = true);
            },
          ),
          _buildTabButton(
            title: 'Daftar',
            isActive: !_isLoginMode,
            onTap: () {
              setState(() => _isLoginMode = false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: isActive ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? primaryColorUI : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _loginEmailC,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Email wajib diisi';
              }
              if (!v.contains('@')) {
                return 'Format email tidak valid';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _loginPassC,
            obscureText: _loginPassObscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _loginPassObscure = !_loginPassObscure;
                  });
                },
                icon: Icon(
                  _loginPassObscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: primaryColorUI,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Password wajib diisi';
              }
              if (v.length < 6) {
                return 'Minimal 6 karakter';
              }
              return null;
            },
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Lupa password? (belum tersedia)',
              style: TextStyle(fontSize: 11.5, color: Colors.black38),
            ),
          ),
          const SizedBox(height: 14),
          if (_loginError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _loginError!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColorUI,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Masuk',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _regNameC,
            decoration: const InputDecoration(
              labelText: 'Nama Lengkap',
              prefixIcon: Icon(Icons.person),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Nama wajib diisi';
              }
              if (v.trim().length < 3) {
                return 'Minimal 3 karakter';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regEmailC,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Email wajib diisi';
              }
              if (!v.contains('@')) {
                return 'Format email tidak valid';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regPassC,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _regPassObscure = !_regPassObscure;
                  });
                },
                icon: Icon(
                  _regPassObscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: primaryColorUI,
                ),
              ),
            ),
            obscureText: _regPassObscure,
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Password wajib diisi';
              }
              if (v.length < 6) {
                return 'Minimal 6 karakter';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() => _registerAsAdmin = !_registerAsAdmin);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _registerAsAdmin,
                    activeColor: primaryColorUI,
                    onChanged: (v) {
                      setState(() => _registerAsAdmin = v ?? false);
                    },
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Ajukan sebagai admin',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Jika dicentang, akunmu akan diajukan sebagai admin dan menunggu persetujuan. Tidak langsung bisa login.',
            style: TextStyle(fontSize: 11.5, color: Colors.black45),
          ),
          const SizedBox(height: 10),
          if (_registerError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _registerError!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColorUI,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Daftar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
