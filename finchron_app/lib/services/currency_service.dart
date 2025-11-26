import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  static const String _currencyKey = 'selected_currency';

  // Currency configurations
  static const Map<String, Map<String, String>> currencies = {
    'USD': {'symbol': '\$', 'name': 'US Dollar', 'code': 'USD'},
    'EUR': {'symbol': '€', 'name': 'Euro', 'code': 'EUR'},
    'GBP': {'symbol': '£', 'name': 'British Pound', 'code': 'GBP'},
    'INR': {'symbol': '₹', 'name': 'Indian Rupee', 'code': 'INR'},
    'CAD': {'symbol': 'C\$', 'name': 'Canadian Dollar', 'code': 'CAD'},
    'AUD': {'symbol': 'A\$', 'name': 'Australian Dollar', 'code': 'AUD'},
  };

  String _currentCurrency = 'USD';

  String get currentCurrency => _currentCurrency;
  String get currentSymbol => currencies[_currentCurrency]?['symbol'] ?? '\$';
  String get currentName =>
      currencies[_currentCurrency]?['name'] ?? 'US Dollar';
  List<String> get availableCurrencies => currencies.keys.toList();

  Future<void> loadSavedCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentCurrency = prefs.getString(_currencyKey) ?? 'USD';
    } catch (e) {
      _currentCurrency = 'USD';
    }
  }

  Future<void> setCurrency(String currency) async {
    if (currencies.containsKey(currency)) {
      _currentCurrency = currency;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_currencyKey, currency);
      } catch (e) {
        // Handle error if needed
      }
    }
  }

  String formatAmount(double amount) {
    return '$currentSymbol${amount.toStringAsFixed(2)}';
  }
}
