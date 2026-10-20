/// Reading Session record for internal app reading and external physical book timer.
class ReadingSession {
  final String id;
  final String bookId;
  final String bookTitle;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final int wordsRead;
  final bool isExternalPaper; // true: logged via physical paper book stopwatch
  final String note;

  const ReadingSession({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    this.wordsRead = 0,
    this.isExternalPaper = false,
    this.note = '',
  });

  double get readingSpeedCharsPerMin {
    if (durationSeconds <= 0) return 0.0;
    return (wordsRead / (durationSeconds / 60.0));
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'durationSeconds': durationSeconds,
        'wordsRead': wordsRead,
        'isExternalPaper': isExternalPaper,
        'note': note,
      };

  factory ReadingSession.fromMap(Map<String, dynamic> map) => ReadingSession(
        id: map['id'] ?? '',
        bookId: map['bookId'] ?? '',
        bookTitle: map['bookTitle'] ?? '',
        startTime: DateTime.tryParse(map['startTime'] ?? '') ?? DateTime.now(),
        endTime: DateTime.tryParse(map['endTime'] ?? '') ?? DateTime.now(),
        durationSeconds: map['durationSeconds'] ?? 0,
        wordsRead: map['wordsRead'] ?? 0,
        isExternalPaper: map['isExternalPaper'] ?? false,
        note: map['note'] ?? '',
      );
}
