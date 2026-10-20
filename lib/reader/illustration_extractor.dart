import 'package:flutter/material.dart';
import '../../theme/archival_theme.dart';
import '../../ui/widgets/archive_masthead.dart';

/// Full-volume Illustration Gallery Viewer with pinch-zoom and export capabilities.
class IllustrationGalleryPage extends StatelessWidget {
  final String bookTitle;
  final List<String> illustrations;

  const IllustrationGalleryPage({
    super.key,
    required this.bookTitle,
    required this.illustrations,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ArchiveMasthead(
        title: '$bookTitle · 插画档案',
        code: 'ILLUST-${illustrations.length.toString().padLeft(3, '0')}',
      ),
      body: illustrations.isEmpty
          ? Center(
              child: Text(
                '此书籍未检索到插图资源',
                style: ArchivalTheme.serifStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : PageView.builder(
              itemCount: illustrations.length,
              itemBuilder: (context, index) {
                final url = illustrations[index];
                return Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 10.0, // 1000% high-precision zoom
                    child: Hero(
                      tag: 'illust_$index',
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: 260,
                          height: 380,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                              width: 0.8,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '[插图载入失败 · #${index + 1}]',
                            style: ArchivalTheme.codeStyle(),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
