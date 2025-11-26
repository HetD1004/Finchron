import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import 'firebase_auth_service.dart';
import 'firebase_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();
  final FirebaseService _firebaseService = FirebaseService();

  User? _currentUser;
  User? get currentUser => _currentUser;

  // Initialize the service and check for existing user
  Future<User?> initialize() async {
    try {
      // Always clear any cached user data first to ensure fresh state
      _currentUser = null;
      
      // Check if user is already signed in with Firebase
      final firebaseUser = _firebaseAuthService.currentUser;
      
      if (firebaseUser != null) {
        print('AuthService: Found Firebase user: ${firebaseUser.email}');
        // Get user data from Firestore
        _currentUser = await _firebaseService.getUserById(firebaseUser.uid);
        
        if (_currentUser != null) {
          print('AuthService: Loaded user from Firestore: ${_currentUser!.email}');
          await _saveUserToStorage(_currentUser!);
          return _currentUser;
        } else {
          print('AuthService: User not found in Firestore, signing out');
          // If user exists in Firebase Auth but not in Firestore, sign out
          await _firebaseAuthService.signOut();
          await _clearUserFromStorage();
          return null;
        }
      }

      // No Firebase user found, clear any local storage
      print('AuthService: No Firebase user found, clearing local storage');
      await _clearUserFromStorage();
      return null;
    } catch (e) {
      print('Error initializing auth service: $e');
      // Clear any cached data on error
      await _clearUserFromStorage();
      _currentUser = null;
      return null;
    }
  }

  // Register new user
  Future<User> register({
    required String email,
    required String name,
    required String password,
  }) async {
    try {
      print('AuthService: Starting registration for email: $email');
      
      // Clear any existing user data first
      await signOut();
      
      final user = await _firebaseAuthService.registerWithEmailAndPassword(
        email,
        password,
        name,
      );

      if (user == null) {
        throw Exception('Failed to create account');
      }

      print('AuthService: Successfully registered user: ${user.email}');
      
      await _saveUserToStorage(user);
      _currentUser = user;

      return user;
    } catch (e) {
      print('Error registering user: $e');
      // Clear any partial state on error
      await _clearUserFromStorage();
      _currentUser = null;
      throw Exception('Failed to register: $e');
    }
  }

  // Sign in with email and password
  Future<User> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _firebaseAuthService.signInWithEmailAndPassword(
        email,
        password,
      );

      if (user == null) {
        throw Exception('Failed to sign in');
      }

      await _saveUserToStorage(user);
      _currentUser = user;

      return user;
    } catch (e) {
      print('Error signing in: $e');
      throw Exception('Failed to sign in: $e');
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      print('AuthService: Starting Google Sign-In...');
      
      // Clear any existing user data first to ensure fresh state
      _currentUser = null;
      
      final user = await _firebaseAuthService.signInWithGoogle();

      if (user == null) {
        print('AuthService: Google Sign-In was cancelled or failed');
        return null;
      }

      print('AuthService: Google Sign-In successful for: ${user.email}');
      
      await _saveUserToStorage(user);
      _currentUser = user;

      return user;
    } catch (e) {
      print('Error signing in with Google: $e');
      print('Error type: ${e.runtimeType}');
      
      // Clear any partial state on error
      await _clearUserFromStorage();
      _currentUser = null;
      
      throw Exception('Failed to sign in with Google: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      print('AuthService: Signing out user');
      
      // Clear current user first
      _currentUser = null;
      
      // Sign out from Firebase
      await _firebaseAuthService.signOut();
      
      // Clear all local storage
      await _clearUserFromStorage();
      
      print('AuthService: Sign out completed');
    } catch (e) {
      print('Error signing out: $e');
      // Even if there's an error, clear local state
      _currentUser = null;
      await _clearUserFromStorage();
      throw Exception('Failed to sign out: $e');
    }
  }

  // Check if user is signed in
  bool get isSignedIn => _currentUser != null;

  // Update current user (used when profile is updated externally)
  void updateCurrentUser(User user) {
    _currentUser = user;
    _saveUserToStorage(user);
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuthService.sendPasswordResetEmail(email);
    } catch (e) {
      print('Error sending password reset email: $e');
      throw Exception('Failed to send password reset email: $e');
    }
  }

  // Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      await _firebaseAuthService.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
      );

      // Update local user data
      if (_currentUser != null) {
        _currentUser = User(
          id: _currentUser!.id,
          email: _currentUser!.email,
          name: displayName ?? _currentUser!.name,
          profilePictureUrl: photoURL ?? _currentUser!.profilePictureUrl,
          googleId: _currentUser!.googleId,
        );
        await _saveUserToStorage(_currentUser!);
      }
    } catch (e) {
      print('Error updating profile: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      await _firebaseAuthService.deleteAccount();
      await _clearUserFromStorage();
      _currentUser = null;
    } catch (e) {
      print('Error deleting account: $e');
      throw Exception('Failed to delete account: $e');
    }
  }

  // Save user to local storage
  Future<void> _saveUserToStorage(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', json.encode(user.toJson()));
    } catch (e) {
      print('Error saving user to storage: $e');
    }
  }

  // Clear user from local storage
  Future<void> _clearUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Clear all user-related data
      await prefs.remove('current_user');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      print('AuthService: Cleared all user data from local storage');
    } catch (e) {
      print('Error clearing user from storage: $e');
    }
  }
}
