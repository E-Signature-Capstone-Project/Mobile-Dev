import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'select_pdf_position_page.dart';

class SignatureDrawOrUploadDialog extends StatefulWidget {
  final int documentId;
  final String pdfUrl;
  final Color primaryColor;

  const SignatureDrawOrUploadDialog({
    super.key,
    required this.documentId,
    required this.pdfUrl,
    required this.primaryColor,
  });

  @override
  State<SignatureDrawOrUploadDialog> createState() =>
      _SignatureDrawOrUploadDialogState();
}

class _SignatureDrawOrUploadDialogState
    extends State<SignatureDrawOrUploadDialog> {
  File? uploadedImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        uploadedImage = File(picked.path);
      });
    }
  }

  Future<void> _proceed() async {
    if (!mounted || uploadedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Silakan upload gambar tanda tangan dulu"),
        ),
      );
      return;
    }

    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectPdfPositionPage(
          documentId: widget.documentId,
          pdfUrl: widget.pdfUrl,
          primaryColor: widget.primaryColor,
          signatureFile: uploadedImage!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Upload Tanda Tangan",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 15),

            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
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
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Belum ada gambar",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 15),

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

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: uploadedImage == null ? null : _proceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Lanjut Pilih Posisi",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
