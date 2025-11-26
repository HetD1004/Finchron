import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:convert';
import '../themes/app_colors.dart';
import '../services/profile_service.dart';
import '../services/image_service.dart';
import '../models/user.dart' as app_user;
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import 'login_screen.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final ProfileService _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  
  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // State
  bool _isLoading = false;
  final bool _emailVerificationSent = false;
  bool _showPasswordSection = false;
  app_user.User? _currentUser;
  File? _selectedImage;
  bool _isUploadingImage = false;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      setState(() => _isLoading = true);
      
      // First sync data between Firebase Auth and Firestore
      await _profileService.syncUserData();
      
      // Then get the current user
      final user = await _profileService.getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUser = user;
          _nameController.text = user.name;
          _emailController.text = user.email;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load user profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      setState(() => _isLoading = true);
      
      String? profileImageUrl;
      
      // Upload image if selected
      if (_selectedImage != null) {
        profileImageUrl = await _uploadProfileImage(_selectedImage!);
      }
      
      final updatedUser = await _profileService.updateProfile(
        name: _nameController.text.trim(),
        profilePictureUrl: profileImageUrl,
      );
      
      setState(() {
        _currentUser = updatedUser;
        _selectedImage = null; // Clear selected image after successful upload
      });
      
      // Sync data to ensure consistency
      await _profileService.syncUserData();
      
      // Notify AuthBloc of the profile update
      if (mounted) {
        context.read<AuthBloc>().add(AuthUserProfileUpdated(user: updatedUser));
      }
      
      // Show success message with details
      if (profileImageUrl != null) {
        _showSuccessSnackBar('Profile and image updated successfully!');
      } else {
        _showSuccessSnackBar('Profile updated successfully!');
      }
      
      // Refresh the user data to ensure UI is in sync
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadCurrentUser();
      
    } catch (e) {
      _showErrorSnackBar('Failed to update profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _uploadProfileImage(File imageFile) async {
    try {
      setState(() => _isUploadingImage = true);
      
      if (_currentUser == null) {
        throw Exception('User not found');
      }
      
      if (_profileService.isFirebaseAuthenticated) {
        try {
          // Firebase Storage upload for authenticated users
          final storageRef = FirebaseStorage.instance.ref();
          final profileImageRef = storageRef.child('profile_images/${_currentUser!.id}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
          
          // Set metadata for the image
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'userId': _currentUser!.id,
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          );
          
          // Upload the file with metadata
          final uploadTask = profileImageRef.putFile(imageFile, metadata);
          
          // Wait for upload to complete
          final snapshot = await uploadTask;
          
          // Get the download URL
          final downloadUrl = await snapshot.ref.getDownloadURL();
          
          print('ProfileEditScreen: Image uploaded successfully to Firebase Storage');
          return downloadUrl;
          
        } catch (storageError) {
          print('ProfileEditScreen: Firebase Storage error: $storageError');
          
          // Handle specific Firebase Storage errors including the ones you're experiencing
          if (storageError.toString().contains('StorageException') || 
              storageError.toString().contains('operation was cancelled') ||
              storageError.toString().contains('AppCheckProvider') ||
              storageError.toString().contains('SSL') ||
              storageError.toString().contains('11727') ||
              storageError.toString().contains('storage') || 
              storageError.toString().contains('permission') ||
              storageError.toString().contains('firebase_storage/object-not-found') ||
              storageError.toString().contains('Code: -13040')) {
            
            print('ProfileEditScreen: Using fallback image due to Firebase Storage issues');
            return await _handleFallbackImageUpload(imageFile);
          } else {
            rethrow;
          }
        }
      } else {
        // For non-Firebase users, use fallback method
        return await _handleFallbackImageUpload(imageFile);
      }
      
    } catch (e) {
      print('ProfileEditScreen: General upload error: $e');
      _showErrorSnackBar('Failed to upload image: ${e.toString().replaceAll('Exception: ', '')}');
      return null;
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<String?> _handleFallbackImageUpload(File imageFile) async {
    try {
      // Convert image to base64 to save the actual image data
      final bytes = await imageFile.readAsBytes();
      final base64String = base64.encode(bytes);
      
      // Instead of using a data URL (which is too long for Firebase Auth),
      // we'll save the base64 data to Firestore and use a placeholder URL
      try {
        // Save the image data to Firestore using ImageService
        await ImageService().saveImageToFirestore(_currentUser!.id, base64String);
        
        // Use a placeholder URL that indicates image is stored in Firestore
        final placeholderUrl = 'firestore://profile_image/${_currentUser!.id}';
        
        print('ProfileEditScreen: Image saved to Firestore successfully');
        
        // Show user that their image is saved
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Image saved successfully!'),
                  SizedBox(height: 4),
                  Text(
                    'Your image has been saved to your profile.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
        
        return placeholderUrl;
        
      } catch (firestoreError) {
        print('ProfileEditScreen: Firestore save error: $firestoreError');
        
        // If Firestore also fails, generate a simple avatar
        final userInitial = _currentUser!.name.isNotEmpty ? _currentUser!.name[0].toUpperCase() : 'U';
        final avatarUrl = 'https://ui-avatars.com/api/?name=$userInitial&background=4CAF50&color=fff&size=200';
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile updated with generated avatar'),
                  SizedBox(height: 4),
                  Text(
                    'Unable to save custom image. Using generated avatar instead.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        
        return avatarUrl;
      }
      
    } catch (e) {
      print('ProfileEditScreen: Fallback upload error: $e');
      return null;
    }
  }

  Widget _buildProfileImage() {
    if (_selectedImage != null) {
      // Show the selected image file
      return Image.file(
        _selectedImage!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
      );
    } else {
      // Use ImageService to get the appropriate profile image
      return FutureBuilder<Widget>(
        future: ImageService().getProfileImageWidget(
          profilePictureUrl: _currentUser?.profilePictureUrl,
          userId: _currentUser?.id,
          userName: _currentUser?.name,
          radius: 60, // 120px diameter = 60px radius
        ),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ClipOval(
              child: SizedBox(
                width: 120,
                height: 120,
                child: snapshot.data!,
              ),
            );
          }
          // Loading state
          return Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      // Show options for camera or gallery
      final ImageSource? source = await _showImageSourceDialog();
      if (source == null) return;
      
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        
        _showSuccessSnackBar('Image selected! Save profile to upload.');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updatePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('New passwords do not match');
      return;
    }
    
    if (_newPasswordController.text.length < 6) {
      _showErrorSnackBar('Password must be at least 6 characters long');
      return;
    }
    
    try {
      setState(() => _isLoading = true);
      
      await _profileService.updatePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );
      
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _showPasswordSection = false);
      
      _showSuccessSnackBar('Password updated successfully!');
      
    } catch (e) {
      _showErrorSnackBar('Failed to update password: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendEmailVerification() async {
    try {
      await _profileService.sendEmailVerification();
      _showSuccessSnackBar('Verification email sent!');
    } catch (e) {
      _showErrorSnackBar('Failed to send verification email: $e');
    }
  }

  Future<void> _showDeleteAccountConfirmation() async {
    final passwordController = TextEditingController();
    bool isDeleting = false;
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false, // Prevent dismissing during deletion
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  const Text('Delete Account', style: TextStyle(color: Colors.red)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Are you absolutely sure you want to delete your account?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This action will permanently:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 8),
                        Text('• Delete your user account'),
                        Text('• Delete all your transactions'),
                        Text('• Delete all your data from our servers'),
                        Text('• Remove your authentication'),
                        SizedBox(height: 8),
                        Text(
                          'This action cannot be undone.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Enter your current password to confirm',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    enabled: !isDeleting,
                  ),
                  if (isDeleting) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Deleting your account and all data. This may take a moment...',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.of(context).pop('cancel'),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isDeleting ? null : () async {
                    if (passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter your password'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setDialogState(() {
                      isDeleting = true;
                    });

                    try {
                      print('ProfileEditScreen: Starting account deletion...');
                      await _profileService.deleteAccount(passwordController.text);
                      print('ProfileEditScreen: Account deletion successful');
                      Navigator.of(context).pop('success');
                    } catch (e) {
                      print('ProfileEditScreen: Account deletion failed: $e');
                      setDialogState(() {
                        isDeleting = false;
                      });
                      
                      // Show error in dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Delete failed: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: isDeleting 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Delete Account'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == 'success') {
      if (mounted) {
        // Navigate to login screen and clear all navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // Remove all previous routes
        );
        
        // Show success message on the login screen
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(child: Text('Account deleted successfully')),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'All your data has been permanently removed. You can create a new account if needed.',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 5),
              ),
            );
          }
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'DISMISS',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            IconButton(
              onPressed: _updateProfile,
              icon: const Icon(Icons.save),
              tooltip: 'Save Profile',
            ),
        ],
      ),
      body: _isLoading && _currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Picture Section
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.1),
                              border: Border.all(color: AppColors.primary, width: 2),
                            ),
                            child: ClipOval(
                              child: _buildProfileImage(),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: _isUploadingImage
                                  ? const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      onPressed: _pickImage,
                                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                      iconSize: 20,
                                      padding: const EdgeInsets.all(8),
                                    ),
                            ),
                          ),
                          if (_selectedImage != null)
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.green,
                                  border: Border.all(color: Colors.white, width: 1),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          if (_selectedImage != null)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImage = null;
                                  });
                                  _showSuccessSnackBar('Image selection cleared.');
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red,
                                    border: Border.all(color: Colors.white, width: 1),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_selectedImage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'New image selected. Save to update profile.',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Basic Information Section
                    _buildSection(
                      title: 'Basic Information',
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: const Icon(Icons.email),
                            border: const OutlineInputBorder(),
                            suffixIcon: _profileService.isFirebaseAuthenticated
                                ? (_profileService.isEmailVerified
                                    ? const Icon(Icons.verified, color: Colors.green)
                                    : IconButton(
                                        onPressed: _sendEmailVerification,
                                        icon: const Icon(Icons.send, color: Colors.orange),
                                        tooltip: 'Send verification email',
                                      ))
                                : null,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                          enabled: _profileService.isFirebaseAuthenticated,
                        ),
                        if (_emailVerificationSent)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info, color: Colors.blue, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Verification email sent. Please check your inbox.',
                                      style: TextStyle(color: Colors.blue, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Email Update Section (Firebase only)
                    if (_profileService.isFirebaseAuthenticated) ...[
                      const SizedBox(height: 24),

                      // Password Section
                      _buildSection(
                        title: 'Change Password',
                        children: [
                          if (!_showPasswordSection)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => setState(() => _showPasswordSection = true),
                                icon: const Icon(Icons.lock_outline),
                                label: const Text('Change Password'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            )
                          else ...[
                            TextFormField(
                              controller: _newPasswordController,
                              decoration: const InputDecoration(
                                labelText: 'New Password',
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(),
                                helperText: 'Minimum 6 characters',
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              decoration: const InputDecoration(
                                labelText: 'Confirm New Password',
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _updatePassword,
                                    icon: const Icon(Icons.save),
                                    label: const Text('Update Password'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() => _showPasswordSection = false);
                                    _newPasswordController.clear();
                                    _confirmPasswordController.clear();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Danger Zone Section
                      _buildSection(
                        title: 'Danger Zone',
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning, color: Colors.red[700], size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Delete Account',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Once you delete your account, there is no going back. This will permanently delete your account and all associated data including transactions.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _profileService.isFirebaseAuthenticated && !_isLoading 
                                        ? _showDeleteAccountConfirmation 
                                        : null,
                                    icon: const Icon(Icons.delete_forever),
                                    label: const Text('Delete Account'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[700],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                if (!_profileService.isFirebaseAuthenticated)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Account deletion is only available for Firebase authenticated users.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}