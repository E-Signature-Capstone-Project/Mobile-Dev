// lib/pages/request_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'config/api_config.dart';
import 'widget/app_dialogs.dart';
import 'widget/select_request_position_page.dart';

class RequestPage extends StatefulWidget {
  const RequestPage({super.key});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  final Color primaryColorUI = const Color(0xFF003E9C);

  bool _loading = true;
  List<dynamic> _incoming = [];
  List<dynamic> _outgoing = [];

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  // Ganti fungsi ini di lib/pages/request_page.dart
  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    try {
      final token = await _token();

      final incomingRes = await http.get(
        Uri.parse('${ApiConfig.requestsUrl}/incoming'),
        headers: {"Authorization": "Bearer $token"},
      );
      final outgoingRes = await http.get(
        Uri.parse('${ApiConfig.requestsUrl}/outgoing'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (incomingRes.statusCode == 200) {
        final data = jsonDecode(incomingRes.body);
        final rawIncoming = (data['data'] ?? []) as List;

        // Filter Incoming (Safety: Jangan tampilkan jika requester == signer)
        _incoming = rawIncoming.where((item) {
          final reqId = item['requester_id'].toString();
          final sigId = item['signer_id'].toString();
          return reqId != sigId;
        }).toList();
      }

      if (outgoingRes.statusCode == 200) {
        final data = jsonDecode(outgoingRes.body);
        final rawOutgoing = (data['data'] ?? []) as List;

        // ✅ FILTER UTAMA: Hapus Self Sign dari Tab Keluar
        _outgoing = rawOutgoing.where((item) {
          final reqId = item['requester_id'].toString();
          final sigId = item['signer_id'].toString();
          final note = (item['note'] ?? '').toString().toLowerCase();

          // 1. Cek ID: Jika Requester == Signer, berarti Self TTD -> HIDE
          if (reqId == sigId) return false;

          // 2. Cek Note: Jika note dari backend "self signed...", -> HIDE
          if (note.contains("self signed")) return false;

          return true;
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetch requests: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return Colors.green.shade100;
      case 'rejected':
        return Colors.red.shade100;
      default:
        return Colors.orange.shade100;
    }
  }

  Color _statusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return Colors.green.shade800;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.orange.shade800;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Disetujui';
      case 'completed':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Menunggu';
    }
  }

  String _formatDate(dynamic createdAt) {
    final dt = DateTime.tryParse(createdAt?.toString() ?? '');
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
  }

  /// Ambil URL dari Document
  String _resolveFileUrl(dynamic doc) {
    if (doc == null) return '';

    final path = (doc['file_path'] ?? '').toString();
    if (path.isNotEmpty) {
      final normalized = path.startsWith('/') ? path.substring(1) : path;
      return '${ApiConfig.baseUrl}/$normalized';
    }

    final explicit = (doc['file_url'] ?? '').toString();
    if (explicit.isNotEmpty) return explicit;

    return '';
  }

  /// Untuk item request: ambil URL dari Document
  String _resolveRequestFileUrl(Map<String, dynamic> item) {
    final doc = item['Document'];
    return _resolveFileUrl(doc);
  }

  void _openPdf(String url) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL dokumen tidak ditemukan')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            iconTheme: const IconThemeData(color: Colors.black),
            title: const Text(
              "Lihat Dokumen",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: SfPdfViewer.network(url, enableTextSelection: false),
        ),
      ),
    );
  }

  /// Download file ke folder Download
  Future<void> _downloadFile(String url, String title) async {
    try {
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

      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengunduh file dari server')),
        );
        return;
      }

      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }

      final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9-_]'), '_');
      final filePath =
          '${downloadsDir.path}/${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(res.bodyBytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File tersimpan di folder Download')),
      );
    } catch (e) {
      debugPrint('❌ Error download: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan file: $e')));
    }
  }

  Future<void> _handleApprove(int requestId) async {
    final ok = await AppDialogs.showConfirm(
      context,
      title: "Setujui Permintaan",
      message:
          "Apakah Anda yakin ingin menyetujui permintaan tanda tangan ini?",
      primaryColor: primaryColorUI,
      confirmText: "Setujui",
    );
    if (ok != true) return;

    try {
      final token = await _token();
      final res = await http.post(
        Uri.parse('${ApiConfig.requestsUrl}/$requestId/approve'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        await AppDialogs.showMessage(
          context,
          title: "Berhasil",
          message: "Permintaan tanda tangan disetujui.",
          primaryColor: primaryColorUI,
          success: true,
        );
        _fetchAll();
      } else {
        final data = jsonDecode(res.body);
        await AppDialogs.showMessage(
          context,
          title: "Gagal",
          message: (data['message'] ?? data['error'] ?? 'Gagal menyetujui')
              .toString(),
          primaryColor: primaryColorUI,
          success: false,
        );
      }
    } catch (e) {
      await AppDialogs.showMessage(
        context,
        title: "Error",
        message: "Terjadi kesalahan: $e",
        primaryColor: primaryColorUI,
        success: false,
      );
    }
  }

  Future<void> _handleReject(int requestId) async {
    final ok = await AppDialogs.showConfirm(
      context,
      title: "Tolak Permintaan",
      message: "Apakah Anda yakin ingin menolak permintaan tanda tangan ini?",
      primaryColor: primaryColorUI,
      confirmText: "Tolak",
    );
    if (ok != true) return;

    try {
      final token = await _token();
      final res = await http.post(
        Uri.parse('${ApiConfig.requestsUrl}/$requestId/reject'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        await AppDialogs.showMessage(
          context,
          title: "Berhasil",
          message: "Permintaan tanda tangan ditolak.",
          primaryColor: primaryColorUI,
          success: true,
        );
        _fetchAll();
      } else {
        final data = jsonDecode(res.body);
        await AppDialogs.showMessage(
          context,
          title: "Gagal",
          message: (data['message'] ?? data['error'] ?? 'Gagal menolak')
              .toString(),
          primaryColor: primaryColorUI,
          success: false,
        );
      }
    } catch (e) {
      await AppDialogs.showMessage(
        context,
        title: "Error",
        message: "Terjadi kesalahan: $e",
        primaryColor: primaryColorUI,
        success: false,
      );
    }
  }

  /// Peminta men-trigger signDocumentExternally di BE
  Future<void> _applyExternalSignature(Map<String, dynamic> item) async {
    final status = (item['status'] ?? 'pending').toString().toLowerCase();
    if (status != 'approved') {
      await AppDialogs.showMessage(
        context,
        title: "Tidak Bisa",
        message: "Tanda tangan hanya bisa dipasang ketika status 'Disetujui'.",
        primaryColor: primaryColorUI,
        success: false,
      );
      return;
    }

    final doc = item['Document'] as Map<String, dynamic>?;
    final requestId = item['request_id'];
    final documentId = doc?['document_id'];
    final pdfUrl = _resolveRequestFileUrl(item);

    if (requestId == null || documentId == null) {
      await AppDialogs.showMessage(
        context,
        title: "Data tidak lengkap",
        message: "ID permintaan atau dokumen tidak ditemukan.",
        primaryColor: primaryColorUI,
        success: false,
      );
      return;
    }

    if (pdfUrl.isEmpty) {
      await AppDialogs.showMessage(
        context,
        title: "Dokumen tidak ditemukan",
        message: "URL dokumen tidak tersedia untuk permintaan ini.",
        primaryColor: primaryColorUI,
        success: false,
      );
      return;
    }

    try {
      final token = await _token();

      // 1️⃣ GET /requests/:id/signature → ambil baseline_id & sign_image
      final sigRes = await http.get(
        Uri.parse('${ApiConfig.requestsUrl}/$requestId/signature'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (sigRes.statusCode != 200) {
        final body = jsonDecode(sigRes.body);
        await AppDialogs.showMessage(
          context,
          title: "Gagal",
          message:
              (body['message'] ?? body['error'] ?? 'Gagal mengambil signature')
                  .toString(),
          primaryColor: primaryColorUI,
          success: false,
        );
        return;
      }

      final sigJson = jsonDecode(sigRes.body);
      if (sigJson['success'] != true) {
        await AppDialogs.showMessage(
          context,
          title: "Gagal",
          message: (sigJson['message'] ?? 'Gagal mengambil signature')
              .toString(),
          primaryColor: primaryColorUI,
          success: false,
        );
        return;
      }

      final data = sigJson['data'] ?? {};
      final baselineId = data['baseline_id'];
      final signImagePath = (data['sign_image'] ?? '').toString();

      if (baselineId == null) {
        await AppDialogs.showMessage(
          context,
          title: "Gagal",
          message: "baseline_id kosong dari server.",
          primaryColor: primaryColorUI,
          success: false,
        );
        return;
      }

      String? signImageUrl;
      if (signImagePath.isNotEmpty) {
        if (signImagePath.startsWith('http')) {
          signImageUrl = signImagePath;
        } else {
          final normalized = signImagePath.startsWith('/')
              ? signImagePath.substring(1)
              : signImagePath;
          signImageUrl = '${ApiConfig.baseUrl}/$normalized';
        }
      }

      // 2️⃣ Buka halaman pilih posisi TTD + preview gambar tanda tangan
      final position = await Navigator.push<SignaturePositionResult>(
        context,
        MaterialPageRoute(
          builder: (_) => SelectRequestPositionPage(
            pdfUrl: pdfUrl,
            primaryColor: primaryColorUI,
          ),
        ),
      );

      if (position == null) {
        // user batal pilih posisi
        return;
      }

      final okConfirm = await AppDialogs.showConfirm(
        context,
        title: "Pasang Tanda Tangan",
        message:
            "Signer sudah menyetujui.\nPasang tanda tangan ke dokumen pada posisi yang dipilih?",
        primaryColor: primaryColorUI,
        confirmText: "Pasang",
      );
      if (okConfirm != true) return;

      // 3️⃣ POST /documents/:id/sign/external pakai baseline + posisi
      final uri = Uri.parse(
        '${ApiConfig.documentsUrl}/$documentId/sign/external',
      );
      final req = http.MultipartRequest('POST', uri);
      req.headers['Authorization'] = 'Bearer $token';

      req.fields['baseline_id'] = baselineId.toString();
      req.fields['pageNumber'] = position.pageNumber.toString();
      req.fields['x'] = position.x.toString();
      req.fields['y'] = position.y.toString();
      req.fields['width'] = position.width.toString();
      req.fields['height'] = position.height.toString();

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        await AppDialogs.showMessage(
          context,
          title: "Berhasil",
          message:
              "Tanda tangan berhasil ditempel pada dokumen.\nStatus request akan menjadi 'Selesai'.",
          primaryColor: primaryColorUI,
          success: true,
        );
        await _fetchAll();
      } else {
        final body = jsonDecode(res.body);
        await AppDialogs.showMessage(
          context,
          title: "Gagal",
          message: (body['message'] ?? body['error'] ?? 'Gagal menandatangani')
              .toString(),
          primaryColor: primaryColorUI,
          success: false,
        );
      }
    } catch (e) {
      await AppDialogs.showMessage(
        context,
        title: "Error",
        message: "Terjadi kesalahan saat memasang TTD: $e",
        primaryColor: primaryColorUI,
        success: false,
      );
    }
  }

  void _showRequestDetail(Map<String, dynamic> item, bool incoming) {
    final status = (item['status'] ?? 'pending').toString();
    final statusLower = status.toLowerCase();
    final doc = item['Document'];
    final user = incoming ? item['requester'] : item['signer'];

    // URL dokumen (kalau sudah signed, akan pakai file_path terbaru)
    final url = _resolveRequestFileUrl(item);

    // Hanya requester (outgoing) + status completed yang boleh download
    final bool canDownload = !incoming && statusLower == 'completed';

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(Icons.description_outlined, color: primaryColorUI),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Detail Permintaan TTD",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Dari / Kepada
                  Text(
                    incoming ? "Dari" : "Kepada",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (user?['name'] ?? '-').toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (user?['email'] ?? '-').toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Dokumen
                  const Text(
                    "Dokumen",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (doc?['title'] ?? '-').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _openPdf(url);
                          },
                          icon: Icon(
                            Icons.remove_red_eye_outlined,
                            color: primaryColorUI,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Catatan
                  const Text(
                    "Catatan",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      (item['note'] ?? 'Tidak ada catatan').toString(),
                      style: const TextStyle(fontSize: 13.5, height: 1.4),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Status + tanggal
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusBgColor(status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: _statusTextColor(status),
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(item['created_at']),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Tombol PASANG TTD (hanya peminta + approved)
                  if (!incoming && statusLower == 'approved') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _applyExternalSignature(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColorUI,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.draw_rounded,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Pasang Tanda Tangan ke Dokumen",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Tombol download: HANYA requester (outgoing) & status completed
                  if (canDownload) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final downloadUrl = _resolveRequestFileUrl(item);
                          if (downloadUrl.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('URL dokumen tidak ditemukan'),
                              ),
                            );
                            return;
                          }
                          final title = (doc?['title'] ?? 'dokumen').toString();
                          _downloadFile(downloadUrl, title);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColorUI,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Unduh Dokumen Bertanda Tangan",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Action approve/reject hanya untuk incoming + pending
                  if (incoming && statusLower == 'pending')
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _handleReject(item['request_id'] as int),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Tolak",
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _handleApprove(item['request_id'] as int),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColorUI,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Terima",
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
          ),
        );
      },
    );
  }

  Widget _buildList(List<dynamic> data, bool incoming) {
    if (data.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(
            child: Text(
              "Belum ada permintaan",
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12),
      itemCount: data.length,
      itemBuilder: (_, index) {
        final item = data[index] as Map<String, dynamic>;
        final status = (item['status'] ?? 'pending').toString();
        final statusLower = status.toLowerCase();
        final doc = item['Document'];

        String line1;
        String line2;

        if (incoming) {
          final user = item['requester'] as Map<String, dynamic>?;
          line1 = "Dari: ${user?['name'] ?? '-'}";
          line2 = (user?['email'] ?? '-').toString();
        } else {
          final signer = item['signer'] as Map<String, dynamic>?;
          final String email =
              (signer?['email'] ?? item['recipient_email'] ?? '-').toString();
          final String name = (signer?['name'] ?? '').toString();

          line1 = name.isNotEmpty ? "Kepada: $name" : "Kepada: $email";
          line2 = email;
        }

        final isPending = statusLower == 'pending';

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // baris atas: icon + judul + more
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: primaryColorUI.withOpacity(0.06),
                      child: Icon(
                        Icons.assignment_outlined,
                        color: primaryColorUI,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (doc?['title'] ?? '-').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            line1,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            line2,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showRequestDetail(item, incoming),
                      icon: const Icon(
                        Icons.more_horiz,
                        size: 22,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Tanggal kiri, status kanan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(item['created_at']),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.black45,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusBgColor(status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _statusTextColor(status),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Tombol lihat + Pasang TTD / Unduh (untuk requester)
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _openPdf(_resolveRequestFileUrl(item)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      icon: Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 18,
                        color: primaryColorUI,
                      ),
                      label: Text(
                        "Lihat dokumen",
                        style: TextStyle(
                          fontSize: 12.5,
                          color: primaryColorUI,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!incoming && statusLower == 'approved')
                      TextButton.icon(
                        onPressed: () => _applyExternalSignature(item),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: primaryColorUI,
                        ),
                        icon: const Icon(Icons.draw_rounded, size: 18),
                        label: const Text(
                          "Pasang TTD",
                          style: TextStyle(fontSize: 12.5),
                        ),
                      )
                    else if (!incoming && statusLower == 'completed')
                      TextButton.icon(
                        onPressed: () {
                          final url = _resolveRequestFileUrl(item);
                          if (url.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('URL dokumen tidak ditemukan'),
                              ),
                            );
                            return;
                          }
                          final title = (doc?['title'] ?? 'dokumen').toString();
                          _downloadFile(url, title);
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: primaryColorUI,
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text(
                          "Unduh",
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                  ],
                ),

                // Action approve/reject untuk incoming + pending
                if (incoming && isPending) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _handleReject(item['request_id'] as int),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text(
                            "Tolak",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              _handleApprove(item['request_id'] as int),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColorUI,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text(
                            "Terima",
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
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4FAFE),
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: TabBar(
            labelColor: primaryColorUI,
            unselectedLabelColor: Colors.black54,
            indicatorColor: primaryColorUI,
            tabs: const [
              Tab(text: "Masuk"),
              Tab(text: "Keluar"),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: _fetchAll,
                    color: primaryColorUI,
                    child: _buildList(_incoming, true),
                  ),
                  RefreshIndicator(
                    onRefresh: _fetchAll,
                    color: primaryColorUI,
                    child: _buildList(_outgoing, false),
                  ),
                ],
              ),
      ),
    );
  }
}
