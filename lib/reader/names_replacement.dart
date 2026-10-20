/// Regex sanitization and character name replacement rule
class ReplacementRule {
  final String id;
  final String pattern;
  final String replacement;
  final bool isRegex;
  final bool enabled;

  const ReplacementRule({
    required this.id,
    required this.pattern,
    required this.replacement,
    this.isRegex = false,
    this.enabled = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'pattern': pattern,
        'replacement': replacement,
        'isRegex': isRegex,
        'enabled': enabled,
      };

  factory ReplacementRule.fromMap(Map<String, dynamic> map) => ReplacementRule(
        id: map['id'] ?? '',
        pattern: map['pattern'] ?? '',
        replacement: map['replacement'] ?? '',
        isRegex: map['isRegex'] ?? false,
        enabled: map['enabled'] ?? true,
      );
}

/// Text Sanitizer and Replacement Engine
class NamesReplacementEngine {
  final List<ReplacementRule> rules;

  NamesReplacementEngine({this.rules = const []});

  String apply(String rawText) {
    if (rules.isEmpty) return rawText;

    String result = rawText;
    for (final rule in rules) {
      if (!rule.enabled || rule.pattern.isEmpty) continue;
      try {
        if (rule.isRegex) {
          final regex = RegExp(rule.pattern, multiLine: true);
          result = result.replaceAll(regex, rule.replacement);
        } else {
          result = result.replaceAll(rule.pattern, rule.replacement);
        }
      } catch (_) {
        // Continue on invalid regex syntax
      }
    }
    return result;
  }

  /// Comparison breakdown returning original line, modified line and diff highlight
  List<ReplacementDiff> previewComparison(String sampleText) {
    final originalLines = sampleText.split('\n');
    final processedLines = apply(sampleText).split('\n');
    final diffs = <ReplacementDiff>[];

    for (int i = 0; i < originalLines.length; i++) {
      final orig = originalLines[i];
      final proc = i < processedLines.length ? processedLines[i] : '';
      if (orig != proc) {
        diffs.add(ReplacementDiff(
          lineNumber: i + 1,
          original: orig,
          replaced: proc,
        ));
      }
    }
    return diffs;
  }
}

class ReplacementDiff {
  final int lineNumber;
  final String original;
  final String replaced;

  const ReplacementDiff({
    required this.lineNumber,
    required this.original,
    required this.replaced,
  });
}
