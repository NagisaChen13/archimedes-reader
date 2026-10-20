import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../../models/book.dart';

/// Word DOCX Parser extracting paragraphs and headings from OpenXML.
class DocxBookParser {
  static Future<Book> parse({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.findFile('word/document.xml');

    String title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final chapters = <ChapterItem>[];
    int totalWords = 0;

    if (docFile != null) {
      final xmlDoc = XmlDocument.parse(utf8.decode(docFile.content as List<int>, allowMalformed: true));
      final paragraphs = xmlDoc.findAllElements('w:p');

      String currentChapterTitle = '第一部分';
      final currentBuffer = StringBuffer();
      int chapterIdx = 0;

      for (final p in paragraphs) {
        // Check if paragraph is Heading
        final isHeading = p.findAllElements('w:pStyle').any((s) {
          final val = s.getAttribute('w:val') ?? '';
          return val.toLowerCase().contains('heading') || val.toLowerCase().contains('title');
        });

        // Collect text runs in this paragraph
        final pText = p.findAllElements('w:t').map((t) => t.innerText).join();

        if (isHeading && pText.trim().isNotEmpty && pText.length < 60) {
          // If we had buffered content, save previous chapter
          if (currentBuffer.isNotEmpty) {
            final content = currentBuffer.toString().trim();
            totalWords += content.length;
            chapters.add(ChapterItem(
              index: chapterIdx++,
              title: currentChapterTitle,
              wordCount: content.length,
              content: content,
            ));
            currentBuffer.clear();
          }
          currentChapterTitle = pText.trim();
        } else if (pText.trim().isNotEmpty) {
          currentBuffer.writeln('    $pText\n');
        }
      }

      if (currentBuffer.isNotEmpty) {
        final content = currentBuffer.toString().trim();
        totalWords += content.length;
        chapters.add(ChapterItem(
          index: chapterIdx++,
          title: currentChapterTitle,
          wordCount: content.length,
          content: content,
        ));
      }
    }

    if (chapters.isEmpty) {
      chapters.add(ChapterItem(
        index: 0,
        title: '文档正文',
        wordCount: 10,
        content: '未能提取此 DOCX 文本内容。',
      ));
    }

    final volume = BookVolume(
      volumeId: 'V1',
      volumeTitle: '全篇',
      chapters: chapters,
    );

    return Book(
      id: 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      title: title,
      author: 'Office 文档',
      format: 'DOCX',
      coverPath: '',
      totalWords: totalWords,
      currentProgress: 0.0,
      currentChapterIndex: 0,
      volumes: [volume],
      lastReadTime: DateTime.now(),
    );
  }
}
