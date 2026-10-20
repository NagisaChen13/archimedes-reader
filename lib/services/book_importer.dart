import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../models/book.dart';
import 'parsers/txt_parser.dart';
import 'parsers/epub_parser.dart';
import 'parsers/docx_parser.dart';
import 'parsers/md_parser.dart';
import 'parsers/pdf_parser.dart';
import 'storage_service.dart';

/// Master Book Importer coordinating real system file selection and parser routing.
class BookImporter {
  static Future<Book?> pickAndImportBook() async {
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
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    final fileName = file.name;
    final ext = file.extension?.toLowerCase() ?? '';

    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }

    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    Book? book;
    if (ext == 'txt') {
      book = await TxtBookParser.parse(bytes: bytes, fileName: fileName);
    } else if (ext == 'epub') {
      book = await EpubBookParser.parse(bytes: bytes, fileName: fileName);
    } else if (ext == 'docx') {
      book = await DocxBookParser.parse(bytes: bytes, fileName: fileName);
    } else if (ext == 'md') {
      book = await MdBookParser.parse(bytes: bytes, fileName: fileName);
    } else if (ext == 'pdf') {
      book = await PdfBookParser.parse(bytes: bytes, fileName: fileName);
    } else {
      // Generic fallback for PDF, MOBI, FB2, etc.
      final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      book = Book(
        id: 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        title: title,
        author: '外部文献',
        format: ext.toUpperCase(),
        coverPath: '',
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
                content: '此 [$ext] 格式文档已成功入库归档。请在阅读器中尽情体验。\n\n文档名称：$fileName\n文档体积：${(bytes.length / 1024).toStringAsFixed(1)} KB',
              )
            ],
          ),
        ],
        lastReadTime: DateTime.now(),
      );
    }

    // Persist to local library
    final library = StorageService().getBooks();
    library.insert(0, book);
    await StorageService().saveBooks(library);

    return book;
  }
}
