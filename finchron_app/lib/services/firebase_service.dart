import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction.dart' as app_transaction;
import '../models/user.dart' as app_user;

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  static const String usersCollection = 'users';
  static const String transactionsCollection = 'transactions';

  // User Operations
  Future<void> createUser(app_user.User user) async {
    try {
      await _firestore.collection(usersCollection).doc(user.id).set({
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'profilePictureUrl': user.profilePictureUrl,
        'googleId': user.googleId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  Future<app_user.User?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection(usersCollection).doc(userId).get();
      
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      return app_user.User(
        id: data['id'],
        name: data['name'],
        email: data['email'],
        profilePictureUrl: data['profilePictureUrl'],
        googleId: data['googleId'],
      );
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  Future<app_user.User?> getUserByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final data = query.docs.first.data();
      return app_user.User(
        id: data['id'],
        name: data['name'],
        email: data['email'],
        profilePictureUrl: data['profilePictureUrl'],
        googleId: data['googleId'],
      );
    } catch (e) {
      throw Exception('Failed to get user by email: $e');
    }
  }

  Future<app_user.User?> getUserByGoogleId(String googleId) async {
    try {
      final query = await _firestore
          .collection(usersCollection)
          .where('googleId', isEqualTo: googleId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final data = query.docs.first.data();
      return app_user.User(
        id: data['id'],
        name: data['name'],
        email: data['email'],
        profilePictureUrl: data['profilePictureUrl'],
        googleId: data['googleId'],
      );
    } catch (e) {
      throw Exception('Failed to get user by Google ID: $e');
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(usersCollection).doc(userId).update(updates);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Transaction Operations
  Future<void> createTransaction(app_transaction.Transaction transaction) async {
    try {
      await _firestore
          .collection(transactionsCollection)
          .doc(transaction.id)
          .set({
        'id': transaction.id,
        'userId': transaction.userId,
        'type': transaction.type.toString().split('.').last,
        'category': transaction.category.toString().split('.').last,
        'amount': transaction.amount,
        'notes': transaction.notes,
        'date': Timestamp.fromDate(transaction.date),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create transaction: $e');
    }
  }

  Future<List<app_transaction.Transaction>> getTransactions(String userId, {int limit = 100}) async {
    try {
      final query = await _firestore
          .collection(transactionsCollection)
          .where('userId', isEqualTo: userId)
          .limit(limit)
          .get();

      final transactions = query.docs.map((doc) {
        final data = doc.data();
        return app_transaction.Transaction(
          id: data['id'],
          userId: data['userId'],
          type: app_transaction.TransactionType.values.firstWhere(
            (e) => e.toString().split('.').last == data['type'],
          ),
          category: app_transaction.TransactionCategory.values.firstWhere(
            (e) => e.toString().split('.').last == data['category'],
          ),
          amount: data['amount'].toDouble(),
          notes: data['notes'],
          date: (data['date'] as Timestamp).toDate(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();

      // Sort client-side to avoid index requirements
      transactions.sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return b.createdAt.compareTo(a.createdAt);
      });

      return transactions;
    } catch (e) {
      throw Exception('Failed to get transactions: $e');
    }
  }

  Future<void> updateTransaction(String transactionId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      // Convert date if present
      if (updates['date'] is DateTime) {
        updates['date'] = Timestamp.fromDate(updates['date']);
      }
      
      // Convert enums to strings if present
      if (updates['type'] is app_transaction.TransactionType) {
        updates['type'] = updates['type'].toString().split('.').last;
      }
      if (updates['category'] is app_transaction.TransactionCategory) {
        updates['category'] = updates['category'].toString().split('.').last;
      }
      
      await _firestore.collection(transactionsCollection).doc(transactionId).update(updates);
    } catch (e) {
      throw Exception('Failed to update transaction: $e');
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _firestore.collection(transactionsCollection).doc(transactionId).delete();
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  // Analytics Operations
  Future<Map<String, double>> getTransactionSummary(String userId) async {
    try {
      final query = await _firestore
          .collection(transactionsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      double totalIncome = 0;
      double totalExpense = 0;

      for (final doc in query.docs) {
        final data = doc.data();
        final amount = data['amount'].toDouble();
        final type = data['type'];

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
      };
    } catch (e) {
      throw Exception('Failed to get transaction summary: $e');
    }
  }

  Future<Map<String, double>> getCategorySpending(String userId) async {
    try {
      final query = await _firestore
          .collection(transactionsCollection)
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'expense')
          .get();

      final Map<String, double> categoryTotals = {};

      for (final doc in query.docs) {
        final data = doc.data();
        final category = data['category'] as String;
        final amount = data['amount'].toDouble();

        categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
      }

      return categoryTotals;
    } catch (e) {
      throw Exception('Failed to get category spending: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMonthlySpending(String userId) async {
    try {
      final query = await _firestore
          .collection(transactionsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      final Map<String, Map<String, double>> monthlyData = {};

      for (final doc in query.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        final type = data['type'] as String;
        final amount = data['amount'].toDouble();

        if (!monthlyData.containsKey(monthKey)) {
          monthlyData[monthKey] = {'income': 0.0, 'expense': 0.0};
        }

        monthlyData[monthKey]![type] = (monthlyData[monthKey]![type] ?? 0) + amount;
      }

      return monthlyData.entries.map((entry) => {
        'month': entry.key,
        'income': entry.value['income'],
        'expense': entry.value['expense'],
      }).toList();
    } catch (e) {
      throw Exception('Failed to get monthly spending: $e');
    }
  }

  // Utility Operations
  Future<void> clearUserData(String userId) async {
    try {
      // Delete user document
      await _firestore.collection(usersCollection).doc(userId).delete();
      
      // Delete all user transactions
      await clearUserTransactions(userId);
    } catch (e) {
      throw Exception('Failed to clear user data: $e');
    }
  }

  Future<void> clearUserTransactions(String userId) async {
    try {
      final query = await _firestore
          .collection(transactionsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to clear user transactions: $e');
    }
  }
}