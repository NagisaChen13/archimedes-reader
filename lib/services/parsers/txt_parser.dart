import 'dart:convert';
import 'dart:typed_data';
import 'package:fast_gbk/fast_gbk.dart';
import '../../models/book.dart';

/// Intelligent TXT Book Parser with advanced encoding detection (UTF-8, UTF-16, GBK/GB2312)
/// and robust Chinese/Western chapter segmentation.
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

  /// Detects BOM (UTF-8, UTF-16LE, UTF-16BE), strict UTF-8, and falls back to GBK / GB2312
  static String _decodeText(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      // UTF-8 with BOM
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      // UTF-16LE with BOM
      return _decodeUtf16Le(bytes.sublist(2));
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      // UTF-16BE with BOM
      return _decodeUtf16Be(bytes.sublist(2));
    }

    // 1. Try strict UTF-8
    try {
      return utf8.decode(bytes);
    } catch (_) {
      // 2. Fallback: GBK / GB2312 / GB18030 (standard for Chinese TXT novels)
      try {
        return gbk.decode(bytes);
      } catch (_) {
        // 3. Fallback: UTF-8 with malformed recovery
        try {
          return utf8.decode(bytes, allowMalformed: true);
        } catch (_) {
          return latin1.decode(bytes);
        }
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

  static String _decodeUtf16Be(Uint8List bytes) {
    final buffer = StringBuffer();
    for (int i = 0; i < bytes.length - 1; i += 2) {
      final codeUnit = (bytes[i] << 8) | bytes[i + 1];
      buffer.writeCharCode(codeUnit);
    }
    return buffer.toString();
  }

  /// Automatically parses chapters using comprehensive Chinese & Western patterns
  static List<ChapterItem> _extractChapters(String text) {
    final cleanText = _cleanBlankLines(text);

    // Matches: 第x章, 第 x 节, 第一回, Chapter 1, 【第一章】, 序章, 楔子, 尾声, 后记, 番外, 引子, 终章, 大结局
    final pattern = RegExp(
      r'(?m)^\s*([【\[(]?\s*第\s*[0-9０-９一二三四五六七八九十百千万零两〇]+\s*[章节回幕话話页頁卷集部篇折]\s*.*?|Chapter\s+\d+.*?|CHAPTER\s+\d+.*?|序[章言幕]|前言|楔子|尾[声聲]|后记|後記|番外.*?|引子|终章|大结局).*$',
      caseSensitive: false,
    );

    final matches = pattern.allMatches(cleanText).toList();
    if (matches.isEmpty) {
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

  /// Splits massive text without chapter titles into natural paragraph-aligned segments (~5000 chars)
  static List<ChapterItem> _splitIntoFixedChunks(String text) {
    final chapters = <ChapterItem>[];
    const targetChunkSize = 5000;
    int chunkIdx = 0;
    int start = 0;

    while (start < text.length) {
      if (start + targetChunkSize >= text.length) {
        final content = text.substring(start).trim();
        if (content.isNotEmpty) {
          chapters.add(ChapterItem(
            index: chunkIdx,
            title: '第 ${chunkIdx + 1} 部分',
            wordCount: content.length,
            content: content,
          ));
        }
        break;
      }

      int end = start + targetChunkSize;
      final nextNewline = text.indexOf('\n', end);
      if (nextNewline != -1 && nextNewline - end < 1000) {
        end = nextNewline + 1;
      }

      final content = text.substring(start, end).trim();
      chapters.add(ChapterItem(
        index: chunkIdx,
        title: '第 ${chunkIdx + 1} 部分',
        wordCount: content.length,
        content: content,
      ));
      chunkIdx++;
      start = end;
    }

    return chapters;
  }

  /// Cleans excess blank lines and trims spaces
  static String _cleanBlankLines(String raw) {
    return raw
        .replaceAll(RegExp(r'\r\n|\r'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+$'), '');
  }
}
