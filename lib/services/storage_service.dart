import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../models/reading_session.dart';

/// Storage & Persistence Service for Books, Reading History, and Analytics.
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Pre-loaded initial library books if storage is clean
  List<Book> getBooks() {
    final raw = _prefs?.getStringList('user_books');
    if (raw == null || raw.isEmpty) {
      return _defaultSampleLibrary();
    }
    return raw.map((str) => Book.fromJson(str)).toList();
  }

  Future<void> saveBooks(List<Book> books) async {
    final list = books.map((b) => b.toJson()).toList();
    await _prefs?.setStringList('user_books', list);
  }

  List<ReadingSession> getSessions() {
    final raw = _prefs?.getStringList('reading_sessions');
    if (raw == null || raw.isEmpty) return [];
    return raw.map((str) => ReadingSession.fromMap(json.decode(str))).toList();
  }

  Future<void> logSession(ReadingSession session) async {
    final sessions = getSessions();
    sessions.add(session);
    final raw = sessions.map((s) => json.encode(s.toMap())).toList();
    await _prefs?.setStringList('reading_sessions', raw);
  }

  List<Book> _defaultSampleLibrary() {
    return [
      Book(
        id: 'BK-00001',
        title: '阿基米德断简与星环迷宫',
        author: '希帕索斯',
        format: 'EPUB',
        coverPath: '',
        totalWords: 384000,
        currentProgress: 0.35,
        currentChapterIndex: 4,
        illustrations: const [
          'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=600&auto=format&fit=crop',
        ],
        lastReadTime: DateTime.now(),
        volumes: const [
          BookVolume(
            volumeId: 'V1',
            volumeTitle: '第一卷 · 秘境档案之匙',
            chapters: [
              ChapterItem(index: 1, title: '档案馆的晨雾与断简', wordCount: 4200),
              ChapterItem(index: 2, title: '老守馆人的秘密誓约', wordCount: 5100),
              ChapterItem(index: 3, title: '失落的几何回廊', wordCount: 4800),
            ],
          ),
          BookVolume(
            volumeId: 'V2',
            volumeTitle: '第二卷 · 黄金螺旋逆流',
            chapters: [
              ChapterItem(index: 4, title: '浮力定律与虚空之秤', wordCount: 6200),
              ChapterItem(index: 5, title: '机械算盘的低鸣', wordCount: 5400),
            ],
          ),
        ],
      ),
      Book(
        id: 'BK-00002',
        title: '银河尽头的图书手抄本',
        author: '艾萨克·文库',
        format: 'TXT',
        coverPath: '',
        totalWords: 245000,
        currentProgress: 0.12,
        currentChapterIndex: 2,
        lastReadTime: DateTime.now().subtract(const Duration(hours: 18)),
      ),
      Book(
        id: 'BK-00003',
        title: '物理纸张的声音拓扑学',
        author: '声学工坊',
        format: 'MOBI',
        coverPath: '',
        totalWords: 156000,
        currentProgress: 0.88,
        currentChapterIndex: 12,
        lastReadTime: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }
}
