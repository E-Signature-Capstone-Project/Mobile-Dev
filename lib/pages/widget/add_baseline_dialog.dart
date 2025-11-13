import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

class AddBaselineDialog extends StatefulWidget {
  final Color primaryColor;
  final Future<void> Function(File file) onSubmit;

  const AddBaselineDialog({
    super.key,
    required this.primaryColor,
    required this.onSubmit,
  });

  @override
  State<AddBaselineDialog> createState() => _AddBaselineDialogState();
}

class _AddBaselineDialogState extends State<AddBaselineDialog> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  File? uploadedImage;
  bool isDrawing = true;
  bool isSubmitting = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        uploadedImage = File(picked.path);
        isDrawing = false;
      });
    }
  }

  Future<void> _submit() async {
    if (isSubmitting) return;
    setState(() => isSubmitting = true);

    try {
      File? sigFile;
      if (isDrawing) {
        final bytes = await _controller.toPngBytes();
        if (bytes == null || bytes.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tanda tangan belum digambar')),
          );
          setState(() => isSubmitting = false);
          return;
        }
        final file = File(
          '${Directory.systemTemp.path}/baseline_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(bytes);
        sigFile = file;
      } else {
        sigFile = uploadedImage;
      }

      if (sigFile == null) return;
      await widget.onSubmit(sigFile);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Tambah Baseline Signature",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 15),

              // area gambar / upload
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isDrawing
                    ? Signature(
                        controller: _controller,
                        backgroundColor: Colors.white,
                      )
                    : (uploadedImage != null
                          ? Image.file(uploadedImage!, fit: BoxFit.contain)
                          : const Center(child: Text("Belum ada gambar"))),
              ),

              if (isDrawing) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _controller.clear,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: widget.primaryColor,
                      size: 20,
                    ),
                    label: Text(
                      "Reset",
                      style: TextStyle(
                        color: widget.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // tombol gambar / upload
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => isDrawing = true),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: widget.primaryColor),
                      ),
                      child: Text(
                        "Gambar",
                        style: TextStyle(color: widget.primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickImage,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: widget.primaryColor),
                      ),
                      child: Text(
                        "Upload",
                        style: TextStyle(color: widget.primaryColor),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // tombol simpan
              ElevatedButton(
                onPressed: isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Simpan Baseline",
                        style: TextStyle(color: Colors.white),
                      ),
              ),

              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Batal",
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
