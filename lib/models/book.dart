import 'dart:convert';

/// Electronic Book Entity supporting multi-volume aggregation and multi-format metadata.
class Book {
  final String id; // e.g. "BK-00104"
  final String title;
  final String author;
  final String format; // "EPUB", "TXT", "MOBI", "PDF"
  final String coverPath;
  final String? filePath;
  final int totalWords;
  final double currentProgress; // 0.0 to 1.0
  final int currentChapterIndex;
  final int status; // 0: Want to read, 1: Reading, 2: Finished, 3: Dropped
  final List<BookVolume> volumes;
  final List<String> illustrations;
  final DateTime lastReadTime;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.format,
    required this.coverPath,
    this.filePath,
    this.totalWords = 0,
    this.currentProgress = 0.0,
    this.currentChapterIndex = 0,
    this.status = 1,
    this.volumes = const [],
    this.illustrations = const [],
    required this.lastReadTime,
  });

  bool get isSeries => volumes.length > 1;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'format': format,
      'coverPath': coverPath,
      'filePath': filePath,
      'totalWords': totalWords,
      'currentProgress': currentProgress,
      'currentChapterIndex': currentChapterIndex,
      'status': status,
      'volumes': volumes.map((v) => v.toMap()).toList(),
      'illustrations': illustrations,
      'lastReadTime': lastReadTime.toIso8601String(),
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      author: map['author'] ?? '',
      format: map['format'] ?? 'TXT',
      coverPath: map['coverPath'] ?? '',
      filePath: map['filePath'] as String?,
      totalWords: map['totalWords'] ?? 0,
      currentProgress: (map['currentProgress'] as num?)?.toDouble() ?? 0.0,
      currentChapterIndex: map['currentChapterIndex'] ?? 0,
      status: map['status'] ?? 1,
      volumes: (map['volumes'] as List<dynamic>?)
              ?.map((v) => BookVolume.fromMap(v))
              .toList() ??
          const [],
      illustrations: List<String>.from(map['illustrations'] ?? const []),
      lastReadTime: DateTime.tryParse(map['lastReadTime'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
  factory Book.fromJson(String source) => Book.fromMap(json.decode(source));
}

/// Volume definition for series aggregation (e.g. Vol 1, Vol 2...)
class BookVolume {
  final String volumeId;
  final String volumeTitle;
  final List<ChapterItem> chapters;

  const BookVolume({
    required this.volumeId,
    required this.volumeTitle,
    required this.chapters,
  });

  Map<String, dynamic> toMap() => {
        'volumeId': volumeId,
        'volumeTitle': volumeTitle,
        'chapters': chapters.map((c) => c.toMap()).toList(),
      };

  factory BookVolume.fromMap(Map<String, dynamic> map) => BookVolume(
        volumeId: map['volumeId'] ?? '',
        volumeTitle: map['volumeTitle'] ?? '',
        chapters: (map['chapters'] as List<dynamic>?)
                ?.map((c) => ChapterItem.fromMap(c))
                .toList() ??
            const [],
      );
}

/// Chapter metadata and content pointer
class ChapterItem {
  final int index;
  final String title;
  final int wordCount;
  final String? content;

  const ChapterItem({
    required this.index,
    required this.title,
    this.wordCount = 0,
    this.content,
  });

  Map<String, dynamic> toMap() => {
        'index': index,
        'title': title,
        'wordCount': wordCount,
        'content': content,
      };

  factory ChapterItem.fromMap(Map<String, dynamic> map) => ChapterItem(
        index: map['index'] ?? 0,
        title: map['title'] ?? '',
        wordCount: map['wordCount'] ?? 0,
        content: map['content'] as String?,
      );
}
