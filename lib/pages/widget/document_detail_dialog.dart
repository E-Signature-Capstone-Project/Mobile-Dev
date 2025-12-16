import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'request_signature_dialog.dart';
import 'signature_draw_or_upload_dialog.dart'; // File yang baru diupdate (tanpa draw)

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
    final status = document['status'] ?? 'pending';
    final isSigned = status == 'signed' || status == 'completed';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tombol Self Sign
            // Disable jika dokumen sudah ditandatangani
            if (!isSigned)
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

            if (isSigned)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Text(
                  "Dokumen sudah ditandatangani",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // Tombol Request TTD
            OutlinedButton.icon(
              onPressed: () async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (_) => RequestSignatureDialog(
                    documentId: document['document_id'],
                    documentTitle: title,
                    pdfUrl: pdfUrl,
                    primaryColor: primaryColor,
                  ),
                );

                if (result == true) {
                  onChanged?.call();
                }
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
