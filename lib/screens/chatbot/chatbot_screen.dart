import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/ai_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {"role": "system", "content": AiService.chatSystemPrompt}
  ];
  final List<Map<String, dynamic>> _displayMessages = [];
  bool _isLoading = true;
  bool _contextLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadInitialContext();
  }

  Future<void> _loadInitialContext() async {
    final contextData = await AiService.getGroundingContext();
    if (mounted) {
      setState(() {
        _messages.add({
          "role": "system",
          "content": "GOUNDING USER CONTEXT:\n$contextData\nALWAYS refer to this data if the user asks about their own logs or condition."
        });
        _displayMessages.add({
          "role": "assistant", 
          "content": "Hello! I've synchronized with your latest health logs. I'm ready to discuss your symptoms or cycle. How are you feeling?"
        });
        _isLoading = false;
        _contextLoaded = true;
      });
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || !_contextLoaded) return;

    setState(() {
      _displayMessages.add({"role": "user", "content": text});
      _messages.add({"role": "user", "content": text});
      _controller.clear();
      _isLoading = true;
    });

    final response = await AiService.sendMessage(messages: _messages, isDiet: false);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response != null && response.isNotEmpty) {
          _displayMessages.add({"role": "assistant", "content": response});
          _messages.add({"role": "assistant", "content": response});
        } else {
          _displayMessages.add({"role": "assistant", "content": "Failed to get response."});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('HealthChat AI', style: TextStyle(color: Color(0xFF2E4A6B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF2E4A6B)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _displayMessages.length,
              itemBuilder: (context, index) {
                final msg = _displayMessages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF3A6EA8) : Colors.white,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: isUser
                        ? Text(
                            msg['content'],
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                          )
                        : MarkdownBody(
                            data: msg['content'],
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(color: Color(0xFF1A2B3C), fontSize: 15),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(),
            ),
          _buildInputBox(),
        ],
      ),
    );
  }

  Widget _buildInputBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 5,
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Ask about health, PCOS, symptoms...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF4F6FA),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF3A6EA8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
