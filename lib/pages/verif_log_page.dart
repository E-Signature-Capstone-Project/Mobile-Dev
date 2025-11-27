import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        final decoded = jsonDecode(res.body);

        List allLogs = [];
        if (decoded is List) {
          // ✅ BE baru: langsung array
          allLogs = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          // 🔁 fallback kalau nanti bentuknya { data: [...] }
          allLogs = decoded['data'] as List;
        }

        if (userId != null) {
          logs = allLogs.where((log) => log['user_id'] == userId).toList();
        } else {
          logs = allLogs;
        }
      } else {
        logs = [];
      }
    } catch (e) {
      debugPrint('Error fetch logs: $e');
      logs = [];
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // --- Helper warna status (buat strip & chip) ---

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
        return Colors.green;
      case 'invalid':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  Color _statusChipBg(String status) {
    return _statusColor(status).withOpacity(0.12);
  }

  Future<void> _downloadFile(String url, String title, int index) async {
    try {
      setState(() => downloading.add(index));

      // 1. Minta izin penyimpanan
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin penyimpanan ditolak')),
          );
          return;
        }
      }

      // 2. Download file dari URL
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengunduh file dari server')),
        );
        return;
      }

      // 3. Pastikan folder Download tersedia
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }

      // 4. Simpan file
      final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9-_]'), '_');
      final filePath =
          '${downloadsDir.path}/${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(res.bodyBytes);

      if (!mounted) return;

      // 5. Pop-up berhasil
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
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

      // Auto-close popup setelah 3 detik
      Future.delayed(const Duration(seconds: 3), () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });

      debugPrint('✅ File tersimpan: $filePath');
    } catch (e) {
      debugPrint('❌ Error download: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan file: $e')));
    } finally {
      if (mounted) setState(() => downloading.remove(index));
    }
  }

  // --- Card verif log

  Widget _buildLogCard(Map<String, dynamic> log, int index) {
    final status = (log['verification_result'] ?? 'unknown').toString();
    final isValid = status.toLowerCase() == 'valid';
    final doc = log['Document'];
    final ts = log['timestamp'];
    final dt = ts != null ? DateTime.tryParse(ts) : null;

    final String title = doc?['title'] ?? 'Dokumen';
    final String dateText = dt == null
        ? 'Tanggal tidak diketahui'
        : DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Strip warna status di kiri
          Container(
            width: 6,
            decoration: BoxDecoration(
              color: _statusColor(status),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Baris atas: icon + judul + chip status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: primaryColorUI.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isValid
                              ? Icons.verified_rounded
                              : Icons.error_outline_rounded,
                          color: isValid
                              ? Colors.green
                              : Colors.redAccent.shade200,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusChipBg(status),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Baris bawah: info kecil + tombol unduh / status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // kalau mau, ini bisa dihapus juga
                      Text(
                        'Riwayat verifikasi',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isValid)
                        downloading.contains(index)
                            ? const SizedBox(
                                height: 26,
                                width: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: () {
                                  String? url;
                                  if (doc != null) {
                                    final filePath = (doc['file_path'] ?? '')
                                        .toString();
                                    if (filePath.isNotEmpty) {
                                      final normalized =
                                          filePath.startsWith('/')
                                          ? filePath.substring(1)
                                          : filePath;
                                      url = '$apiBase/$normalized';
                                    }
                                  }

                                  if (url != null && url.isNotEmpty) {
                                    _downloadFile(
                                      url,
                                      doc?['title'] ?? 'file',
                                      index,
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'URL dokumen tidak ditemukan',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColorUI,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(
                                  Icons.download_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Unduh',
                                  style: TextStyle(fontSize: 12),
                                ),
                              )
                      else
                        Text(
                          'Tidak Valid',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(status),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        Center(
                          child: Text(
                            'Belum ada log verifikasi',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final log = logs[i] as Map<String, dynamic>;
                        return _buildLogCard(log, i);
                      },
                    ),
            ),
    );
  }
}
