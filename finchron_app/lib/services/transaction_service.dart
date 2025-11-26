import '../models/transaction.dart';
import 'hybrid_data_service.dart';

class TransactionService {
  static final TransactionService _instance = TransactionService._internal();
  factory TransactionService() => _instance;
  TransactionService._internal();

  final HybridDataService _hybridDataService = HybridDataService();
  
  // Caching variables
  List<Transaction>? _cachedTransactions;
  DateTime? _lastCacheTime;
  bool _isInitialized = false;
  
  // Cache duration in milliseconds (5 seconds)
  static const int _cacheDuration = 5000;

  // Initialize the service (only once)
  Future<void> initialize() async {
    if (!_isInitialized) {
      await _hybridDataService.initialize();
      _isInitialized = true;
    }
  }
  
  // Clear cache when data is modified
  void _clearCache() {
    _cachedTransactions = null;
    _lastCacheTime = null;
  }
  
  // Check if cache is valid
  bool _isCacheValid() {
    if (_cachedTransactions == null || _lastCacheTime == null) {
      return false;
    }
    
    final now = DateTime.now();
    final diff = now.difference(_lastCacheTime!).inMilliseconds;
    return diff < _cacheDuration;
  }

  // Create a new transaction
  Future<Transaction> createTransaction(Transaction transaction) async {
    try {
      final createdTransaction = await _hybridDataService.createTransaction(
        amount: transaction.amount,
        type: transaction.type.toString().split('.').last,
        category: transaction.category.toString().split('.').last,
        description: transaction.notes,
        date: transaction.date,
      );
      
      // Clear cache since data has changed
      _clearCache();
      
      return createdTransaction;
    } catch (e) {
      print('Error creating transaction: $e');
      throw Exception('Failed to create transaction: $e');
    }
  }

  // Add a new transaction (alias for createTransaction for backward compatibility)
  Future<Transaction> addTransaction(Transaction transaction) async {
    return await createTransaction(transaction);
  }

  // Get all transactions with caching
  Future<List<Transaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    TransactionType? type,
    int limit = 100,
  }) async {
    try {
      print('TransactionService: getTransactions called with limit: $limit');
      
      // Return cached data if valid and no filters are applied
      if (_isCacheValid() && 
          startDate == null && 
          endDate == null && 
          category == null && 
          type == null) {
        print('TransactionService: Returning ${_cachedTransactions!.length} cached transactions');
        return _cachedTransactions!.take(limit).toList();
      }

      print('TransactionService: Fetching fresh data from HybridDataService');
      final transactions = await _hybridDataService.getTransactions();
      print('TransactionService: Retrieved ${transactions.length} transactions from HybridDataService');
      
      // Cache the raw data (without filters)
      if (startDate == null && endDate == null && category == null && type == null) {
        _cachedTransactions = transactions;
        _lastCacheTime = DateTime.now();
        print('TransactionService: Cached ${transactions.length} transactions');
      }
      
      List<Transaction> result = transactions;
      
      // Apply client-side filtering
      if (startDate != null) {
        result = result.where((t) => t.date.isAfter(startDate) || t.date.isAtSameMomentAs(startDate)).toList();
      }
      
      if (endDate != null) {
        result = result.where((t) => t.date.isBefore(endDate) || t.date.isAtSameMomentAs(endDate)).toList();
      }
      
      if (category != null) {
        result = result.where((t) => t.category.toString().split('.').last == category).toList();
      }
      
      if (type != null) {
        result = result.where((t) => t.type == type).toList();
      }

      // Apply limit
      if (result.length > limit) {
        result = result.take(limit).toList();
      }

      return result;
    } catch (e) {
      print('Error getting transactions: $e');
      throw Exception('Failed to get transactions: $e');
    }
  }

  // Update a transaction
  Future<Transaction> updateTransaction(Transaction transaction) async {
    try {
      await _hybridDataService.updateTransaction(
        id: transaction.id,
        amount: transaction.amount,
        type: transaction.type.toString().split('.').last,
        category: transaction.category.toString().split('.').last,
        description: transaction.notes,
        date: transaction.date,
      );
      
      // Clear cache since data has changed
      _clearCache();
      
      return transaction;
    } catch (e) {
      print('Error updating transaction: $e');
      throw Exception('Failed to update transaction: $e');
    }
  }

  // Delete a transaction
  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _hybridDataService.deleteTransaction(transactionId);
      
      // Clear cache since data has changed
      _clearCache();
    } catch (e) {
      print('Error deleting transaction: $e');
      throw Exception('Failed to delete transaction: $e');
    }
  }

  // Get analytics data
  Future<Map<String, dynamic>> getAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Calculate analytics from transactions
      final transactions = await getTransactions(startDate: startDate, endDate: endDate);
      
      double totalIncome = 0;
      double totalExpense = 0;
      
      for (final transaction in transactions) {
        if (transaction.type == TransactionType.income) {
          totalIncome += transaction.amount;
        } else {
          totalExpense += transaction.amount;
        }
      }
      
      return {
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'balance': totalIncome - totalExpense,
        'totalTransactions': transactions.length,
      };
    } catch (e) {
      print('Error getting analytics: $e');
      throw Exception('Failed to get analytics: $e');
    }
  }

  // Get recent transactions
  Future<List<Transaction>> getRecentTransactions({int limit = 10}) async {
    try {
      final transactions = await getTransactions(limit: limit);
      return transactions;
    } catch (e) {
      print('Error getting recent transactions: $e');
      throw Exception('Failed to get recent transactions: $e');
    }
  }

  // Get transactions by category
  Future<List<Transaction>> getTransactionsByCategory(String category) async {
    try {
      final allTransactions = await getTransactions();
      return allTransactions.where((t) => t.category.toString().split('.').last == category).toList();
    } catch (e) {
      print('Error getting transactions by category: $e');
      throw Exception('Failed to get transactions by category: $e');
    }
  }

  // Get transactions by type (income/expense)
  Future<List<Transaction>> getTransactionsByType(TransactionType type) async {
    try {
      final allTransactions = await getTransactions();
      return allTransactions.where((t) => t.type == type).toList();
    } catch (e) {
      print('Error getting transactions by type: $e');
      throw Exception('Failed to get transactions by type: $e');
    }
  }

  // Get transactions for a specific date range
  Future<List<Transaction>> getTransactionsInDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      return await getTransactions(startDate: startDate, endDate: endDate);
    } catch (e) {
      print('Error getting transactions in date range: $e');
      throw Exception('Failed to get transactions in date range: $e');
    }
  }

  // Get total income for a period
  Future<double> getTotalIncome({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final transactions = await getTransactions(
        startDate: startDate,
        endDate: endDate,
        type: TransactionType.income,
      );

      return transactions.fold<double>(0.0, (sum, transaction) => sum + transaction.amount);
    } catch (e) {
      print('Error getting total income: $e');
      throw Exception('Failed to get total income: $e');
    }
  }

  // Get total expenses for a period
  Future<double> getTotalExpenses({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final transactions = await getTransactions(
        startDate: startDate,
        endDate: endDate,
        type: TransactionType.expense,
      );

      return transactions.fold<double>(0.0, (sum, transaction) => sum + transaction.amount);
    } catch (e) {
      print('Error getting total expenses: $e');
      throw Exception('Failed to get total expenses: $e');
    }
  }

  // Get net balance for a period
  Future<double> getNetBalance({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final income = await getTotalIncome(startDate: startDate, endDate: endDate);
      final expenses = await getTotalExpenses(startDate: startDate, endDate: endDate);
      
      return income - expenses;
    } catch (e) {
      print('Error getting net balance: $e');
      throw Exception('Failed to get net balance: $e');
    }
  }

  // Search transactions
  Future<List<Transaction>> searchTransactions(String query) async {
    try {
      final allTransactions = await getTransactions();
      
      return allTransactions.where((transaction) {
        final queryLower = query.toLowerCase();
        final notes = transaction.notes ?? '';
        return notes.toLowerCase().contains(queryLower) ||
               transaction.category.toString().split('.').last.toLowerCase().contains(queryLower) ||
               transaction.amount.toString().contains(query);
      }).toList();
    } catch (e) {
      print('Error searching transactions: $e');
      throw Exception('Failed to search transactions: $e');
    }
  }

  // Clear all transactions for current user
  Future<void> clearAllTransactions() async {
    try {
      final transactions = await getTransactions();
      for (final transaction in transactions) {
        await deleteTransaction(transaction.id);
      }
    } catch (e) {
      print('Error clearing transactions: $e');
      throw Exception('Failed to clear transactions: $e');
    }
  }

  // Sync with server (for backward compatibility, now a no-op since Firebase handles real-time sync)
  Future<void> syncWithServer() async {
    // Firebase handles real-time sync automatically
  }

  // Check if we need to sync (always false with Firebase)
  Future<bool> needsSync() async {
    return false;
  }

  // Get last sync time (not applicable with Firebase real-time sync)
  Future<DateTime?> getLastSyncTime() async {
    return DateTime.now();
  }

  // Get transactions stream for real-time updates
  Stream<List<Transaction>> getTransactionsStream({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    TransactionType? type,
    int limit = 100,
  }) {
    try {
      return _hybridDataService.getTransactionsStream(
        limit: limit,
        category: category?.toString().split('.').last,
        type: type?.toString().split('.').last,
      ) ?? Stream.empty();
    } catch (e) {
      print('Error getting transactions stream: $e');
      return Stream.error('Failed to get transactions stream: $e');
    }
  }

  // Clear cache (for backward compatibility)
  Future<void> clearCache() async {
    // Firebase doesn't use local cache in the same way
  }
}
