import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/archival_theme.dart';

/// Floating Liquid Milk Glass Bottom Dock
class LiquidGlassDock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final List<DockItem> items;

  const LiquidGlassDock({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = isDark
        ? const Color(0xFF242424).withValues(alpha: 0.82)
        : ArchivalTheme.milkGlass.withValues(alpha: 0.88);

    final borderColor = isDark
        ? const Color(0xFF3C3C3C).withValues(alpha: 0.8)
        : const Color(0xFFE2DFD7).withValues(alpha: 0.9);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0, left: 24.0, right: 24.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              height: 56.0,
              decoration: BoxDecoration(
                color: glassColor,
                borderRadius: BorderRadius.circular(28.0),
                border: Border.all(color: borderColor, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 16.0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == currentIndex;
                  return _buildDockButton(context, index, item, isSelected);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDockButton(
    BuildContext context,
    int index,
    DockItem item,
    bool isSelected,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final activeColor = scheme.onSurface;
    final inactiveColor = scheme.onSurfaceVariant.withValues(alpha: 0.6);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onItemSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected
              ? (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF3A3A3A).withValues(alpha: 0.65)
                  : Colors.black.withValues(alpha: 0.06))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 20.0,
              color: isSelected ? activeColor : inactiveColor,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6.0),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: activeColor,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DockItem {
  final IconData icon;
  final String label;

  const DockItem({required this.icon, required this.label});
}
