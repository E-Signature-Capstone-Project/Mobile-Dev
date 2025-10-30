import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login_register.dart';
import 'add_baseline_sign_page.dart';
import 'package:http_parser/http_parser.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final String apiBase = 'http://10.0.2.2:4000';
  String get authBase => '$apiBase/auth';
  String get baselineBase => '$apiBase/signature_baseline';

  bool isLoading = true;
  String? email;
  String? name;

  // list baseline dari backend
  List<Map<String, dynamic>> baselines = [];

  // warna
  final Color primaryRed = const Color(0xFFDA1E28);
  final Color ColorBG = const Color(0xFFF4FAFE);

  @override
  void initState() {
    super.initState();
    _fetchProfileAndBaselines();
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
        Uri.parse("$authBase/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (resMe.statusCode == 200) {
        final data = jsonDecode(resMe.body);
        setState(() {
          email = data["email"];
          name = data["name"];
        });
        await prefs.setString('user_email', data["email"] ?? '');
        await prefs.setString('user_name', data["name"] ?? '');
        await prefs.setString('current_email', data["email"] ?? '');
      }

      // baselines
      final resBase = await http.get(
        Uri.parse(baselineBase),
        headers: {"Authorization": "Bearer $token"},
      );

      if (resBase.statusCode == 200) {
        final data = jsonDecode(resBase.body);
        final list = List<Map<String, dynamic>>.from(data['baselines'] as List);
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

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('isLoggedIn');
    await prefs.remove('current_email');

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  // pop up logout
  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
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
                Icon(Icons.logout_rounded, color: primaryRed, size: 55),
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
                        onPressed: () => Navigator.pop(context),
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
                          backgroundColor: primaryRed,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _logout();
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

  // ====== TAMBAH dari galeri ======
  Future<void> _pickAndUploadFromGallery({int? replaceBaselineId}) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      await _uploadBaseline(
        File(file.path),
        replaceBaselineId: replaceBaselineId,
      );
    } catch (e) {
      _toast('Gagal membuka galeri: $e');
    }
  }

  // ====== TAMBAH via gambar (navigasi ke AddBaselineSignPage) ======
  Future<void> _goDrawForAdd({int? replaceBaselineId}) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBaselineSignPage()),
    );
    await _fetchProfileAndBaselines();
  }

  // ====== UPLOAD ke backend ======
  Future<void> _uploadBaseline(File file, {int? replaceBaselineId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) return;

      // final req = http.MultipartRequest('POST', Uri.parse('$baselineBase/add'));
      final endpoint = replaceBaselineId != null
          ? '$baselineBase/update/$replaceBaselineId'
          : '$baselineBase/add';

      final req = http.MultipartRequest('POST', Uri.parse(endpoint));

      req.headers['Authorization'] = 'Bearer $token';
      req.files.add(
        await http.MultipartFile.fromPath(
          'image',
          file.path,
          contentType: MediaType('image', 'png'),
        ),
      );

      final resp = await req.send();
      final body = await resp.stream.bytesToString();
      final json = jsonDecode(body);

      if (resp.statusCode == 201) {
        _toast('Baseline berhasil ditambahkan');
        await _fetchProfileAndBaselines();
      } else {
        _toast(json['error'] ?? 'Gagal menambahkan baseline');
      }
    } catch (e) {
      _toast('Gagal mengunggah baseline: $e');
    }
  }

  // ====== POPUP Tambah (Gambar / Upload) ======
  void _showAddSignatureDialog() {
    if (baselines.length >= 5) {
      _toast('Maksimal 5 signature baseline.');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Tambah Signature",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _goDrawForAdd();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  minimumSize: const Size(double.infinity, 45),
                ),
                icon: const Icon(Icons.draw, color: Colors.white),
                label: const Text(
                  "Gambar Signature",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _pickAndUploadFromGallery();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  minimumSize: const Size(double.infinity, 45),
                ),
                icon: const Icon(Icons.upload, color: Colors.white),
                label: const Text(
                  "Upload dari Galeri",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====== SHEET actions item Replace ======
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
                  _showReplaceDialog(baselineId);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ====== DIALOG Replace pilih sumber ======
  void _showReplaceDialog(int baselineId) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Ganti Signature",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _goDrawForAdd(replaceBaselineId: baselineId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  minimumSize: const Size(double.infinity, 45),
                ),
                icon: const Icon(Icons.draw, color: Colors.white),
                label: const Text(
                  "Gambar Signature Baru",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _pickAndUploadFromGallery(replaceBaselineId: baselineId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  minimumSize: const Size(double.infinity, 45),
                ),
                icon: const Icon(Icons.upload, color: Colors.white),
                label: const Text(
                  "Upload dari Galeri",
                  style: TextStyle(color: Colors.white),
                ),
              ),
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

  Future<bool?> _confirm({
    required String title,
    required String message,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: Colors.black)),
        content: Text(message, style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryRed),
            child: const Text('Ya', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorBG,
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
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            )
          : RefreshIndicator(
              color: Colors.redAccent,
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
                    Text(
                      email ?? "-",
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Logout button
                    ElevatedButton.icon(
                      onPressed: _showLogoutDialog,
                      icon: const Icon(Icons.logout, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
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
                    Icon(Icons.add_circle_outline, size: 36, color: primaryRed),
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
                          if (baselineId != null)
                            _showReplaceDialog(baselineId);
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
