import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../models/book.dart';
import '../theme/archival_theme.dart';
import '../ui/widgets/archive_code.dart';
import '../ui/widgets/mini_status_bar.dart';

/// Industrial Native High-Performance PDF Reader supporting 100MB+ files without memory crashes.
class PdfReaderView extends StatefulWidget {
  final Book book;
  final String? filePath;

  const PdfReaderView({super.key, required this.book, this.filePath});

  @override
  State<PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends State<PdfReaderView> {
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;
  String _errorMessage = '';
  PDFViewController? _pdfViewController;
  bool _hudVisible = false;
  bool _isNightMode = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = widget.filePath ?? widget.book.filePath;

    if (path == null || path.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.book.title)),
        body: const Center(child: Text('未找到 PDF 文件物理路径，请重新从书架导入。')),
      );
    }

    return Scaffold(
      backgroundColor: _isNightMode ? const Color(0xFF191919) : const Color(0xFFF4F3EF),
      body: SafeArea(
        child: Stack(
          children: [
            // Gesture Detector wrapping Native PDFView
            GestureDetector(
              onTap: () => setState(() => _hudVisible = !_hudVisible),
              child: Container(
                color: _isNightMode ? Colors.black : const Color(0xFFF4F3EF),
                child: PDFView(
                  filePath: path,
                  enableSwipe: true,
                  swipeHorizontal: true,
                  autoSpacing: false,
                  pageFling: true,
                  pageSnap: true,
                  defaultPage: _currentPage,
                  fitPolicy: FitPolicy.BOTH,
                  nightMode: _isNightMode,
                  onRender: (pages) {
                    setState(() {
                      _totalPages = pages ?? 0;
                      _isReady = true;
                    });
                  },
                  onError: (error) {
                    setState(() {
                      _errorMessage = error.toString();
                    });
                  },
                  onPageError: (page, error) {
                    setState(() {
                      _errorMessage = '$page: ${error.toString()}';
                    });
                  },
                  onViewCreated: (PDFViewController controller) {
                    _pdfViewController = controller;
                  },
                  onPageChanged: (int? page, int? total) {
                    setState(() {
                      _currentPage = page ?? 0;
                      _totalPages = total ?? 0;
                    });
                  },
                ),
              ),
            ),

            // Loading / Error Indicator
            if (!_isReady && _errorMessage.isEmpty)
              const Center(child: CircularProgressIndicator()),
            if (_errorMessage.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('PDF 载入失败: $_errorMessage', style: const TextStyle(color: Colors.red)),
                ),
              ),

            // Bottom Mini Status Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: _isNightMode ? const Color(0xFF191919).withValues(alpha: 0.9) : const Color(0xFFF4F3EF).withValues(alpha: 0.9),
                child: MiniStatusBar(
                  chapterTitle: widget.book.title,
                  progressPercent: _totalPages > 0 ? (_currentPage + 1) / _totalPages : 0.0,
                  currentTime: '${_currentPage + 1}/$_totalPages 页',
                ),
              ),
            ),

            // Top HUD Bar
            if (_hudVisible)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 56.0,
                  color: (_isNightMode ? const Color(0xFF191919) : const Color(0xFFF4F3EF)).withValues(alpha: 0.96),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: _isNightMode ? Colors.white : Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      ArchiveCode('PDF', inverse: true),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _isNightMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isNightMode ? Icons.light_mode : Icons.dark_mode_outlined,
                          color: _isNightMode ? Colors.white : Colors.black,
                        ),
                        tooltip: '切换昼夜',
                        onPressed: () => setState(() => _isNightMode = !_isNightMode),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom HUD Scrubber
            if (_hudVisible)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Container(
                  color: (_isNightMode ? const Color(0xFF191919) : const Color(0xFFF4F3EF)).withValues(alpha: 0.96),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Text('${_currentPage + 1}', style: ArchivalTheme.codeStyle()),
                      Expanded(
                        child: Slider(
                          value: (_currentPage + 1).toDouble().clamp(1.0, _totalPages > 0 ? _totalPages.toDouble() : 1.0),
                          min: 1.0,
                          max: _totalPages > 0 ? _totalPages.toDouble() : 1.0,
                          activeColor: _isNightMode ? Colors.white : scheme.onSurface,
                          onChanged: (val) {
                            final targetPage = val.round() - 1;
                            setState(() => _currentPage = targetPage);
                            _pdfViewController?.setPage(targetPage);
                          },
                        ),
                      ),
                      Text('$_totalPages', style: ArchivalTheme.codeStyle()),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
