import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final String apiBase = 'http://10.0.2.2:4000';
  String get authUrl => '$apiBase/auth';
  String get baselineUrl => '$apiBase/signature_baseline';

  String? userName;
  bool isLoading = true;
  bool hasBaseline = true; // default true biar UI gak muncul dulu

  final Color primaryRed = const Color(0xFFDA1E28);
  final Color bgWhite = const Color(0xFFF4FAFE);

  @override
  void initState() {
    super.initState();
    _fetchProfileAndBaseline();
  }

  Future<void> _fetchProfileAndBaseline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      if (token.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      // ==== Ambil profil user ====
      final profileRes = await http.get(
        Uri.parse("$authUrl/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (profileRes.statusCode == 200) {
        final data = jsonDecode(profileRes.body);
        userName = data["name"] ?? "User";

        await prefs.setString('user_name', data["name"] ?? '');
        await prefs.setString('user_email', data["email"] ?? '');
      }

      // ==== Cek apakah user punya baseline ====
      final baselineRes = await http.get(
        Uri.parse(baselineUrl),
        headers: {"Authorization": "Bearer $token"},
      );

      if (baselineRes.statusCode == 200) {
        final result = jsonDecode(baselineRes.body);
        final count = (result["count"] as num?)?.toInt() ?? 0;
        hasBaseline = count > 0;
        // debugPrint("Jumlah baseline dari backend: $count");
      } else {
        hasBaseline = false;
        // debugPrint("Gagal ambil baseline (${baselineRes.statusCode})");
      }
    } catch (e) {
      debugPrint("Error: $e");
      hasBaseline = false;
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat(
      'EEEE, dd MMMM yyyy',
      'id_ID',
    ).format(DateTime.now());

    return Scaffold(
      backgroundColor: bgWhite,
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              )
            : RefreshIndicator(
                color: primaryRed,
                backgroundColor: bgWhite,
                onRefresh: _fetchProfileAndBaseline,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 25,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting
                      Padding(
                        padding: const EdgeInsets.only(bottom: 25),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Hi, ${userName ?? 'User'}!",
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Peringatan jika belum punya baseline
                            if (!hasBaseline)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orangeAccent,
                                    width: 1.2,
                                  ),
                                ),
                                child: const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.orange,
                                      size: 22,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Anda belum memiliki Signature Baseline.\nSegera ke profil dan tambahkan tanda tangan.",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // 🧾 Placeholder dokumen
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            "Belum ada dokumen terpilih",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 🔘 Tombol Pilih Dokumen
                      Center(
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Belum berfungsi"),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.folder_open,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Pilih Dokumen",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 3,
                              shadowColor: primaryRed.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),
                      const Center(
                        child: Text(
                          "Pilih dokumen yang ingin ditandatangani",
                          style: TextStyle(color: Colors.black45, fontSize: 13),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 🔹 Riwayat dokumen
                      const Text(
                        "Riwayat Dokumen Terakhir",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
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
                        child: ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: 3,
                          itemBuilder: (context, index) {
                            return ListTile(
                              leading: const Icon(
                                Icons.description_outlined,
                                color: Colors.redAccent,
                              ),
                              title: Text(
                                "Dokumen ${index + 1}",
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: const Text(
                                "Terakhir diperbarui: 29 Okt 2025",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.open_in_new,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Fitur belum tersedia"),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
