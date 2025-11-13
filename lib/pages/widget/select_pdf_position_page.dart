import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class SelectPdfPositionPage extends StatefulWidget {
  final int documentId;
  final String pdfUrl;
  final Color primaryColor;
  final File signatureFile;

  const SelectPdfPositionPage({
    super.key,
    required this.documentId,
    required this.pdfUrl,
    required this.primaryColor,
    required this.signatureFile,
  });

  @override
  State<SelectPdfPositionPage> createState() => _SelectPdfPositionPageState();
}

class _SelectPdfPositionPageState extends State<SelectPdfPositionPage> {
  late String signEndpoint;
  final String apiBase = ApiConfig.baseUrl;
  String get documentsUrl => ApiConfig.documentsUrl;

  Offset? _relPos; // posisi relatif (0..1)
  bool isSubmitting = false;
  int currentPage = 1;

  final PdfViewerController _pdfController = PdfViewerController();
  final GlobalKey _pdfKey = GlobalKey();
  final Map<int, Size> _pageSizesPt = {};

  // ukuran tanda tangan
  static const double baseSigWidthPt = 150;
  double scale = 1.0;
  double imageAspectRatio = 3.0; // default (di-update setelah load gambar)

  @override
  void initState() {
    super.initState();
    signEndpoint = '$documentsUrl/${widget.documentId}/sign';
    _loadImageRatio();
  }

  Future<void> _loadImageRatio() async {
    try {
      final img = await decodeImageFromList(
        await widget.signatureFile.readAsBytes(),
      );
      setState(() => imageAspectRatio = img.width / img.height);
    } catch (_) {}
  }

  _PageDisplayRect _computeDisplayRect(
    Size viewerSize,
    Size pagePts,
    double zoom,
  ) {
    final pageAspect = pagePts.width / pagePts.height;
    final displayW = viewerSize.width * zoom;
    final displayH = displayW / pageAspect;

    double offsetY = 0;
    if (displayH < viewerSize.height) {
      offsetY = (viewerSize.height - displayH) / 2;
    }

    return _PageDisplayRect(
      widthPx: displayW,
      heightPx: displayH,
      offsetX: 0,
      offsetY: offsetY,
    );
  }

  void _handleTapDown(TapDownDetails details) {
    final renderBox = _pdfKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final viewerSize = renderBox.size;
    final pagePts = _pageSizesPt[currentPage] ?? const Size(595, 842);
    final rect = _computeDisplayRect(
      viewerSize,
      pagePts,
      _pdfController.zoomLevel,
    );

    final local = details.localPosition;
    final dxInPage = local.dx - rect.offsetX;
    final dyInPage = local.dy - rect.offsetY;

    final relX = (dxInPage / rect.widthPx).clamp(0.0, 1.0);
    final relY = (dyInPage / rect.heightPx).clamp(0.0, 1.0);

    setState(() => _relPos = Offset(relX, relY));
  }

  Future<void> _submit() async {
    if (_relPos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Silakan klik posisi tanda tangan di PDF."),
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final pagePt = _pageSizesPt[currentPage] ?? const Size(595, 842);

      final sigWidthPt = baseSigWidthPt * scale;
      final sigHeightPt = sigWidthPt / imageAspectRatio;

      final centerX = _relPos!.dx * pagePt.width;
      final centerY = pagePt.height * (1 - _relPos!.dy);

      final pdfX = centerX - (sigWidthPt / 2);
      final pdfY = centerY - (sigHeightPt / 2);

      final req = http.MultipartRequest('POST', Uri.parse(signEndpoint))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['pageNumber'] = currentPage.toString()
        ..fields['x'] = pdfX.toStringAsFixed(2)
        ..fields['y'] = pdfY.toStringAsFixed(2)
        ..fields['width'] = sigWidthPt.toStringAsFixed(0)
        ..fields['height'] = sigHeightPt.toStringAsFixed(0)
        ..files.add(
          await http.MultipartFile.fromPath(
            'signatureImage',
            widget.signatureFile.path,
            contentType: MediaType('image', 'png'),
          ),
        );

      final res = await req.send();
      final body = await res.stream.bytesToString();
      final success = res.statusCode == 200;

      if (success) {
        _showResult(true);
      } else {
        debugPrint('❌ Error: $body');
        _showResult(false);
      }
    } catch (e) {
      debugPrint('❌ Submit error: $e');
      _showResult(false);
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void _showResult(bool success) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: success ? Colors.green : Colors.redAccent,
            ),
            const SizedBox(width: 8),
            Text(success ? "Berhasil" : "Gagal"),
          ],
        ),
        content: Text(
          success
              ? "Dokumen berhasil ditandatangani."
              : "Tanda tangan tidak cocok dengan baseline (verifikasi gagal).",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            child: Text("OK", style: TextStyle(color: widget.primaryColor)),
          ),
        ],
      ),
    );
  }

  void _increaseSize() => setState(() => scale = (scale + 0.1).clamp(0.5, 2.0));
  void _decreaseSize() => setState(() => scale = (scale - 0.1).clamp(0.5, 2.0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Pilih Posisi TTD",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Stack(
        children: [
          GestureDetector(
            key: _pdfKey,
            onTapDown: _handleTapDown,
            child: SfPdfViewer.network(
              widget.pdfUrl,
              controller: _pdfController,
              enableTextSelection: false,
              onDocumentLoaded: (details) {
                _pageSizesPt.clear();
                for (int i = 0; i < details.document.pages.count; i++) {
                  final size = details.document.pages[i].size;
                  _pageSizesPt[i + 1] = Size(size.width, size.height);
                }
                setState(() {});
              },
              onPageChanged: (d) =>
                  setState(() => currentPage = d.newPageNumber),
              onDocumentLoadFailed: (e) =>
                  debugPrint('❌ Load PDF gagal: ${e.error} | ${e.description}'),
            ),
          ),

          // === Overlay tanda tangan ===
          if (_relPos != null)
            AnimatedBuilder(
              animation: _pdfController,
              builder: (_, __) {
                final renderBox =
                    _pdfKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox == null) return const SizedBox.shrink();

                final viewerSize = renderBox.size;
                final zoom = _pdfController.zoomLevel;
                final scroll = _pdfController.scrollOffset;
                final pagePts =
                    _pageSizesPt[currentPage] ?? const Size(595, 842);
                final rect = _computeDisplayRect(viewerSize, pagePts, zoom);

                final sigWidthPx =
                    (baseSigWidthPt * scale / pagePts.width) * rect.widthPx;
                final sigHeightPx =
                    sigWidthPx /
                    imageAspectRatio /
                    pagePts.height *
                    rect.heightPx;

                final centerX =
                    rect.offsetX + (_relPos!.dx * rect.widthPx) - scroll.dx;
                final centerY =
                    rect.offsetY + (_relPos!.dy * rect.heightPx) - scroll.dy;

                return Positioned(
                  left: centerX - sigWidthPx / 2,
                  top: centerY - sigHeightPx / 2,
                  child: GestureDetector(
                    onPanStart: (_) => HapticFeedback.selectionClick(),
                    onPanUpdate: (d) {
                      final dxRel = d.delta.dx / rect.widthPx;
                      final dyRel = d.delta.dy / rect.heightPx;
                      setState(() {
                        _relPos = Offset(
                          (_relPos!.dx + dxRel).clamp(0.0, 1.0),
                          (_relPos!.dy + dyRel).clamp(0.0, 1.0),
                        );
                      });
                    },
                    child: RepaintBoundary(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 60),
                            width: sigWidthPx,
                            height: sigHeightPx,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: widget.primaryColor,
                                width: 2,
                              ),
                              color: widget.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(widget.signatureFile),
                                fit: BoxFit.fill,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                          // tombol resize
                          Positioned(
                            right: -10,
                            top: -10,
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: _increaseSize,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: widget.primaryColor,
                                    child: const Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: _decreaseSize,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.remove,
                                      size: 16,
                                      color: widget.primaryColor,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black12,
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isSubmitting ? null : _submit,
        backgroundColor: widget.primaryColor,
        icon: const Icon(Icons.check, color: Colors.white),
        label: isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text("Tempel Tanda Tangan"),
      ),
    );
  }
}

class _PageDisplayRect {
  final double widthPx;
  final double heightPx;
  final double offsetX;
  final double offsetY;
  _PageDisplayRect({
    required this.widthPx,
    required this.heightPx,
    required this.offsetX,
    required this.offsetY,
  });
}
