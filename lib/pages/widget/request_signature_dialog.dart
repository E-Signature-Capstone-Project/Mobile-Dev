import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../config/api_config.dart';

class RequestSignatureDialog extends StatefulWidget {
  final Map<String, dynamic> document;
  final Color primaryColor;

  const RequestSignatureDialog({
    super.key,
    required this.document,
    required this.primaryColor,
  });

  @override
  State<RequestSignatureDialog> createState() => _RequestSignatureDialogState();
}

class _RequestSignatureDialogState extends State<RequestSignatureDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  bool _submitting = false;

  String _resolveFileUrl(Map<String, dynamic> doc) {
    final explicit = (doc['file_url'] ?? '').toString();
    if (explicit.isNotEmpty) return explicit;

    final path = (doc['file_path'] ?? '').toString();
    if (path.isEmpty) return '';

    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return '${ApiConfig.baseUrl}/$normalized';
  }

  Future<void> _openPdf() async {
    final url = _resolveFileUrl(widget.document);
    if (url.isEmpty) return;

    await Navigator.push(
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
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: SfPdfViewer.network(url, enableTextSelection: false),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final email = _emailCtrl.text.trim();
      final note = _noteCtrl.text.trim();

      final res = await http.post(
        Uri.parse(ApiConfig.requestsUrl), // POST /requests
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'document_id': widget.document['document_id'],
          'recipientEmail': email,
          'note': note.isEmpty ? null : note,
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 201 && (data['success'] == true)) {
        if (!mounted) return;

        // ✅ Pop up berhasil kirim request
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: widget.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  "Request terkirim",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: Text(
              "Permintaan tanda tangan berhasil dikirim ke:\n$email",
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK", style: TextStyle(color: widget.primaryColor)),
              ),
            ],
          ),
        );

        // Tutup dialog utama & kirim hasil true ke caller
        if (mounted) Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (data['message'] ?? data['error'] ?? 'Gagal membuat request')
                  .toString(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _outlinedInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black54, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: widget.primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.document['title'] ?? 'Dokumen').toString();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.outgoing_mail, color: widget.primaryColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Request Tanda Tangan",
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
                const SizedBox(height: 12),

                // Info dokumen + tombol lihat
                Text(
                  "Dokumen",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey.shade800,
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
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _openPdf,
                        icon: Icon(
                          Icons.remove_red_eye_outlined,
                          color: widget.primaryColor,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Email tujuan
                Text(
                  "Email Tujuan",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _outlinedInputDecoration(
                    "contoh: user@gmail.com",
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return "Email tidak boleh kosong";
                    if (!value.contains('@')) return "Email tidak valid";
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Catatan
                Text(
                  "Catatan (opsional)",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  decoration: _outlinedInputDecoration(
                    "Contoh: Tolong tanda tangani sebelum hari Jumat.",
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Kirim Request",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
