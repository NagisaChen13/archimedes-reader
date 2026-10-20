import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../models/character_node.dart';
import '../theme/archival_theme.dart';
import '../ui/widgets/archive_code.dart';
import '../ui/widgets/archive_masthead.dart';

/// Full-screen Interactive Character Relationship Network Topology Graph.
/// Dynamically extracts or maintains characters specifically bound to each Book.
class CharacterGraphPage extends StatefulWidget {
  final Book book;

  const CharacterGraphPage({super.key, required this.book});

  @override
  State<CharacterGraphPage> createState() => _CharacterGraphPageState();
}

class _CharacterGraphPageState extends State<CharacterGraphPage> {
  final List<CharacterDisplayNode> _nodes = [];
  CharacterDisplayNode? _selectedNode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrExtractCharacters();
  }

  Future<void> _loadOrExtractCharacters() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'character_graph_${widget.book.id}';
    final cached = prefs.getString(cacheKey);

    if (cached != null) {
      try {
        final list = (jsonDecode(cached) as List)
            .map((e) => CharacterNode.fromMap(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          _layoutNodes(list);
          setState(() => _isLoading = false);
          return;
        }
      } catch (_) {}
    }

    // Dynamically extract characters from this specific book's text
    final extracted = _extractCharactersFromBook(widget.book);
    _layoutNodes(extracted);
    await _saveNodes(extracted);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNodes(List<CharacterNode> nodes) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'character_graph_${widget.book.id}';
    final jsonStr = jsonEncode(nodes.map((n) => n.toMap()).toList());
    await prefs.setString(cacheKey, jsonStr);
  }

  List<CharacterNode> _extractCharactersFromBook(Book book) {
    final fullTextBuffer = StringBuffer();
    for (final v in book.volumes) {
      for (final c in v.chapters) {
        fullTextBuffer.writeln(c.content);
        if (fullTextBuffer.length > 300000) break; // Scan up to 300k chars for performance
      }
      if (fullTextBuffer.length > 300000) break;
    }
    final text = fullTextBuffer.toString();

    // Frequency map for candidate names
    final nameCounts = <String, int>{};

    // 1. Match dialogue speech patterns: e.g. "..."张三说, "..."李四道, "..."王五笑
    final speechRegex = RegExp(r'[”"」][\s，,]*([\u4e00-\u9fa5]{2,4})(?:说|道|问|叹|笑|喝|喊|答|想|喃喃)');
    for (final m in speechRegex.allMatches(text)) {
      final name = m.group(1);
      if (name != null && _isValidChineseName(name)) {
        nameCounts[name] = (nameCounts[name] ?? 0) + 1;
      }
    }

    // 2. Scan for titles: e.g. 掌门, 教授, 姑娘, 先生, 陛下, 师兄, 师妹, 盟主
    final titleRegex = RegExp(r'([\u4e00-\u9fa5]{2,4})(?:先生|姑娘|教授|掌门|陛下|师兄|师弟|师妹|尊者|将军)');
    for (final m in titleRegex.allMatches(text)) {
      final name = m.group(1);
      if (name != null && _isValidChineseName(name)) {
        nameCounts[name] = (nameCounts[name] ?? 0) + 1;
      }
    }

    // Sort by occurrence frequency
    final sorted = nameCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Pick top characters (at most 7)
    final topCandidates = sorted.take(7).toList();

    if (topCandidates.isEmpty) {
      // Fallback: derive representative figures from book metadata or generate clean starter nodes
      return [
        CharacterNode(
          id: 'c1',
          bookId: book.id,
          name: book.author.isNotEmpty && book.author != '未知作者' ? '${book.author} (著记)' : '第一视角叙述者',
          role: '核心主角',
          faction: '主角阵营',
          bio: '《${book.title}》文本记录中的关键观察与叙述核心。',
        ),
        CharacterNode(
          id: 'c2',
          bookId: book.id,
          name: '书中人物',
          role: '关键配角',
          faction: '旅伴同行',
          bio: '陪伴叙述者参与书中事件发展的同行者。',
          relations: const [
            CharacterRelation(targetCharacterId: 'c1', relationType: '同行', description: '共同经历故事起伏'),
          ],
        ),
      ];
    }

    final result = <CharacterNode>[];
    for (int i = 0; i < topCandidates.length; i++) {
      final entry = topCandidates[i];
      final id = 'c${i + 1}';
      final role = i == 0 ? '第一主角' : (i == 1 ? '核心同伴' : (i == 2 ? '重要角色' : '登场人物'));
      final faction = (i % 2 == 0) ? '正义阵营' : '探索阵营';

      // Build relations to protagonist or previous node
      final relations = <CharacterRelation>[];
      if (i > 0) {
        relations.add(CharacterRelation(
          targetCharacterId: 'c1',
          relationType: i == 1 ? '挚友/同盟' : (i % 2 == 0 ? '对手/交集' : '同行'),
          description: '在故事主线中频繁产生交集与对话',
        ));
      }

      result.add(CharacterNode(
        id: id,
        bookId: book.id,
        name: entry.key,
        role: role,
        faction: faction,
        bio: '《${book.title}》正文中登场频次达 ${entry.value} 次的重要人物。',
        relations: relations,
      ));
    }
    return result;
  }

  bool _isValidChineseName(String name) {
    final stopWords = {
      '什么', '怎么', '这里', '那里', '我们', '你们', '他们', '自己', '大家', '忽然', '突然',
      '只见', '听见', '如果', '虽然', '但是', '然后', '最后', '此时', '这时', '片刻', '不过'
    };
    return !stopWords.contains(name) && name.length >= 2 && name.length <= 4;
  }

  void _layoutNodes(List<CharacterNode> nodes) {
    _nodes.clear();
    final center = const Offset(200, 260);
    final count = nodes.length;

    for (int i = 0; i < count; i++) {
      final n = nodes[i];
      Offset pos;
      if (i == 0) {
        pos = center; // Protagonist in center
      } else {
        final angle = (2 * math.pi / (count - 1)) * (i - 1) - (math.pi / 2);
        final radius = 130.0 + (i % 2 == 0 ? 15.0 : -15.0);
        pos = Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        );
      }
      _nodes.add(CharacterDisplayNode(
        node: n,
        position: pos,
      ));
    }
  }

  void _addNewCharacterDialog() {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: '登场角色');
    final bioCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增角色节点'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '角色姓名')),
            const SizedBox(height: 8),
            TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: '角色定位 (主角/对手/同行)')),
            const SizedBox(height: 8),
            TextField(controller: bioCtrl, decoration: const InputDecoration(labelText: '生平与剧情简要')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                final newId = 'c${_nodes.length + 1}';
                final newNode = CharacterNode(
                  id: newId,
                  bookId: widget.book.id,
                  name: nameCtrl.text.trim(),
                  role: roleCtrl.text.trim(),
                  bio: bioCtrl.text.trim(),
                  relations: _nodes.isNotEmpty
                      ? [CharacterRelation(targetCharacterId: _nodes.first.node.id, relationType: '同行')]
                      : const [],
                );
                final updatedList = _nodes.map((d) => d.node).toList()..add(newNode);
                _layoutNodes(updatedList);
                _saveNodes(updatedList);
                setState(() {});
                Navigator.pop(ctx);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: ArchiveMasthead(
        title: '${widget.book.title} · 角色拓扑',
        code: 'CHARACTERS',
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: '新增角色',
            onPressed: _addNewCharacterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: '重新根据文本解析',
            onPressed: () async {
              setState(() => _isLoading = true);
              final extracted = _extractCharactersFromBook(widget.book);
              _layoutNodes(extracted);
              await _saveNodes(extracted);
              setState(() => _isLoading = false);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Network Link Lines
                CustomPaint(
                  size: Size.infinite,
                  painter: _GraphLinkPainter(
                    nodes: _nodes,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
                ),

                // Interactive Nodes
                ..._nodes.map((dNode) {
                  final isSelected = _selectedNode == dNode;
                  return Positioned(
                    left: dNode.position.dx - 45,
                    top: dNode.position.dy - 45,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedNode = dNode;
                        });
                        _showNodeDetails(context, dNode);
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          dNode.position += details.delta;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? scheme.onSurface : scheme.surface,
                          border: Border.all(
                            color: isSelected ? scheme.surface : scheme.outline,
                            width: isSelected ? 2.5 : ArchivalTheme.hairlineThickness,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: scheme.onSurface.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dNode.node.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? scheme.surface : scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dNode.node.role,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: isSelected
                                    ? scheme.surface.withValues(alpha: 0.8)
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Bottom Hint
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(ArchivalTheme.cornerRadius),
                      border: Border.all(color: scheme.outline, width: ArchivalTheme.hairlineThickness),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '共识别 ${_nodes.length} 位核心角色 · 可长按拖拽调整排布',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                        ArchiveCode('${widget.book.format} 拓扑', inverse: true, fontSize: 9),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showNodeDetails(BuildContext context, CharacterDisplayNode dNode) {
    final scheme = Theme.of(context).colorScheme;
    final n = dNode.node;
    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(n.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ArchiveCode(n.role, inverse: true),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '所属阵营: ${n.faction.isEmpty ? "中立" : n.faction}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const Divider(height: 24),
              Text(
                n.bio,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              if (n.relations.isNotEmpty) ...[
                const Text('主要人际羁绊与关联：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                ...n.relations.map((r) {
                  final target = _nodes.firstWhere(
                    (d) => d.node.id == r.targetCharacterId,
                    orElse: () => _nodes.first,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• 对 ${target.node.name}：[${r.relationType}] ${r.description}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class CharacterDisplayNode {
  final CharacterNode node;
  Offset position;

  CharacterDisplayNode({required this.node, required this.position});
}

class _GraphLinkPainter extends CustomPainter {
  final List<CharacterDisplayNode> nodes;
  final Color color;

  _GraphLinkPainter({required this.nodes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final idToNode = {for (var d in nodes) d.node.id: d};

    for (final source in nodes) {
      for (final rel in source.node.relations) {
        final target = idToNode[rel.targetCharacterId];
        if (target != null) {
          canvas.drawLine(source.position, target.position, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphLinkPainter oldDelegate) => true;
}
