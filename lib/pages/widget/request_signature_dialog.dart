import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../main_menu.dart';

class RequestSignatureDialog extends StatefulWidget {
  final int documentId;
  final String documentTitle;
  final String pdfUrl; // ✅ Pastikan ini ada
  final Color primaryColor;

  const RequestSignatureDialog({
    super.key,
    required this.documentId,
    required this.documentTitle,
    required this.pdfUrl, // ✅ Wajib diisi
    required this.primaryColor,
  });

  @override
  State<RequestSignatureDialog> createState() => _RequestSignatureDialogState();
}

class _RequestSignatureDialogState extends State<RequestSignatureDialog> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;
  String? _emailError;
  List<Map<String, dynamic>> _userSuggestions = [];
  Timer? _searchDebounce;

  @override
  void dispose() {
    _emailController.dispose();
    _noteController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onEmailChanged(String value) {
    setState(() => _emailError = null);
    _searchDebounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _userSuggestions = []);
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchUsers(value.trim()),
    );
  }

  Future<void> _searchUsers(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final res = await http.get(
        Uri.parse(
          '${ApiConfig.usersUrl}/search?q=${Uri.encodeComponent(query)}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _userSuggestions = (body is List)
                ? List<Map<String, dynamic>>.from(body)
                : [];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _submitRequest() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailError = "Email tidak valid");
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.post(
        Uri.parse(ApiConfig.requestsUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "document_id": widget.documentId,
          "recipientEmail": email,
          "note": _noteController.text.trim(),
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 201) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Permintaan terkirim")));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainMenu()),
        );
      } else {
        final body = jsonDecode(res.body);
        setState(
          () => _emailError =
              body['message'] ?? body['error'] ?? "Gagal mengirim",
        );
      }
    } catch (e) {
      setState(() => _emailError = "Error koneksi: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          // Tambah ini biar aman keyboard
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Request Tanda Tangan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      size: 20,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.documentTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _emailController,
                onChanged: _onEmailChanged,
                decoration: InputDecoration(
                  labelText: "Email Penerima",
                  errorText: _emailError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              if (_userSuggestions.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 100),
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _userSuggestions.length,
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      title: Text(_userSuggestions[i]['email']),
                      subtitle: Text(_userSuggestions[i]['name'] ?? ''),
                      onTap: () {
                        _emailController.text = _userSuggestions[i]['email'];
                        setState(() => _userSuggestions = []);
                      },
                    ),
                  ),
                ),

              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: "Catatan (Opsional)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Text(
                          "Kirim Permintaan",
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
