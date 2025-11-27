// lib/pages/request_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'config/api_config.dart';
import 'widget/app_dialogs.dart';

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
        _incoming = (data['data'] ?? []) as List;
      }
      if (outgoingRes.statusCode == 200) {
        final data = jsonDecode(outgoingRes.body);
        _outgoing = (data['data'] ?? []) as List;
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

  String _resolveFileUrl(dynamic doc) {
    if (doc == null) return '';
    final explicit = (doc['file_url'] ?? '').toString();
    if (explicit.isNotEmpty) return explicit;
    final path = (doc['file_path'] ?? '').toString();
    if (path.isEmpty) return '';
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return '${ApiConfig.baseUrl}/$normalized';
  }

  void _openPdf(String url) {
    if (url.isEmpty) return;
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

  void _showRequestDetail(Map<String, dynamic> item, bool incoming) {
    final status = (item['status'] ?? 'pending').toString();
    final doc = item['Document'];
    final user = incoming ? item['requester'] : item['signer'];
    final url = _resolveFileUrl(doc);

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

                const SizedBox(height: 18),

                if (incoming && status.toLowerCase() == 'pending')
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
                            style: TextStyle(color: Colors.white),
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
        final doc = item['Document'];

        // ==== Nama & email tergantung Masuk / Keluar ====
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

        final isPending = status.toLowerCase() == 'pending';

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
