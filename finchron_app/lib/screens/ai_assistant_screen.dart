import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/ai_service.dart';
import '../themes/app_colors.dart';
import '../bloc/transaction/transaction_bloc.dart';
import '../bloc/transaction/transaction_state.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();
  
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
    _addWelcomeMessage();
  }

  void _loadSuggestions() async {
    final suggestions = await _aiService.getSuggestions();
    setState(() {
      _suggestions = suggestions;
    });
  }

  void _addWelcomeMessage() {
    _messages.add(
      ChatMessage(
        text: "Hello! I'm your AI financial assistant. How can I help you with your finances today?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      String response;
      
      // Check if user wants expense analysis
      if (text.toLowerCase().contains('analyze') || 
          text.toLowerCase().contains('analysis') ||
          text.toLowerCase().contains('spending patterns')) {
        final transactionState = context.read<TransactionBloc>().state;
        if (transactionState is TransactionLoaded) {
          final transactions = transactionState.transactions.map((t) => t.toJson()).toList();
          response = await _aiService.analyzeExpenses(transactions);
        } else {
          response = await _aiService.sendMessage(text);
        }
      } else {
        response = await _aiService.sendMessage(text);
      }

      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Sorry, I encountered an error. Please try again.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Financial Assistant'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages.clear();
                _addWelcomeMessage();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Suggestions row
          if (_suggestions.isNotEmpty && _messages.length <= 1)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(
                        _suggestions[index],
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? AppColors.darkText : AppColors.primary,
                        ),
                      ),
                      onPressed: () => _sendMessage(_suggestions[index]),
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                    ),
                  );
                },
              ),
            ),
          
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildLoadingMessage();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          
          // Input field
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: message.isUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.psychology, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? AppColors.primary 
                    : isDarkMode 
                        ? AppColors.darkCard
                        : Colors.grey[100],
                borderRadius: BorderRadius.circular(18),
              ),
              child: message.isUser 
                ? Text(
                    message.text,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  )
                : _buildFormattedText(
                    message.text,
                    isDarkMode,
                  ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: isDarkMode ? AppColors.darkCard : Colors.grey[300],
              child: Icon(
                Icons.person, 
                color: isDarkMode ? AppColors.darkText : Colors.grey, 
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text, bool isDarkMode) {
    final lines = text.split('\n');
    List<Widget> widgets = [];
    
    for (String line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      
      if (line.trim().startsWith('* ')) {
        // Format bullet points
        final bulletText = line.trim().substring(2);
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8, right: 8),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppColors.darkText : Colors.black87,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    bulletText,
                    style: TextStyle(
                      color: isDarkMode ? AppColors.darkText : Colors.black87,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Regular text
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              line,
              style: TextStyle(
                color: isDarkMode ? AppColors.darkText : Colors.black87,
                fontSize: 16,
                height: 1.4,
                fontWeight: line.trim().endsWith(':') || line.trim().endsWith('!') 
                  ? FontWeight.w600 
                  : FontWeight.normal,
              ),
            ),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildLoadingMessage() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.psychology, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.darkCard : Colors.grey[100],
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Thinking...',
                  style: TextStyle(
                    color: isDarkMode ? AppColors.darkText : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(isDarkMode ? 0.3 : 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: TextStyle(
                color: isDarkMode ? AppColors.darkText : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Ask me about your finances...',
                hintStyle: TextStyle(
                  color: isDarkMode ? AppColors.darkSecondaryText : Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDarkMode ? AppColors.darkCard : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: _sendMessage,
              enabled: !_isLoading,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _isLoading 
                  ? null 
                  : () => _sendMessage(_messageController.text),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}