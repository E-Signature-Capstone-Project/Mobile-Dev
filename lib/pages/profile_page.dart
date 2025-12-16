import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';

import 'widget/add_baseline_dialog.dart';
import 'config/api_config.dart';
import 'widget/logout_helper.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final String apiBase = ApiConfig.baseUrl;
  String get authUrl => ApiConfig.authUrl;
  String get baselineUrl => ApiConfig.baselineUrl;

  bool isLoading = true;
  String? email;
  String? name;
  String? role;

  // list baseline dari backend
  List<Map<String, dynamic>> baselines = [];

  // warna
  final Color primaryColorUI = const Color(0xFF003E9C);
  final Color colorBG = const Color(0xFFF4FAFE);

  bool _updatingName = false;
  final TextEditingController _nameEditController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfileAndBaselines();
  }

  @override
  void dispose() {
    _nameEditController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileAndBaselines() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null || token.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      // profile
      final resMe = await http.get(
        Uri.parse("$authUrl/profile"), // ⬅️ FIX: pakai /profile
        headers: {"Authorization": "Bearer $token"},
      );

      if (resMe.statusCode == 200) {
        final data = jsonDecode(resMe.body);
        final fetchedEmail = (data["email"] ?? '').toString();
        final fetchedName = (data["name"] ?? '').toString();
        final fetchedRole = (data["role"] ?? 'user').toString();

        setState(() {
          email = fetchedEmail;
          name = fetchedName.isEmpty ? '-' : fetchedName;
          role = fetchedRole;
        });

        _nameEditController.text = fetchedName;

        await prefs.setString('user_email', fetchedEmail);
        await prefs.setString('user_name', fetchedName);
        await prefs.setString('current_email', fetchedEmail);
        await prefs.setString('role', fetchedRole);
      }

      // baselines
      final resBase = await http.get(
        Uri.parse(baselineUrl),
        headers: {"Authorization": "Bearer $token"},
      );

      if (resBase.statusCode == 200) {
        final data = jsonDecode(resBase.body);
        final list = List<Map<String, dynamic>>.from(
          (data['baselines'] ?? []) as List,
        );
        setState(() {
          baselines = list;
        });
      }

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint("Error fetching profile/baselines: $e");
      setState(() => isLoading = false);
    }
  }

  // ====== UPDATE NAME ke backend ======
  Future<void> _updateName(String newName) async {
    newName = newName.trim();
    if (newName.length < 3) {
      _showErrorDialog("Nama harus minimal 3 karakter.");
      return;
    }

    try {
      setState(() {
        _updatingName = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        _showErrorDialog("Token tidak ditemukan. Silakan login ulang.");
        return;
      }

      final res = await http.put(
        Uri.parse('$authUrl/name'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': newName}),
      );

      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        await prefs.setString('user_name', newName);
        setState(() {
          name = newName;
        });
        Navigator.of(context).pop(); // tutup sheet/dialog
        _showSuccessDialog('Nama berhasil diperbarui.');
      } else {
        final msg =
            body['error']?.toString() ??
            body['message']?.toString() ??
            'Gagal memperbarui nama.';
        _showErrorDialog(msg);
      }
    } catch (e) {
      _showErrorDialog('Gagal terhubung ke server: $e');
    } finally {
      if (mounted) {
        setState(() {
          _updatingName = false;
        });
      }
    }
  }

  // ====== BOTTOM SHEET: Edit Nama ======
  void _showEditNameSheet() {
    _nameEditController.text = name ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: bottomInset + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Ubah Nama",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Perbarui nama yang akan ditampilkan di aplikasi.",
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameEditController,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap',
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.black.withOpacity(0.15),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _updatingName
                          ? null
                          : () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Batal",
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _updatingName
                          ? null
                          : () => _updateName(_nameEditController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColorUI,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _updatingName
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Simpan",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // pop up logout
  void _showLogoutDialog() {
    final rootContext = context;

    showDialog(
      context: rootContext,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.1),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout_rounded, color: primaryColorUI, size: 55),
                const SizedBox(height: 20),
                const Text(
                  "Logout Akun",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Apakah kamu yakin ingin keluar dari akun ini?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Colors.black.withOpacity(0.2),
                          ),
                        ),
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: const Text(
                          "Batal",
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColorUI,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          // tutup dialog pakai context dialog
                          Navigator.pop(dialogCtx);
                          // logout & pindah ke login pakai context root (halaman)
                          await performLogout(rootContext);
                        },
                        child: const Text(
                          "Logout",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ====== UPLOAD baseline ke backend ======
  Future<void> _uploadBaseline(File file, {int? replaceBaselineId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        _showErrorDialog("Token tidak ditemukan. Silakan login ulang.");
        return;
      }

      final bool isReplace = replaceBaselineId != null;

      final uri = isReplace
          ? Uri.parse('$baselineUrl/$replaceBaselineId')
          : Uri.parse('$baselineUrl/add');

      final method = isReplace ? 'PUT' : 'POST';
      final req = http.MultipartRequest(method, uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
          await http.MultipartFile.fromPath(
            'image',
            file.path,
            contentType: MediaType('image', 'png'),
          ),
        );

      final resp = await req.send();
      final body = await resp.stream.bytesToString();

      debugPrint('🔹 baseline upload status: ${resp.statusCode}');
      debugPrint('🔹 body: $body');

      Map<String, dynamic>? json;
      try {
        json = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {}

      if (!isReplace && resp.statusCode == 201) {
        // tambah baseline baru
        _showSuccessDialog('Baseline berhasil ditambahkan!');
        await _fetchProfileAndBaselines();
      } else if (isReplace && resp.statusCode == 200) {
        // update baseline (kalau nanti fitur replace dipakai)
        _showSuccessDialog('Baseline berhasil diperbarui!');
        await _fetchProfileAndBaselines();
      } else {
        final errorMsg =
            json?['error']?.toString() ??
            json?['message']?.toString() ??
            'Gagal menambahkan baseline.';
        _showErrorDialog(errorMsg);
      }
    } catch (e) {
      debugPrint('❌ Gagal upload baseline: $e');
      _toast('Gagal mengunggah baseline: $e');
    }
  }

  // ====== POPUP Success ======
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, color: primaryColorUI, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Berhasil",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColorUI,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Tutup",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====== POPUP Error ======
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Gagal",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColorUI,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Tutup",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====== POPUP Tambah Baseline (pakai dialog custom) ======
  void _showAddSignatureDialog() {
    if (baselines.length >= 5) {
      _toast('Maksimal 5 signature baseline.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddBaselineDialog(
        primaryColor: primaryColorUI,
        onSubmit: (file) async {
          Navigator.pop(context);
          await _uploadBaseline(file);
        },
      ),
    );
  }

  // ====== SHEET actions item (untuk replace, nanti bisa diisi) ======
  void _showItemActions(int baselineId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.black87),
                title: const Text(
                  'Ganti (Replace)',
                  style: TextStyle(color: Colors.black87),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fitur Belum Bisa digunakan'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ====== Helpers ======
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _roleLabel(String? r) {
    switch ((r ?? '').toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'admin_request':
        return 'Calon Admin';
      default:
        return 'User';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorBG,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Profile",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColorUI))
          : RefreshIndicator(
              color: primaryColorUI,
              backgroundColor: Colors.white,
              onRefresh: _fetchProfileAndBaselines,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 25,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // avatar
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFFF2F2F2),
                        child: Icon(
                          Icons.person,
                          size: 70,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    Text(
                      name ?? "-",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email ?? "-",
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Role chip
                    if (role != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColorUI.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: primaryColorUI.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user,
                              size: 16,
                              color: primaryColorUI,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _roleLabel(role),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: primaryColorUI,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Tombol edit nama
                    Align(
                      alignment: Alignment.center,
                      child: OutlinedButton.icon(
                        onPressed: _showEditNameSheet,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ),
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: primaryColorUI,
                        ),
                        label: const Text(
                          "Ubah Nama",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Logout button
                    ElevatedButton.icon(
                      onPressed: _showLogoutDialog,
                      icon: const Icon(Icons.logout, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColorUI,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      label: const Text(
                        "Log out",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Signature Baseline",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildBaselineGrid(),

                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.center,
                      child: Text(
                        "Maksimal 5 signature. Kamu bisa menambah dan mengganti.",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBaselineGrid() {
    final items = List<Map<String, dynamic>>.from(baselines);
    final canAddMore = items.length < 5;
    if (canAddMore) items.add({'_add': true});

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final isAdd = item['_add'] == true;

        if (isAdd) {
          return InkWell(
            onTap: _showAddSignatureDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 36,
                      color: primaryColorUI,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Tambah Signature",
                      style: TextStyle(color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final baselineId = (item['baseline_id'] as num?)?.toInt();
        final relPath = item['sign_image'] as String?;
        final url = relPath != null ? '$apiBase/$relPath' : null;

        return InkWell(
          onTap: () {
            if (baselineId != null) _showItemActions(baselineId);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                if (url != null)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) {
                          return const Center(
                            child: Text(
                              "Gambar tidak tersedia",
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                else
                  const Center(
                    child: Text(
                      "Tidak ada gambar",
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ),

                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      _roundIconButton(
                        icon: Icons.swap_horiz,
                        onTap: () {
                          if (baselineId != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fitur Belum Bisa digunakan'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.redAccent.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: isDestructive ? Colors.redAccent : Colors.black26,
          ),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.redAccent : Colors.black87,
          size: 18,
        ),
      ),
    );
  }
}
