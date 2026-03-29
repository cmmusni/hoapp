import 'package:flutter/material.dart';
import 'chatbot_knowledge.dart';

/// A floating help-chatbot widget that overlays the app.
///
/// Shows a FAB that expands into a chat panel. Users can type questions
/// or tap suggested topics to get contextual help.
class ChatbotWidget extends StatefulWidget {
  /// Current page identifier (e.g. 'announcements', 'billing').
  final String? currentPage;

  /// User's role for role-based topic filtering.
  final String? userRole;

  /// Optional callback when user taps a navigation link.
  /// Receives the route suffix (e.g. '/announcements').
  final void Function(String route)? onNavigate;

  const ChatbotWidget({
    super.key,
    this.currentPage,
    this.userRole,
    this.onNavigate,
  });

  @override
  State<ChatbotWidget> createState() => _ChatbotWidgetState();
}

class _ChatbotWidgetState extends State<ChatbotWidget> {
  bool _isOpen = false;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  static const _brand = Color(0xff215e3f);

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
          if (topic.route != null && widget.onNavigate != null) {
            _messages.add(_ChatMessage(
              text: 'Go to this page →',
              isUser: false,
              route: topic.route,
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
      if (topic.route != null && widget.onNavigate != null) {
        _messages.add(_ChatMessage(
          text: 'Go to this page →',
          isUser: false,
          route: topic.route,
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
    return Stack(
      children: [
        if (_isOpen)
          Positioned(
            right: 16,
            bottom: 80,
            child: _buildChatPanel(context),
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'chatbot_fab',
            onPressed: () => setState(() => _isOpen = !_isOpen),
            backgroundColor: _brand,
            child: Icon(
              _isOpen ? Icons.close : Icons.support_agent,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatPanel(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final panelHeight = (screenHeight * 0.55).clamp(280.0, 480.0);
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth < 500 ? screenWidth - 32 : 380.0;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: panelWidth,
        height: panelHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: _brand,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'HOApp Assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _isOpen = false),
                    child: const Icon(Icons.close,
                        color: Colors.white70, size: 20),
                  ),
                ],
              ),
            ),
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    return _buildMessageBubble(_messages[index]);
                  }
                  return _buildSuggestions();
                },
              ),
            ),
            // Input
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Ask me anything...',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 14),
                      onSubmitted: _handleSubmit,
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: _brand),
                    onPressed: () => _handleSubmit(_controller.text),
                    iconSize: 22,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;
    final isLink = message.route != null;

    if (isLink) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: TextButton.icon(
            onPressed: () {
              widget.onNavigate?.call(message.route!);
              setState(() => _isOpen = false);
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(message.text),
            style: TextButton.styleFrom(
              foregroundColor: _brand,
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? _brand : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 2),
            bottomRight: Radius.circular(isUser ? 2 : 14),
          ),
        ),
        child: _RichAnswerText(
          text: message.text,
          isUser: isUser,
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = suggestionsForContext(
      currentPage: widget.currentPage,
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
  final String? route;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.route,
  });
}

class _RichAnswerText extends StatelessWidget {
  final String text;
  final bool isUser;

  const _RichAnswerText({required this.text, required this.isUser});

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
        style: TextStyle(fontSize: 13.5, color: color, height: 1.45),
        children: spans,
      ),
    );
  }
}
