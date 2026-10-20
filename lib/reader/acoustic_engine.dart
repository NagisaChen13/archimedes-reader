import 'package:audioplayers/audioplayers.dart';

enum PageTurnSoundType {
  none,
  book,
  magazine,
  natural,
  quick,
  quiet,
  soft,
}

/// Acoustic Page-Turn Engine handling physical paper sound feedback.
class AcousticEngine {
  static final AcousticEngine _instance = AcousticEngine._internal();
  factory AcousticEngine() => _instance;
  AcousticEngine._internal();

  final AudioPlayer _player = AudioPlayer();
  bool enabled = true;
  PageTurnSoundType currentSound = PageTurnSoundType.book;

  Future<void> init() async {
    await _player.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> playPageTurnSound({double velocity = 1.0}) async {
    if (!enabled || currentSound == PageTurnSoundType.none) return;

    final fileName = switch (currentSound) {
      PageTurnSoundType.book => 'book.wav',
      PageTurnSoundType.magazine => 'magazine.wav',
      PageTurnSoundType.natural => 'natural.wav',
      PageTurnSoundType.quick => 'quick.wav',
      PageTurnSoundType.quiet => 'quiet.wav',
      PageTurnSoundType.soft => 'soft.wav',
      PageTurnSoundType.none => null,
    };

    if (fileName == null) return;

    try {
      // Dynamic volume modulation based on swipe speed
      final vol = (0.5 + (velocity / 2000.0) * 0.5).clamp(0.3, 1.0);
      await _player.setVolume(vol);
      await _player.play(AssetSource('audio/$fileName'));
    } catch (_) {
      // Fail gracefully if audio driver is busy or muted
    }
  }

  void dispose() {
    _player.dispose();
  }
}
