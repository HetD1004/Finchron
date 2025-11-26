import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../models/user.dart' as app_user;
import 'api_service.dart';
import 'firestore_service.dart';

enum DataSource { local, cloud }

class HybridDataService {
  static final HybridDataService _instance = HybridDataService._internal();
  factory HybridDataService() => _instance;
  HybridDataService._internal();

  final ApiService _apiService = ApiService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _dataSourceKey = 'preferred_data_source';
  static const String _syncStatusKey = 'last_sync_timestamp';

  DataSource _preferredDataSource = DataSource.cloud;
  bool _isOnline = true;
  bool _isInitialized = false;
  DateTime? _lastConnectivityCheck;
  
  // Cache connectivity check for 30 seconds
  static const int _connectivityCacheDuration = 30000;

  // Get current data source preference
  DataSource get preferredDataSource => _preferredDataSource;
  bool get isOnline => _isOnline;
  bool get isFirebaseAuthenticated => _auth.currentUser != null;

  // Initialize the service (simplified to avoid hanging)
  Future<void> initialize() async {
    if (_isInitialized) {
      return; // Already initialized, skip
    }
    
    try {
      await _loadPreferences();
      // Skip connectivity check on initialization to prevent hanging
      _isInitialized = true;
      print('HybridDataService: Initialization completed successfully');
    } catch (e) {
      print('HybridDataService: Initialization failed: $e');
      _isInitialized = false;
    }
  }

  // Load saved preferences
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final sourceIndex = prefs.getInt(_dataSourceKey) ?? DataSource.cloud.index;
    _preferredDataSource = DataSource.values[sourceIndex];
  }

  // Save data source preference
  Future<void> setPreferredDataSource(DataSource source) async {
    _preferredDataSource = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dataSourceKey, source.index);
  }

  // Check connectivity to both services (with caching)
  Future<void> _checkConnectivity() async {
    // Skip if checked recently
    if (_lastConnectivityCheck != null) {
      final now = DateTime.now();
      final diff = now.difference(_lastConnectivityCheck!).inMilliseconds;
      if (diff < _connectivityCacheDuration) {
        return; // Use cached connectivity status
      }
    }
    
    try {
      final [apiHealth, firestoreHealth] = await Future.wait([
        _apiService.checkHealth(),
        _firestoreService.testConnection(),
      ]);
      
      _isOnline = apiHealth || firestoreHealth;
      _lastConnectivityCheck = DateTime.now();
    } catch (e) {
      _isOnline = false;
      _lastConnectivityCheck = DateTime.now();
    }
  }

  // Determine which service to use based on preference and availability
  bool _shouldUseFirestore() {
    if (!isFirebaseAuthenticated) return false;
    
    switch (_preferredDataSource) {
      case DataSource.cloud:
        return true;
      case DataSource.local:
        return false;
    }
  }

  // Authentication methods
  Future<Map<String, dynamic>> register({
    required String email,
    required String name,
    required String password,
  }) async {
    try {
      // Always use Firebase Auth for authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      await userCredential.user?.updateDisplayName(name);
      
      // Create user profile in Firestore
      final user = app_user.User(
        id: userCredential.user!.uid,
        email: email,
        name: name,
      );
      
      await _firestoreService.createUser(user);
      
      // Also register with local API if available
      try {
        await _apiService.register(email: email, name: name, password: password);
      } catch (e) {
        // Local API registration failed, but Firebase succeeded
        print('Local API registration failed: $e');
      }
      
      return {
        'token': await userCredential.user!.getIdToken(),
        'user': user.toJson(),
      };
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      // Try Firebase Auth first
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = await _firestoreService.getUser();
      
      // Also login to local API if available
      try {
        await _apiService.login(email: email, password: password);
      } catch (e) {
        // Local API login failed, but Firebase succeeded
        print('Local API login failed: $e');
      }
      
      return {
        'token': await userCredential.user!.getIdToken(),
        'user': user?.toJson(),
      };
    } catch (e) {
      // If Firebase fails, try local API as fallback
      return await _apiService.login(email: email, password: password);
    }
  }

  Future<Map<String, dynamic>> googleLogin({required String idToken}) async {
    try {
      // Firebase Google Auth
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Create or update user in Firestore
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        final user = app_user.User(
          id: userCredential.user!.uid,
          email: userCredential.user!.email!,
          name: userCredential.user!.displayName ?? '',
        );
        await _firestoreService.createUser(user);
      }
      
      final user = await _firestoreService.getUser();
      
      return {
        'token': await userCredential.user!.getIdToken(),
        'user': user?.toJson(),
      };
    } catch (e) {
      throw Exception('Google login failed: $e');
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    try {
      await _apiService.logout();
    } catch (e) {
      // Local logout failed, but Firebase logout succeeded
      print('Local API logout failed: $e');
    }
  }

  // Transaction methods
  Future<List<Transaction>> getTransactions({
    int? limit,
    int? offset,
    String? category,
    String? type,
    String? startDate,
    String? endDate,
  }) async {
    print('HybridDataService: getTransactions called');
    print('HybridDataService: _shouldUseFirestore() = ${_shouldUseFirestore()}');
    print('HybridDataService: isFirebaseAuthenticated = $isFirebaseAuthenticated');
    
    if (_shouldUseFirestore()) {
      print('HybridDataService: Using Firestore');
      return await _firestoreService.getTransactions(
        limit: limit,
        category: category,
        type: type,
        startDate: startDate != null ? DateTime.parse(startDate) : null,
        endDate: endDate != null ? DateTime.parse(endDate) : null,
      );
    } else {
      print('HybridDataService: Using API service');
      return await _apiService.getTransactions(
        limit: limit,
        offset: offset,
        category: category,
        type: type,
        startDate: startDate,
        endDate: endDate,
      );
    }
  }

  Future<Transaction> createTransaction({
    required double amount,
    required String type,
    required String category,
    String? description,
    required DateTime date,
  }) async {
    final transactionType = TransactionType.values.firstWhere(
      (e) => e.toString().split('.').last == type,
      orElse: () => TransactionType.expense,
    );
    
    final transactionCategory = TransactionCategory.values.firstWhere(
      (e) => e.toString().split('.').last == category,
      orElse: () => TransactionCategory.others,
    );

    if (_shouldUseFirestore()) {
      await _firestoreService.createTransaction(
        amount: amount,
        type: transactionType,
        category: transactionCategory,
        notes: description,
        date: date,
      );
      
      // Return the created transaction
      final transactions = await _firestoreService.getTransactions(limit: 1);
      return transactions.first;
    } else {
      return await _apiService.createTransaction(
        amount: amount,
        type: type,
        category: category,
        description: description ?? '',
        date: date,
      );
    }
  }

  Future<Transaction> updateTransaction({
    required String id,
    double? amount,
    String? type,
    String? category,
    String? description,
    DateTime? date,
  }) async {
    final transactionType = type != null 
        ? TransactionType.values.firstWhere(
            (e) => e.toString().split('.').last == type,
            orElse: () => TransactionType.expense,
          )
        : null;
    
    final transactionCategory = category != null
        ? TransactionCategory.values.firstWhere(
            (e) => e.toString().split('.').last == category,
            orElse: () => TransactionCategory.others,
          )
        : null;

    if (_shouldUseFirestore()) {
      return await _firestoreService.updateTransaction(
        transactionId: id,
        amount: amount,
        type: transactionType,
        category: transactionCategory,
        notes: description,
        date: date,
      );
    } else {
      return await _apiService.updateTransaction(
        id: id,
        amount: amount,
        type: type,
        category: category,
        description: description,
        date: date,
      );
    }
  }

  Future<void> deleteTransaction(String id) async {
    if (_shouldUseFirestore()) {
      await _firestoreService.deleteTransaction(id);
    } else {
      await _apiService.deleteTransaction(id);
    }
  }

  // Analytics methods
  Future<Map<String, dynamic>> getAnalyticsSummary({
    String? startDate,
    String? endDate,
  }) async {
    if (_shouldUseFirestore()) {
      return await _firestoreService.getAnalyticsSummary(
        startDate: startDate != null ? DateTime.parse(startDate) : null,
        endDate: endDate != null ? DateTime.parse(endDate) : null,
      );
    } else {
      return await _apiService.getAnalyticsSummary(
        startDate: startDate,
        endDate: endDate,
      );
    }
  }

  Future<Map<String, dynamic>> getCategoryAnalytics({
    String? startDate,
    String? endDate,
    String? type,
  }) async {
    if (_shouldUseFirestore()) {
      return await _firestoreService.getCategoryAnalytics(
        startDate: startDate != null ? DateTime.parse(startDate) : null,
        endDate: endDate != null ? DateTime.parse(endDate) : null,
        type: type,
      );
    } else {
      return await _apiService.getCategoryAnalytics(
        startDate: startDate,
        endDate: endDate,
        type: type,
      );
    }
  }

  Future<Map<String, dynamic>> getTrends({String? period, String? type}) async {
    if (_shouldUseFirestore()) {
      return await _firestoreService.getTrends(period: period, type: type);
    } else {
      return await _apiService.getTrends(period: period, type: type);
    }
  }

  Future<Map<String, dynamic>> getDashboard() async {
    if (_shouldUseFirestore()) {
      return await _firestoreService.getDashboard();
    } else {
      return await _apiService.getDashboard();
    }
  }

  // Real-time data streams (only available with Firestore)
  Stream<List<Transaction>>? getTransactionsStream({
    int? limit,
    String? category,
    String? type,
  }) {
    if (_shouldUseFirestore()) {
      return _firestoreService.getTransactionsStream(
        limit: limit,
        category: category,
        type: type,
      );
    }
    return null; // API doesn't support streams
  }

  // Sync methods
  Future<void> syncData() async {
    if (!isFirebaseAuthenticated) return;
    
    try {
      // This is a placeholder for a more sophisticated sync strategy
      // You could implement bi-directional sync here
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_syncStatusKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      throw Exception('Sync failed: $e');
    }
  }

  // Test connectivity
  Future<Map<String, bool>> testConnectivity() async {
    final [apiHealth, firestoreHealth] = await Future.wait([
      _apiService.checkHealth(),
      _firestoreService.testConnection(),
    ]);
    
    return {
      'api': apiHealth,
      'firestore': firestoreHealth,
    };
  }
}