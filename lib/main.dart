import 'package:flutter/material.dart';
import 'models/book.dart';
import 'services/book_importer.dart';
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
    _refreshBooks();
  }

  void _refreshBooks() {
    setState(() {
      _books = StorageService().getBooks();
    });
  }

  Future<void> _importBook() async {
    try {
      final book = await BookImporter.pickAndImportBook();
      if (book != null && mounted) {
        _refreshBooks();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                ArchiveCode(book.format, inverse: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已成功入库归档: 《${book.title}》',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: '立即阅读',
              onPressed: () => _openReader(book),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入文献失败: $e')),
        );
      }
    }
  }

  void _showBookOptionsModal(Book book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final totalChapters = book.volumes.fold<int>(0, (sum, v) => sum + v.chapters.length);
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
                    ArchiveCode(book.id, inverse: true),
                    ArchiveCode(book.format),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  book.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${book.author} · ${(book.totalWords / 10000).toStringAsFixed(1)}万字 · $totalChapters 章节',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.menu_book),
                  title: const Text('打开阅读器'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openReader(book);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('移出藏书馆', style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final library = StorageService().getBooks();
                    library.removeWhere((b) => b.id == book.id);
                    await StorageService().saveBooks(library);
                    _refreshBooks();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已从藏书架移除: 《${book.title}》')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentTabIndex == 1
          ? null
          : ArchiveMasthead(
              title: _getTabTitle(_currentTabIndex),
              code: _getTabCode(_currentTabIndex),
              actions: [
                if (_currentTabIndex == 0) ...[
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: '导入外部书籍 (TXT/EPUB/PDF/DOCX/MD...)',
                    onPressed: _importBook,
                  ),
                  IconButton(
                    icon: Icon(_isCarouselMode ? Icons.view_agenda_outlined : Icons.view_carousel_outlined),
                    tooltip: _isCarouselMode ? '切换列表视图' : '切换立体轮播',
                    onPressed: () => setState(() => _isCarouselMode = !_isCarouselMode),
                  ),
                ],
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
              StatsDashboardPage(onToggleTheme: widget.onToggleTheme),
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
    if (_books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              const Text(
                '当前典藏架尚无卷宗',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '支持 TXT, EPUB, PDF, MOBI, DOCX, MD, XLSX, PPTX 等多种格式',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onSurface,
                  foregroundColor: Theme.of(context).colorScheme.surface,
                ),
                icon: const Icon(Icons.add),
                label: const Text('导入第一本电子书'),
                onPressed: _importBook,
              ),
            ],
          ),
        ),
      );
    }

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
              onLongPress: () => _showBookOptionsModal(book),
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
          onLongPress: () => _showBookOptionsModal(book),
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
    ).then((_) => _refreshBooks());
  }

  Widget _buildSettingsView(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 90),
      children: [
        const ArchiveSectionHeader(title: '工坊核心设置', code: 'CONF-01'),
        const SizedBox(height: 12),
        _buildSettingTile(
          context,
          title: '3D 仿真真实纸张物理翻页',
          subtitle: '启用物理网格变形及纸张阴影渐变',
          trailing: Switch(value: true, onChanged: (_) {}),
        ),
        _buildSettingTile(
          context,
          title: '云端同步与备份 (WebDAV / 百度网盘 / NAS)',
          subtitle: '同步书签、批注、阅读历史与进度跨端漫游',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showCloudSyncDialog(context),
        ),
        _buildSettingTile(
          context,
          title: 'OpenAI 协议 AI 助手密钥配置',
          subtitle: '已支持 DeepSeek、GPT-4o、Claude 3.5 上下文模型',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showAiKeyDialog(context),
        ),
        _buildSettingTile(
          context,
          title: 'E-Ink 墨水屏二值化黑白模式',
          subtitle: '移除半色调与动画，强制纯黑纯白超高对比度',
          trailing: Switch(value: false, onChanged: (_) {}),
        ),
      ],
    );
  }

  void _showCloudSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('云端同步与数据备份'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('支持多协议跨端同步进度与批注：'),
            const SizedBox(height: 12),
            ListTile(
              dense: true,
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('WebDAV (坚果云 / NAS / Nextcloud)'),
              subtitle: const Text('点击配置服务器 URL 及账号'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.folder_shared_outlined),
              title: const Text('百度网盘开放授权'),
              subtitle: const Text('自动备份书库及阅读档案'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('完成')),
        ],
      ),
    );
  }

  void _showAiKeyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 助手 API 密钥'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'API Base URL',
                hintText: 'https://api.openai.com/v1',
              ),
            ),
            SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('保存')),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
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
      ),
    );
  }
}
