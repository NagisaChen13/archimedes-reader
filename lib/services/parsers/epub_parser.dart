import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../../models/book.dart';

/// Full-featured EPUB Ebook Parser extracting metadata, chapters, and illustrations.
class EpubBookParser {
  static Future<Book> parse({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Locate content.opf from META-INF/container.xml
    String opfPath = '';
    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile != null) {
      final xmlDoc = XmlDocument.parse(utf8.decode(containerFile.content as List<int>));
      final rootfile = xmlDoc.findAllElements('rootfile').firstOrNull;
      if (rootfile != null) {
        opfPath = rootfile.getAttribute('full-path') ?? '';
      }
    }

    if (opfPath.isEmpty) {
      // Search for any .opf file in the archive
      for (final f in archive.files) {
        if (f.name.endsWith('.opf')) {
          opfPath = f.name;
          break;
        }
      }
    }

    String title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    String author = '未知作者';
    final chapters = <ChapterItem>[];
    final illustrations = <String>[];
    int totalWords = 0;

    if (opfPath.isNotEmpty) {
      final opfFile = archive.findFile(opfPath);
      if (opfFile != null) {
        final opfDir = opfPath.contains('/')
            ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
            : '';
        final opfXml = XmlDocument.parse(utf8.decode(opfFile.content as List<int>));

        // Metadata extraction
        final titleElem = opfXml.findAllElements('dc:title').firstOrNull;
        if (titleElem != null && titleElem.innerText.trim().isNotEmpty) {
          title = titleElem.innerText.trim();
        }

        final creatorElem = opfXml.findAllElements('dc:creator').firstOrNull;
        if (creatorElem != null && creatorElem.innerText.trim().isNotEmpty) {
          author = creatorElem.innerText.trim();
        }

        // Manifest: map id to href
        final manifestMap = <String, String>{};
        for (final item in opfXml.findAllElements('item')) {
          final id = item.getAttribute('id');
          final href = item.getAttribute('href');
          final mediaType = item.getAttribute('media-type') ?? '';
          if (id != null && href != null) {
            manifestMap[id] = href;
            // Record illustration paths
            if (mediaType.startsWith('image/')) {
              illustrations.add(href);
            }
          }
        }

        // Spine: reading order of chapters
        final spineItems = opfXml.findAllElements('itemref');
        int chapterIndex = 0;

        for (final itemref in spineItems) {
          final idref = itemref.getAttribute('idref');
          if (idref == null) continue;

          final href = manifestMap[idref];
          if (href == null) continue;

          final chapterFilePath = _resolvePath(opfDir, href);
          final chapterFile = archive.findFile(chapterFilePath);
          if (chapterFile != null) {
            final rawHtml = utf8.decode(chapterFile.content as List<int>, allowMalformed: true);
            final (parsedTitle, plainText) = _extractHtmlText(rawHtml, defaultTitle: '第 ${chapterIndex + 1} 章');

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
          }
        }
      }
    }

    if (chapters.isEmpty) {
      chapters.add(ChapterItem(
        index: 0,
        title: '正文',
        wordCount: 100,
        content: '未能提取此 EPUB 章节文本，或文档结构已受密码保护。',
      ));
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

  static String _resolvePath(String baseDir, String relativePath) {
    if (baseDir.isEmpty) return relativePath;
    if (relativePath.startsWith('/')) return relativePath.substring(1);
    return '$baseDir$relativePath';
  }

  /// Extracts readable text and title from HTML string
  static (String title, String text) _extractHtmlText(String html, {required String defaultTitle}) {
    String title = defaultTitle;

    // Extract title from <title>, <h1> or <h2>
    final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false).firstMatch(html) ??
        RegExp(r'<h[12][^>]*>(.*?)</h[12]>', caseSensitive: false).firstMatch(html);
    if (titleMatch != null) {
      final candidate = _stripTags(titleMatch.group(1) ?? '').trim();
      if (candidate.isNotEmpty && candidate.length < 50) {
        title = candidate;
      }
    }

    // Convert block elements to newlines
    String content = html
        .replaceAll(RegExp(r'<(br|p|div|h[1-6]|li)[^>]*>', caseSensitive: false), '\n')
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
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return (title, content);
  }

  static String _stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}
