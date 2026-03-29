import 'package:flutter/material.dart';
import 'chatbot_knowledge.dart';

const _brand = Color(0xff215e3f);

/// Mobile chatbot screen – accessible from the drawer.
///
/// Provides a conversational interface for navigating the app
/// and getting step-by-step help on features.
class ChatbotScreen extends StatefulWidget {
  final String currentPage;
  final String? userRole;
  final void Function(String label)? onNavigate;

  const ChatbotScreen({
    super.key,
    this.currentPage = '',
    this.userRole,
    this.onNavigate,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _addBotMessage(
      'Hi! I\'m your HOApp assistant. Ask me anything about using the app, '
      'or tap a suggestion below.',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addBotMessage(String text) {
    _messages.add(_ChatMessage(text: text, isUser: false));
  }

  void _handleSubmit(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text.trim(), isUser: true));
    });
    _controller.clear();

    final results =
        searchTopics(text, userRole: widget.userRole, maxResults: 2);
    if (results.isEmpty) {
      setState(() {
        _addBotMessage(
          'I\'m not sure about that. Try asking about a specific feature like '
          '"How do I book an amenity?" or "How do I pay my dues?".\n\n'
          'You can also tap one of the suggestions below.',
        );
      });
    } else {
      for (final topic in results) {
        setState(() {
          _addBotMessage('**${topic.question}**\n\n${topic.answer}');
          if (topic.navLabel != null && widget.onNavigate != null) {
            _messages.add(_ChatMessage(
              text: 'Go to ${topic.navLabel}',
              isUser: false,
              navLabel: topic.navLabel,
            ));
          }
        });
      }
    }

    _scrollToBottom();
  }

  void _handleSuggestionTap(HelpTopic topic) {
    setState(() {
      _messages.add(_ChatMessage(text: topic.question, isUser: true));
      _addBotMessage('**${topic.question}**\n\n${topic.answer}');
      if (topic.navLabel != null && widget.onNavigate != null) {
        _messages.add(_ChatMessage(
          text: 'Go to ${topic.navLabel}',
          isUser: false,
          navLabel: topic.navLabel,
        ));
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Messages
        Expanded(
          child: GestureDetector(
            onTap: () => _focusNode.unfocus(),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length + 1,
              itemBuilder: (context, index) {
                if (index < _messages.length) {
                  return _buildMessageBubble(_messages[index]);
                }
                return _buildSuggestions();
              },
            ),
          ),
        ),
        // Input bar
        SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: const InputDecoration(
                      hintText: 'Ask me anything...',
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 15),
                    onSubmitted: _handleSubmit,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: _brand),
                  onPressed: () => _handleSubmit(_controller.text),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;
    final isLink = message.navLabel != null;

    if (isLink) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: TextButton.icon(
            onPressed: () {
              widget.onNavigate?.call(message.navLabel!);
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(message.text),
            style: TextButton.styleFrom(
              foregroundColor: _brand,
              textStyle: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? _brand : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 2),
            bottomRight: Radius.circular(isUser ? 2 : 16),
          ),
        ),
        child: _RichAnswerText(text: message.text, isUser: isUser),
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = suggestionsForPage(
      widget.currentPage,
      userRole: widget.userRole,
    );
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: suggestions.map((topic) {
          return ActionChip(
            label: Text(topic.question, style: const TextStyle(fontSize: 12)),
            backgroundColor: _brand.withValues(alpha: 0.08),
            side: BorderSide(color: _brand.withValues(alpha: 0.2)),
            onPressed: () => _handleSuggestionTap(topic),
          );
        }).toList(),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final String? navLabel;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.navLabel,
  });
}

class _RichAnswerText extends StatelessWidget {
  final String text;
  final bool isUser;

  const _RichAnswerText({super.key, required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final color = isUser ? Colors.white : Colors.black87;
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, color: color, height: 1.45),
        children: spans,
      ),
    );
  }
}
