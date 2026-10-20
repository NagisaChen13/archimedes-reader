import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/book.dart';
import '../models/reading_session.dart';
import '../services/storage_service.dart';
import '../theme/archival_theme.dart';
import '../ui/widgets/archive_code.dart';
import '../ui/widgets/archive_masthead.dart';

/// Professional Markdown Reader View referencing top GitHub Flutter Markdown projects.
/// Features GitHub Flavored Markdown (GFM), Table of Contents (TOC) Outline,
/// smooth scrolling, custom font scaling, and reading telemetry.
class MarkdownReaderView extends StatefulWidget {
  final Book book;
  final String? filePath;

  const MarkdownReaderView({
    super.key,
    required this.book,
    this.filePath,
  });

  @override
  State<MarkdownReaderView> createState() => _MarkdownReaderViewState();
}

class _MarkdownReaderViewState extends State<MarkdownReaderView> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _content = '';
  bool _isLoading = true;
  double _fontSize = 16.0;
  double _scrollProgress = 0.0;
  double _initialProgress = 0.0;
  DateTime _sessionStart = DateTime.now();

  // Table of Contents entries: (headingText, level, approxLineIndex)
  final List<MarkdownHeading> _headings = [];

  // Reading Themes: 0 = Paper White, 1 = Dark Obsidian, 2 = Sepia Warm, 3 = Eye-Care Mint
  int _themeIndex = 0;
  static const List<_MdTheme> _themes = [
    _MdTheme(
      name: '纸白',
      bg: Color(0xFFF9F9F8),
      text: Color(0xFF1F1F1F),
      codeBg: Color(0xFFEEEEEE),
      accent: Color(0xFF2C3E50),
    ),
    _MdTheme(
      name: '墨夜',
      bg: Color(0xFF141414),
      text: Color(0xFFDDDDDD),
      codeBg: Color(0xFF222222),
      accent: Color(0xFF7F8C8D),
    ),
    _MdTheme(
      name: '羊皮纸',
      bg: Color(0xFFF4ECD8),
      text: Color(0xFF382E1E),
      codeBg: Color(0xFFE8DEBF),
      accent: Color(0xFF8C6D3F),
    ),
    _MdTheme(
      name: '青草护眼',
      bg: Color(0xFFE8F1E5),
      text: Color(0xFF203820),
      codeBg: Color(0xFFD6E4D1),
      accent: Color(0xFF27AE60),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    _scrollProgress = widget.book.currentProgress.clamp(0.0, 1.0);
    _initialProgress = _scrollProgress;
    _loadMarkdownContent();
    _scrollController.addListener(_onScroll);
  }

  int _calculateCurrentCpm() {
    final durationSeconds = DateTime.now().difference(_sessionStart).inSeconds;
    if (durationSeconds < 3) return 0;
    final docWords = widget.book.totalWords > 0 ? widget.book.totalWords : _content.length;
    final progressDelta = (_scrollProgress - _initialProgress).abs();
    int words = (docWords * progressDelta).round();
    if (words < 10) {
      words = math.min(docWords, ((durationSeconds / 60) * 350).round());
    }
    final minutes = durationSeconds / 60.0;
    return minutes > 0 ? (words / minutes).round() : 0;
  }

  @override
  void dispose() {
    _saveReadingProgress();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMarkdownContent() async {
    String text = '';
    try {
      if (widget.filePath != null && widget.filePath!.isNotEmpty) {
        final file = File(widget.filePath!);
        if (await file.exists()) {
          text = await file.readAsString();
        }
      }
    } catch (_) {}

    if (text.isEmpty) {
      final buffer = StringBuffer();
      for (final v in widget.book.volumes) {
        for (final c in v.chapters) {
          buffer.writeln(c.content);
        }
      }
      text = buffer.toString();
    }

    if (text.trim().isEmpty) {
      text = '# ${widget.book.title}\n\n【空文档或暂无文字内容】';
    }

    _extractHeadings(text);

    if (mounted) {
      setState(() {
        _content = text;
        _isLoading = false;
      });

      // Restore scroll progress after initial layout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && widget.book.currentProgress > 0) {
          final max = _scrollController.position.maxScrollExtent;
          if (max > 0) {
            final targetOffset = max * widget.book.currentProgress;
            _scrollController.jumpTo(targetOffset);
          }
        }
      });
    }
  }

  void _extractHeadings(String markdown) {
    _headings.clear();
    final lines = markdown.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#')) {
        int level = 0;
        while (level < line.length && line[level] == '#') {
          level++;
        }
        if (level >= 1 && level <= 6 && level < line.length && line[level] == ' ') {
          final title = line.substring(level).trim();
          _headings.add(MarkdownHeading(
            title: title,
            level: level,
            lineIndex: i,
            totalLines: lines.length,
          ));
        }
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (max > 0) {
      final progress = (current / max).clamp(0.0, 1.0);
      if ((progress - _scrollProgress).abs() > 0.01) {
        setState(() {
          _scrollProgress = progress;
        });
      }
    }
  }

  void _saveReadingProgress() {
    final now = DateTime.now();
    final durationSeconds = now.difference(_sessionStart).inSeconds;

    final updatedBook = widget.book.copyWith(
      currentProgress: _scrollProgress,
      lastReadTime: now,
    );

    // Save book progress
    final library = StorageService().getBooks();
    final idx = library.indexWhere((b) => b.id == widget.book.id);
    if (idx != null && idx >= 0) {
      library[idx] = updatedBook;
      StorageService().saveBooks(library);
    }

    // Record quantified session if read for more than 5 seconds
    if (durationSeconds >= 5) {
      final docWords = widget.book.totalWords > 0 ? widget.book.totalWords : _content.length;
      final progressDelta = (_scrollProgress - _initialProgress).abs();
      int words = (docWords * progressDelta).round();
      if (words < 10) {
        words = math.min(docWords, math.max(15, ((durationSeconds / 60) * 350).round()));
      }
      final pagesRead = math.max(1, (durationSeconds / 30).round());
      final session = ReadingSession(
        id: 'SES-${DateTime.now().millisecondsSinceEpoch}',
        bookId: widget.book.id,
        bookTitle: widget.book.title,
        startTime: _sessionStart,
        endTime: now,
        durationSeconds: durationSeconds,
        pagesRead: pagesRead,
        wordsRead: words,
      );
      StorageService().logSession(session);
    }
  }

  void _scrollToHeading(MarkdownHeading heading) {
    Navigator.pop(context); // Close drawer
    if (!_scrollController.hasClients) return;

    final max = _scrollController.position.maxScrollExtent;
    if (max > 0 && heading.totalLines > 0) {
      final fraction = heading.lineIndex / heading.totalLines;
      final target = (max * fraction).clamp(0.0, max);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showMarkdownSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _themes[_themeIndex].bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final curTheme = _themes[_themeIndex];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '文档阅读排版',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: curTheme.text,
                        ),
                      ),
                      ArchiveCode('MD 排版', inverse: true, fontSize: 9),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Font Size Adjust
                  Row(
                    children: [
                      Icon(Icons.format_size, size: 20, color: curTheme.text),
                      const SizedBox(width: 12),
                      Text('字号大小', style: TextStyle(color: curTheme.text, fontSize: 14)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: curTheme.text,
                        onPressed: _fontSize > 12
                            ? () {
                                setState(() => _fontSize -= 1.0);
                                setSheetState(() {});
                              }
                            : null,
                      ),
                      Text(
                        '${_fontSize.toInt()} pt',
                        style: TextStyle(color: curTheme.text, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: curTheme.text,
                        onPressed: _fontSize < 28
                            ? () {
                                setState(() => _fontSize += 1.0);
                                setSheetState(() {});
                              }
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Theme Palette Selector
                  Text('阅读色彩主题', style: TextStyle(color: curTheme.text, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(_themes.length, (i) {
                      final t = _themes[i];
                      final isSelected = _themeIndex == i;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _themeIndex = i);
                          setSheetState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: t.bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? t.text : Colors.grey.withValues(alpha: 0.4),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: Text(
                            t.name,
                            style: TextStyle(
                              color: t.text,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themes[_themeIndex];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.bg,
      appBar: ArchiveMasthead(
        title: widget.book.title,
        code: 'MD-GFM',
        actions: [
          // Table of Contents / Outline Drawer Trigger
          IconButton(
            icon: const Icon(Icons.toc_outlined),
            tooltip: '文档大纲目录',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          // Reader Settings
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: '排版主题设置',
            onPressed: () => _showMarkdownSettings(context),
          ),
        ],
      ),
      drawer: _buildTocDrawer(context, theme),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: theme.accent),
            )
          : Column(
              children: [
                // Top Progress indicator
                LinearProgressIndicator(
                  value: _scrollProgress.clamp(0.0, 1.0),
                  backgroundColor: theme.codeBg,
                  color: theme.accent,
                  minHeight: 2.5,
                ),

                // Markdown AST Render Body with Real-time Scroll Notification
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.maxScrollExtent > 0) {
                        final progress = (notification.metrics.pixels / notification.metrics.maxScrollExtent).clamp(0.0, 1.0);
                        if ((progress - _scrollProgress).abs() > 0.005) {
                          setState(() {
                            _scrollProgress = progress;
                          });
                        }
                      }
                      return false;
                    },
                    child: SelectionArea(
                      child: Markdown(
                        controller: _scrollController,
                        data: _content,
                        selectable: true,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        styleSheet: _buildMarkdownStyleSheet(theme),
                        onTapLink: (text, href, title) {
                          if (href != null && href.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('链接: $href')),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),

                // Bottom Status Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.bg,
                    border: Border(top: BorderSide(color: theme.codeBg, width: 0.8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '阅读进度: ${(_scrollProgress * 100).toStringAsFixed(0)}%',
                        style: ArchivalTheme.codeStyle(
                          fontSize: 10,
                          color: theme.text.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        '阅读速度: ${_calculateCurrentCpm() > 0 ? '${_calculateCurrentCpm()} 字/分' : '-- 字/分'}',
                        style: ArchivalTheme.codeStyle(
                          fontSize: 10,
                          color: theme.text.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        '总字数: ${widget.book.totalWords > 0 ? widget.book.totalWords : _content.length}',
                        style: ArchivalTheme.codeStyle(
                          fontSize: 10,
                          color: theme.text.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTocDrawer(BuildContext context, _MdTheme theme) {
    return Drawer(
      backgroundColor: theme.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '文档大纲 (${_headings.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.text,
                    ),
                  ),
                  ArchiveCode('TOC', inverse: true, fontSize: 9),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_headings.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  '未检测到 # 标题标记',
                  style: TextStyle(color: theme.text.withValues(alpha: 0.6)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _headings.length,
                  itemBuilder: (context, index) {
                    final h = _headings[index];
                    final indent = (h.level - 1) * 14.0;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.only(left: 16.0 + indent, right: 16.0),
                      title: Text(
                        h.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5 - (h.level * 0.4),
                          fontWeight: h.level <= 2 ? FontWeight.bold : FontWeight.normal,
                          color: theme.text,
                        ),
                      ),
                      onTap: () => _scrollToHeading(h),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(_MdTheme theme) {
    return MarkdownStyleSheet(
      p: TextStyle(
        fontSize: _fontSize,
        height: 1.7,
        color: theme.text,
        letterSpacing: 0.2,
      ),
      h1: TextStyle(
        fontSize: _fontSize + 8,
        fontWeight: FontWeight.w800,
        color: theme.text,
        height: 1.4,
      ),
      h2: TextStyle(
        fontSize: _fontSize + 5,
        fontWeight: FontWeight.w700,
        color: theme.text,
        height: 1.4,
      ),
      h3: TextStyle(
        fontSize: _fontSize + 3,
        fontWeight: FontWeight.w700,
        color: theme.text,
        height: 1.4,
      ),
      h4: TextStyle(
        fontSize: _fontSize + 1,
        fontWeight: FontWeight.w600,
        color: theme.text,
      ),
      h5: TextStyle(
        fontSize: _fontSize,
        fontWeight: FontWeight.w600,
        color: theme.text,
      ),
      h6: TextStyle(
        fontSize: _fontSize - 1,
        fontWeight: FontWeight.w600,
        color: theme.text.withValues(alpha: 0.8),
      ),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: _fontSize - 2,
        backgroundColor: theme.codeBg,
        color: theme.text,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.codeBg,
        borderRadius: BorderRadius.circular(ArchivalTheme.cornerRadius),
        border: Border.all(color: theme.text.withValues(alpha: 0.15), width: 0.8),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote: TextStyle(
        fontSize: _fontSize - 0.5,
        fontStyle: FontStyle.italic,
        color: theme.text.withValues(alpha: 0.85),
      ),
      blockquoteDecoration: BoxDecoration(
        color: theme.codeBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: theme.accent, width: 4)),
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      tableBorder: TableBorder.all(
        color: theme.text.withValues(alpha: 0.25),
        width: 0.8,
        borderRadius: BorderRadius.circular(4),
      ),
      tableHead: TextStyle(
        fontSize: _fontSize - 1,
        fontWeight: FontWeight.bold,
        color: theme.text,
      ),
      tableBody: TextStyle(
        fontSize: _fontSize - 1.5,
        color: theme.text,
      ),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      listBullet: TextStyle(
        fontSize: _fontSize,
        color: theme.text,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.text.withValues(alpha: 0.2), width: 1)),
      ),
    );
  }
}

class MarkdownHeading {
  final String title;
  final int level;
  final int lineIndex;
  final int totalLines;

  MarkdownHeading({
    required this.title,
    required this.level,
    required this.lineIndex,
    required this.totalLines,
  });
}

class _MdTheme {
  final String name;
  final Color bg;
  final Color text;
  final Color codeBg;
  final Color accent;

  const _MdTheme({
    required this.name,
    required this.bg,
    required this.text,
    required this.codeBg,
    required this.accent,
  });
}
