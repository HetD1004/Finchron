import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;

  // Replace with your actual Gemini API key
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  GenerativeModel? _model;
  ChatSession? _chatSession;

  AIService._internal() {
    _initializeGemini();
  }

  void _initializeGemini() {
    if (_apiKey.isEmpty || _apiKey == 'YOUR_GEMINI_API_KEY') {
      print('Gemini API key not configured');
      return;
    }

    try {
      print(
        'Initializing Gemini model with API key: ${_apiKey.substring(0, 10)}...',
      );
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
        systemInstruction: Content.system(
          'You are a helpful financial assistant for the Finchron app. '
          'Help users with budgeting, expense tracking, financial advice, and understanding their spending patterns. '
          'Keep responses concise, actionable, and friendly. '
          'Use emojis and bullet points for better readability. '
          'Do NOT use markdown formatting like **bold** or *italic*. '
          'Use plain text with emojis and bullet points only. '
          'Always provide practical financial advice.',
        ),
      );
      _chatSession = _model!.startChat();
      print('Gemini model initialized successfully');
    } catch (e) {
      print('Failed to initialize Gemini model: $e');
      _model = null;
      _chatSession = null;
    }
  }

  Future<String> sendMessage(
    String message, {
    List<Map<String, dynamic>>? context,
  }) async {
    try {
      // Check if model is initialized, try to reinitialize if not
      if (!_isModelInitialized()) {
        print('Model not initialized, attempting to reinitialize...');
        _initializeGemini();

        // Wait a bit for initialization
        await Future.delayed(const Duration(milliseconds: 500));

        if (!_isModelInitialized()) {
          return 'AI service could not be initialized. Please check your internet connection and API key.';
        }
      }

      // Add context if provided (user's financial data)
      String contextualMessage = message;
      if (context != null && context.isNotEmpty) {
        contextualMessage =
            'Based on my financial data: $context\n\nQuestion: $message';
      }

      print(
        'Sending message to Gemini: ${contextualMessage.substring(0, contextualMessage.length > 50 ? 50 : contextualMessage.length)}...',
      );

      final response = await _chatSession!.sendMessage(
        Content.text(contextualMessage),
      );

      if (response.text != null && response.text!.isNotEmpty) {
        print(
          'Received response from Gemini: ${response.text!.substring(0, response.text!.length > 50 ? 50 : response.text!.length)}...',
        );
        return response.text!.trim();
      } else {
        return 'Sorry, I couldn\'t generate a response. Please try rephrasing your question.';
      }
    } catch (e) {
      print('Gemini AI Service Error: $e');

      if (e.toString().contains('API_KEY') ||
          e.toString().contains('permission')) {
        return 'Invalid API key. Please check your Gemini API key configuration.';
      } else if (e.toString().contains('quota') ||
          e.toString().contains('billing')) {
        return 'API quota exceeded. Please check your billing settings in Google AI Studio.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        return 'Network error. Please check your internet connection and try again.';
      } else if (e.toString().contains('SAFETY')) {
        return 'Sorry, I cannot provide a response to that request. Please try rephrasing your question.';
      }

      return 'Sorry, I\'m having trouble connecting right now. Error: ${e.toString().length > 100 ? e.toString().substring(0, 100) : e.toString()}';
    }
  }

  bool _isModelInitialized() {
    try {
      bool initialized = _model != null && _chatSession != null;
      print('Model initialized: $initialized');
      return initialized;
    } catch (e) {
      print('Error checking model initialization: $e');
      return false;
    }
  }

  // Method to test API key and connectivity
  Future<bool> testConnection() async {
    try {
      if (!_isModelInitialized()) {
        _initializeGemini();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!_isModelInitialized()) {
        return false;
      }

      final response = await _chatSession!.sendMessage(
        Content.text('Hello, are you working?'),
      );

      return response.text != null && response.text!.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> getSuggestions() async {
    return [
      'How can I create a monthly budget?',
      'What are some ways to save money?',
      'Help me analyze my spending patterns',
      'Tips for reducing expenses',
      'How to build an emergency fund?',
      'Investment advice for beginners',
    ];
  }

  Future<String> analyzeExpenses(
    List<Map<String, dynamic>> transactions,
  ) async {
    if (transactions.isEmpty) {
      return 'You don\'t have any transactions to analyze yet. Start by adding some expenses to get personalized insights!';
    }

    // Simple analysis of expenses
    double totalExpenses = 0;
    Map<String, double> categoryTotals = {};

    for (var transaction in transactions) {
      if (transaction['type'] == 'expense') {
        double amount = (transaction['amount'] as num).toDouble();
        totalExpenses += amount;

        String category = transaction['category'] ?? 'Other';
        categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
      }
    }

    if (totalExpenses == 0) {
      return 'No expense transactions found. Add some expenses to get detailed analysis!';
    }

    // Find top category
    String topCategory = categoryTotals.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    double topCategoryAmount = categoryTotals[topCategory]!;
    double topCategoryPercentage = (topCategoryAmount / totalExpenses) * 100;

    return 'Expense Analysis:\n\n'
        '💰 Total Expenses: \$${totalExpenses.toStringAsFixed(2)}\n'
        '📊 Top Category: $topCategory (${topCategoryPercentage.toStringAsFixed(1)}%)\n'
        '💡 Tip: Consider reviewing your $topCategory expenses for potential savings opportunities.';
  }
}
