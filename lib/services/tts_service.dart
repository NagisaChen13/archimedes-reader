import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsRole {
  narrator,
  maleLead,
  femaleLead,
  dialogue,
}

/// Offline High-Performance Text-To-Speech (TTS) Service via Native OS Engines (Android TextToSpeech & iOS AVSpeechSynthesizer).
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool isPlaying = false;
  double speed = 1.0;
  bool _initialized = false;
  VoidCallback? onStateChanged;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _flutterTts.setLanguage("zh-CN");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        isPlaying = true;
        onStateChanged?.call();
      });

      _flutterTts.setCompletionHandler(() {
        isPlaying = false;
        onStateChanged?.call();
      });

      _flutterTts.setErrorHandler((msg) {
        isPlaying = false;
        onStateChanged?.call();
      });
      _initialized = true;
    } catch (_) {}
  }

  Future<void> startSpeaking({required String text, TtsRole role = TtsRole.narrator}) async {
    if (text.trim().isEmpty) return;
    await init();
    try {
      final rate = (speed * 0.5).clamp(0.1, 1.0);
      await _flutterTts.setSpeechRate(rate);
      isPlaying = true;
      onStateChanged?.call();
      await _flutterTts.speak(text);
    } catch (_) {
      isPlaying = false;
      onStateChanged?.call();
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    isPlaying = false;
    onStateChanged?.call();
  }
}
