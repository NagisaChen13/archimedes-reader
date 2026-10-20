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

/// High-speed layout engine using localized binary search and selective paragraph indentation.
class PaginationEngine {
  static List<PageSlice> paginateChapter({
    required String chapterText,
    required int chapterIndex,
    required String chapterTitle,
    required Size viewportSize,
    required EdgeInsets padding,
    required TextStyle textStyle,
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
          processedLines.add(rawLine);
        } else {
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

    // Fast character estimate for bounded search window
    final approxCharWidth = (textStyle.fontSize ?? 18.0) * 1.05;
    final approxLineHeight = approxCharWidth * (textStyle.height ?? 1.8);
    final linesPerPage = (availableHeight / approxLineHeight).floor().clamp(4, 80);
    final charsPerLine = (availableWidth / approxCharWidth).floor().clamp(8, 120);
    final estimatedCharsPerPage = linesPerPage * charsPerLine;

    while (currentOffset < totalLength) {
      final remainingLength = totalLength - currentOffset;

      // Check if all remaining text fits on the page
      if (remainingLength <= (estimatedCharsPerPage * 1.2).toInt()) {
        final painter = TextPainter(
          text: TextSpan(text: processedText.substring(currentOffset, totalLength), style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: availableWidth);

        if (painter.size.height <= availableHeight) {
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
      }

      // Fast localized binary search within estimated window
      int low = (currentOffset + (estimatedCharsPerPage * 0.4).toInt()).clamp(currentOffset + 1, totalLength);
      int high = (currentOffset + (estimatedCharsPerPage * 1.5).toInt()).clamp(low, totalLength);
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

      // Natural punctuation boundary snap
      int pageEnd = bestEnd;
      if (pageEnd < totalLength) {
        for (int lookback = 0; lookback < 20 && (pageEnd - lookback) > currentOffset + 10; lookback++) {
          final ch = processedText[pageEnd - lookback - 1];
          if (ch == '\n' || ch == '。' || ch == '！' || ch == '？' || ch == '；') {
            pageEnd = pageEnd - lookback;
            break;
          }
        }
      }

      if (pageEnd <= currentOffset) {
        pageEnd = (currentOffset + (estimatedCharsPerPage * 0.8).toInt()).clamp(currentOffset + 1, totalLength);
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
}
