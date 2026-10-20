import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/archival_theme.dart';
import '../../ui/widgets/archive_masthead.dart';

/// Context-Aware AI Reading Assistant supporting any OpenAI-compatible API.
class AiReadingAssistantPage extends StatefulWidget {
  final String bookTitle;
  final String currentContext;

  const AiReadingAssistantPage({
    super.key,
    required this.bookTitle,
    required this.currentContext,
  });

  @override
  State<AiReadingAssistantPage> createState() => _AiReadingAssistantPageState();
}

class _AiReadingAssistantPageState extends State<AiReadingAssistantPage> {
  final TextEditingController _inputController = TextEditingController();
  final List<AiMessage> _messages = [];
  bool _isLoading = false;

  // Defaults (can be configured in Settings)
  String _baseUrl = 'https://api.openai.com/v1';
  String _apiKey = '';
  String _model = 'gpt-4o-mini';

  @override
  void initState() {
    super.initState();
    _messages.add(AiMessage(
      role: 'assistant',
      content: '我是《${widget.bookTitle}》的驻场 AI 助手。已自动装载当前阅读章节上下文。您可以让我梳理出场角色、总结剧情或翻译生涩词句。',
    ));
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _inputController.clear();

    setState(() {
      _messages.add(AiMessage(role: 'user', content: text));
      _isLoading = true;
    });

    try {
      if (_apiKey.isEmpty) {
        // Fallback simulated intelligent response if API key is not yet set
        await Future.delayed(const Duration(milliseconds: 1000));
        setState(() {
          _messages.add(AiMessage(
            role: 'assistant',
            content: '[当前处于离线演示模式]\n针对当前段落上下文：文本描绘了主角在清晨探访古老档案馆的情境。出场人物包含探寻《阿基米德断简》的少年与掌握星环算法机密的守馆老人。您可在设置中填入 OpenAI 或 DeepSeek API Key 开启全量深度分析。',
          ));
          _isLoading = false;
        });
        return;
      }

      final res = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a literary reading assistant for "${widget.bookTitle}". Current reading passage:\n"""${widget.currentContext}"""',
            },
            ..._messages.map((m) => {'role': m.role, 'content': m.content}),
          ],
        }),
      );

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        final reply = data['choices'][0]['message']['content'] ?? '';
        setState(() {
          _messages.add(AiMessage(role: 'assistant', content: reply));
        });
      } else {
        setState(() {
          _messages.add(AiMessage(role: 'assistant', content: '调用失败: HTTP ${res.statusCode}'));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(AiMessage(role: 'assistant', content: '连接异常: $e'));
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: ArchiveMasthead(
        title: '${widget.bookTitle} · AI 助读',
        code: 'AI-ASSIST-01',
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser ? scheme.onSurface : scheme.surface,
                      borderRadius: BorderRadius.circular(ArchivalTheme.cornerRadius),
                      border: Border.all(color: scheme.outline, width: ArchivalTheme.hairlineThickness),
                    ),
                    child: Text(
                      msg.content,
                      style: TextStyle(
                        fontSize: 14.0,
                        color: isUser ? scheme.surface : scheme.onSurface,
                        height: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              ),
            ),
          // Input bar
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outline, width: ArchivalTheme.hairlineThickness)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: const InputDecoration(
                      hintText: '向 AI 提问当前剧情、出场人物或隐喻...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded),
                  onPressed: () => _sendMessage(_inputController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AiMessage {
  final String role;
  final String content;

  AiMessage({required this.role, required this.content});
}
