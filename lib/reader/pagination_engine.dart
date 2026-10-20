import 'package:flutter/material.dart';

/// Single physical page slice calculated by the Pagination Engine
class PageSlice {
  final int pageIndex; // 0-based index within chapter
  final int totalPagesInChapter;
  final int chapterIndex;
  final String chapterTitle;
  final String content;
  final int startCharOffset;
  final int endCharOffset;

  const PageSlice({
    required this.pageIndex,
    required this.totalPagesInChapter,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.content,
    required this.startCharOffset,
    required this.endCharOffset,
  });
}

/// Industrial-grade Physical Pagination Engine using precise Binary Search layout geometry.
class PaginationEngine {
  static List<PageSlice> paginateChapter({
    required String chapterText,
    required int chapterIndex,
    required String chapterTitle,
    required Size viewportSize,
    required EdgeInsets padding,
    required TextStyle textStyle,
    double paragraphSpacing = 12.0,
    bool indentTwoChars = true,
  }) {
    if (chapterText.trim().isEmpty) {
      return [
        PageSlice(
          pageIndex: 0,
          totalPagesInChapter: 1,
          chapterIndex: chapterIndex,
          chapterTitle: chapterTitle,
          content: '【本章无正文内容】',
          startCharOffset: 0,
          endCharOffset: 0,
        )
      ];
    }

    // Selective indentation: Only indent normal prose paragraphs
    // Never indent Markdown headers (#), lists (-, *, 1.), quotes (>), code blocks, etc.
    String processedText = chapterText;
    if (indentTwoChars) {
      final lines = processedText.split('\n');
      final processedLines = <String>[];
      for (final rawLine in lines) {
        final trimmed = rawLine.trim();
        if (trimmed.isEmpty) {
          processedLines.add('');
        } else if (trimmed.startsWith('#') ||
            trimmed.startsWith('-') ||
            trimmed.startsWith('*') ||
            trimmed.startsWith('>') ||
            trimmed.startsWith('`') ||
            trimmed.startsWith('|') ||
            RegExp(r'^\d+\.').hasMatch(trimmed)) {
          // Keep formatting intact for markdown syntax
          processedLines.add(rawLine);
        } else {
          // Standard Chinese paragraph: add 2 full-width spaces
          processedLines.add('　　$trimmed');
        }
      }
      processedText = processedLines.join('\n');
    }

    final availableWidth = (viewportSize.width - padding.left - padding.right).clamp(100.0, 3000.0);
    final availableHeight = (viewportSize.height - padding.top - padding.bottom).clamp(100.0, 5000.0);

    final slices = <PageSlice>[];
    int currentOffset = 0;
    final totalLength = processedText.length;

    while (currentOffset < totalLength) {
      // 1. Check if all remaining text fits on the current page
      final fullRemainingPainter = TextPainter(
        text: TextSpan(text: processedText.substring(currentOffset, totalLength), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: availableWidth);

      if (fullRemainingPainter.size.height <= availableHeight) {
        slices.add(PageSlice(
          pageIndex: slices.length,
          totalPagesInChapter: 0,
          chapterIndex: chapterIndex,
          chapterTitle: chapterTitle,
          content: processedText.substring(currentOffset, totalLength),
          startCharOffset: currentOffset,
          endCharOffset: totalLength,
        ));
        break;
      }

      // 2. High-precision Binary Search for the maximum character offset that fits availableHeight
      int low = currentOffset + 1;
      int high = totalLength;
      int bestEnd = low;

      while (low <= high) {
        final mid = (low + high) ~/ 2;
        final candidate = processedText.substring(currentOffset, mid);
        final painter = TextPainter(
          text: TextSpan(text: candidate, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: availableWidth);

        if (painter.size.height <= availableHeight) {
          bestEnd = mid;
          low = mid + 1; // Try fitting more
        } else {
          high = mid - 1; // Too tall, shrink
        }
      }

      // 3. Snap boundary to natural sentence ending or newline to avoid mid-word truncation
      int pageEnd = bestEnd;
      if (pageEnd < totalLength) {
        // Look back up to 24 characters for a line break or Chinese punctuation
        for (int lookback = 0; lookback < 24 && (pageEnd - lookback) > currentOffset + 15; lookback++) {
          final ch = processedText[pageEnd - lookback - 1];
          if (ch == '\n' || ch == '。' || ch == '！' || ch == '？' || ch == '；') {
            pageEnd = pageEnd - lookback;
            break;
          }
        }
      }

      if (pageEnd <= currentOffset) {
        pageEnd = (currentOffset + 1).clamp(0, totalLength);
      }

      final pageText = processedText.substring(currentOffset, pageEnd);
      slices.add(PageSlice(
        pageIndex: slices.length,
        totalPagesInChapter: 0,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        content: pageText,
        startCharOffset: currentOffset,
        endCharOffset: pageEnd,
      ));

      currentOffset = pageEnd;
    }

    // Patch total pages in chapter
    final totalPages = slices.length;
    return slices.map((s) => PageSlice(
      pageIndex: s.pageIndex,
      totalPagesInChapter: totalPages,
      chapterIndex: s.chapterIndex,
      chapterTitle: s.chapterTitle,
      content: s.content,
      startCharOffset: s.startCharOffset,
      endCharOffset: s.endCharOffset,
    )).toList();
  }

  /// Locates which page slice contains the specific character offset after reflow
  static int findPageIndexForOffset(List<PageSlice> pages, int charOffset) {
    for (int i = 0; i < pages.length; i++) {
      if (charOffset >= pages[i].startCharOffset && charOffset < pages[i].endCharOffset) {
        return i;
      }
    }
    return 0;
  }
}
