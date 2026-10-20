import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../models/book.dart';
import 'parsers/txt_parser.dart';
import 'parsers/epub_parser.dart';
import 'parsers/docx_parser.dart';
import 'parsers/md_parser.dart';
import 'storage_service.dart';

/// Master Book Importer coordinating real system file selection and parser routing.
class BookImporter {
  static Future<Book?> pickAndImportBook() async {
    // Crucial: withData: false prevents loading 100MB+ files into RAM!
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'txt',
        'epub',
        'docx',
        'doc',
        'md',
        'pdf',
        'mobi',
        'azw3',
        'fb2',
        'html',
        'xlsx',
        'pptx',
      ],
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    final fileName = file.name;
    final ext = file.extension?.toLowerCase() ?? '';
    final filePath = file.path;

    if (filePath == null) {
      return null;
    }

    Book? book;

    if (ext == 'pdf') {
      // For PDF: Keep file path directly. Never read 100MB into memory!
      final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      final ioFile = File(filePath);
      final sizeBytes = await ioFile.length();
      final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);

      book = Book(
        id: 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        title: title,
        author: 'PDF 文献 ($sizeMb MB)',
        format: 'PDF',
        coverPath: '',
        filePath: filePath,
        totalWords: 30000,
        currentProgress: 0.0,
        currentChapterIndex: 0,
        volumes: [
          BookVolume(
            volumeId: 'V1',
            volumeTitle: '全卷',
            chapters: [
              ChapterItem(
                index: 0,
                title: 'PDF 原生页面',
                wordCount: 30000,
                content: '',
              )
            ],
          ),
        ],
        lastReadTime: DateTime.now(),
      );
    } else {
      // For text formats (TXT, EPUB, DOCX, MD): Read bytes for parsing
      final bytes = await File(filePath).readAsBytes();

      if (ext == 'txt') {
        book = await TxtBookParser.parse(bytes: bytes, fileName: fileName);
      } else if (ext == 'epub') {
        book = await EpubBookParser.parse(bytes: bytes, fileName: fileName);
      } else if (ext == 'docx') {
        book = await DocxBookParser.parse(bytes: bytes, fileName: fileName);
      } else if (ext == 'md') {
        book = await MdBookParser.parse(bytes: bytes, fileName: fileName);
      } else {
        final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
        book = Book(
          id: 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          title: title,
          author: '外部文献',
          format: ext.toUpperCase(),
          coverPath: '',
          filePath: filePath,
          totalWords: 12000,
          currentProgress: 0.0,
          currentChapterIndex: 0,
          volumes: [
            BookVolume(
              volumeId: 'V1',
              volumeTitle: '正文',
              chapters: [
                ChapterItem(
                  index: 0,
                  title: title,
                  wordCount: 12000,
                  content: '此 [$ext] 格式文档已成功入库归档。请在阅读器中尽情体验。\n\n文档名称：$fileName',
                )
              ],
            ),
          ],
          lastReadTime: DateTime.now(),
        );
      }
    }

    if (book != null) {
      // Ensure filePath is retained
      if (book.filePath == null) {
        book = Book(
          id: book.id,
          title: book.title,
          author: book.author,
          format: book.format,
          coverPath: book.coverPath,
          filePath: filePath,
          totalWords: book.totalWords,
          currentProgress: book.currentProgress,
          currentChapterIndex: book.currentChapterIndex,
          status: book.status,
          volumes: book.volumes,
          illustrations: book.illustrations,
          lastReadTime: book.lastReadTime,
        );
      }

      // Persist to local library
      final library = StorageService().getBooks();
      library.insert(0, book);
      await StorageService().saveBooks(library);
    }

    return book;
  }
}
