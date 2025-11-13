import 'package:flutter/material.dart';
import 'signature_draw_or_upload_dialog.dart';
import '../config/api_config.dart';

class DocumentDetailDialog extends StatelessWidget {
  final Map<String, dynamic> document;
  final Color primaryColor;
  final VoidCallback? onChanged;

  const DocumentDetailDialog({
    super.key,
    required this.document,
    required this.primaryColor,
    this.onChanged,
  });

  /// Ambil URL file PDF dari API config
  String _resolveFileUrl(Map<String, dynamic> doc) {
    final explicit = (doc['file_url'] ?? '').toString();
    if (explicit.isNotEmpty) return explicit;

    final path = (doc['file_path'] ?? '').toString();
    if (path.isEmpty) return '';

    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return '${ApiConfig.baseUrl}/$normalized';
  }

  @override
  Widget build(BuildContext context) {
    final title = document['title'] ?? 'Dokumen';
    final pdfUrl = _resolveFileUrl(document);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header dokumen
            Row(
              children: [
                Icon(Icons.picture_as_pdf, color: primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
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
            const SizedBox(height: 20),

            // Tombol Tandatangani Dokumen
            ElevatedButton.icon(
              icon: const Icon(Icons.edit, color: Colors.white),
              label: const Text(
                "Tandatangani Dokumen",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => SignatureDrawOrUploadDialog(
                    documentId: document['document_id'],
                    pdfUrl: pdfUrl,
                    primaryColor: primaryColor,
                  ),
                );
                onChanged?.call();
              },
            ),

            const SizedBox(height: 10),

            // Tombol Request TTD
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Fitur Request TTD belum tersedia."),
                    backgroundColor: Colors.orangeAccent,
                  ),
                );
              },
              icon: Icon(Icons.outgoing_mail, color: primaryColor),
              label: Text("Request TTD", style: TextStyle(color: primaryColor)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: primaryColor),
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
