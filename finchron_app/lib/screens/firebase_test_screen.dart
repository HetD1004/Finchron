import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../services/firestore_service.dart';
import '../services/hybrid_data_service.dart';
import '../services/transaction_service.dart';

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final HybridDataService _hybridDataService = HybridDataService();
  final TransactionService _transactionService = TransactionService();
  
  Map<String, dynamic> diagnosticResults = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      isLoading = true;
      diagnosticResults = {};
    });

    final results = <String, dynamic>{};

    try {
      // Check Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      results['auth_user_id'] = user?.uid ?? 'Not authenticated';
      results['auth_email'] = user?.email ?? 'No email';
      results['auth_display_name'] = user?.displayName ?? 'No display name';
      results['auth_status'] = user != null ? 'Authenticated' : 'Not authenticated';

      // Check Firestore connection
      try {
        await FirebaseFirestore.instance.collection('test').limit(1).get();
        results['firestore_connection'] = 'Connected';
      } catch (e) {
        results['firestore_connection'] = 'Error: $e';
      }

      // Check if user document exists
      if (user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          results['user_document_exists'] = userDoc.exists;
          if (userDoc.exists) {
            results['user_document_data'] = userDoc.data();
          }
        } catch (e) {
          results['user_document_error'] = e.toString();
        }

        // Check transactions in root collection
        try {
          final rootTransactions = await FirebaseFirestore.instance
              .collection('transactions')
              .where('userId', isEqualTo: user.uid)
              .limit(10)
              .get();
          results['root_transactions_count'] = rootTransactions.docs.length;
          results['root_transactions_sample'] = rootTransactions.docs
              .take(3)
              .map((doc) => {'id': doc.id, 'data': doc.data()})
              .toList();
        } catch (e) {
          results['root_transactions_error'] = e.toString();
        }

        // Check transactions in nested collection
        try {
          final nestedTransactions = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('transactions')
              .limit(10)
              .get();
          results['nested_transactions_count'] = nestedTransactions.docs.length;
          results['nested_transactions_sample'] = nestedTransactions.docs
              .take(3)
              .map((doc) => {'id': doc.id, 'data': doc.data()})
              .toList();
        } catch (e) {
          results['nested_transactions_error'] = e.toString();
        }

        // Test FirestoreService
        try {
          final transactions = await _firestoreService.getTransactions(limit: 5);
          results['firestore_service_transactions'] = transactions.length;
          results['firestore_service_sample'] = transactions
              .take(3)
              .map((t) => {
                'id': t.id,
                'amount': t.amount,
                'type': t.type.toString(),
                'category': t.category.toString(),
                'date': t.date.toIso8601String(),
              })
              .toList();
        } catch (e) {
          results['firestore_service_error'] = e.toString();
        }

        // Test HybridDataService
        try {
          await _hybridDataService.initialize();
          final hybridTransactions = await _hybridDataService.getTransactions();
          results['hybrid_service_transactions'] = hybridTransactions.length;
          results['hybrid_service_preferred_source'] = _hybridDataService.preferredDataSource.toString();
          results['hybrid_service_firebase_auth'] = _hybridDataService.isFirebaseAuthenticated;
        } catch (e) {
          results['hybrid_service_error'] = e.toString();
        }

        // Test TransactionService
        try {
          await _transactionService.initialize();
          final transactionServiceData = await _transactionService.getTransactions(limit: 5);
          results['transaction_service_transactions'] = transactionServiceData.length;
        } catch (e) {
          results['transaction_service_error'] = e.toString();
        }
      }

      // Check Firestore rules by attempting to read/write
      if (user != null) {
        try {
          // Test read permissions
          await FirebaseFirestore.instance
              .collection('transactions')
              .where('userId', isEqualTo: user.uid)
              .limit(1)
              .get();
          results['firestore_read_permission'] = 'Allowed';
        } catch (e) {
          results['firestore_read_permission'] = 'Denied: $e';
        }

        try {
          // Test write permissions (create and immediately delete a minimal document)
          final testDoc = await FirebaseFirestore.instance
              .collection('transactions')
              .add({
            'userId': user.uid,
            'amount': 0.01,
            'type': 'expense',
            'category': 'others',
            'notes': 'Permission test - auto-deleted',
            'date': Timestamp.now(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          // Delete the test document immediately
          await testDoc.delete();
          results['firestore_write_permission'] = 'Allowed';
        } catch (e) {
          results['firestore_write_permission'] = 'Denied: $e';
        }
      }

    } catch (e) {
      results['general_error'] = e.toString();
    }

    setState(() {
      diagnosticResults = results;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runDiagnostics,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Diagnostic Results',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          ...diagnosticResults.entries.map((entry) {
                            return _buildDiagnosticItem(entry.key, entry.value);
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Actions',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _viewFirestoreConsole,
                              child: const Text('Instructions for Firestore Console'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDiagnosticItem(String key, dynamic value) {
    Color statusColor = Colors.grey;
    if (key.contains('error')) {
      statusColor = Colors.red;
    } else if (key.contains('count') && value is int && value > 0) {
      statusColor = Colors.green;
    } else if (key.contains('status') || key.contains('connection')) {
      statusColor = value.toString().contains('Error') ? Colors.red : Colors.green;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _viewFirestoreConsole() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Firestore Console Instructions'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Go to Firebase Console (https://console.firebase.google.com)\n\n'
            '2. Select your Finchron project\n\n'
            '3. Go to Firestore Database\n\n'
            '4. Check the "transactions" collection\n\n'
            '5. Look for documents with your userId\n\n'
            '6. Verify the data structure matches:\n'
            '   - amount (number)\n'
            '   - type (string: "income" or "expense")\n'
            '   - category (string)\n'
            '   - date (timestamp)\n'
            '   - userId (string)\n'
            '   - notes (string, optional)\n\n'
            '7. Check Firestore Rules to ensure read/write permissions for authenticated users',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}