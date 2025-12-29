import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/user_avatar.dart';

// Intent classes for keyboard shortcuts
class _DiscardChangesIntent extends Intent {
  const _DiscardChangesIntent();
}

class _SaveProfileIntent extends Intent {
  const _SaveProfileIntent();
}

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final VoidCallback onProfileUpdated;

  const EditProfileScreen({
    Key? key,
    required this.userProfile,
    required this.onProfileUpdated,
  }) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();
  final _picker = ImagePicker();

  // Loading states
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  // Form data
  File? _selectedImage;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;

  String? _initialFirstName;
  String? _initialLastName;
  String? _avatarUrl;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final nameParts = widget.userProfile['full_name']?.split(' ') ?? ['', ''];
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    _initialFirstName = firstName;
    _initialLastName = lastName;
    _avatarUrl = widget.userProfile['avatar_url'];
    _currentAvatarUrl = widget.userProfile['avatar_url'];

    _firstNameController = TextEditingController(text: firstName);
    _lastNameController = TextEditingController(text: lastName);
    _emailController = TextEditingController(text: widget.userProfile['email'] ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final initialFullName = '$_initialFirstName $_initialLastName'.trim();
    final currentFullName = '${_firstNameController.text} ${_lastNameController.text}'.trim();
    
    return _selectedImage != null ||
        currentFullName != initialFullName ||
        (_avatarUrl == null && _currentAvatarUrl != null) ||
        (_avatarUrl != null && _avatarUrl != _currentAvatarUrl);
  }

  // ---------------- IMAGE HANDLING ----------------
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        final fileSize = await imageFile.length();
        
        // Validate file size (5MB limit)
        if (fileSize > 5 * 1024 * 1024) {
          if (!mounted) return;
          _showErrorSnackBar('Image size should be less than 5MB');
          return;
        }

        // Validate image dimensions
        try {
          final imageData = await imageFile.readAsBytes();
          final image = await decodeImageFromList(imageData);
          if (image.width < 100 || image.height < 100) {
            if (!mounted) return;
            _showErrorSnackBar('Image should be at least 100x100 pixels');
            return;
          }
        } catch (e) {
          debugPrint('Error decoding image: $e');
        }

        // Compress image if needed
        final compressedImage = await _compressImageIfNeeded(imageFile);
        final fileToUse = compressedImage ?? imageFile;
        
        setState(() {
          _selectedImage = fileToUse;
          // Clear the avatar URL to show the selected image instead of the old one
          _avatarUrl = null;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: ${e.toString()}');
    }
  }

  Future<File?> _compressImageIfNeeded(File imageFile) async {
    try {
      final imageData = await imageFile.readAsBytes();
      if (imageData.length < 1 * 1024 * 1024) {
        return null; // No need to compress if < 1MB
      }

      final image = await decodeImageFromList(imageData);
      
      // Calculate new dimensions while maintaining aspect ratio
      final maxDimension = 800;
      int newWidth = image.width;
      int newHeight = image.height;

      if (image.width > maxDimension || image.height > maxDimension) {
        if (image.width > image.height) {
          newWidth = maxDimension;
          newHeight = (image.height * maxDimension / image.width).round();
        } else {
          newHeight = maxDimension;
          newWidth = (image.width * maxDimension / image.height).round();
        }
      }

      // Create a new canvas with the new dimensions
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();
      final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      final dst = Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble());
      canvas.drawImageRect(image, src, dst, paint);
      final picture = recorder.endRecording();
      final newImage = await picture.toImage(newWidth, newHeight);
      final byteData = await newImage.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      // Save compressed image to temp directory
      final tempDir = await getTemporaryDirectory();
      final compressedFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.png');
      await compressedFile.writeAsBytes(bytes);

      debugPrint('Image compressed from ${imageData.length ~/ 1024}KB to ${bytes.length ~/ 1024}KB');
      return compressedFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  Future<void> _removeImage() async {
    if (_currentAvatarUrl == null && _selectedImage == null && _avatarUrl == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Profile Picture?'),
        content: const Text('Are you sure you want to remove your profile picture?'),
        backgroundColor: const Color(0xFF2D2D2D),
        surfaceTintColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUploadingImage = true);

    try {
      bool deleteSuccessful = true;
      
      // Only delete from storage if we have an existing URL AND we're not just removing a newly selected image
      if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty && _selectedImage == null) {
        final fileName = _extractFileNameFromUrl(_currentAvatarUrl!);
        
        if (fileName != null && fileName.isNotEmpty) {
          final deleteResult = await _supabaseService.deleteProfileImage(fileName);
          deleteSuccessful = deleteResult['success'] == true;
        }
      }

      if (deleteSuccessful) {
        setState(() {
          _selectedImage = null;
          _avatarUrl = null;
        });
        _showSuccessSnackBar('Profile picture removed');
      } else {
        _showErrorSnackBar('Failed to remove profile picture');
      }
    } catch (e) {
      debugPrint('Error removing image: $e');
      _showErrorSnackBar('Error removing profile picture: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  String? _extractFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      final publicIndex = pathSegments.indexOf('public');
      if (publicIndex != -1 && pathSegments.length > publicIndex + 2) {
        return pathSegments.sublist(publicIndex + 2).join('/');
      }
      
      final pattern = RegExp(r'avatars/(.+)');
      final match = pattern.firstMatch(url);
      return match?.group(1);
    } catch (e) {
      debugPrint('Error extracting filename: $e');
      return null;
    }
  }

  // ---------------- VALIDATION ----------------
  String? _validateName(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (value.length > 50) {
      return '$fieldName is too long (max 50 characters)';
    }
    if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(value)) {
      return '$fieldName can only contain letters, spaces, and hyphens';
    }
    return null;
  }

  // ---------------- SAVE PROFILE ----------------
  Future<void> _saveProfile() async {
    if (_isSaving || _isLoading) return;
    
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> updates = {};
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final fullName = '$firstName $lastName'.trim();

      // Validate name length
      if (fullName.length > 100) {
        _showErrorSnackBar('Name is too long (max 100 characters)');
        return;
      }

      // 1️⃣ Handle profile image changes
      if (_selectedImage != null) {
        try {
          setState(() => _isUploadingImage = true);
          final imageUrl = await _supabaseService.uploadProfileImage(_selectedImage!);
          if (imageUrl != null) {
            updates['avatar_url'] = imageUrl;
          }
        } catch (e) {
          debugPrint('Upload image error: $e');
          _showErrorSnackBar('Failed to upload profile image');
          return;
        } finally {
          setState(() => _isUploadingImage = false);
        }
      } else if (_avatarUrl == null && _currentAvatarUrl != null && _selectedImage == null) {
        // User removed their existing avatar (and didn't select a new one)
        updates['avatar_url'] = null;
      }

      // 2️⃣ Update name if changed
      final initialFullName = '$_initialFirstName $_initialLastName'.trim();
      if (fullName != initialFullName) {
        updates['full_name'] = fullName;
      }

      // 3️⃣ Send updates if any
      if (updates.isNotEmpty) {
        final success = await _supabaseService.updateUserProfile(updates);
        if (!success) {
          _showErrorSnackBar('Failed to update profile');
          return;
        }
      }

      if (!mounted) return;

      _showSuccessSnackBar('Profile updated successfully');
      widget.onProfileUpdated();
      Navigator.pop(context);
    } on SocketException catch (e) {
      _showErrorSnackBar('No internet connection. Please check your network.');
    } on HttpException catch (e) {
      _showErrorSnackBar('Network error: ${e.message}');
    } on FormatException catch (e) {
      _showErrorSnackBar('Data format error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error updating profile: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isLoading = false;
        });
      }
    }
  }

  // ---------------- SNACKBARS ----------------
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const _DiscardChangesIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const _SaveProfileIntent(),
      },
      actions: {
        _DiscardChangesIntent: CallbackAction(
          onInvoke: (_) {
            if (_hasChanges && !_isLoading) {
              _showDiscardChangesDialog();
            } else {
              Navigator.pop(context);
            }
            return null;
          },
        ),
        _SaveProfileIntent: CallbackAction(
          onInvoke: (_) {
            if (!_isLoading) {
              _saveProfile();
            }
            return null;
          },
        ),
      },
      child: PopScope(
        canPop: !_isLoading && !_isUploadingImage,
        onPopInvoked: (didPop) async {
          if (!didPop && _hasChanges && !_isLoading) {
            final shouldPop = await _showDiscardChangesDialog();
            if (shouldPop) {
              Navigator.pop(context);
            }
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF1A1A1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2D2D2D),
            title: const Text('Edit Profile'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: (_isLoading || _isUploadingImage) ? null : () => Navigator.pop(context),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _buildSaveButton(),
              ),
            ],
          ),
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    final isSaving = _isLoading || _isSaving;
    
    return TextButton(
      onPressed: isSaving ? null : _saveProfile,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.grey.shade600,
      ),
      child: isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Row(
              children: [
                Icon(Icons.save, size: 20),
                SizedBox(width: 4),
                Text('Save'),
              ],
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading || _isUploadingImage) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Processing...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileImageSection(),
              const SizedBox(height: 32),
              _buildPersonalInfoSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              // Show selected image preview if exists, otherwise show current avatar
              if (_selectedImage != null)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                    ),
                  ),
                )
              else
                UserAvatar(
                  avatarUrl: _avatarUrl,
                  fullName: '${_firstNameController.text} ${_lastNameController.text}',
                  size: 120,
                  showBorder: true,
                  borderColor: Colors.white,
                  borderWidth: 3,
                ),
              if (!_isUploadingImage)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_isUploadingImage)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Change Photo'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green.shade400,
                  ),
                ),
                if (_avatarUrl != null || _selectedImage != null) ...[
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: _removeImage,
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                    ),
                  ),
                ],
              ],
            ),
          // Show preview text
          if (_selectedImage != null)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'Preview: New profile picture',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal Information',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _firstNameController,
              label: 'First Name',
              icon: Icons.person_outline,
              maxLength: 50,
              validator: (value) => _validateName(value, 'First name'),
            ),
            const SizedBox(height: 4),
            _buildCharacterCount(
              controller: _firstNameController,
              maxLength: 50,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _lastNameController,
              label: 'Last Name',
              icon: Icons.person_outline,
              maxLength: 50,
              validator: (value) => _validateName(value, 'Last name'),
            ),
            const SizedBox(height: 4),
            _buildCharacterCount(
              controller: _lastNameController,
              maxLength: 50,
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          readOnly: true,
          style: TextStyle(color: Colors.grey.shade500),
          decoration: InputDecoration(
            labelText: 'Email',
            labelStyle: TextStyle(color: Colors.grey.shade600),
            helperText: 'Email cannot be changed',
            helperStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade600),
            filled: true,
            fillColor: const Color(0xFF1F1F1F),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade800),
            ),
          ),
        ),
                     const SizedBox(height: 32),
                    const Text(
                      'Role',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.userProfile['role'] == 'admin'
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.userProfile['role'] == 'admin'
                                  ? Icons.admin_panel_settings
                                  : Icons.person,
                              color: widget.userProfile['role'] == 'admin'
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.userProfile['role'] == 'admin' ? 'Team Admin' : 'Team Member',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.userProfile['role'] == 'admin'
                                    ? 'You have admin privileges'
                                    : 'Standard team member access',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),     
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400),
        counterText: '', // Hide default counter
        prefixIcon: Icon(icon, color: Colors.grey.shade400),
        filled: true,
        fillColor: const Color(0xFF2D2D2D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade400),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
      ),
    );
  }

  Widget _buildCharacterCount({
    required TextEditingController controller,
    required int maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(
        '${controller.text.length}/$maxLength',
        style: TextStyle(
          color: controller.text.length > maxLength 
            ? Colors.red 
            : Colors.grey.shade500,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<bool> _showDiscardChangesDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        backgroundColor: const Color(0xFF2D2D2D),
        surfaceTintColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}