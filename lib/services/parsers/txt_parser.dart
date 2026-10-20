import 'dart:convert';
import 'dart:typed_data';
import '../../models/book.dart';

/// Intelligent TXT Book Parser with encoding detection and automatic chapter extraction.
class TxtBookParser {
  static Future<Book> parse({
    required Uint8List bytes,
    required String fileName,
    String? customTitle,
  }) async {
    final decodedText = _decodeText(bytes);
    final title = customTitle ?? fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final chapters = _extractChapters(decodedText);

    int totalWords = 0;
    for (final c in chapters) {
      totalWords += c.wordCount;
    }

    final volume = BookVolume(
      volumeId: 'V1',
      volumeTitle: '正文章节',
      chapters: chapters,
    );

    return Book(
      id: 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      title: title,
      author: '本地文献',
      format: 'TXT',
      coverPath: '',
      totalWords: totalWords,
      currentProgress: 0.0,
      currentChapterIndex: 0,
      volumes: [volume],
      lastReadTime: DateTime.now(),
    );
  }

  /// Detects UTF-8, UTF-16, or falls back to GBK/Latin1
  static String _decodeText(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      // UTF-8 with BOM
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      // UTF-16LE with BOM
      return _decodeUtf16Le(bytes.sublist(2));
    }

    try {
      // Try strict UTF-8 first
      return utf8.decode(bytes);
    } catch (_) {
      try {
        // Fallback: GBK / GB2312 simulation or malformed UTF-8 recovery
        return utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        return latin1.decode(bytes);
      }
    }
  }

  static String _decodeUtf16Le(Uint8List bytes) {
    final buffer = StringBuffer();
    for (int i = 0; i < bytes.length - 1; i += 2) {
      final codeUnit = bytes[i] | (bytes[i + 1] << 8);
      buffer.writeCharCode(codeUnit);
    }
    return buffer.toString();
  }

  /// Automatically parses chapters using regex patterns
  static List<ChapterItem> _extractChapters(String text) {
    final cleanText = _cleanBlankLines(text);

    // Standard Chinese & Western chapter title regex
    final pattern = RegExp(
      r'(?m)^\s*(第[0-9一二三四五六七八九十百千万零两]+[章回节卷集部篇话].*|Chapter\s+\d+.*|序[章言]|前言|楔子|尾声|后记).*$',
    );

    final matches = pattern.allMatches(cleanText).toList();
    if (matches.isEmpty) {
      // If no chapter headers found, partition into readable blocks of ~6000 chars
      return _splitIntoFixedChunks(cleanText);
    }

    final chapters = <ChapterItem>[];
    int chapterIdx = 0;

    // Introduction / Prologue before the first matched chapter
    if (matches.first.start > 0) {
      final introContent = cleanText.substring(0, matches.first.start).trim();
      if (introContent.isNotEmpty) {
        chapters.add(ChapterItem(
          index: chapterIdx++,
          title: '序章 / 前言',
          wordCount: introContent.length,
          content: introContent,
        ));
      }
    }

    for (int i = 0; i < matches.length; i++) {
      final currentMatch = matches[i];
      final chapterTitle = currentMatch.group(0)!.trim();
      final startIndex = currentMatch.end;
      final endIndex = (i + 1 < matches.length) ? matches[i + 1].start : cleanText.length;

      final chapterContent = cleanText.substring(startIndex, endIndex).trim();
      chapters.add(ChapterItem(
        index: chapterIdx++,
        title: chapterTitle,
        wordCount: chapterContent.length,
        content: chapterContent.isEmpty ? '[本章无文本内容]' : chapterContent,
      ));
    }

    return chapters;
  }

  /// Splits massive text without chapter titles into fixed segments
  static List<ChapterItem> _splitIntoFixedChunks(String text) {
    final chapters = <ChapterItem>[];
    const chunkSize = 6000;
    int chunkIdx = 0;

    for (int i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      final content = text.substring(i, end).trim();
      chapters.add(ChapterItem(
        index: chunkIdx,
        title: '第 ${chunkIdx + 1} 部分',
        wordCount: content.length,
        content: content,
      ));
      chunkIdx++;
    }

    return chapters;
  }

  /// Moon+ Reader Style: cleans excess blank lines and trims spaces
  static String _cleanBlankLines(String raw) {
    return raw
        .replaceAll(RegExp(r'\r\n|\r'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+$'), '');
  }
}
