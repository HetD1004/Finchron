import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction.dart';
import '../models/user.dart' as app_user;

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Helper method to convert string to TransactionType
  TransactionType _stringToTransactionType(String type) {
    return TransactionType.values.firstWhere(
      (e) => e.toString().split('.').last == type,
      orElse: () => TransactionType.expense,
    );
  }

  // Helper method to convert string to TransactionCategory
  TransactionCategory _stringToTransactionCategory(String category) {
    return TransactionCategory.values.firstWhere(
      (e) => e.toString().split('.').last == category,
      orElse: () => TransactionCategory.others,
    );
  }

  // Helper method to safely convert date from Firestore
  DateTime _convertToDateTime(dynamic dateValue) {
    if (dateValue is Timestamp) {
      return dateValue.toDate();
    } else if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        print('Warning: Could not parse date string: $dateValue, using current time');
        return DateTime.now();
      }
    } else if (dateValue is int) {
      // Handle milliseconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(dateValue);
    } else {
      print('Warning: Unknown date format: $dateValue (${dateValue.runtimeType}), using current time');
      return DateTime.now();
    }
  }

  // Helper method to create Transaction from Firestore document
  Transaction _transactionFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Transaction(
      id: doc.id,
      userId: data['userId'] ?? currentUserId!,
      amount: (data['amount'] as num).toDouble(),
      type: _stringToTransactionType(data['type'] as String),
      category: _stringToTransactionCategory(data['category'] as String),
      notes: data['notes'] as String?,
      date: _convertToDateTime(data['date']),
      createdAt: data['createdAt'] != null 
          ? _convertToDateTime(data['createdAt'])
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null 
          ? _convertToDateTime(data['updatedAt'])
          : DateTime.now(),
    );
  }

  // User operations
  Future<void> createUser(app_user.User user) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    final userData = <String, dynamic>{
      'id': user.id,
      'email': user.email,
      'name': user.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    // Only include optional fields if they are not null
    if (user.profilePictureUrl != null) {
      userData['profilePictureUrl'] = user.profilePictureUrl;
    }
    
    if (user.googleId != null) {
      userData['googleId'] = user.googleId;
    }
    
    await _firestore.collection('users').doc(currentUserId).set(userData);
  }

  Future<app_user.User?> getUser() async {
    if (currentUserId == null) return null;
    
    final doc = await _firestore.collection('users').doc(currentUserId).get();
    
    if (!doc.exists) return null;
    
    final data = doc.data()!;
    return app_user.User(
      id: data['id'] ?? currentUserId!,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      profilePictureUrl: data['profilePictureUrl'],
      googleId: data['googleId'],
    );
  }

  Future<void> updateUser(app_user.User user) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    final updateData = <String, dynamic>{
      'email': user.email,
      'name': user.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    // Only include profilePictureUrl if it's not null
    if (user.profilePictureUrl != null) {
      updateData['profilePictureUrl'] = user.profilePictureUrl;
    }
    
    // Only include googleId if it's not null
    if (user.googleId != null) {
      updateData['googleId'] = user.googleId;
    }
    
    await _firestore.collection('users').doc(currentUserId).update(updateData);
  }

  // Transaction operations
  Future<Transaction> createTransaction({
    required double amount,
    required TransactionType type,
    required TransactionCategory category,
    String? notes,
    required DateTime date,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    // Create transaction in both places for compatibility
    final transactionData = {
      'amount': amount,
      'type': type.toString().split('.').last,
      'category': category.toString().split('.').last,
      'notes': notes,
      'date': Timestamp.fromDate(date),
      'userId': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Add to root transactions collection (matching existing data structure)
    final rootDocRef = await _firestore.collection('transactions').add(transactionData);
    
    // Also add to nested collection for future consistency
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('transactions')
          .doc(rootDocRef.id)
          .set(transactionData);
    } catch (e) {
      // Silently handle nested collection creation failure
    }
    
    // Get the created document and return as Transaction object
    final doc = await rootDocRef.get();
    return _transactionFromDoc(doc);
  }

  Future<List<Transaction>> getTransactions({
    int? limit,
    String? category,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    try {
      // Use simple query without ordering to avoid index requirements
      Query query = _firestore
          .collection('transactions')
          .where('userId', isEqualTo: currentUserId);
      
      // Apply limit early to reduce data transfer
      final effectiveLimit = limit ?? 100;
      query = query.limit(effectiveLimit * 2); // Get more to allow for sorting
      
      print('FirestoreService: Executing simple query with limit ${effectiveLimit * 2}');
      
      final querySnapshot = await query.get();
      print('FirestoreService: Retrieved ${querySnapshot.docs.length} documents');
      
      List<Transaction> transactions = querySnapshot.docs.map((doc) {
        return _transactionFromDoc(doc);
      }).toList();
      
      // If no results from root collection, try nested collection as fallback
      if (transactions.isEmpty) {
        print('FirestoreService: Fallback to nested collection');
        query = _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('transactions')
            .limit(effectiveLimit * 2);
            
        final nestedSnapshot = await query.get();
        transactions = nestedSnapshot.docs.map((doc) => _transactionFromDoc(doc)).toList();
      }
      
      // Apply client-side filters only if needed (keep minimal)
      if (type != null) {
        transactions = transactions.where((t) => 
            t.type.toString().split('.').last == type).toList();
      }
      
      if (category != null) {
        transactions = transactions.where((t) => 
            t.category.toString().split('.').last == category).toList();
      }
      
      if (startDate != null) {
        transactions = transactions.where((t) => 
            t.date.isAfter(startDate.subtract(const Duration(seconds: 1)))).toList();
      }
      
      if (endDate != null) {
        transactions = transactions.where((t) => 
            t.date.isBefore(endDate.add(const Duration(days: 1)))).toList();
      }
      
      // Sort by date descending on client side (most recent first)
      transactions.sort((a, b) => b.date.compareTo(a.date));
      
      // Apply final limit after sorting
      if (transactions.length > effectiveLimit) {
        transactions = transactions.take(effectiveLimit).toList();
      }
      
      print('FirestoreService: Returning ${transactions.length} filtered and sorted transactions');
      return transactions;
    } catch (e) {
      print('FirestoreService: Error getting transactions: $e');
      throw Exception('Failed to get transactions: $e');
    }
  }

  Future<Transaction> updateTransaction({
    required String transactionId,
    double? amount,
    TransactionType? type,
    TransactionCategory? category,
    String? notes,
    DateTime? date,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (amount != null) updateData['amount'] = amount;
    if (type != null) updateData['type'] = type.toString().split('.').last;
    if (category != null) updateData['category'] = category.toString().split('.').last;
    if (notes != null) updateData['notes'] = notes;
    if (date != null) updateData['date'] = Timestamp.fromDate(date);
    
    // Update in root collection
    await _firestore.collection('transactions').doc(transactionId).update(updateData);
    
    // Also try to update in nested collection
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('transactions')
          .doc(transactionId)
          .update(updateData);
    } catch (e) {
      print('Warning: Could not update nested transaction: $e');
    }
    
    // Fetch and return the updated transaction
    final doc = await _firestore.collection('transactions').doc(transactionId).get();
    
    return _transactionFromDoc(doc);
  }

  Future<void> deleteTransaction(String transactionId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    // Delete from root collection
    await _firestore.collection('transactions').doc(transactionId).delete();
    
    // Also try to delete from nested collection
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('transactions')
          .doc(transactionId)
          .delete();
    } catch (e) {
      print('Warning: Could not delete nested transaction: $e');
    }
  }

  // Analytics operations
  Future<Map<String, dynamic>> getAnalyticsSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    // Use simple query and filter on client side
    Query query = _firestore.collection('transactions').where('userId', isEqualTo: currentUserId);

    final querySnapshot = await query.get();
    
    double totalIncome = 0;
    double totalExpense = 0;
    int totalTransactions = 0;
    
    for (final doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['amount'] as num).toDouble();
      final type = data['type'] as String;
      final transactionDate = _convertToDateTime(data['date']);
      
      // Apply date filtering on client side
      if (startDate != null && transactionDate.isBefore(startDate)) continue;
      if (endDate != null && transactionDate.isAfter(endDate)) continue;
      
      totalTransactions++;
      
      if (type == 'income') {
        totalIncome += amount;
      } else if (type == 'expense') {
        totalExpense += amount;
      }
    }
    
    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'balance': totalIncome - totalExpense,
      'totalTransactions': totalTransactions,
    };
  }

  Future<Map<String, dynamic>> getCategoryAnalytics({
    DateTime? startDate,
    DateTime? endDate,
    String? type,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    // Use simple query with optional type filter
    Query query = _firestore.collection('transactions').where('userId', isEqualTo: currentUserId);
    
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    final querySnapshot = await query.get();
    final Map<String, double> categoryTotals = {};
    
    for (final doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['amount'] as num).toDouble();
      final category = data['category'] as String;
      final transactionDate = _convertToDateTime(data['date']);
      
      // Apply date filtering on client side
      if (startDate != null && transactionDate.isBefore(startDate)) continue;
      if (endDate != null && transactionDate.isAfter(endDate)) continue;
      
      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
    }
    
    final categories = categoryTotals.entries.map((entry) => {
      'category': entry.key,
      'amount': entry.value,
    }).toList();
    
    // Sort by amount descending
    categories.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    
    return {
      'categories': categories,
      'total': categoryTotals.values.fold(0.0, (sum, amount) => sum + amount),
    };
  }

  Future<Map<String, dynamic>> getTrends({
    String? period,
    String? type,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    // Calculate date range based on period
    final now = DateTime.now();
    DateTime startDate;
    
    switch (period) {
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'year':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = DateTime(now.year, now.month, 1); // Current month
    }
    
    // Use simple query with optional type filter
    Query query = _firestore.collection('transactions').where('userId', isEqualTo: currentUserId);

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    final querySnapshot = await query.get();
    final Map<String, double> dailyTotals = {};
    
    for (final doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['amount'] as num).toDouble();
      final date = _convertToDateTime(data['date']);
      
      // Apply date filtering on client side
      if (date.isBefore(startDate)) continue;
      
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + amount;
    }
    
    final trends = dailyTotals.entries.map((entry) => {
      'date': entry.key,
      'amount': entry.value,
    }).toList();
    
    return {
      'trends': trends,
      'period': period ?? 'month',
    };
  }

  Future<Map<String, dynamic>> getDashboard() async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    // Get current month data
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    
    final [summary, categoryAnalytics, recentTransactions] = await Future.wait([
      getAnalyticsSummary(startDate: startOfMonth, endDate: endOfMonth),
      getCategoryAnalytics(startDate: startOfMonth, endDate: endOfMonth),
      getTransactions(limit: 5),
    ]);
    
    return {
      'summary': summary,
      'categoryAnalytics': categoryAnalytics,
      'recentTransactions': (recentTransactions as List<Transaction>).map((t) => t.toJson()).toList(),
    };
  }

  // Stream methods for real-time updates
  Stream<List<Transaction>> getTransactionsStream({
    int? limit,
    String? category,
    String? type,
  }) {
    if (currentUserId == null) {
      return Stream.error('User not authenticated');
    }
    
    // Use simple query to avoid index requirements
    Query query = _firestore
        .collection('transactions')
        .where('userId', isEqualTo: currentUserId);
    
    // Apply only one filter at a time to avoid complex indexes
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    } else if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      var transactions = snapshot.docs.map((doc) => _transactionFromDoc(doc)).toList();
      
      // Apply client-side category filter if type was already applied
      if (category != null && type != null) {
        transactions = transactions.where((t) => t.category.toString().split('.').last == category).toList();
      }
      
      // Sort on client side
      transactions.sort((a, b) => b.date.compareTo(a.date));
      
      return transactions;
    });
  }

  // Test Firestore connection
  Future<bool> testConnection() async {
    try {
      // Try to read from Firestore
      await _firestore.collection('transactions').limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }
}