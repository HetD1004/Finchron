import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart' as app_user;
import 'firebase_service.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseService _firebaseService = FirebaseService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Convert Firebase User to app User
  Future<app_user.User?> _convertFirebaseUser(User firebaseUser) async {
    try {
      print('FirebaseAuthService: Converting Firebase user: ${firebaseUser.email}');
      
      // First check if user exists in Firestore
      app_user.User? existingUser = await _firebaseService.getUserById(firebaseUser.uid);
      
      if (existingUser != null) {
        print('FirebaseAuthService: Found existing user in Firestore: ${existingUser.email}');
        return existingUser;
      }

      print('FirebaseAuthService: Creating new user in Firestore');
      
      // If not, create a new user in Firestore
      final newUser = app_user.User(
        id: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'User',
        email: firebaseUser.email ?? '',
        profilePictureUrl: firebaseUser.photoURL,
        googleId: firebaseUser.providerData
            .where((provider) => provider.providerId == 'google.com')
            .isNotEmpty
            ? firebaseUser.providerData
                .firstWhere((provider) => provider.providerId == 'google.com')
                .uid
            : null,
      );

      await _firebaseService.createUser(newUser);
      print('FirebaseAuthService: Successfully created new user in Firestore: ${newUser.email}');
      return newUser;
    } catch (e) {
      print('Error converting Firebase user: $e');
      return null;
    }
  }

  // Sign in with Google
  Future<app_user.User?> signInWithGoogle() async {
    try {
      print('FirebaseAuthService: Starting Google Sign-In...');
      
      // Clear any existing Google sign-in state first
      await _googleSignIn.signOut();
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('FirebaseAuthService: Google sign in was cancelled by user');
        return null; // Return null instead of throwing exception for cancellation
      }

      print('FirebaseAuthService: Google user signed in: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to obtain Google authentication tokens');
      }

      print('FirebaseAuthService: Obtained Google authentication tokens');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('FirebaseAuthService: Signing in to Firebase with Google credential...');

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user == null) {
        throw Exception('Failed to authenticate with Firebase');
      }

      print('FirebaseAuthService: Successfully authenticated with Firebase: ${userCredential.user!.email}');

      // Convert to app user and store in Firestore
      final user = await _convertFirebaseUser(userCredential.user!);
      
      if (user != null) {
        print('FirebaseAuthService: Google Sign-In completed successfully: ${user.email}');
      }
      
      return user;
    } catch (e) {
      print('Google sign in error: $e');
      print('Error type: ${e.runtimeType}');
      
      // Provide more specific error messages
      if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      } else if (e.toString().contains('cancelled')) {
        return null; // Don't throw for user cancellation
      } else {
        throw Exception('Failed to sign in with Google: $e');
      }
    }
  }

  // Sign in with email and password
  Future<app_user.User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Failed to authenticate');
      }

      return await _convertFirebaseUser(userCredential.user!);
    } catch (e) {
      print('Email sign in error: $e');
      throw Exception('Failed to sign in: $e');
    }
  }

  // Register with email and password
  Future<app_user.User?> registerWithEmailAndPassword(
    String email, 
    String password, 
    String name
  ) async {
    try {
      print('FirebaseAuthService: Creating account for email: $email');
      
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Failed to create account');
      }

      print('FirebaseAuthService: Account created with UID: ${userCredential.user!.uid}');

      // Update display name
      await userCredential.user!.updateDisplayName(name);
      await userCredential.user!.reload();
      
      print('FirebaseAuthService: Display name updated to: $name');

      final user = await _convertFirebaseUser(userCredential.user!);
      
      if (user != null) {
        print('FirebaseAuthService: User successfully created and stored: ${user.email}');
      } else {
        print('FirebaseAuthService: Warning - User created in Auth but failed to store in Firestore');
      }
      
      return user;
    } catch (e) {
      print('Registration error: $e');
      throw Exception('Failed to create account: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      print('Sign out error: $e');
      throw Exception('Failed to sign out: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Clear user data from Firestore
      await _firebaseService.clearUserData(user.uid);

      // Delete the Firebase Auth account
      await user.delete();
    } catch (e) {
      print('Delete account error: $e');
      throw Exception('Failed to delete account: $e');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Password reset error: $e');
      throw Exception('Failed to send password reset email: $e');
    }
  }

  // Update profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      await user.reload();

      // Update in Firestore as well
      final updates = <String, dynamic>{};
      if (displayName != null) updates['name'] = displayName;
      if (photoURL != null) updates['profilePictureUrl'] = photoURL;

      if (updates.isNotEmpty) {
        await _firebaseService.updateUser(user.uid, updates);
      }
    } catch (e) {
      print('Update profile error: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  // Re-authenticate user (required for sensitive operations)
  Future<void> reauthenticateWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign in was cancelled');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      await user.reauthenticateWithCredential(credential);
    } catch (e) {
      print('Re-authentication error: $e');
      throw Exception('Failed to re-authenticate: $e');
    }
  }
}