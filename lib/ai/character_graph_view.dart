import 'package:flutter/material.dart';
import '../../theme/archival_theme.dart';
import '../../ui/widgets/archive_code.dart';
import '../../ui/widgets/archive_masthead.dart';

/// Full-screen Interactive Character Relationship Network Topology Graph.
class CharacterGraphPage extends StatefulWidget {
  final String bookTitle;

  const CharacterGraphPage({super.key, required this.bookTitle});

  @override
  State<CharacterGraphPage> createState() => _CharacterGraphPageState();
}

class _CharacterGraphPageState extends State<CharacterGraphPage> {
  // Sample characters and relations
  final List<CharacterGraphNode> _nodes = [
    CharacterGraphNode(
      id: 'c1',
      name: '寻简少年',
      role: '主角',
      faction: '探寻者',
      bio: '怀揣星环金属吊坠的执着旅人，誓要查明失落星环算法的隐秘真相。',
      position: const Offset(180, 220),
    ),
    CharacterGraphNode(
      id: 'c2',
      name: '守馆老者',
      role: '引导者',
      faction: '秘境档案局',
      bio: '守护大档案馆四十载的神秘守密人，深谙墨痕之下的历史禁忌。',
      position: const Offset(80, 100),
    ),
    CharacterGraphNode(
      id: 'c3',
      name: '星环学者',
      role: '关键配角',
      faction: '学院派',
      bio: '前代算法奠基人，其遗落的手稿引发了整个大陆的搜寻风暴。',
      position: const Offset(280, 110),
    ),
    CharacterGraphNode(
      id: 'c4',
      name: '黑鸦骑士',
      role: '敌对',
      faction: '铁血裁决所',
      bio: '奉命封锁档案馆信息的冷酷追捕者。',
      position: const Offset(180, 360),
    ),
  ];

  CharacterGraphNode? _selectedNode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: ArchiveMasthead(
        title: '${widget.bookTitle} · 角色关系拓扑图谱',
        code: 'GRAPH-NET-01',
      ),
      body: Stack(
        children: [
          // Topology Canvas
          Positioned.fill(
            child: CustomPaint(
              painter: _GraphLinkPainter(
                nodes: _nodes,
                color: scheme.outline,
              ),
            ),
          ),

          // Interactive Node Avatars
          ..._nodes.map((node) {
            final isSelected = _selectedNode?.id == node.id;
            return Positioned(
              left: node.position.dx - 36,
              top: node.position.dy - 36,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedNode = node;
                  });
                },
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: isSelected ? scheme.onSurface : scheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? scheme.surface : scheme.onSurface,
                          width: isSelected ? 2.5 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8.0,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        node.name.substring(0, 2),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? scheme.surface : scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      color: scheme.surface,
                      child: Text(
                        node.role,
                        style: ArchivalTheme.codeStyle(fontSize: 8.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Character Bio Popup Bottom Sheet
          if (_selectedNode != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(ArchivalTheme.cornerRadius),
                  border: Border.all(color: scheme.outline, width: ArchivalTheme.hairlineThickness),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16.0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          _selectedNode!.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        const SizedBox(width: 8),
                        ArchiveCode(_selectedNode!.faction, inverse: true),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => setState(() => _selectedNode = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedNode!.bio,
                      style: ArchivalTheme.serifStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CharacterGraphNode {
  final String id;
  final String name;
  final String role;
  final String faction;
  final String bio;
  final Offset position;

  CharacterGraphNode({
    required this.id,
    required this.name,
    required this.role,
    required this.faction,
    required this.bio,
    required this.position,
  });
}

class _GraphLinkPainter extends CustomPainter {
  final List<CharacterGraphNode> nodes;
  final Color color;

  _GraphLinkPainter({required this.nodes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Connect node 0 to 1, 0 to 2, 0 to 3
    if (nodes.length >= 4) {
      canvas.drawLine(nodes[0].position, nodes[1].position, paint);
      canvas.drawLine(nodes[0].position, nodes[2].position, paint);
      canvas.drawLine(nodes[0].position, nodes[3].position, paint);
      canvas.drawLine(nodes[1].position, nodes[2].position, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
