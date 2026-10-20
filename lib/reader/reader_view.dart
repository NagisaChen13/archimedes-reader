import 'package:flutter/material.dart';
import '../models/book.dart';
import '../theme/archival_theme.dart';
import '../ui/widgets/mini_status_bar.dart';
import 'acoustic_engine.dart';
import 'bionic_reading.dart';
import 'nine_grid_gesture.dart';
import 'reading_ruler.dart';
import 'illustration_extractor.dart';
import '../ai/ai_reading_assistant.dart';
import '../ai/character_graph_view.dart';

/// The Master Reader Viewport integrating Moon+ gestures, acoustic audio, and archival styling.
class ReaderView extends StatefulWidget {
  final Book book;

  const ReaderView({super.key, required this.book});

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  bool _hudVisible = false;
  bool _rulerVisible = false;
  double _fontSize = 18.0;
  double _lineHeight = 1.8;
  BionicReadingMode _bionicMode = BionicReadingMode.disabled;
  RulerStyle _rulerStyle = RulerStyle.yellowHighlight;

  int _currentPage = 1;
  final int _totalPages = 48;
  late final AcousticEngine _acousticEngine;

  // Sample reading passage
  final String _sampleChapterContent = '''
那是一个被晨雾笼罩的古老档案馆。
阳光穿透穹顶高悬的毛玻璃窗，将细碎的光斑投射在斑驳的羊皮纸与古旧书脊之上。
少年缓缓推开沉重的黄铜大门，空气中弥漫着油墨、木质纤维与微凉空气混合的奇异气息。

“你终于来了。”
守馆人沙哑的声音从高耸的红木书架深处传来。他手中托着一盏微弱的煤油灯，火光在他枯槁的面容上勾勒出深邃的阴影。

“我一直在寻找《阿基米德断简》的下落，”少年握紧了胸前的金属吊坠，低声说道，“传说中记录着失落星环算法的原本。”

老者轻轻合上手中的巨大皮质册页，发出沉闷而清脆的声响。
“世间所有深邃的真理，从不写在喧嚣的广场，而静静沉睡于这片沉默的墨痕之中。若想翻开它，你必须先学会如何注视。”

窗外的风掠过尖顶钟楼，远方传来了低沉而悠长的鸣响。新的卷轴已然展开，而命运的齿轮，正以不可逆转的轨迹悄然咬合。
''';

  @override
  void initState() {
    super.initState();
    _acousticEngine = AcousticEngine()..init();
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
      // Double tap toggles reading ruler
      setState(() {
        _rulerVisible = !_rulerVisible;
      });
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages) {
      setState(() => _currentPage++);
      _acousticEngine.playPageTurnSound();
    }
  }

  void _prevPage() {
    if (_currentPage > 1) {
      setState(() => _currentPage--);
      _acousticEngine.playPageTurnSound();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseTextStyle = ArchivalTheme.serifStyle(
      fontSize: _fontSize,
      height: _lineHeight,
      color: scheme.onSurface,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // 9-Square Grid Touch Detector & Reader Text Surface
            NineGridGestureDetector(
              onZoneTriggered: _onGridTriggered,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: RichText(
                          text: TextSpan(
                            children: BionicReadingParser.parseText(
                              text: _sampleChapterContent,
                              baseStyle: baseTextStyle,
                              mode: _bionicMode,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Moon+ Mini Status Bar
                  MiniStatusBar(
                    chapterTitle: '第一卷 · 档案馆的晨雾与断简',
                    progressPercent: _currentPage / _totalPages,
                    currentTime: '14:35',
                  ),
                  const SizedBox(height: 6),
                ],
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
                child: _buildBottomHud(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHud(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 56.0,
      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          // Illustration Gallery button
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
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
            icon: const Icon(Icons.hub_outlined),
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
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'AI 阅读助手',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiReadingAssistantPage(
                    bookTitle: widget.book.title,
                    currentContext: _sampleChapterContent,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomHud(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.96),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slider for progress
          Row(
            children: [
              Text('$_currentPage', style: ArchivalTheme.codeStyle()),
              Expanded(
                child: Slider(
                  value: _currentPage.toDouble(),
                  min: 1,
                  max: _totalPages.toDouble(),
                  activeColor: scheme.onSurface,
                  inactiveColor: scheme.outline,
                  onChanged: (val) {
                    setState(() => _currentPage = val.round());
                  },
                ),
              ),
              Text('$_totalPages', style: ArchivalTheme.codeStyle()),
            ],
          ),
          // Tool button bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildToolButton(
                icon: Icons.format_size,
                label: '字号',
                onTap: () {
                  setState(() {
                    _fontSize = _fontSize >= 24 ? 14 : _fontSize + 2;
                  });
                },
              ),
              _buildToolButton(
                icon: Icons.straighten,
                label: '标尺',
                active: _rulerVisible,
                onTap: () {
                  setState(() => _rulerVisible = !_rulerVisible);
                },
              ),
              _buildToolButton(
                icon: Icons.visibility,
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
                label: '翻页音效',
                active: _acousticEngine.enabled,
                onTap: () {
                  setState(() {
                    _acousticEngine.enabled = !_acousticEngine.enabled;
                  });
                },
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
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
