// lib/pages/widget/add_baseline_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  File? uploadedImage;
  bool isSubmitting = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        uploadedImage = File(picked.path);
      });
    }
  }

  Future<void> _submit() async {
    if (uploadedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih gambar tanda tangan')),
      );
      return;
    }

    if (isSubmitting) return;
    setState(() => isSubmitting = true);

    try {
      await widget.onSubmit(uploadedImage!);
    } catch (e) {
      // Handle error di parent, atau tampilkan snackbar di sini jika perlu
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
                "Upload Baseline Signature",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 15),

              // Preview Image Container
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: uploadedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(uploadedImage!, fit: BoxFit.contain),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Belum ada gambar",
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 15),

              // Tombol Pilih Gambar
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(Icons.upload_file, color: widget.primaryColor),
                  label: Text(
                    uploadedImage == null ? "Pilih Gambar" : "Ganti Gambar",
                    style: TextStyle(color: widget.primaryColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: widget.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (uploadedImage == null || isSubmitting)
                      ? null
                      : _submit,
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
              ),

              const SizedBox(height: 10),

              // Tombol Batal
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
