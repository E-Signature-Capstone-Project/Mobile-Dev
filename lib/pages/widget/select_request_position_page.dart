import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// Model untuk mengembalikan hasil posisi ke halaman sebelumnya
class SignaturePositionResult {
  final int pageNumber;
  final double x;
  final double y;
  final double width;
  final double height;

  SignaturePositionResult({
    required this.pageNumber,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class SelectRequestPositionPage extends StatefulWidget {
  final String pdfUrl;
  final Color primaryColor;

  const SelectRequestPositionPage({
    super.key,
    required this.pdfUrl,
    required this.primaryColor,
  });

  @override
  State<SelectRequestPositionPage> createState() =>
      _SelectRequestPositionPageState();
}

class _SelectRequestPositionPageState extends State<SelectRequestPositionPage> {
  final PdfViewerController _pdfController = PdfViewerController();
  final GlobalKey _pdfKey = GlobalKey();
  final Map<int, Size> _pageSizesPt = {};

  int _currentPage = 1;
  Offset? _relPos; // Posisi relatif (0.0 - 1.0)

  // Ukuran dasar QR (Point)
  static const double baseSigWidthPt = 100.0;
  double scale = 1.0;
  double imageAspectRatio = 1.0; // QR Code persegi

  // --- LOGIKA RENDER TAMPILAN ---
  _PageDisplayRect _computeDisplayRect(
    Size viewerSize,
    Size pagePts,
    double zoom,
  ) {
    if (pagePts.height == 0) return _PageDisplayRect.zero();

    final pageAspect = pagePts.width / pagePts.height;
    final displayW = viewerSize.width * zoom;
    final displayH = displayW / pageAspect;

    double offsetY = 0;
    if (displayH < viewerSize.height) {
      offsetY = (viewerSize.height - displayH) / 2;
    }

    double offsetX = 0;
    if (displayW < viewerSize.width) {
      offsetX = (viewerSize.width - displayW) / 2;
    }

    return _PageDisplayRect(
      widthPx: displayW,
      heightPx: displayH,
      offsetX: offsetX,
      offsetY: offsetY,
    );
  }

  // --- HANDLER TAP & DRAG ---
  void _handleTapDown(TapDownDetails details) {
    final renderBox = _pdfKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final viewerSize = renderBox.size;
    final pagePts = _pageSizesPt[_currentPage] ?? const Size(595, 842);

    final rect = _computeDisplayRect(
      viewerSize,
      pagePts,
      _pdfController.zoomLevel,
    );

    final local = details.localPosition;

    // Hitung posisi relatif dalam halaman
    final dxInPage = local.dx - rect.offsetX;
    final dyInPage = local.dy - rect.offsetY;

    final relX = (dxInPage / rect.widthPx).clamp(0.0, 1.0);
    final relY = (dyInPage / rect.heightPx).clamp(0.0, 1.0);

    setState(() => _relPos = Offset(relX, relY));
  }

  // --- LOGIKA SUBMIT DENGAN KOMPENSASI ---
  void _submit() {
    if (_relPos == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Ketuk layar PDF dulu.")));
      return;
    }

    // 1. Ambil ukuran halaman asli
    final pagePt = _pageSizesPt[_currentPage] ?? const Size(595, 842);

    // 2. Hitung Ukuran QR
    final sigWidthPt = baseSigWidthPt * scale;
    final sigHeightPt = sigWidthPt; // Persegi

    // 3. Hitung Titik Tengah Kotak (Pilihan User)
    final centerX = _relPos!.dx * pagePt.width;
    final centerY_FromTop = _relPos!.dy * pagePt.height;

    // 4. Hitung Sisi Kiri Kotak (Visual Left)
    // Ini batas kiri dimana user MELIHAT kotak
    final visualLeft = centerX - (sigWidthPt / 2);

    // --- RUMUS 'HANTU' UNTUK BACKEND ---
    // Backend: QR_X = Sent_X + Width + 8
    // Kita mau: QR_X == visualLeft
    // Maka: Sent_X = visualLeft - Width - 8

    final finalX = visualLeft - sigWidthPt - 8;

    // --- HITUNG Y (FLIP COORDINATE) ---
    // Y_Bawah = TinggiHalaman - Y_Pusat - SetengahTinggi
    final finalY = pagePt.height - centerY_FromTop - (sigHeightPt / 2);

    // Kembalikan hasil ke Request Page
    Navigator.pop(
      context,
      SignaturePositionResult(
        pageNumber: _currentPage,
        x: double.parse(finalX.toStringAsFixed(2)),
        y: double.parse(finalY.toStringAsFixed(2)),
        width: double.parse(sigWidthPt.toStringAsFixed(0)),
        height: double.parse(sigHeightPt.toStringAsFixed(0)),
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
          "Pilih Posisi QR",
          style: TextStyle(color: Colors.black),
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
                  setState(() => _currentPage = d.newPageNumber),
            ),
          ),

          // === OVERLAY KOTAK QR ===
          if (_relPos != null)
            AnimatedBuilder(
              animation: _pdfController,
              builder: (_, __) {
                final renderBox =
                    _pdfKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox == null) return const SizedBox();

                final viewerSize = renderBox.size;
                final zoom = _pdfController.zoomLevel;
                final scroll = _pdfController.scrollOffset;
                final pagePts =
                    _pageSizesPt[_currentPage] ?? const Size(595, 842);

                final rect = _computeDisplayRect(viewerSize, pagePts, zoom);
                final scaleFactor = rect.widthPx / pagePts.width;

                // Ukuran & Posisi Visual di Layar (Pixel)
                final sigW_Px = (baseSigWidthPt * scale) * scaleFactor;
                final sigH_Px = sigW_Px;

                final centerX =
                    rect.offsetX + (_relPos!.dx * rect.widthPx) - scroll.dx;
                final centerY =
                    rect.offsetY + (_relPos!.dy * rect.heightPx) - scroll.dy;

                return Positioned(
                  left: centerX - sigW_Px / 2,
                  top: centerY - sigH_Px / 2,
                  child: GestureDetector(
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
                    child: Container(
                      width: sigW_Px,
                      height: sigH_Px,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: widget.primaryColor,
                          width: 2,
                        ),
                        color: widget.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              Icons.qr_code_2,
                              color: widget.primaryColor,
                              size: sigW_Px * 0.6,
                            ),
                          ),
                          Positioned(
                            right: -5,
                            top: -5,
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: _increaseSize,
                                  child: const Icon(
                                    Icons.add_circle,
                                    color: Colors.green,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _decreaseSize,
                                  child: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
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
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black12)],
          ),
          child: ElevatedButton(
            onPressed: _relPos == null ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              "SIMPAN POSISI",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
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
  factory _PageDisplayRect.zero() =>
      _PageDisplayRect(widthPx: 0, heightPx: 0, offsetX: 0, offsetY: 0);
}
