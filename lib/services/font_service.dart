import 'dart:io';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing custom font loading, dynamic runtime registration, and persistence.
class FontService {
  static final FontService _instance = FontService._internal();
  factory FontService() => _instance;
  FontService._internal();

  final List<String> _customFonts = [];
  List<String> get customFonts => List.unmodifiable(_customFonts);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('custom_fonts') ?? [];
    for (final fontPath in saved) {
      final file = File(fontPath);
      if (await file.exists()) {
        final fontName = file.uri.pathSegments.last.replaceAll(RegExp(r'\.[^.]+$'), '');
        try {
          final bytes = await file.readAsBytes();
          final fontLoader = FontLoader(fontName);
          fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
          await fontLoader.load();
          if (!_customFonts.contains(fontName)) {
            _customFonts.add(fontName);
          }
        } catch (_) {}
      }
    }
  }

  Future<String?> pickAndImportFont() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return null;
    final path = result.files.first.path;
    if (path == null) return null;

    final file = File(path);
    final fontName = file.uri.pathSegments.last.replaceAll(RegExp(r'\.[^.]+$'), '');

    try {
      final bytes = await file.readAsBytes();
      final fontLoader = FontLoader(fontName);
      fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await fontLoader.load();

      if (!_customFonts.contains(fontName)) {
        _customFonts.add(fontName);
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getStringList('custom_fonts') ?? [];
        saved.add(path);
        await prefs.setStringList('custom_fonts', saved);
      }
      return fontName;
    } catch (_) {
      return null;
    }
  }
}
