import 'package:flutter/material.dart';
import '../../theme/archival_theme.dart';
import 'archive_code.dart';

/// Top bar masthead with high-contrast badge stamp (e.g., `[ARCH]`) and title.
class ArchiveMasthead extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? code;
  final List<Widget>? actions;

  const ArchiveMasthead({
    super.key,
    required this.title,
    this.code,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60.0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Container(
        height: 60.0,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            bottom: BorderSide(
              color: scheme.outline,
              width: ArchivalTheme.hairlineThickness,
            ),
          ),
        ),
        child: Row(
          children: [
            // Black rectangular brand badge stamp
            Container(
              width: 32,
              height: 34,
              alignment: Alignment.center,
              color: scheme.onSurface,
              child: Text(
                'ARC',
                style: TextStyle(
                  color: scheme.surface,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (code != null && code!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    ArchiveCode(code!, fontSize: 9.5),
                  ],
                ],
              ),
            ),
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }
}
