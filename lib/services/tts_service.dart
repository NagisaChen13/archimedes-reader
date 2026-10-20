enum TtsRole {
  narrator,
  maleLead,
  femaleLead,
  dialogue,
}

/// Multi-Role Dramatized Text-To-Speech (TTS) Service.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  bool isPlaying = false;
  double speed = 1.0;
  String currentVoice = 'zh-CN-XiaoxiaoNeural';

  // Role-to-voice mapping table
  final Map<TtsRole, String> roleVoiceMap = {
    TtsRole.narrator: 'zh-CN-YunxiNeural', // Calm narrator
    TtsRole.maleLead: 'zh-CN-YunjianNeural', // Firm male protagonist
    TtsRole.femaleLead: 'zh-CN-XiaoyiNeural', // Gentle female protagonist
    TtsRole.dialogue: 'zh-CN-XiaoxiaoNeural',
  };

  Future<void> startSpeaking({required String text, required TtsRole role}) async {
    isPlaying = true;
    final selectedVoice = roleVoiceMap[role] ?? currentVoice;
    // Dispatches SSML synthesis request to Edge-TTS or local TTS engine
    // In actual build, connects to WebSocket wss://speech.platform.bing.com or system engine
  }

  Future<void> stop() async {
    isPlaying = false;
  }
}
