import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/archival_theme.dart';
import '../../ui/widgets/archive_masthead.dart';

/// External Reading Stopwatch / Timer logging physical paper book sessions into app database.
class ExternalPaperTimerPage extends StatefulWidget {
  const ExternalPaperTimerPage({super.key});

  @override
  State<ExternalPaperTimerPage> createState() => _ExternalPaperTimerPageState();
}

class _ExternalPaperTimerPageState extends State<ExternalPaperTimerPage> {
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isRunning = false;
  final TextEditingController _bookNameController = TextEditingController(text: '纸质书籍阅读');

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _secondsElapsed++);
      });
      setState(() => _isRunning = true);
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _secondsElapsed = 0;
      _isRunning = false;
    });
  }

  void _saveSession() {
    if (_secondsElapsed < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('阅读时长过短，未记录')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已归档纸书阅读记录：${_secondsElapsed ~/ 60} 分钟')),
    );
    Navigator.pop(context, _secondsElapsed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bookNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final minutes = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsElapsed % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: const ArchiveMasthead(
        title: '外挂实体书计时器',
        code: 'TIMER-PAPER-01',
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          children: [
            TextField(
              controller: _bookNameController,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              decoration: InputDecoration(
                labelText: '正在阅读的书名或主题',
                labelStyle: ArchivalTheme.codeStyle(),
                border: const OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            // Large Stopwatch display
            Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.outline,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$minutes:$seconds',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  icon: const Icon(Icons.refresh),
                  iconSize: 28,
                  onPressed: _resetTimer,
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  onPressed: _toggleTimer,
                  icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(_isRunning ? '暂停' : '开始计时'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.onSurface,
                    foregroundColor: scheme.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                ),
                const SizedBox(width: 24),
                IconButton.outlined(
                  icon: const Icon(Icons.check),
                  iconSize: 28,
                  onPressed: _saveSession,
                ),
              ],
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}
