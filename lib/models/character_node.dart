/// Character entity extracted by AI or managed by user for knowledge graphs.
class CharacterNode {
  final String id;
  final String bookId;
  final String name;
  final List<String> aliases;
  final String role; // e.g. "Protagonist", "Antagonist", "Supporting"
  final String faction; // e.g. "Royal Guard", "Rebel Alliance"
  final String bio;
  final String? avatarPath;
  final List<CharacterRelation> relations;

  const CharacterNode({
    required this.id,
    required this.bookId,
    required this.name,
    this.aliases = const [],
    this.role = 'Supporting',
    this.faction = '',
    this.bio = '',
    this.avatarPath,
    this.relations = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'bookId': bookId,
        'name': name,
        'aliases': aliases,
        'role': role,
        'faction': faction,
        'bio': bio,
        'avatarPath': avatarPath,
        'relations': relations.map((r) => r.toMap()).toList(),
      };

  factory CharacterNode.fromMap(Map<String, dynamic> map) => CharacterNode(
        id: map['id'] ?? '',
        bookId: map['bookId'] ?? '',
        name: map['name'] ?? '',
        aliases: List<String>.from(map['aliases'] ?? []),
        role: map['role'] ?? 'Supporting',
        faction: map['faction'] ?? '',
        bio: map['bio'] ?? '',
        avatarPath: map['avatarPath'],
        relations: (map['relations'] as List<dynamic>?)
                ?.map((r) => CharacterRelation.fromMap(r))
                .toList() ??
            const [],
      );
}

class CharacterRelation {
  final String targetCharacterId;
  final String relationType; // "Ally", "Rival", "Family", "Master-Apprentice"
  final String description;

  const CharacterRelation({
    required this.targetCharacterId,
    required this.relationType,
    this.description = '',
  });

  Map<String, dynamic> toMap() => {
        'targetCharacterId': targetCharacterId,
        'relationType': relationType,
        'description': description,
      };

  factory CharacterRelation.fromMap(Map<String, dynamic> map) => CharacterRelation(
        targetCharacterId: map['targetCharacterId'] ?? '',
        relationType: map['relationType'] ?? '',
        description: map['description'] ?? '',
      );
}
