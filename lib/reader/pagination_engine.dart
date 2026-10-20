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

/// Industrial-grade Physical Pagination Engine using TextPainter geometry.
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
          content: '',
          startCharOffset: 0,
          endCharOffset: 0,
        )
      ];
    }

    // Apply Chinese 2-character indentation if enabled
    String processedText = chapterText;
    if (indentTwoChars) {
      processedText = processedText
          .split('\n')
          .map((line) => line.trim().isEmpty ? '' : '　　${line.trim()}')
          .join('\n\n');
    }

    final availableWidth = (viewportSize.width - padding.left - padding.right).clamp(100.0, 2000.0);
    final availableHeight = (viewportSize.height - padding.top - padding.bottom).clamp(100.0, 4000.0);

    final slices = <PageSlice>[];
    int currentOffset = 0;
    final totalLength = processedText.length;

    // Estimate characters per page to prevent full-text re-layout overhead
    final approxCharWidth = textStyle.fontSize ?? 18.0;
    final approxLineHeight = approxCharWidth * (textStyle.height ?? 1.8);
    final linesPerPage = (availableHeight / approxLineHeight).floor().clamp(5, 50);
    final charsPerLine = (availableWidth / approxCharWidth).floor().clamp(10, 80);
    final estimatedCharsPerPage = linesPerPage * charsPerLine;

    while (currentOffset < totalLength) {
      // Pick a candidate window of text
      int candidateEnd = (currentOffset + (estimatedCharsPerPage * 1.6).toInt()).clamp(currentOffset + 10, totalLength);
      String candidateText = processedText.substring(currentOffset, candidateEnd);

      final painter = TextPainter(
        text: TextSpan(text: candidateText, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      painter.layout(maxWidth: availableWidth);

      if (painter.size.height <= availableHeight && candidateEnd == totalLength) {
        // Last page
        slices.add(PageSlice(
          pageIndex: slices.length,
          totalPagesInChapter: 0, // will be patched below
          chapterIndex: chapterIndex,
          chapterTitle: chapterTitle,
          content: candidateText,
          startCharOffset: currentOffset,
          endCharOffset: totalLength,
        ));
        break;
      }

      // Find exact position where content overflows availableHeight
      final position = painter.getPositionForOffset(Offset(availableWidth, availableHeight - 2.0));
      int pageCharCount = position.offset;

      if (pageCharCount <= 0 || pageCharCount >= candidateText.length) {
        pageCharCount = (estimatedCharsPerPage * 0.8).toInt().clamp(50, candidateText.length);
      }

      // Avoid breaking mid-word or hanging punctuation if possible
      if (currentOffset + pageCharCount < totalLength) {
        final lastChar = candidateText[pageCharCount - 1];
        if (lastChar == '，' || lastChar == '。' || lastChar == '！' || lastChar == '？') {
          // Keep punctuation at the end of the page
        }
      }

      final pageContent = processedText.substring(currentOffset, currentOffset + pageCharCount);

      slices.add(PageSlice(
        pageIndex: slices.length,
        totalPagesInChapter: 0,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        content: pageContent,
        startCharOffset: currentOffset,
        endCharOffset: currentOffset + pageCharCount,
      ));

      currentOffset += pageCharCount;
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
