import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../theme/archival_theme.dart';
import '../ui/widgets/archive_code.dart';
import '../ui/widgets/mini_status_bar.dart';
import 'nine_grid_gesture.dart';
import 'illustration_extractor.dart';
import 'pagination_engine.dart';
import '../services/font_service.dart';
import '../services/parsers/txt_parser.dart';
import '../services/parsers/epub_parser.dart';

/// Active Reading Theme Definition (8 Archival & Eye-care Themes)
enum ReaderThemePreset {
  archivalPaper('温润羊皮纸', Color(0xFFF4F3EF), Color(0xFF191919), Color(0xFF8C827A)),
  obsidianDark('曜石暗黑', Color(0xFF191919), Color(0xFFE2E2E2), Color(0xFF4A4A4A)),
  milkWhite('羊脂玉白', Color(0xFFFAFAFA), Color(0xFF222222), Color(0xFF9E9E9E)),
  matchaGreen('护眼豆沙绿', Color(0xFFE9EFE6), Color(0xFF2B3A28), Color(0xFF6B7E68)),
  eInk('水墨墨水屏', Color(0xFFFFFFFF), Color(0xFF000000), Color(0xFF555555)),
  sunsetDusk('暮色晚霞', Color(0xFF2B2527), Color(0xFFEBDDD8), Color(0xFF7A686C)),
  deepSea('深海幽蓝', Color(0xFF151C28), Color(0xFFC9D6E8), Color(0xFF4F627D)),
  morningGlow('雅致晨曦', Color(0xFFF9F6F0), Color(0xFF3D3731), Color(0xFF8F857B));

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color secondaryColor;

  const ReaderThemePreset(this.label, this.backgroundColor, this.textColor, this.secondaryColor);
}

/// Master Reader Viewport featuring on-demand chapter pagination, theme switching, and custom font support.
class ReaderView extends StatefulWidget {
  final Book book;

  const ReaderView({super.key, required this.book});

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Flattened chapters
  late List<ChapterItem> _allChapters;
  int _currentChapterIndex = 0;
  int _currentPageInChapter = 0;
  List<PageSlice> _slices = [];
  PageController _pageController = PageController();

  // Typography & Layout state
  double _fontSize = 18.0;
  double _lineHeight = 1.8;
  double _paragraphSpacing = 8.0;
  String _fontFamily = 'SourceHanSerifCN';
  bool _indentTwoChars = true;
  TextAlign _textAlign = TextAlign.justify;

  // Visual & Colors state
  ReaderThemePreset _currentTheme = ReaderThemePreset.archivalPaper;
  double _brightness = 1.0;
  bool _showBrightnessOverlay = false;
  Timer? _brightnessTimer;
  double _warmFilterOpacity = 0.0; // Amber warm filter 0.0 to 0.4

  // Reading Assist state (Moon+ Reader Eye Health & Auto Turn)
  bool _hudVisible = false;
  bool _autoTurnEnabled = false;
  int _autoTurnSeconds = 15;
  Timer? _autoTurnTimer;
  int _eyeRestMinutes = 45; // 0: disabled, 30, 45, 60
  Timer? _eyeRestTimer;
  int _readingMinutesElapsed = 0;

  // Viewport tracking for instant on-demand pagination
  Size? _lastViewportSize;

  @override
  void initState() {
    super.initState();
    _prepareChapters();
    _startEyeHealthTracker();
    FontService().init();
    _checkAndReloadChaptersIfNeeded();
  }

  Future<void> _checkAndReloadChaptersIfNeeded() async {
    final needsReload = _allChapters.isEmpty ||
        (_allChapters.length == 1 && (_allChapters.first.content == null || _allChapters.first.content!.isEmpty));
    if (needsReload && widget.book.filePath != null && widget.book.filePath!.isNotEmpty) {
      final file = File(widget.book.filePath!);
      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          Book? reloaded;
          if (widget.book.format == 'EPUB') {
            reloaded = await EpubBookParser.parse(bytes: bytes, fileName: widget.book.title);
          } else if (widget.book.format == 'TXT') {
            reloaded = await TxtBookParser.parse(bytes: bytes, fileName: widget.book.title);
          }
          if (reloaded != null && reloaded.volumes.isNotEmpty && reloaded.volumes.first.chapters.isNotEmpty) {
            final list = <ChapterItem>[];
            for (final v in reloaded.volumes) {
              list.addAll(v.chapters);
            }
            if (mounted && list.isNotEmpty) {
              setState(() {
                _allChapters = list;
                _currentChapterIndex = widget.book.currentChapterIndex.clamp(0, _allChapters.length - 1);
              });
              if (_lastViewportSize != null) {
                _paginateCurrentChapter(_lastViewportSize!);
              }
            }
          }
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _brightnessTimer?.cancel();
    _autoTurnTimer?.cancel();
    _eyeRestTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _prepareChapters() {
    final list = <ChapterItem>[];
    for (final volume in widget.book.volumes) {
      list.addAll(volume.chapters);
    }

    if (list.isEmpty) {
      list.add(
        ChapterItem(
          index: 0,
          title: widget.book.title,
          wordCount: 1500,
          content: '本档案卷宗暂未录入更多章节。\n\n文献名称：${widget.book.title}\n文献格式：${widget.book.format}',
        ),
      );
    }

    _allChapters = list;
    _currentChapterIndex = widget.book.currentChapterIndex.clamp(0, _allChapters.length - 1);
  }

  void _startEyeHealthTracker() {
    _eyeRestTimer?.cancel();
    _eyeRestTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _readingMinutesElapsed++;
      if (_eyeRestMinutes > 0 && _readingMinutesElapsed >= _eyeRestMinutes) {
        _readingMinutesElapsed = 0;
        _showEyeRestDialog();
      }
    });
  }

  void _showEyeRestDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _currentTheme.backgroundColor,
        title: Row(
          children: [
            const Icon(Icons.remove_red_eye_outlined, color: Colors.green),
            const SizedBox(width: 8),
            Text('护眼休息提示', style: TextStyle(color: _currentTheme.textColor, fontSize: 16)),
          ],
        ),
        content: Text(
          '您已经专注阅读超过 $_eyeRestMinutes 分钟。\n建议闭目养神或极目远眺 30 秒，缓解睫状肌疲劳。',
          style: TextStyle(color: _currentTheme.textColor, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('我知道了', style: TextStyle(color: _currentTheme.textColor)),
          ),
        ],
      ),
    );
  }

  void _toggleAutoTurn(bool enabled) {
    setState(() => _autoTurnEnabled = enabled);
    _autoTurnTimer?.cancel();
    if (enabled) {
      _autoTurnTimer = Timer.periodic(Duration(seconds: _autoTurnSeconds), (_) {
        if (mounted) _nextPage();
      });
    }
  }

  void _showAutoTurnSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _currentTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '自动翻页速度设置',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _currentTheme.textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: _currentTheme.textColor),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '当前翻页间隔: $_autoTurnSeconds 秒',
                  style: TextStyle(fontSize: 14, color: _currentTheme.textColor),
                ),
                const SizedBox(height: 12),
                Slider(
                  value: _autoTurnSeconds.toDouble(),
                  min: 3,
                  max: 60,
                  divisions: 19,
                  activeColor: _currentTheme.textColor,
                  inactiveColor: _currentTheme.secondaryColor.withValues(alpha: 0.3),
                  onChanged: (v) {
                    setState(() => _autoTurnSeconds = v.round());
                    setSheetState(() {});
                    if (_autoTurnEnabled) _toggleAutoTurn(true);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('极速 (3s)', style: TextStyle(fontSize: 11, color: _currentTheme.secondaryColor)),
                    Text('适中 (15s)', style: TextStyle(fontSize: 11, color: _currentTheme.secondaryColor)),
                    Text('舒缓 (60s)', style: TextStyle(fontSize: 11, color: _currentTheme.secondaryColor)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// On-demand instant pagination for the current chapter only (< 3ms)
  void _paginateCurrentChapter(Size size) {
    if (_allChapters.isEmpty) return;

    final chapter = _allChapters[_currentChapterIndex];
    final text = chapter.content ?? chapter.title;

    final textStyle = TextStyle(
      fontSize: _fontSize,
      height: _lineHeight,
      fontFamily: _fontFamily == 'SourceHanSerifCN'
          ? 'SourceHanSerifCN'
          : (_fontFamily == 'System' ? null : _fontFamily),
      color: _currentTheme.textColor,
    );

    final slices = PaginationEngine.paginateChapter(
      chapterText: text,
      chapterIndex: _currentChapterIndex,
      chapterTitle: chapter.title,
      viewportSize: size,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      textStyle: textStyle,
      indentTwoChars: _indentTwoChars,
    );

    setState(() {
      _slices = slices;
      if (_currentPageInChapter >= _slices.length) {
        _currentPageInChapter = (_slices.length - 1).clamp(0, 9999);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && _pageController.page?.round() != _currentPageInChapter) {
        _pageController.jumpToPage(_currentPageInChapter);
      }
    });
  }

  void _onGridTriggered(GridZone zone, GestureType type) {
    if (type == GestureType.singleTap) {
      if (zone == GridZone.center) {
        setState(() {
          _hudVisible = !_hudVisible;
        });
      } else if (zone == GridZone.centerLeft || zone == GridZone.topLeft || zone == GridZone.bottomLeft) {
        _prevPage();
      } else if (zone == GridZone.centerRight || zone == GridZone.topRight || zone == GridZone.bottomRight) {
        _nextPage();
      }
    }
  }

  void _nextPage() {
    if (_currentPageInChapter < _slices.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    } else if (_currentChapterIndex < _allChapters.length - 1) {
      // Advance to next chapter
      _goToChapter(_currentChapterIndex + 1, startAtLastPage: false);
      _showToast('进入下一章: ${_allChapters[_currentChapterIndex].title}');
    } else {
      _showToast('已到达全书最后一页');
    }
  }

  void _prevPage() {
    if (_currentPageInChapter > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    } else if (_currentChapterIndex > 0) {
      // Revert to previous chapter's end
      _goToChapter(_currentChapterIndex - 1, startAtLastPage: true);
      _showToast('回到上一章: ${_allChapters[_currentChapterIndex].title}');
    } else {
      _showToast('已到达全书开头');
    }
  }

  void _goToChapter(int chapterIndex, {bool startAtLastPage = false}) {
    if (chapterIndex < 0 || chapterIndex >= _allChapters.length) return;
    setState(() {
      _currentChapterIndex = chapterIndex;
      _currentPageInChapter = 0;
    });

    if (_lastViewportSize != null) {
      _paginateCurrentChapter(_lastViewportSize!);
      if (startAtLastPage && _slices.isNotEmpty) {
        setState(() {
          _currentPageInChapter = _slices.length - 1;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_currentPageInChapter);
          }
        });
      }
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black.withValues(alpha: 0.8),
      ),
    );
  }

  void _handleLeftEdgeDrag(DragUpdateDetails details) {
    setState(() {
      _brightness = (_brightness - details.delta.dy / 250.0).clamp(0.15, 1.0);
      _showBrightnessOverlay = true;
    });

    _brightnessTimer?.cancel();
    _brightnessTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _showBrightnessOverlay = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentChapter = _allChapters.isNotEmpty ? _allChapters[_currentChapterIndex] : null;
    final chapterTitle = currentChapter?.title ?? widget.book.title;
    final totalChapters = _allChapters.length;
    final totalPagesInChapter = _slices.isNotEmpty ? _slices.length : 1;
    final overallProgress = totalChapters > 0
        ? (_currentChapterIndex + (_currentPageInChapter + 1) / totalPagesInChapter) / totalChapters
        : 0.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _currentTheme.backgroundColor,
      drawer: _buildTocDrawer(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final currentSize = Size(constraints.maxWidth, constraints.maxHeight - 36.0);
            if (_lastViewportSize == null ||
                (_lastViewportSize!.width - currentSize.width).abs() > 2 ||
                (_lastViewportSize!.height - currentSize.height).abs() > 2) {
              _lastViewportSize = currentSize;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _paginateCurrentChapter(currentSize);
              });
            }

            return Stack(
              children: [
                // Nine Grid Touch Zone & Physical Page Viewer
                NineGridGestureDetector(
                  onZoneTriggered: _onGridTriggered,
                  child: Column(
                    children: [
                      Expanded(
                        child: _slices.isEmpty
                            ? Center(
                                child: Text(
                                  '正在编排页码...',
                                  style: ArchivalTheme.codeStyle(color: _currentTheme.secondaryColor),
                                ),
                              )
                            : PageView.builder(
                                controller: _pageController,
                                itemCount: _slices.length,
                                physics: const BouncingScrollPhysics(),
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentPageInChapter = index;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final slice = _slices[index];
                                  return _buildPageSurface(slice);
                                },
                              ),
                      ),
                      // Moon+ Mini Status Bar
                      MiniStatusBar(
                        chapterTitle: chapterTitle,
                        progressPercent: overallProgress.clamp(0.0, 1.0),
                        currentTime: '${_currentPageInChapter + 1}/$totalPagesInChapter 页',
                      ),
                    ],
                  ),
                ),

                // Left-Edge Brightness Gesture Detector
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 50,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: _handleLeftEdgeDrag,
                  ),
                ),

                // Simulated Screen Dimming Overlay
                if (_brightness < 0.98)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black.withValues(alpha: (1.0 - _brightness) * 0.8),
                      ),
                    ),
                  ),

                // Amber Warm Filter Overlay (0% ~ 40%)
                if (_warmFilterOpacity > 0.01)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: const Color(0xFFFF9800).withValues(alpha: _warmFilterOpacity),
                      ),
                    ),
                  ),

                // Brightness Indicator Toast
                if (_showBrightnessOverlay)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _brightness > 0.5 ? Icons.brightness_7 : Icons.brightness_4,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '屏幕亮度 ${(_brightness * 100).toInt()}%',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Auto Turn Floating Status Pill with Speed Adjustment
                if (_autoTurnEnabled)
                  Positioned(
                    top: 14,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _currentTheme.textColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, size: 14, color: _currentTheme.backgroundColor),
                          const SizedBox(width: 4),
                          // Speed decrement (faster)
                          GestureDetector(
                            onTap: () {
                              final newSpeed = (_autoTurnSeconds - 2).clamp(3, 60);
                              setState(() => _autoTurnSeconds = newSpeed);
                              _toggleAutoTurn(true);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Icon(Icons.remove, size: 13, color: _currentTheme.backgroundColor),
                            ),
                          ),
                          // Tap seconds to open slider modal
                          GestureDetector(
                            onTap: _showAutoTurnSpeedDialog,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3.0),
                              child: Text(
                                '${_autoTurnSeconds}s',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _currentTheme.backgroundColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // Speed increment (slower)
                          GestureDetector(
                            onTap: () {
                              final newSpeed = (_autoTurnSeconds + 2).clamp(3, 60);
                              setState(() => _autoTurnSeconds = newSpeed);
                              _toggleAutoTurn(true);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Icon(Icons.add, size: 13, color: _currentTheme.backgroundColor),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(width: 1, height: 10, color: _currentTheme.backgroundColor.withValues(alpha: 0.4)),
                          const SizedBox(width: 4),
                          // Exit auto-turn
                          GestureDetector(
                            onTap: () => _toggleAutoTurn(false),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: Icon(Icons.close, size: 14, color: _currentTheme.backgroundColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Top HUD Bar
                if (_hudVisible)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildTopHud(context),
                  ),

                // Bottom HUD Controls
                if (_hudVisible)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildBottomHud(context, totalPagesInChapter),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageSurface(PageSlice slice) {
    final baseTextStyle = TextStyle(
      fontSize: _fontSize,
      height: _lineHeight,
      fontFamily: _fontFamily == 'SourceHanSerifCN'
          ? 'SourceHanSerifCN'
          : (_fontFamily == 'System' ? null : _fontFamily),
      color: _currentTheme.textColor,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Text(
        slice.content,
        textAlign: _textAlign,
        style: baseTextStyle,
      ),
    );
  }

  // ==========================================
  // HUD BARS & DRAWER
  // ==========================================

  Widget _buildTopHud(BuildContext context) {
    return Container(
      height: 56.0,
      decoration: BoxDecoration(
        color: _currentTheme.backgroundColor.withValues(alpha: 0.96),
        border: Border(bottom: BorderSide(color: _currentTheme.secondaryColor.withValues(alpha: 0.2))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: _currentTheme.textColor),
            onPressed: () => Navigator.pop(context),
          ),
          IconButton(
            icon: Icon(Icons.menu_book_outlined, color: _currentTheme.textColor),
            tooltip: '目录章节',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _currentTheme.textColor),
                ),
                Text(
                  _allChapters.isNotEmpty ? _allChapters[_currentChapterIndex].title : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: _currentTheme.secondaryColor),
                ),
              ],
            ),
          ),
          // Illustration Gallery button
          IconButton(
            icon: Icon(Icons.photo_library_outlined, color: _currentTheme.textColor),
            tooltip: '全卷插画提取',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IllustrationGalleryPage(
                    bookTitle: widget.book.title,
                    illustrations: widget.book.illustrations,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomHud(BuildContext context, int totalPagesInChapter) {
    return Container(
      decoration: BoxDecoration(
        color: _currentTheme.backgroundColor.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: _currentTheme.secondaryColor.withValues(alpha: 0.2))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slider for progress within chapter
          Row(
            children: [
              Text('${_currentPageInChapter + 1}', style: ArchivalTheme.codeStyle(color: _currentTheme.textColor)),
              Expanded(
                child: Slider(
                  value: (_currentPageInChapter + 1).toDouble().clamp(1.0, totalPagesInChapter.toDouble()),
                  min: 1.0,
                  max: totalPagesInChapter.toDouble() > 1 ? totalPagesInChapter.toDouble() : 1.0,
                  activeColor: _currentTheme.textColor,
                  inactiveColor: _currentTheme.secondaryColor.withValues(alpha: 0.3),
                  onChanged: (val) {
                    final target = val.round() - 1;
                    if (target != _currentPageInChapter) {
                      setState(() => _currentPageInChapter = target);
                      if (_pageController.hasClients) {
                        _pageController.jumpToPage(target);
                      }
                    }
                  },
                ),
              ),
              Text('$totalPagesInChapter', style: ArchivalTheme.codeStyle(color: _currentTheme.textColor)),
            ],
          ),
          // Quick Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildToolButton(
                icon: Icons.list_alt,
                label: '目录',
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              _buildToolButton(
                icon: Icons.format_size,
                label: '字号',
                onTap: () {
                  setState(() {
                    _fontSize = _fontSize >= 26 ? 14 : _fontSize + 2;
                  });
                  if (_lastViewportSize != null) {
                    _paginateCurrentChapter(_lastViewportSize!);
                  }
                },
              ),
              _buildToolButton(
                icon: Icons.play_circle_outline,
                label: _autoTurnEnabled ? '${_autoTurnSeconds}s翻页' : '自动翻页',
                active: _autoTurnEnabled,
                onTap: () {
                  if (!_autoTurnEnabled) {
                    _toggleAutoTurn(true);
                  } else {
                    _showAutoTurnSpeedDialog();
                  }
                },
              ),
              _buildToolButton(
                icon: Icons.tune,
                label: '全部设置',
                active: true,
                onTap: () => _showComprehensiveSettingsModal(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    bool active = false,
    required VoidCallback onTap,
  }) {
    final color = active ? _currentTheme.textColor : _currentTheme.secondaryColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TOC DRAWER
  // ==========================================

  Widget _buildTocDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: _currentTheme.backgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ArchiveCode(widget.book.format, inverse: true),
                  const SizedBox(height: 8),
                  Text(
                    widget.book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _currentTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.book.author} · 共 ${_allChapters.length} 章节',
                    style: TextStyle(fontSize: 12, color: _currentTheme.secondaryColor),
                  ),
                ],
              ),
            ),
            Divider(color: _currentTheme.secondaryColor.withValues(alpha: 0.2), height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _allChapters.length,
                separatorBuilder: (_, __) => Divider(
                  color: _currentTheme.secondaryColor.withValues(alpha: 0.1),
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final chapter = _allChapters[index];
                  final isCurrent = index == _currentChapterIndex;
                  return ListTile(
                    selected: isCurrent,
                    selectedTileColor: _currentTheme.secondaryColor.withValues(alpha: 0.12),
                    title: Text(
                      chapter.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                        color: isCurrent ? _currentTheme.textColor : _currentTheme.textColor.withValues(alpha: 0.85),
                      ),
                    ),
                    subtitle: Text(
                      '${chapter.wordCount} 字',
                      style: TextStyle(fontSize: 11, color: _currentTheme.secondaryColor),
                    ),
                    trailing: isCurrent ? Icon(Icons.bookmark, size: 18, color: _currentTheme.textColor) : null,
                    onTap: () {
                      Navigator.pop(context);
                      _goToChapter(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // MOON+ READER 5-TAB COMPREHENSIVE SETTINGS
  // ==========================================

  void _showComprehensiveSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _currentTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return DefaultTabController(
              length: 3,
              child: Container(
                height: 480,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _currentTheme.secondaryColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Multi-Tab Bar: 视觉排版, 主题色彩, 辅助护眼
                    TabBar(
                      isScrollable: false,
                      labelColor: _currentTheme.textColor,
                      unselectedLabelColor: _currentTheme.secondaryColor,
                      indicatorColor: _currentTheme.textColor,
                      tabs: const [
                        Tab(text: '视觉排版'),
                        Tab(text: '主题色彩'),
                        Tab(text: '辅助护眼'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildTypographyTab(setModalState),
                          _buildThemeTab(setModalState),
                          _buildEyeHealthTab(setModalState),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTypographyTab(StateSetter setModalState) {
    final customFonts = FontService().customFonts;
    final allFonts = ['SourceHanSerifCN', 'System', 'Monospace', ...customFonts];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Font Selection & Custom Font Import
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('阅读字体族', style: TextStyle(fontWeight: FontWeight.bold, color: _currentTheme.textColor)),
            TextButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('导入本地字体', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                final fontName = await FontService().pickAndImportFont();
                if (fontName != null && mounted) {
                  setState(() => _fontFamily = fontName);
                  setModalState(() {});
                  if (_lastViewportSize != null) _paginateCurrentChapter(_lastViewportSize!);
                  _showToast('成功导入并应用字体: $fontName');
                }
              },
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: allFonts.map((font) {
            final isSelected = _fontFamily == font;
            final label = font == 'SourceHanSerifCN'
                ? '思源宋体'
                : (font == 'System' ? '系统黑体' : (font == 'Monospace' ? '机械等宽' : font));
            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _fontFamily = font);
                setModalState(() {});
                if (_lastViewportSize != null) _paginateCurrentChapter(_lastViewportSize!);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Font Size
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('正文字号 (${_fontSize.toInt()}pt)', style: TextStyle(fontWeight: FontWeight.bold, color: _currentTheme.textColor)),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    if (_fontSize > 12) {
                      setState(() => _fontSize -= 1);
                      setModalState(() {});
                      if (_lastViewportSize != null) _paginateCurrentChapter(_lastViewportSize!);
                    }
                  },
                ),
                Text('${_fontSize.toInt()}', style: ArchivalTheme.codeStyle(color: _currentTheme.textColor)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    if (_fontSize < 36) {
                      setState(() => _fontSize += 1);
                      setModalState(() {});
                      if (_lastViewportSize != null) _paginateCurrentChapter(_lastViewportSize!);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        Slider(
          value: _fontSize,
          min: 12,
          max: 36,
          activeColor: _currentTheme.textColor,
          onChanged: (v) {
            setState(() => _fontSize = v);
            setModalState(() {});
            if (_lastViewportSize != null) _paginateCurrentChapter(_lastViewportSize!);
          },
        ),
        const SizedBox(height: 12),

        // Line Height
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('行间距倍率 (${_lineHeight.toStringAsFixed(1)})', style: TextStyle(fontWeight: FontWeight.bold, color: _currentTheme.textColor)),
            Text('${_lineHeight.toStringAsFixed(1)}x', style: ArchivalTheme.codeStyle(color: _currentTheme.textColor)),
          ],
        ),
        Slider(
          value: _lineHeight,
          min: 1.2,
          max: 2.6,
          activeColor: _currentTheme.textColor,
          onChanged: (v) {
            setState(() => _lineHeight = v);
            setModalState(() {});
            if (_lastViewportSize != null) _paginateCurrentChapter(_lastViewportSize!);
          },
        ),
        const SizedBox(height: 12),

        // Indent & Align
        SwitchListTile(
          title: Text('中文首行自动空两全角格', style: TextStyle(color: _currentTheme.textColor)),
          value: _indentTwoChars,
          activeColor: _currentTheme.textColor,
          onChanged: (val) {
            setState(() => _indentTwoChars = val);
            setModalState(() {});
            if (_lastViewportSize != null) _paginateCurrentChapter(_lastViewportSize!);
          },
        ),
        SwitchListTile(
          title: Text('两端分散对齐', style: TextStyle(color: _currentTheme.textColor)),
          value: _textAlign == TextAlign.justify,
          activeColor: _currentTheme.textColor,
          onChanged: (val) {
            setState(() => _textAlign = val ? TextAlign.justify : TextAlign.left);
            setModalState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildThemeTab(StateSetter setModalState) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('内置护眼典藏主题', style: TextStyle(fontWeight: FontWeight.bold, color: _currentTheme.textColor)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ReaderThemePreset.values.map((preset) {
            final isSelected = _currentTheme == preset;
            return GestureDetector(
              onTap: () {
                setState(() => _currentTheme = preset);
                setModalState(() {});
                if (_lastViewportSize != null) _paginateCurrentChapter(_lastViewportSize!);
              },
              child: Container(
                width: 135,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: preset.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.orange : preset.secondaryColor.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      preset.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: preset.textColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Divider(color: _currentTheme.secondaryColor.withValues(alpha: 0.2)),
        const SizedBox(height: 10),

        // Amber Warm Filter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('护眼琥珀暖色滤镜 (${(_warmFilterOpacity * 250).toInt()}%)', style: TextStyle(fontWeight: FontWeight.bold, color: _currentTheme.textColor)),
            Icon(Icons.nightlight_round, size: 18, color: Colors.orange.shade700),
          ],
        ),
        Slider(
          value: _warmFilterOpacity,
          min: 0.0,
          max: 0.4,
          activeColor: Colors.orange,
          onChanged: (val) {
            setState(() => _warmFilterOpacity = val);
            setModalState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildEyeHealthTab(StateSetter setModalState) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Eye health reminder
        Text('长时阅读防疲劳提醒', style: TextStyle(fontWeight: FontWeight.bold, color: _currentTheme.textColor)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [0, 30, 45, 60].map((m) {
            final isSelected = _eyeRestMinutes == m;
            return ChoiceChip(
              label: Text(m == 0 ? '关闭提醒' : '$m 分钟'),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _eyeRestMinutes = m);
                setModalState(() {});
                _startEyeHealthTracker();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Divider(color: _currentTheme.secondaryColor.withValues(alpha: 0.2)),
        const SizedBox(height: 12),

        // Auto Page Turn
        SwitchListTile(
          title: Text('定时自动翻页', style: TextStyle(fontWeight: FontWeight.bold, color: _currentTheme.textColor)),
          subtitle: Text('无需触碰屏幕，按设定间隔时间平稳翻页', style: TextStyle(fontSize: 11, color: _currentTheme.secondaryColor)),
          value: _autoTurnEnabled,
          activeColor: _currentTheme.textColor,
          onChanged: (val) {
            _toggleAutoTurn(val);
            setModalState(() {});
          },
        ),
        if (_autoTurnEnabled) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text('翻页间隔: ${_autoTurnSeconds} 秒', style: TextStyle(fontSize: 12, color: _currentTheme.textColor)),
                Expanded(
                  child: Slider(
                    value: _autoTurnSeconds.toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    activeColor: _currentTheme.textColor,
                    onChanged: (v) {
                      setState(() => _autoTurnSeconds = v.round());
                      setModalState(() {});
                      _toggleAutoTurn(true);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
