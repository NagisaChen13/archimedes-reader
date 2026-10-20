import 'package:flutter/material.dart';

enum BionicReadingMode {
  disabled,
  englishWordPrefix,
  chinesePhraseHead,
  alternateEmphasis,
}

/// Bionic Reading Parser converting regular text into eye-guiding bolded TextSpans.
class BionicReadingParser {
  static List<TextSpan> parseText({
    required String text,
    required TextStyle baseStyle,
    BionicReadingMode mode = BionicReadingMode.englishWordPrefix,
    FontWeight boldWeight = FontWeight.w900,
  }) {
    if (mode == BionicReadingMode.disabled) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <TextSpan>[];
    final boldStyle = baseStyle.copyWith(fontWeight: boldWeight);

    // Regex splitting into word/cjk tokens and delimiters
    final regex = RegExp(r'([a-zA-Z0-9]+|[\u4e00-\u9fa5]+|[^\s\w]+|\s+)');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      final token = match.group(0) ?? '';
      if (token.isEmpty) continue;

      final firstChar = token.codeUnitAt(0);
      final isAsciiWord = (firstChar >= 65 && firstChar <= 90) ||
          (firstChar >= 97 && firstChar <= 122);
      final isCjk = firstChar >= 0x4e00 && firstChar <= 0x9fa5;

      if (isAsciiWord && mode == BionicReadingMode.englishWordPrefix) {
        // Bold initial 35% ~ 50% of the word
        final pivot = token.length <= 3 ? 1 : (token.length * 0.45).ceil();
        spans.add(TextSpan(text: token.substring(0, pivot), style: boldStyle));
        if (pivot < token.length) {
          spans.add(TextSpan(text: token.substring(pivot), style: baseStyle));
        }
      } else if (isCjk && (mode == BionicReadingMode.chinesePhraseHead || mode == BionicReadingMode.alternateEmphasis)) {
        // CJK bionic focus: bold first character of 2-4 character compounds
        if (token.length == 1) {
          spans.add(TextSpan(text: token, style: baseStyle));
        } else {
          // Bolding head character of semantic blocks
          for (int i = 0; i < token.length; i++) {
            final isHead = (i % 2 == 0);
            spans.add(TextSpan(
              text: token[i],
              style: isHead ? boldStyle : baseStyle,
            ));
          }
        }
      } else {
        spans.add(TextSpan(text: token, style: baseStyle));
      }
    }

    return spans;
  }
}
