import 'package:flutter/material.dart';
import '../../theme/archival_theme.dart';

/// Machine-stamped archival identification code (e.g. `BK-00412`, `SEC-09`).
class ArchiveCode extends StatelessWidget {
  final String text;
  final bool inverse;
  final Color? color;
  final double fontSize;

  const ArchiveCode(
    this.text, {
    super.key,
    this.inverse = false,
    this.color,
    this.fontSize = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textWidget = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: ArchivalTheme.codeStyle(
        fontSize: fontSize,
        color: color ?? (inverse ? scheme.surface : scheme.onSurfaceVariant),
      ),
    );

    if (inverse) {
      return Container(
        color: scheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: textWidget,
      );
    }

    return textWidget;
  }
}

/// Archival Section Title with rule divider and black micro square endpoint.
class ArchiveSectionHeader extends StatelessWidget {
  final String title;
  final String code;

  const ArchiveSectionHeader({
    super.key,
    required this.title,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            ArchiveCode(code),
            const SizedBox(width: 8),
            Expanded(
              child: Divider(
                height: 1,
                thickness: ArchivalTheme.hairlineThickness,
                color: scheme.outline,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 3.5,
              height: 3.5,
              color: scheme.onSurface,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
