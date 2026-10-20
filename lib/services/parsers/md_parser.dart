import 'dart:convert';
import 'dart:typed_data';
import '../../models/book.dart';

/// Markdown Document Parser extracting chapters by top-level headers (# or ##).
class MdBookParser {
  static Future<Book> parse({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final text = utf8.decode(bytes, allowMalformed: true);
    final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

    final chapters = <ChapterItem>[];
    final lines = text.split('\n');

    String currentTitle = '引言';
    final currentBuffer = StringBuffer();
    int chapterIdx = 0;
    int totalWords = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('# ') || trimmed.startsWith('## ')) {
        if (currentBuffer.isNotEmpty) {
          final content = currentBuffer.toString().trim();
          totalWords += content.length;
          chapters.add(ChapterItem(
            index: chapterIdx++,
            title: currentTitle,
            wordCount: content.length,
            content: content,
          ));
          currentBuffer.clear();
        }
        currentTitle = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
      } else {
        currentBuffer.writeln(line);
      }
    }

    if (currentBuffer.isNotEmpty) {
      final content = currentBuffer.toString().trim();
      totalWords += content.length;
      chapters.add(ChapterItem(
        index: chapterIdx++,
        title: currentTitle,
        wordCount: content.length,
        content: content,
      ));
    }

    if (chapters.isEmpty) {
      chapters.add(ChapterItem(
        index: 0,
        title: '正文',
        wordCount: text.length,
        content: text,
      ));
      totalWords = text.length;
    }

    final volume = BookVolume(
      volumeId: 'V1',
      volumeTitle: '正文大纲',
      chapters: chapters,
    );

    return Book(
      id: 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      title: title,
      author: 'Markdown 笔记',
      format: 'MD',
      coverPath: '',
      totalWords: totalWords,
      currentProgress: 0.0,
      currentChapterIndex: 0,
      volumes: [volume],
      lastReadTime: DateTime.now(),
    );
  }
}
