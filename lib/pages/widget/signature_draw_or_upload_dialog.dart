import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
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
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  File? uploadedImage;
  bool isDrawing = true;

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

  Future<void> _proceed() async {
    File? sigFile;
    if (isDrawing) {
      final bytes = await _controller.toPngBytes();
      if (bytes == null) return;
      final file = File(
        '${Directory.systemTemp.path}/sig_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      sigFile = file;
    } else {
      sigFile = uploadedImage;
    }

    if (!mounted || sigFile == null) return;
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectPdfPositionPage(
          documentId: widget.documentId,
          pdfUrl: widget.pdfUrl,
          primaryColor: widget.primaryColor,
          signatureFile: sigFile!,
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
              "Tanda Tangan",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 15),

            // Area gambar / upload
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

            // Tombol reset (muncul hanya saat mode menggambar)
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
                  style: TextButton.styleFrom(
                    foregroundColor: widget.primaryColor,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Tombol Gambar / Upload
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

            const SizedBox(height: 15),

            ElevatedButton(
              onPressed: _proceed,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Lanjut Pilih Posisi",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
