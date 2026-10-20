import 'dart:async';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../theme/archival_theme.dart';
import '../ui/widgets/archive_code.dart';
import '../ui/widgets/mini_status_bar.dart';
import 'acoustic_engine.dart';
import 'bionic_reading.dart';
import 'nine_grid_gesture.dart';
import 'reading_ruler.dart';
import 'illustration_extractor.dart';
import 'pagination_engine.dart';
import '../ai/ai_reading_assistant.dart';
import '../ai/character_graph_view.dart';
import '../services/tts_service.dart';

/// Active Reading Theme Definition
enum ReaderThemePreset {
  archivalPaper('温润羊皮纸', Color(0xFFF4F3EF), Color(0xFF191919), Color(0xFF8C827A)),
  obsidianDark('曜石夜间', Color(0xFF191919), Color(0xFFE2E2E2), Color(0xFF4A4A4A)),
  milkWhite('羊脂玉白', Color(0xFFFAFAFA), Color(0xFF222222), Color(0xFF9E9E9E)),
  matchaGreen('护眼豆沙绿', Color(0xFFE9EFE6), Color(0xFF2B3A28), Color(0xFF6B7E68)),
  eInk('水墨二值', Color(0xFFFFFFFF), Color(0xFF000000), Color(0xFF555555));

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color secondaryColor;

  const ReaderThemePreset(this.label, this.backgroundColor, this.textColor, this.secondaryColor);
}

/// Master Reader Viewport with Unified Multi-Chapter Pagination, Moon+ Gestures, and Archival Aesthetics.
class ReaderView extends StatefulWidget {
  final Book book;

  const ReaderView({super.key, required this.book});

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Flattened list of chapters
  late List<ChapterItem> _allChapters;
  final List<int> _chapterStartingSliceIndex = [];
  List<PageSlice> _allSlices = [];
  int _currentGlobalSliceIndex = 0;
  final PageController _pageController = PageController();

  // Typography & Layout state
  double _fontSize = 18.0;
  double _lineHeight = 1.8;
  String _fontFamily = 'SourceHanSerifCN';
  bool _indentTwoChars = true;
  TextAlign _textAlign = TextAlign.justify;

  // Visual & Brightness state
  ReaderThemePreset _currentTheme = ReaderThemePreset.archivalPaper;
  double _brightness = 1.0;
  bool _showBrightnessOverlay = false;
  Timer? _brightnessTimer;

  // Reading tools
  bool _hudVisible = false;
  bool _rulerVisible = false;
  RulerStyle _rulerStyle = RulerStyle.yellowHighlight;
  BionicReadingMode _bionicMode = BionicReadingMode.disabled;

  // Sound & Acoustics
  late final AcousticEngine _acousticEngine;
  final TtsService _ttsService = TtsService();

  // Viewport tracking for reflow
  Size? _lastViewportSize;

  @override
  void initState() {
    super.initState();
    _acousticEngine = AcousticEngine()..init();
    _prepareChapters();
  }

  @override
  void dispose() {
    _brightnessTimer?.cancel();
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
  }

  /// Paginates all chapters of the book into a unified continuous slice sequence
  void _paginateAllChapters(Size size) {
    if (_allChapters.isEmpty) return;

    final textStyle = TextStyle(
      fontSize: _fontSize,
      height: _lineHeight,
      fontFamily: _fontFamily == 'SourceHanSerifCN' ? 'SourceHanSerifCN' : null,
      color: _currentTheme.textColor,
    );

    final combinedSlices = <PageSlice>[];
    _chapterStartingSliceIndex.clear();

    for (int chIdx = 0; chIdx < _allChapters.length; chIdx++) {
      final chapter = _allChapters[chIdx];
      final text = chapter.content ?? chapter.title;

      _chapterStartingSliceIndex.add(combinedSlices.length);

      final slices = PaginationEngine.paginateChapter(
        chapterText: text,
        chapterIndex: chIdx,
        chapterTitle: chapter.title,
        viewportSize: size,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        textStyle: textStyle,
        indentTwoChars: _indentTwoChars,
      );

      combinedSlices.addAll(slices);
    }

    // If completely empty, add 1 empty fallback slice
    if (combinedSlices.isEmpty) {
      combinedSlices.add(
        PageSlice(
          pageIndex: 0,
          totalPagesInChapter: 1,
          chapterIndex: 0,
          chapterTitle: widget.book.title,
          content: '【无内容】',
          startCharOffset: 0,
          endCharOffset: 0,
        ),
      );
      _chapterStartingSliceIndex.add(0);
    }

    setState(() {
      _allSlices = combinedSlices;
      if (_currentGlobalSliceIndex >= _allSlices.length) {
        _currentGlobalSliceIndex = (_allSlices.length - 1).clamp(0, 99999);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && _pageController.page?.round() != _currentGlobalSliceIndex) {
        _pageController.jumpToPage(_currentGlobalSliceIndex);
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
    } else if (type == GestureType.doubleTap) {
      setState(() {
        _rulerVisible = !_rulerVisible;
      });
    }
  }

  void _nextPage() {
    if (_currentGlobalSliceIndex < _allSlices.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      _acousticEngine.playPageTurnSound();
    } else {
      _showToast('已到达全书最后一页');
    }
  }

  void _prevPage() {
    if (_currentGlobalSliceIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      _acousticEngine.playPageTurnSound();
    } else {
      _showToast('已到达全书开头');
    }
  }

  void _jumpToChapter(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= _chapterStartingSliceIndex.length) return;
    final targetSlice = _chapterStartingSliceIndex[chapterIndex];
    if (targetSlice < _allSlices.length) {
      setState(() {
        _currentGlobalSliceIndex = targetSlice;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(targetSlice);
      }
      _acousticEngine.playPageTurnSound();
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
    final currentSlice = _allSlices.isNotEmpty ? _allSlices[_currentGlobalSliceIndex] : null;
    final chapterTitle = currentSlice?.chapterTitle ?? widget.book.title;
    final totalSlices = _allSlices.isNotEmpty ? _allSlices.length : 1;
    final overallProgress = totalSlices > 0 ? (_currentGlobalSliceIndex + 1) / totalSlices : 0.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _currentTheme.backgroundColor,
      drawer: _buildTocDrawer(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final currentSize = Size(constraints.maxWidth, constraints.maxHeight - 36.0); // reserve for status bar
            if (_lastViewportSize == null ||
                (_lastViewportSize!.width - currentSize.width).abs() > 2 ||
                (_lastViewportSize!.height - currentSize.height).abs() > 2) {
              _lastViewportSize = currentSize;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _paginateAllChapters(currentSize);
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
                        child: _allSlices.isEmpty
                            ? Center(
                                child: Text(
                                  '正在编排物理页码...',
                                  style: ArchivalTheme.codeStyle(color: _currentTheme.secondaryColor),
                                ),
                              )
                            : PageView.builder(
                                controller: _pageController,
                                itemCount: _allSlices.length,
                                physics: const BouncingScrollPhysics(),
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentGlobalSliceIndex = index;
                                  });
                                  _acousticEngine.playPageTurnSound();
                                },
                                itemBuilder: (context, index) {
                                  final slice = _allSlices[index];
                                  return _buildPageSurface(slice);
                                },
                              ),
                      ),
                      // Moon+ Mini Status Bar
                      MiniStatusBar(
                        chapterTitle: chapterTitle,
                        progressPercent: overallProgress.clamp(0.0, 1.0),
                        currentTime: currentSlice != null
                            ? '${currentSlice.pageIndex + 1}/${currentSlice.totalPagesInChapter} 页 (全书 ${indexString()})'
                            : '${_currentGlobalSliceIndex + 1}/$totalSlices 页',
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

                // Reading Ruler Overlay
                ReadingRulerOverlay(
                  visible: _rulerVisible,
                  style: _rulerStyle,
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
                    child: _buildBottomHud(context, totalSlices),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String indexString() => '${_currentGlobalSliceIndex + 1}/${_allSlices.length}';

  Widget _buildPageSurface(PageSlice slice) {
    final baseTextStyle = TextStyle(
      fontSize: _fontSize,
      height: _lineHeight,
      fontFamily: _fontFamily == 'SourceHanSerifCN' ? 'SourceHanSerifCN' : null,
      color: _currentTheme.textColor,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: RichText(
        textAlign: _textAlign,
        text: TextSpan(
          children: BionicReadingParser.parseText(
            text: slice.content,
            baseStyle: baseTextStyle,
            mode: _bionicMode,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HUD BARS & DRAWER
  // ==========================================

  Widget _buildTopHud(BuildContext context) {
    final currentSlice = _allSlices.isNotEmpty ? _allSlices[_currentGlobalSliceIndex] : null;

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
                  currentSlice?.chapterTitle ?? '',
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
          // Character Graph button
          IconButton(
            icon: Icon(Icons.hub_outlined, color: _currentTheme.textColor),
            tooltip: '全书角色关系图谱',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CharacterGraphPage(bookTitle: widget.book.title),
                ),
              );
            },
          ),
          // AI Assistant button
          IconButton(
            icon: Icon(Icons.auto_awesome, color: _currentTheme.textColor),
            tooltip: 'AI 阅读助手',
            onPressed: () {
              final contextSnippet = _allSlices.isNotEmpty ? _allSlices[_currentGlobalSliceIndex].content : '';
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiReadingAssistantPage(
                    bookTitle: widget.book.title,
                    currentContext: contextSnippet,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomHud(BuildContext context, int totalSlices) {
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
          // Slider for progress within the whole book
          Row(
            children: [
              Text('${_currentGlobalSliceIndex + 1}', style: ArchivalTheme.codeStyle(color: _currentTheme.textColor)),
              Expanded(
                child: Slider(
                  value: (_currentGlobalSliceIndex + 1).toDouble().clamp(1.0, totalSlices.toDouble()),
                  min: 1.0,
                  max: totalSlices > 1 ? totalSlices.toDouble() : 1.0,
                  activeColor: _currentTheme.textColor,
                  inactiveColor: _currentTheme.secondaryColor.withValues(alpha: 0.3),
                  onChanged: (val) {
                    final target = val.round() - 1;
                    if (target != _currentGlobalSliceIndex) {
                      setState(() => _currentGlobalSliceIndex = target);
                      if (_pageController.hasClients) {
                        _pageController.jumpToPage(target);
                      }
                    }
                  },
                ),
              ),
              Text('$totalSlices', style: ArchivalTheme.codeStyle(color: _currentTheme.textColor)),
            ],
          ),
          // Tool button bar
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
                    _paginateAllChapters(_lastViewportSize!);
                  }
                },
              ),
              _buildToolButton(
                icon: Icons.straighten,
                label: '标尺',
                active: _rulerVisible,
                onTap: () => setState(() => _rulerVisible = !_rulerVisible),
              ),
              _buildToolButton(
                icon: Icons.visibility_outlined,
                label: '仿生阅读',
                active: _bionicMode != BionicReadingMode.disabled,
                onTap: () {
                  setState(() {
                    _bionicMode = _bionicMode == BionicReadingMode.disabled
                        ? BionicReadingMode.chinesePhraseHead
                        : BionicReadingMode.disabled;
                  });
                },
              ),
              _buildToolButton(
                icon: Icons.volume_up_outlined,
                label: '翻页音',
                active: _acousticEngine.enabled,
                onTap: () {
                  setState(() => _acousticEngine.enabled = !_acousticEngine.enabled);
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
    final currentSlice = _allSlices.isNotEmpty ? _allSlices[_currentGlobalSliceIndex] : null;
    final currentChIdx = currentSlice?.chapterIndex ?? 0;

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
                    '${widget.book.author} · 共 ${_allChapters.length} 章节 · 全书 ${_allSlices.length} 页',
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
                  final isCurrent = index == currentChIdx;
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
                      Navigator.pop(context); // close drawer
                      _jumpToChapter(index);
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
  // COMPREHENSIVE SETTINGS MODAL (MOON+ STYLE)
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
              length: 5,
              child: Container(
                height: 480,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    // Modal Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _currentTheme.secondaryColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Multi-Tab Bar
                    TabBar(
                      isScrollable: true,
                      labelColor: _currentTheme.textColor,
                      unselectedLabelColor: _currentTheme.secondaryColor,
                      indicatorColor: _currentTheme.textColor,
                      tabAlignment: TabAlignment.start,
                      tabs: const [
                        Tab(text: '视觉排版'),
                        Tab(text: '主题色彩'),
                        Tab(text: '翻页音效'),
                        Tab(text: '阅读辅助'),
                        Tab(text: '听书朗读'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildTypographyTab(setModalState),
                          _buildThemeTab(setModalState),
                          _buildTurnSoundTab(setModalState),
                          _buildAssistToolsTab(setModalState),
                          _buildTtsTab(setModalState),
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
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
                      if (_lastViewportSize != null) _paginateAllChapters(_lastViewportSize!);
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
                      if (_lastViewportSize != null) _paginateAllChapters(_lastViewportSize!);
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
            if (_lastViewportSize != null) _paginateAllChapters(_lastViewportSize!);
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('行高倍率 (${_lineHeight.toStringAsFixed(1)})', style: TextStyle(fontWeight: FontWeight.bold, color: _currentTheme.textColor)),
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
            if (_lastViewportSize != null) _paginateAllChapters(_lastViewportSize!);
          },
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: Text('中文首行缩进两全角空格', style: TextStyle(color: _currentTheme.textColor)),
          value: _indentTwoChars,
          activeColor: _currentTheme.textColor,
          onChanged: (val) {
            setState(() => _indentTwoChars = val);
            setModalState(() {});
            if (_lastViewportSize != null) _paginateAllChapters(_lastViewportSize!);
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
          spacing: 12,
          runSpacing: 12,
          children: ReaderThemePreset.values.map((preset) {
            final isSelected = _currentTheme == preset;
            return GestureDetector(
              onTap: () {
                setState(() => _currentTheme = preset);
                setModalState(() {});
                if (_lastViewportSize != null) _paginateAllChapters(_lastViewportSize!);
              },
              child: Container(
                width: 140,
                padding: const EdgeInsets.all(12),
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
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: preset.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '典藏墨痕',
                      style: TextStyle(fontSize: 10, color: preset.secondaryColor),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTurnSoundTab(StateSetter setModalState) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SwitchListTile(
          title: Text('物理纸张翻页音效', style: TextStyle(fontWeight: FontWeight.bold, color: _currentTheme.textColor)),
          value: _acousticEngine.enabled,
          activeColor: _currentTheme.textColor,
          onChanged: (val) {
            setState(() => _acousticEngine.enabled = val);
            setModalState(() {});
          },
        ),
        const SizedBox(height: 12),
        Text('6 款实体纸张高保真采样', style: TextStyle(fontWeight: FontWeight.bold, color: _currentTheme.textColor)),
        const SizedBox(height: 8),
        ...[
          (PageTurnSoundType.book, '经典硬壳书页 (book.wav)'),
          (PageTurnSoundType.magazine, '铜版光滑杂志 (magazine.wav)'),
          (PageTurnSoundType.natural, '纯木浆轻型纸 (natural.wav)'),
          (PageTurnSoundType.quick, '极速沙沙轻翻 (quick.wav)'),
          (PageTurnSoundType.quiet, '静谧微风翻动 (quiet.wav)'),
          (PageTurnSoundType.soft, '柔软棉质羊皮 (soft.wav)'),
        ].map((item) {
          final isSelected = _acousticEngine.currentSound == item.$1;
          return ListTile(
            dense: true,
            title: Text(item.$2, style: TextStyle(color: _currentTheme.textColor)),
            leading: Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? _currentTheme.textColor : _currentTheme.secondaryColor,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.volume_up, size: 18),
              onPressed: () {
                _acousticEngine.currentSound = item.$1;
                _acousticEngine.playPageTurnSound();
              },
            ),
            onTap: () {
              setState(() => _acousticEngine.currentSound = item.$1);
              setModalState(() {});
              _acousticEngine.playPageTurnSound();
            },
          );
        }),
      ],
    );
  }

  Widget _buildAssistToolsTab(StateSetter setModalState) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SwitchListTile(
          title: Text('仿生阅读 (Bionic Reading)', style: TextStyle(fontWeight: FontWeight.bold, color: _currentTheme.textColor)),
          subtitle: Text('词首半段加粗，引导视线快速扫读', style: TextStyle(color: _currentTheme.secondaryColor, fontSize: 11)),
          value: _bionicMode != BionicReadingMode.disabled,
          activeColor: _currentTheme.textColor,
          onChanged: (val) {
            setState(() {
              _bionicMode = val ? BionicReadingMode.chinesePhraseHead : BionicReadingMode.disabled;
            });
            setModalState(() {});
          },
        ),
        const Divider(),
        SwitchListTile(
          title: Text('阅读标尺 (Reading Ruler)', style: TextStyle(fontWeight: FontWeight.bold, color: _currentTheme.textColor)),
          subtitle: Text('聚焦当前正在阅读的行，过滤干扰', style: TextStyle(color: _currentTheme.secondaryColor, fontSize: 11)),
          value: _rulerVisible,
          activeColor: _currentTheme.textColor,
          onChanged: (val) {
            setState(() => _rulerVisible = val);
            setModalState(() {});
          },
        ),
        if (_rulerVisible) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('黄色荧光'),
                  selected: _rulerStyle == RulerStyle.yellowHighlight,
                  onSelected: (_) {
                    setState(() => _rulerStyle = RulerStyle.yellowHighlight);
                    setModalState(() {});
                  },
                ),
                ChoiceChip(
                  label: const Text('下划线导轨'),
                  selected: _rulerStyle == RulerStyle.underlineGuide,
                  onSelected: (_) {
                    setState(() => _rulerStyle = RulerStyle.underlineGuide);
                    setModalState(() {});
                  },
                ),
                ChoiceChip(
                  label: const Text('渐变聚焦条'),
                  selected: _rulerStyle == RulerStyle.cyanFocusBar,
                  onSelected: (_) {
                    setState(() => _rulerStyle = RulerStyle.cyanFocusBar);
                    setModalState(() {});
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTtsTab(StateSetter setModalState) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Column(
            children: [
              IconButton(
                iconSize: 56,
                icon: Icon(
                  _ttsService.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: _currentTheme.textColor,
                ),
                onPressed: () {
                  setState(() {
                    if (_ttsService.isPlaying) {
                      _ttsService.stop();
                    } else {
                      final text = _allSlices.isNotEmpty ? _allSlices[_currentGlobalSliceIndex].content : '';
                      _ttsService.startSpeaking(text: text, role: TtsRole.narrator);
                    }
                  });
                  setModalState(() {});
                },
              ),
              Text(
                _ttsService.isPlaying ? '正在朗读当前页内容...' : '点击开始语音朗读',
                style: TextStyle(fontWeight: FontWeight.bold, color: _currentTheme.textColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('朗读语速 (${_ttsService.speed}x)', style: TextStyle(fontWeight: FontWeight.bold, color: _currentTheme.textColor)),
        Slider(
          value: _ttsService.speed,
          min: 0.5,
          max: 2.0,
          divisions: 6,
          activeColor: _currentTheme.textColor,
          onChanged: (val) {
            setState(() => _ttsService.speed = val);
            setModalState(() {});
          },
        ),
      ],
    );
  }
}
