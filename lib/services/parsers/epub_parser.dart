import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:epubx/epubx.dart' as epub;
import 'package:fast_gbk/fast_gbk.dart';
import '../../models/book.dart';

/// Full-featured Dual-Engine EPUB Ebook Parser.
/// Engine 1: epubx standard specifications (Spine, TOC, Metadata, Cover, Subchapters)
/// Engine 2: Deep ZIP & XHTML fallback extraction for non-standard or compressed EPUBs.
class EpubBookParser {
  static Future<Book> parse({
    required Uint8List bytes,
    required String fileName,
  }) async {
    String title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    String author = '未知作者';
    final chapters = <ChapterItem>[];
    final illustrations = <String>[];
    int totalWords = 0;

    // ==========================================
    // ENGINE 1: Standard epubx parser
    // ==========================================
    try {
      final epubBook = await epub.EpubReader.readBook(bytes);
      if (epubBook.Title != null && epubBook.Title!.trim().isNotEmpty) {
        title = epubBook.Title!.trim();
      }
      if (epubBook.Author != null && epubBook.Author!.trim().isNotEmpty) {
        author = epubBook.Author!.trim();
      }

      // Collect illustrations
      if (epubBook.Content?.Images != null) {
        illustrations.addAll(epubBook.Content!.Images.keys);
      }

      int chapterIndex = 0;

      void processChapter(epub.EpubChapter ch) {
        final rawHtml = ch.HtmlContent ?? '';
        final (parsedTitle, plainText) = _extractHtmlText(
          rawHtml,
          defaultTitle: (ch.Title != null && ch.Title!.trim().isNotEmpty)
              ? ch.Title!.trim()
              : '第 ${chapterIndex + 1} 章',
        );

        if (plainText.trim().isNotEmpty) {
          final words = plainText.length;
          totalWords += words;
          chapters.add(ChapterItem(
            index: chapterIndex++,
            title: parsedTitle,
            wordCount: words,
            content: plainText,
          ));
        }

        if (ch.SubChapters != null) {
          for (final sub in ch.SubChapters!) {
            processChapter(sub);
          }
        }
      }

      if (epubBook.Chapters != null) {
        for (final ch in epubBook.Chapters!) {
          processChapter(ch);
        }
      }
    } catch (_) {
      // Fall through to Engine 2
    }

    // ==========================================
    // ENGINE 2: Deep Zip & HTML Fallback Parser
    // ==========================================
    if (chapters.isEmpty) {
      try {
        final archive = ZipDecoder().decodeBytes(bytes);

        // Find all HTML / XHTML / HTM content files
        final contentFiles = <ArchiveFile>[];
        for (final file in archive.files) {
          final nameLower = file.name.toLowerCase().replaceAll('\\', '/');
          if (nameLower.endsWith('.xhtml') ||
              nameLower.endsWith('.html') ||
              nameLower.endsWith('.htm')) {
            // Exclude pure metadata / navigation container if possible
            if (!nameLower.contains('nav.xhtml') && !nameLower.contains('toc.ncx')) {
              contentFiles.add(file);
            }
          }
          if (nameLower.endsWith('.jpg') ||
              nameLower.endsWith('.jpeg') ||
              nameLower.endsWith('.png') ||
              nameLower.endsWith('.webp')) {
            illustrations.add(file.name);
          }
        }

        // Sort naturally
        contentFiles.sort((a, b) => a.name.compareTo(b.name));

        int chapterIndex = 0;
        for (final file in contentFiles) {
          final fileBytes = file.content as List<int>;
          String rawHtml = '';
          try {
            rawHtml = utf8.decode(fileBytes);
          } catch (_) {
            try {
              rawHtml = gbk.decode(fileBytes);
            } catch (_) {
              rawHtml = utf8.decode(fileBytes, allowMalformed: true);
            }
          }

          final (parsedTitle, plainText) = _extractHtmlText(
            rawHtml,
            defaultTitle: '第 ${chapterIndex + 1} 章',
          );

          if (plainText.trim().isNotEmpty && plainText.length > 20) {
            final words = plainText.length;
            totalWords += words;
            chapters.add(ChapterItem(
              index: chapterIndex++,
              title: parsedTitle,
              wordCount: words,
              content: plainText,
            ));
          }
        }
      } catch (_) {}
    }

    // Ensure at least one chapter exists
    if (chapters.isEmpty) {
      chapters.add(ChapterItem(
        index: 0,
        title: title,
        wordCount: 100,
        content: '未能提取此 EPUB 章节文本，或文档结构已受密码保护。',
      ));
      totalWords = 100;
    }

    final volume = BookVolume(
      volumeId: 'V1',
      volumeTitle: '全本',
      chapters: chapters,
    );

    return Book(
      id: 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      title: title,
      author: author,
      format: 'EPUB',
      coverPath: '',
      totalWords: totalWords,
      currentProgress: 0.0,
      currentChapterIndex: 0,
      volumes: [volume],
      illustrations: illustrations,
      lastReadTime: DateTime.now(),
    );
  }

  /// Extracts readable text and title from HTML string
  static (String title, String text) _extractHtmlText(String html, {required String defaultTitle}) {
    String title = defaultTitle;

    // Extract title from <title>, <h1> or <h2>
    final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false).firstMatch(html) ??
        RegExp(r'<h[12][^>]*>(.*?)</h[12]>', caseSensitive: false).firstMatch(html);
    if (titleMatch != null) {
      final candidate = _stripTags(titleMatch.group(1) ?? '').trim();
      if (candidate.isNotEmpty && candidate.length < 60) {
        title = candidate;
      }
    }

    // Convert block elements to newlines
    String content = html
        .replaceAll(RegExp(r'<(br|p|div|h[1-6]|li|tr)[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '');

    content = _stripTags(content);

    // Decode HTML entities
    content = content
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”')
        .replaceAll('&hellip;', '…')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return (title, content);
  }

  static String _stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}
