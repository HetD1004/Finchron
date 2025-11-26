import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../themes/app_colors.dart';

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get profile image widget for the current user
  Future<Widget> getProfileImageWidget({
    required String? profilePictureUrl,
    String? userId,
    String? userName,
    double radius = 24,
  }) async {
    try {
      // Use provided userId or get from current auth
      final uid = userId ?? _auth.currentUser?.uid;
      if (uid == null) {
        return _buildFallbackAvatar(userName, radius);
      }

      // First try to get image from Firestore
      final imageData = await getImageFromFirestore(uid);
      if (imageData != null) {
        return _buildBase64Avatar(imageData, radius);
      }

      // Fall back to network image if available
      if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
        return _buildNetworkAvatar(profilePictureUrl, userName, radius);
      }

      // Final fallback to generated avatar
      return _buildFallbackAvatar(userName, radius);
    } catch (e) {
      print('ImageService: Error loading profile image: $e');
      return _buildFallbackAvatar(userName, radius);
    }
  }

  /// Get image data from Firestore for a specific user
  Future<String?> getImageFromFirestore(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('image')
          .get();

      if (doc.exists && doc.data() != null) {
        return doc.data()!['imageData'] as String?;
      }
      return null;
    } catch (e) {
      print('ImageService: Error getting image from Firestore: $e');
      return null;
    }
  }

  /// Save image data to Firestore
  Future<void> saveImageToFirestore(String userId, String base64Data) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('image')
          .set({
        'imageData': base64Data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('ImageService: Image saved to Firestore successfully');
    } catch (e) {
      print('ImageService: Error saving image to Firestore: $e');
      throw Exception('Failed to save image: $e');
    }
  }

  /// Delete image data from Firestore
  Future<void> deleteImageFromFirestore(String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('image')
          .delete();
      print('ImageService: Image deleted from Firestore successfully');
    } catch (e) {
      print('ImageService: Error deleting image from Firestore: $e');
    }
  }

  Widget _buildBase64Avatar(String base64Data, double radius) {
    try {
      final Uint8List bytes = base64Decode(base64Data);
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(bytes),
        backgroundColor: Colors.transparent,
      );
    } catch (e) {
      print('ImageService: Error decoding base64 image: $e');
      return _buildFallbackAvatar(null, radius);
    }
  }

  Widget _buildNetworkAvatar(String url, String? userName, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.1),
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (exception, stackTrace) {
        print('ImageService: Error loading network image: $exception');
      },
      child: null, // Let the background image show, fallback handled by onBackgroundImageError
    );
  }

  Widget _buildFallbackAvatar(String? userName, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.1),
      child: Icon(
        Icons.person,
        color: AppColors.primary,
        size: radius * 1.2,
      ),
    );
  }

  /// Generate a color based on user name for consistent theming
  String generateColorFromName(String name) {
    final colors = ['FF5722', '2196F3', '4CAF50', 'FF9800', '9C27B0', 'F44336', '00BCD4', 'FFEB3B'];
    final hash = name.hashCode;
    final index = hash.abs() % colors.length;
    return colors[index];
  }
}