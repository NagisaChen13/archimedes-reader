import 'package:flutter/material.dart';
import 'models/book.dart';
import 'services/storage_service.dart';
import 'theme/archival_theme.dart';
import 'ui/widgets/archive_code.dart';
import 'ui/widgets/archive_masthead.dart';
import 'ui/widgets/archive_registration.dart';
import 'ui/widgets/liquid_glass_dock.dart';
import 'reader/reader_view.dart';
import 'stats/stats_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService().init();
  runApp(const ArchimedesApp());
}

class ArchimedesApp extends StatefulWidget {
  const ArchimedesApp({super.key});

  @override
  State<ArchimedesApp> createState() => _ArchimedesAppState();
}

class _ArchimedesAppState extends State<ArchimedesApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Archimedes Reader',
      debugShowCheckedModeBanner: false,
      theme: ArchivalTheme.lightTheme(),
      darkTheme: ArchivalTheme.darkTheme(),
      themeMode: _themeMode,
      home: MasterHomeScreen(onToggleTheme: _toggleTheme),
    );
  }
}

class MasterHomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const MasterHomeScreen({super.key, required this.onToggleTheme});

  @override
  State<MasterHomeScreen> createState() => _MasterHomeScreenState();
}

class _MasterHomeScreenState extends State<MasterHomeScreen> {
  int _currentTabIndex = 0;
  bool _isCarouselMode = false;
  late List<Book> _books;

  @override
  void initState() {
    super.initState();
    _books = StorageService().getBooks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ArchiveMasthead(
        title: _getTabTitle(_currentTabIndex),
        code: _getTabCode(_currentTabIndex),
        actions: [
          if (_currentTabIndex == 0)
            IconButton(
              icon: Icon(_isCarouselMode ? Icons.view_agenda_outlined : Icons.view_carousel_outlined),
              tooltip: _isCarouselMode ? '切换列表视图' : '切换立体轮播',
              onPressed: () => setState(() => _isCarouselMode = !_isCarouselMode),
            ),
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            tooltip: '切换昼夜暗室',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentTabIndex,
            children: [
              _buildBookshelfView(context),
              const StatsDashboardPage(),
              _buildSettingsView(context),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LiquidGlassDock(
              currentIndex: _currentTabIndex,
              onItemSelected: (index) => setState(() => _currentTabIndex = index),
              items: const [
                DockItem(icon: Icons.book_outlined, label: '书库档案'),
                DockItem(icon: Icons.analytics_outlined, label: '量化统计'),
                DockItem(icon: Icons.tune_outlined, label: '工坊配置'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTabTitle(int index) => switch (index) {
        0 => '典藏档案馆 · 藏书架',
        1 => '量化阅读中心',
        2 => '工坊全局设置',
        _ => '阿基米德阅读器',
      };

  String _getTabCode(int index) => switch (index) {
        0 => 'SHELF-ROOT-01',
        1 => 'STATS-HUB-01',
        2 => 'CONFIG-SYS-01',
        _ => 'ROOT',
      };

  Widget _buildBookshelfView(BuildContext context) {
    if (_isCarouselMode) {
      return _buildCarouselShelf(context);
    }
    return _buildListShelf(context);
  }

  Widget _buildCarouselShelf(BuildContext context) {
    return PageView.builder(
      controller: PageController(viewportFraction: 0.72),
      itemCount: _books.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final book = _books[index];
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 40.0),
            child: GestureDetector(
              onTap: () => _openReader(book),
              child: ArchiveRegistration(
                inset: 3.0,
                child: Container(
                  height: 420,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(ArchivalTheme.cornerRadius),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: ArchivalTheme.hairlineThickness,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 18.0,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ArchiveCode(book.id, inverse: true),
                          ArchiveCode(book.format),
                        ],
                      ),
                      const Spacer(),
                      if (book.isSeries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Text(
                            '[${book.volumes.length} 卷全系合集]',
                            style: ArchivalTheme.codeStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        book.author,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: book.currentProgress,
                        backgroundColor: Theme.of(context).colorScheme.outline,
                        color: Theme.of(context).colorScheme.onSurface,
                        minHeight: 2.5,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '阅读进度: ${(book.currentProgress * 100).toInt()}%',
                        style: ArchivalTheme.codeStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListShelf(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 90),
      itemCount: _books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final book = _books[index];
        return GestureDetector(
          onTap: () => _openReader(book),
          child: ArchiveRegistration(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(ArchivalTheme.cornerRadius),
                border: Border.all(color: scheme.outline, width: ArchivalTheme.hairlineThickness),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      book.format,
                      style: ArchivalTheme.codeStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ArchiveCode(book.id),
                            if (book.isSeries) ...[
                              const SizedBox(width: 6),
                              ArchiveCode('${book.volumes.length}卷合并', inverse: true, fontSize: 8),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${book.author} · ${(book.totalWords / 10000).toStringAsFixed(1)}万字',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openReader(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderView(book: book)),
    );
  }

  Widget _buildSettingsView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 90),
      children: [
        const ArchiveSectionHeader(title: '工坊核心设置', code: 'CONF-01'),
        const SizedBox(height: 12),
        _buildSettingTile(
          context,
          title: '3D OpenGL 纸张弯曲形变翻页',
          subtitle: '启用网格顶点变形（Mesh3D）物理渲染仿真纸页',
          trailing: Switch(value: true, onChanged: (_) {}),
        ),
        _buildSettingTile(
          context,
          title: '6 款真实纸张翻页音效',
          subtitle: '当前预设：经典书本 (book.wav)',
          trailing: const Icon(Icons.chevron_right),
        ),
        _buildSettingTile(
          context,
          title: '9 宫格屏幕触控映射',
          subtitle: '自定义 3×3 屏幕区域单双击与长按功能',
          trailing: const Icon(Icons.chevron_right),
        ),
        _buildSettingTile(
          context,
          title: 'OpenAI 协议 AI 密钥配置',
          subtitle: '已支持 DeepSeek、GPT-4o、Claude 3.5 上下文模型',
          trailing: const Icon(Icons.chevron_right),
        ),
        _buildSettingTile(
          context,
          title: 'E-Ink 墨水屏二值化模式',
          subtitle: '移除所有半色调与动画，强制纯黑纯白输出',
          trailing: Switch(value: false, onChanged: (_) {}),
        ),
      ],
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(ArchivalTheme.cornerRadius),
        border: Border.all(color: scheme.outline, width: ArchivalTheme.hairlineThickness),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
