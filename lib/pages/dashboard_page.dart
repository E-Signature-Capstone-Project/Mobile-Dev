import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:google_fonts/google_fonts.dart';

import 'widget/document_detail_dialog.dart';
import 'config/api_config.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // ====== CONFIG ======
  final String apiBase = ApiConfig.baseUrl;
  String get authUrl => ApiConfig.authUrl;
  String get documentsUrl => ApiConfig.documentsUrl;
  String get logsUrl => ApiConfig.logsUrl;
  String get baselineUrl => ApiConfig.baselineUrl;

  // ====== STATE ======
  String? userName;
  bool isLoading = true;
  List<Map<String, dynamic>> documents = [];
  List<dynamic> verifLogs = [];
  final Map<int, String> latestLogStatusByDoc = {}; // dari log valid/invalid

  List<Map<String, dynamic>> baselines = [];

  List<dynamic> outgoingRequests = [];
  final Map<int, String> requestStatusByDoc =
      {}; // document_id -> pending/approved/rejected

  // ====== THEME ======
  final Color primaryColorUI = const Color(0xFF003E9C);
  final Color bgWhite = const Color(0xFFF4FAFE);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _fetchProfile();
    await Future.wait([
      _fetchDocuments(),
      _fetchLogs(),
      _fetchBaselines(),
      _fetchOutgoingRequests(),
    ]);
    _recomputeEffectiveStatuses();
    if (mounted) setState(() {});
  }

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }

  // ====== API ======
  Future<void> _fetchProfile() async {
    try {
      final token = await _token() ?? "";
      final res = await http.get(
        Uri.parse("$authUrl/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        userName = data["name"] ?? "User";
        final prefs = await SharedPreferences.getInstance();
        // simpan utk filter log jika mau dipakai
        if (data["user_id"] != null) {
          prefs.setInt("user_id", data["user_id"]);
        }
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchDocuments() async {
    try {
      final token = await _token() ?? "";
      final res = await http.get(
        Uri.parse(documentsUrl),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        documents = data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint("Error fetch docs: $e");
    }
  }

  Future<void> _fetchLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      final res = await http.get(
        Uri.parse(logsUrl),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        if (decoded is List) {
          verifLogs = List<Map<String, dynamic>>.from(decoded);
        } else if (decoded is Map && decoded['data'] is List) {
          verifLogs = List<Map<String, dynamic>>.from(
            decoded['data'] as List<dynamic>,
          );
        } else {
          verifLogs = [];
        }
      }
    } catch (e) {
      debugPrint('Error fetch logs: $e');
    }
  }

  Future<void> _fetchOutgoingRequests() async {
    try {
      final token = await _token() ?? "";
      final res = await http.get(
        Uri.parse('${ApiConfig.requestsUrl}/outgoing'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        outgoingRequests = (data['data'] ?? []) as List;
        _recomputeRequestStatuses();
      }
    } catch (e) {
      debugPrint('Error fetch outgoing requests: $e');
    }
  }

  void _recomputeRequestStatuses() {
    requestStatusByDoc.clear();

    for (final r in outgoingRequests) {
      final Map<String, dynamic> item = r as Map<String, dynamic>;
      final Map<String, dynamic>? doc =
          item['Document'] as Map<String, dynamic>?;

      final int? docId = _parseDocId(doc);
      if (docId == null) continue;

      final DateTime createdAt = _parseDate(item['created_at']);

      if (requestStatusByDoc.containsKey(docId)) {
        final existing =
            outgoingRequests.firstWhere((e) {
                  final Map<String, dynamic>? d =
                      (e as Map<String, dynamic>)['Document'];
                  final int? id = _parseDocId(d);
                  return id == docId;
                }, orElse: () => item)
                as Map<String, dynamic>;

        final DateTime existingCreatedAt = _parseDate(existing['created_at']);

        if (existingCreatedAt.isAfter(createdAt)) continue;
      }

      requestStatusByDoc[docId] = (item['status'] ?? 'pending').toString();
    }
  }

  int? _parseDocId(Map<String, dynamic>? doc) {
    if (doc == null) return null;

    final raw = doc['document_id'];

    if (raw is int) return raw;

    return int.tryParse(raw?.toString() ?? '');
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final parsed = DateTime.tryParse(value.toString());
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ✅ NEW: ambil baseline user
  Future<void> _fetchBaselines() async {
    try {
      final token = await _token() ?? "";
      final res = await http.get(
        Uri.parse(baselineUrl),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = List<Map<String, dynamic>>.from(data['baselines'] ?? []);
        baselines = list;
      }
    } catch (e) {
      debugPrint('Error fetch baselines: $e');
    }
  }

  /// Ambil log paling baru per dokumen -> isi latestLogStatusByDoc
  void _recomputeEffectiveStatuses() {
    latestLogStatusByDoc.clear();
    // sort log by timestamp desc supaya yang pertama adalah yang terbaru
    final sorted = List<Map<String, dynamic>>.from(
      verifLogs.cast<Map<String, dynamic>>(),
    );
    sorted.sort((a, b) {
      final ta =
          DateTime.tryParse((a['timestamp'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb =
          DateTime.tryParse((b['timestamp'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });

    for (final log in sorted) {
      final int? docId = log['document_id'] is int
          ? log['document_id'] as int
          : int.tryParse((log['document_id'] ?? '').toString());
      if (docId == null) continue;
      if (!latestLogStatusByDoc.containsKey(docId)) {
        final result = (log['verification_result'] ?? '')
            .toString()
            .toLowerCase(); // valid/invalid
        if (result == 'valid' || result == 'invalid') {
          latestLogStatusByDoc[docId] = result;
        }
      }
    }
  }

  // ====== HELPERS ======
  // Warna card untuk status gabungan
  Color _cardColor(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
      case 'signed':
      case 'request_approved':
        return Colors.green.shade50;
      case 'invalid':
      case 'rejected':
      case 'request_rejected':
        return Colors.red.shade50;
      case 'request_pending':
        return Colors.blue.shade50;
      case 'draft':
      default:
        return Colors.orange.shade50;
    }
  }

  // Status efektif = jika ada log terbaru valid/invalid → pakai itu; selain itu pakai status dokumen
  String _effectiveStatusForDoc(Map<String, dynamic> doc) {
    final int? docId = doc['document_id'] is int
        ? doc['document_id'] as int
        : int.tryParse((doc['document_id'] ?? '').toString());

    // 1. cek log verifikasi valid/invalid
    if (docId != null && latestLogStatusByDoc.containsKey(docId)) {
      return latestLogStatusByDoc[docId]!; // valid / invalid
    }

    // 2. cek request outgoing
    if (docId != null && requestStatusByDoc.containsKey(docId)) {
      final reqStatus = requestStatusByDoc[docId]!.toLowerCase();
      switch (reqStatus) {
        case 'pending':
          return 'request_pending';
        case 'approved':
          return 'request_approved';
        case 'rejected':
          return 'request_rejected';
      }
    }

    // 3. status dokumen mentah
    final rawStatus = (doc['status'] ?? '').toString().toLowerCase();

    if (rawStatus.isEmpty || rawStatus == 'pending') {
      // dokumen baru / belum diapa-apakan -> Draft
      return 'draft';
    }

    return rawStatus; // signed, rejected, dll
  }

  // Resolve URL file
  String _resolveFileUrl(Map<String, dynamic> doc) {
    final explicit = (doc['file_url'] ?? '').toString();
    if (explicit.isNotEmpty) return explicit;
    final path = (doc['file_path'] ?? '').toString();
    if (path.isEmpty) return '';
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return '$apiBase/$normalized';
  }

  void _openPdfInApp(String url) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL dokumen kosong')));
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
          body: SfPdfViewer.network(
            url,
            enableTextSelection: false,
            canShowScrollStatus: true,
          ),
        ),
      ),
    );
  }

  // ====== UPLOAD ======
  Future<void> _pickAndUploadPdf() async {
    try {
      final token = await _token() ?? "";
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = File(result.files.single.path!);

      final req =
          http.MultipartRequest('POST', Uri.parse('$documentsUrl/upload'))
            ..headers['Authorization'] = 'Bearer $token'
            ..files.add(
              await http.MultipartFile.fromPath(
                'file',
                file.path,
                contentType: MediaType('application', 'pdf'),
              ),
            );

      final resp = await req.send();
      final body = await resp.stream.bytesToString();
      if (!mounted) return;

      if (resp.statusCode == 201) {
        final data = jsonDecode(body);
        final doc = Map<String, dynamic>.from(data["document"] ?? {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dokumen berhasil diupload'),
            backgroundColor: Colors.green,
          ),
        );
        // refresh dokumen & log agar status gabungan akurat
        await Future.wait([_fetchDocuments(), _fetchLogs()]);
        _recomputeEffectiveStatuses();
        if (!mounted) return;
        setState(() {});

        if (doc.isNotEmpty) {
          showDialog(
            context: context,
            builder: (_) => DocumentDetailDialog(
              document: doc,
              primaryColor: primaryColorUI,
              onChanged: () async {
                // dipanggil setelah berhasil TTD → segarkan lagi
                await Future.wait([_fetchDocuments(), _fetchLogs()]);
                _recomputeEffectiveStatuses();
                if (mounted) setState(() {});
              },
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal upload dokumen'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal upload PDF: $e')));
    }
  }

  void _showDetailDialog(Map<String, dynamic> doc) {
    final title = doc['title'] ?? 'Dokumen';
    final status = _effectiveStatusForDoc(doc);
    final createdAt = doc['created_at'] ?? DateTime.now().toString();
    final formattedDate = DateFormat(
      'dd MMM yyyy, HH:mm',
      'id_ID',
    ).format(DateTime.tryParse(createdAt) ?? DateTime.now());
    final pdfUrl = _resolveFileUrl(doc);

    Color statusColor(String s) {
      switch (s) {
        case 'signed':
        case 'valid':
          return Colors.green;
        case 'invalid':
        case 'rejected':
          return Colors.redAccent;
        default:
          return Colors.orange;
      }
    }

    String statusLabel(String s) {
      switch (s) {
        case 'signed':
          return 'Ditandatangani';
        case 'valid':
          return 'Valid';
        case 'invalid':
          return 'Tidak Valid';
        case 'approved':
          return 'Request Disetujui';
        case 'rejected':
          return 'Request Ditolak';
        default:
          return 'Belum Diproses'; // pending / default
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Tanggal
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.black45,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formattedDate,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Status chip
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor(status)),
                  ),
                  child: Text(
                    statusLabel(status),
                    style: TextStyle(
                      color: statusColor(status),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Tombol Lihat PDF
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openPdfInApp(pdfUrl),
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                  label: const Text(
                    "Lihat Dokumen",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColorUI,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====== UI ======
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
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _bootstrap,
                color: primaryColorUI,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 25,
                  ),
                  children: [
                    Text(
                      "Hi, ${userName ?? 'User'}!",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      formattedDate,
                      style: const TextStyle(color: Colors.black54),
                    ),

                    const SizedBox(height: 10),
                    if (baselines.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange.shade700,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Belum ada baseline tanda tangan",
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Tambahkan tanda tangan di halaman profil agar bisa menandatangani dokumen.",
                                    style: GoogleFonts.inter(
                                      fontSize: 13.2,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 15),

                    // Placeholder box
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          "Belum ada dokumen terpilih",
                          style: TextStyle(color: Colors.black54, fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    ElevatedButton.icon(
                      onPressed: _pickAndUploadPdf,
                      icon: const Icon(Icons.upload_file, color: Colors.white),
                      label: const Text(
                        "Upload Dokumen",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColorUI,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    const Text(
                      "Riwayat Dokumen",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    documents.isEmpty
                        ? const Center(
                            child: Text(
                              "Belum ada dokumen",
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 15,
                              ),
                            ),
                          )
                        : Column(
                            children: documents.map((doc) {
                              final status = _effectiveStatusForDoc(doc);

                              String statusLabelForList(String s) {
                                switch (s) {
                                  case 'draft':
                                    return 'Draft';
                                  case 'request_pending':
                                    return 'Menunggu Tanda Tangan';
                                  case 'request_approved':
                                    return 'Request Disetujui';
                                  case 'request_rejected':
                                    return 'Request Ditolak';
                                  case 'signed':
                                    return 'Ditandatangani';
                                  case 'valid':
                                    return 'Valid';
                                  case 'invalid':
                                    return 'Tidak Valid';
                                  case 'rejected':
                                    return 'Ditolak';
                                  default:
                                    return 'Belum Diproses';
                                }
                              }

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 0,
                                ),
                                decoration: BoxDecoration(
                                  color: _cardColor(status),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 2,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 0,
                                          ),
                                      leading: Icon(
                                        Icons.picture_as_pdf,
                                        color: primaryColorUI,
                                        size: 30,
                                      ),
                                      title: Text(
                                        doc['title'] ?? 'Dokumen',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "Status: ${statusLabelForList(status)}",
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 13,
                                        ),
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right,
                                        color: Colors.black45,
                                      ),
                                      onTap: () {
                                        final eff =
                                            status; // sudah _effectiveStatusForDoc(doc)

                                        if (eff == 'draft') {
                                          // hanya Draft yang boleh pilih Self TTD / Request
                                          showDialog(
                                            context: context,
                                            builder: (_) => DocumentDetailDialog(
                                              document: doc,
                                              primaryColor: primaryColorUI,
                                              onChanged: () async {
                                                await Future.wait([
                                                  _fetchDocuments(),
                                                  _fetchLogs(),
                                                  _fetchOutgoingRequests(),
                                                ]);
                                                _recomputeEffectiveStatuses();
                                                if (mounted) setState(() {});
                                              },
                                            ),
                                          );
                                        } else {
                                          // selain Draft, buka detail biasa
                                          _showDetailDialog(doc);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ],
                ),
              ),
      ),
    );
  }
}
