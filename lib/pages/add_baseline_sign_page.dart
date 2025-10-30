import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_menu.dart';
import 'package:http_parser/http_parser.dart';

class AddBaselineSignPage extends StatefulWidget {
  const AddBaselineSignPage({super.key});

  @override
  State<AddBaselineSignPage> createState() => _AddBaselineSignPageState();
}

class _AddBaselineSignPageState extends State<AddBaselineSignPage> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  Uint8List? _signatureBytes;
  File? _uploadedImage;
  bool _isDrawing = false;
  bool _isUploading = false;

  final String apiBase = 'http://10.0.2.2:4000';
  String get baselineBase => '$apiBase/baseline';

  final Color primaryRed = const Color(0xFFDA1E28);

  //upload ttd ke backend
  Future<void> _uploadToBackend(File file) async {
    try {
      setState(() => _isUploading = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final uri = Uri.parse('http://10.0.2.2:4000/signature_baseline/add');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
          await http.MultipartFile.fromPath(
            'image',
            file.path,
            contentType: MediaType('image', 'png'),
          ),
        );

      final response = await request.send();
      final body = await response.stream.bytesToString();

      try {
        final data = jsonDecode(body);
        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Baseline berhasil ditambahkan'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainMenu()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Gagal menambah baseline'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        debugPrint('⚠️ Server Response HTML: $body');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Server mengembalikan HTML, bukan JSON. Cek endpoint.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error upload: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kesalahan upload: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _exportDrawing() async {
    if (_controller.isNotEmpty) {
      final bytes = await _controller.toPngBytes();
      if (bytes != null) {
        final tempFile = File(
          '${Directory.systemTemp.path}/sign_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await tempFile.writeAsBytes(bytes);
        await _uploadToBackend(tempFile);
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan gambar tanda tangan dulu')),
      );
    }
  }

  Future<void> _uploadSignature() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _uploadedImage = File(pickedFile.path);
        _isDrawing = false;
      });
      _showUploadPreview();
    }
  }

  void _showUploadPreview() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Upload Signature",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 15),
              if (_uploadedImage != null)
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: Image.file(_uploadedImage!, fit: BoxFit.contain),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade400),
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      child: const Text(
                        "Back",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        if (_uploadedImage != null) {
                          await _uploadToBackend(_uploadedImage!);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      child: const Text(
                        "Save",
                        style: TextStyle(color: Colors.white),
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text(
          "Add Baseline Sign",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _isDrawing
                    ? Signature(
                        controller: _controller,
                        backgroundColor: Colors.white,
                      )
                    : const Center(
                        child: Text(
                          "Gambar atau upload tanda tangan kamu",
                          style: TextStyle(color: Colors.black54, fontSize: 14),
                        ),
                      ),
              ),
              const SizedBox(height: 25),
              if (_isDrawing)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _isDrawing = false),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text("Back"),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 45),
                          side: BorderSide(color: Colors.grey.shade400),
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _exportDrawing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          minimumSize: const Size(double.infinity, 45),
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Save",
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _controller.clear(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          minimumSize: const Size(double.infinity, 45),
                        ),
                        child: const Text(
                          "Reset",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => setState(() {
                        _isDrawing = true;
                        _uploadedImage = null;
                      }),
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
                      onPressed: _uploadSignature,
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
            ],
          ),
        ),
      ),
    );
  }
}
