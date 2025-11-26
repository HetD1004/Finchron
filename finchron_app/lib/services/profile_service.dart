import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart' as app_user;
import 'firestore_service.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool get isFirebaseAuthenticated => _auth.currentUser != null;

  /// Get current user profile
  Future<app_user.User?> getCurrentUser() async {
    try {
      if (isFirebaseAuthenticated) {
        return await _firestoreService.getUser();
      } else {
        // Try to get from local storage or API
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id');
        final userName = prefs.getString('user_name');
        final userEmail = prefs.getString('user_email');
        
        if (userId != null && userName != null && userEmail != null) {
          return app_user.User(
            id: userId,
            name: userName,
            email: userEmail,
          );
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get current user: $e');
    }
  }

  /// Update user profile with enhanced Firestore synchronization
  Future<app_user.User> updateProfile({
    String? name,
    String? profilePictureUrl,
  }) async {
    try {
      if (isFirebaseAuthenticated) {
        final firebaseUser = _auth.currentUser!;
        
        // Step 1: Update Firebase Auth profile
        if (name != null && name.trim() != firebaseUser.displayName) {
          await firebaseUser.updateDisplayName(name.trim());
          print('ProfileService: Updated Firebase Auth display name');
        }
        
        if (profilePictureUrl != null && profilePictureUrl != firebaseUser.photoURL) {
          await firebaseUser.updatePhotoURL(profilePictureUrl);
          print('ProfileService: Updated Firebase Auth photo URL');
        }

        // Step 2: Get current user from Firestore
        final firestoreUser = await _firestoreService.getUser();
        if (firestoreUser == null) {
          // If user doesn't exist in Firestore, create it
          final newUser = app_user.User(
            id: firebaseUser.uid,
            name: name?.trim() ?? firebaseUser.displayName ?? '',
            email: firebaseUser.email ?? '',
            profilePictureUrl: profilePictureUrl ?? firebaseUser.photoURL,
          );
          await _firestoreService.createUser(newUser);
          print('ProfileService: Created new user document in Firestore');
          
          // Update local storage
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', newUser.name);
          await prefs.setString('user_email', newUser.email);
          await prefs.setString('user_id', newUser.id);
          
          return newUser;
        }

        // Step 3: Create updated user object only if there are actual changes
        bool hasChanges = false;
        String finalName = firestoreUser.name;
        String finalProfileUrl = firestoreUser.profilePictureUrl ?? '';

        if (name != null && name.trim() != firestoreUser.name) {
          finalName = name.trim();
          hasChanges = true;
        }

        if (profilePictureUrl != null && profilePictureUrl != firestoreUser.profilePictureUrl) {
          finalProfileUrl = profilePictureUrl;
          hasChanges = true;
        }

        final updatedUser = firestoreUser.copyWith(
          name: finalName,
          profilePictureUrl: finalProfileUrl,
        );

        // Step 4: Update Firestore user document only if there are changes
        if (hasChanges) {
          await _firestoreService.updateUser(updatedUser);
          print('ProfileService: Updated Firestore user document');
          
          // Step 5: Update local storage with the latest data
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', finalName);
          await prefs.setString('user_email', updatedUser.email);
          await prefs.setString('user_id', updatedUser.id);
          print('ProfileService: Updated local storage');
        } else {
          print('ProfileService: No changes detected, skipping Firestore update');
        }

        return updatedUser;
      } else {
        // Update via API (if available) - simplified for now
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id') ?? '';
        final userEmail = prefs.getString('user_email') ?? '';
        
        if (name != null) {
          await prefs.setString('user_name', name);
        }
        
        return app_user.User(
          id: userId,
          name: name ?? prefs.getString('user_name') ?? '',
          email: userEmail,
          profilePictureUrl: profilePictureUrl,
        );
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  /// Update email with enhanced Firestore synchronization (Firebase only)
  Future<void> updateEmail(String newEmail, String currentPassword) async {
    try {
      if (!isFirebaseAuthenticated) {
        throw Exception('Email update is only available with Firebase authentication');
      }

      final currentUser = _auth.currentUser!;
      final trimmedEmail = newEmail.trim().toLowerCase();
      
      // Check if email is actually changing
      if (trimmedEmail == currentUser.email?.toLowerCase()) {
        throw Exception('New email is the same as current email');
      }
      
      // Step 1: Re-authenticate user before email change
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: currentPassword,
      );
      
      await currentUser.reauthenticateWithCredential(credential);
      print('ProfileService: User re-authenticated successfully');
      
      // Step 2: Update email in Firebase Auth
      await currentUser.updateEmail(trimmedEmail);
      print('ProfileService: Updated Firebase Auth email');
      
      // Step 3: Send verification email
      await currentUser.sendEmailVerification();
      print('ProfileService: Sent email verification');
      
      // Step 4: Update Firestore user document
      final firestoreUser = await _firestoreService.getUser();
      if (firestoreUser != null) {
        final updatedUser = firestoreUser.copyWith(email: trimmedEmail);
        await _firestoreService.updateUser(updatedUser);
        print('ProfileService: Updated Firestore user document with new email');
      } else {
        // Create user document if it doesn't exist
        final newUser = app_user.User(
          id: currentUser.uid,
          name: currentUser.displayName ?? '',
          email: trimmedEmail,
          profilePictureUrl: currentUser.photoURL,
        );
        await _firestoreService.createUser(newUser);
        print('ProfileService: Created new user document in Firestore');
      }
      
      // Step 5: Update local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', trimmedEmail);
      print('ProfileService: Updated local storage with new email');
      
    } catch (e) {
      print('ProfileService: Error updating email: $e');
      throw Exception('Failed to update email: $e');
    }
  }

  /// Update password (Firebase only)
  Future<void> updatePassword(String currentPassword, String newPassword) async {
    try {
      if (!isFirebaseAuthenticated) {
        throw Exception('Password update is only available with Firebase authentication');
      }

      final currentUser = _auth.currentUser!;
      
      // Re-authenticate user before password change
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: currentPassword,
      );
      
      await currentUser.reauthenticateWithCredential(credential);
      
      // Update password
      await currentUser.updatePassword(newPassword);
      
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  /// Delete user account with complete Firestore cleanup (Firebase only)
  Future<void> deleteAccount(String currentPassword) async {
    try {
      if (!isFirebaseAuthenticated) {
        throw Exception('Account deletion is only available with Firebase authentication');
      }

      final currentUser = _auth.currentUser!;
      print('ProfileService: Starting account deletion for user: ${currentUser.uid}');
      
      // Step 1: Re-authenticate user before account deletion
      try {
        final credential = EmailAuthProvider.credential(
          email: currentUser.email!,
          password: currentPassword,
        );
        
        await currentUser.reauthenticateWithCredential(credential);
        print('ProfileService: User re-authenticated successfully');
      } catch (e) {
        print('ProfileService: Re-authentication failed: $e');
        throw Exception('Invalid password. Please check your password and try again.');
      }
      
      // Step 2: Delete all user transactions from Firestore
      try {
        final transactionsRef = _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('transactions');
        
        final transactionsSnapshot = await transactionsRef.get();
        print('ProfileService: Found ${transactionsSnapshot.docs.length} transactions to delete');
        
        // Delete transactions in smaller batches to avoid timeout
        if (transactionsSnapshot.docs.isNotEmpty) {
          const batchSize = 50; // Smaller batch size for safety
          
          for (int i = 0; i < transactionsSnapshot.docs.length; i += batchSize) {
            final batch = _firestore.batch();
            final endIndex = (i + batchSize < transactionsSnapshot.docs.length) 
                ? i + batchSize 
                : transactionsSnapshot.docs.length;
            
            for (int j = i; j < endIndex; j++) {
              batch.delete(transactionsSnapshot.docs[j].reference);
            }
            
            await batch.commit();
            print('ProfileService: Deleted batch ${(i / batchSize).floor() + 1}');
          }
        }
        
        print('ProfileService: Successfully deleted all ${transactionsSnapshot.docs.length} transactions');
      } catch (e) {
        print('ProfileService: Error deleting transactions: $e');
        // Continue with account deletion even if transaction deletion fails
        print('ProfileService: Continuing with account deletion despite transaction deletion error');
      }
      
      // Step 3: Delete user document from Firestore
      try {
        await _firestore.collection('users').doc(currentUser.uid).delete();
        print('ProfileService: Deleted user document from Firestore');
      } catch (e) {
        print('ProfileService: Error deleting user document: $e');
        // Continue with auth account deletion even if Firestore deletion fails
        print('ProfileService: Continuing with Firebase Auth deletion despite Firestore error');
      }
      
      // Step 4: Clear local storage before deleting auth account
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        print('ProfileService: Cleared local storage');
      } catch (e) {
        print('ProfileService: Error clearing local storage: $e');
      }
      
      // Step 5: Delete Firebase Auth account (this automatically signs out)
      try {
        await currentUser.delete();
        print('ProfileService: Successfully deleted Firebase Auth account');
      } catch (e) {
        print('ProfileService: Error deleting Firebase Auth account: $e');
        throw Exception('Failed to delete authentication account: $e');
      }
      
      print('ProfileService: Account deletion completed successfully');
      
    } catch (e) {
      print('ProfileService: Account deletion failed with error: $e');
      // Re-throw with more specific error message
      if (e.toString().contains('Invalid password')) {
        rethrow;
      } else if (e.toString().contains('requires-recent-login')) {
        throw Exception('This operation requires recent authentication. Please log out and log back in, then try again.');
      } else if (e.toString().contains('network-request-failed')) {
        throw Exception('Network error. Please check your internet connection and try again.');
      } else {
        throw Exception('Failed to delete account: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  /// Verify current password
  Future<bool> verifyCurrentPassword(String password) async {
    try {
      if (!isFirebaseAuthenticated) {
        return false;
      }

      final currentUser = _auth.currentUser!;
      
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: password,
      );
      
      await currentUser.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    try {
      if (!isFirebaseAuthenticated) {
        throw Exception('Email verification is only available with Firebase authentication');
      }

      final currentUser = _auth.currentUser!;
      await currentUser.sendEmailVerification();
    } catch (e) {
      throw Exception('Failed to send email verification: $e');
    }
  }

  /// Check if email is verified
  bool get isEmailVerified {
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Reload user to get latest verification status
  Future<void> reloadUser() async {
    if (isFirebaseAuthenticated) {
      await _auth.currentUser!.reload();
    }
  }

  /// Sync user data between Firebase Auth and Firestore
  Future<app_user.User?> syncUserData() async {
    try {
      if (!isFirebaseAuthenticated) {
        print('ProfileService: User not authenticated, cannot sync');
        return null;
      }

      final firebaseUser = _auth.currentUser!;
      
      // Reload Firebase user to get latest data
      await firebaseUser.reload();
      
      // Get current user from Firestore
      final firestoreUser = await _firestoreService.getUser();
      
      // If user doesn't exist in Firestore, create it from Firebase Auth data
      if (firestoreUser == null) {
        final newUser = app_user.User(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? '',
          email: firebaseUser.email ?? '',
          profilePictureUrl: firebaseUser.photoURL,
        );
        
        await _firestoreService.createUser(newUser);
        print('ProfileService: Created user document in Firestore from Firebase Auth data');
        
        // Update local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', newUser.id);
        await prefs.setString('user_name', newUser.name);
        await prefs.setString('user_email', newUser.email);
        
        return newUser;
      }
      
      // Check if Firestore data needs to be updated from Firebase Auth
      bool needsUpdate = false;
      String updatedName = firestoreUser.name;
      String updatedEmail = firestoreUser.email;
      String? updatedProfileUrl = firestoreUser.profilePictureUrl;
      
      if (firebaseUser.displayName != null && firebaseUser.displayName != firestoreUser.name) {
        updatedName = firebaseUser.displayName!;
        needsUpdate = true;
      }
      
      if (firebaseUser.email != null && firebaseUser.email != firestoreUser.email) {
        updatedEmail = firebaseUser.email!;
        needsUpdate = true;
      }
      
      if (firebaseUser.photoURL != firestoreUser.profilePictureUrl) {
        updatedProfileUrl = firebaseUser.photoURL;
        needsUpdate = true;
      }
      
      if (needsUpdate) {
        final updatedUser = firestoreUser.copyWith(
          name: updatedName,
          email: updatedEmail,
          profilePictureUrl: updatedProfileUrl,
        );
        
        await _firestoreService.updateUser(updatedUser);
        print('ProfileService: Synced Firestore data with Firebase Auth');
        
        // Update local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', updatedName);
        await prefs.setString('user_email', updatedEmail);
        
        return updatedUser;
      }
      
      // Update local storage with current data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', firestoreUser.id);
      await prefs.setString('user_name', firestoreUser.name);
      await prefs.setString('user_email', firestoreUser.email);
      
      return firestoreUser;
      
    } catch (e) {
      print('ProfileService: Error syncing user data: $e');
      throw Exception('Failed to sync user data: $e');
    }
  }
}