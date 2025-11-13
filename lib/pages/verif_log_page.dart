import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'config/api_config.dart';

class VerifLogPage extends StatefulWidget {
  const VerifLogPage({super.key});

  @override
  State<VerifLogPage> createState() => _VerifLogPageState();
}

class _VerifLogPageState extends State<VerifLogPage> {
  final String apiBase = ApiConfig.baseUrl;
  String get logsUrl => ApiConfig.logsUrl;

  final Color primaryColorUI = const Color(0xFF003E9C);
  final Color colorBG = const Color(0xFFF4FAFE);

  bool loading = true;
  List logs = [];
  Set<int> downloading = {};

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final userId = prefs.getInt("user_id");
      final res = await http.get(
        Uri.parse(logsUrl),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final allLogs = (data['data'] ?? []) as List;
        if (userId != null) {
          logs = allLogs.where((log) => log['user_id'] == userId).toList();
        } else {
          logs = allLogs;
        }
      }
    } catch (e) {
      debugPrint('Error fetch logs: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Color _cardColor(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
        return Colors.green.shade50;
      case 'invalid':
        return Colors.red.shade50;
      default:
        return Colors.orange.shade50;
    }
  }

  Future<void> _downloadFile(String url, String title, int index) async {
    try {
      setState(() => downloading.add(index));

      // ✅ 1. Minta izin penyimpanan
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin penyimpanan ditolak')),
          );
          return;
        }
      }

      // ✅ 2. Download file dari URL
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengunduh file dari server')),
        );
        return;
      }

      // ✅ 3. Pastikan folder Download tersedia
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }

      // ✅ 4. Simpan file
      final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9-_]'), '_');
      final filePath =
          '${downloadsDir.path}/${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(res.bodyBytes);

      if (!mounted) return;

      // ✅ 5. Tampilkan pop-up modern & minimalis
      showGeneralDialog(
        context: context,
        barrierDismissible: true, // bisa ditutup klik di luar
        barrierLabel: '',
        barrierColor: Colors.black.withOpacity(0.3),
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, anim1, anim2) {
          return Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: primaryColorUI,
                    size: 55,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Berhasil Disimpan!",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: primaryColorUI,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "File telah disimpan di folder Download.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColorUI,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      "Tutup",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Auto-close popup setelah 3 detik jika user tidak menekan apa pun
      Future.delayed(const Duration(seconds: 3), () {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });

      debugPrint('✅ File tersimpan: $filePath');
    } catch (e) {
      debugPrint('❌ Error download: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan file: $e')));
    } finally {
      setState(() => downloading.remove(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorBG,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchLogs,
              color: primaryColorUI,
              backgroundColor: colorBG,
              child: logs.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada log verifikasi',
                        style: TextStyle(color: Colors.black54, fontSize: 15),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final log = logs[i];
                        final status = (log['verification_result'] ?? 'unknown')
                            .toString();
                        final isValid = status == 'valid';
                        final doc = log['Document'];
                        final ts = log['timestamp'];
                        final dt = ts != null ? DateTime.tryParse(ts) : null;

                        return Card(
                          color: _cardColor(status),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: ListTile(
                            leading: Icon(
                              isValid ? Icons.verified : Icons.error_outline,
                              color: isValid ? Colors.green : Colors.redAccent,
                              size: 30,
                            ),
                            title: Text(
                              doc?['title'] ?? 'Dokumen',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              dt == null
                                  ? 'Tanggal tidak diketahui'
                                  : DateFormat(
                                      'dd MMM yyyy, HH:mm',
                                      'id_ID',
                                    ).format(dt),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),

                            // 🔽 Tambahkan icon download hanya untuk valid
                            trailing: isValid
                                ? (downloading.contains(i)
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.green,
                                          ),
                                        )
                                      : IconButton(
                                          icon: const Icon(
                                            Icons.download_rounded,
                                            color: Colors.green,
                                            size: 26,
                                          ),
                                          tooltip: 'Download dokumen',
                                          onPressed: () {
                                            String? url;
                                            if (doc != null) {
                                              final filePath =
                                                  (doc['file_path'] ?? '')
                                                      .toString();
                                              if (filePath.isNotEmpty) {
                                                final normalized =
                                                    filePath.startsWith('/')
                                                    ? filePath.substring(1)
                                                    : filePath;
                                                url =
                                                    '$apiBase/$normalized'; // bangun URL lengkap ke backend
                                              }
                                            }

                                            if (url != null && url.isNotEmpty) {
                                              _downloadFile(
                                                url,
                                                doc?['title'] ?? 'file',
                                                i,
                                              );
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'URL dokumen tidak ditemukan',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ))
                                : Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
