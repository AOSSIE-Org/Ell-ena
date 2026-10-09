import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/user_profile_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_widgets.dart';

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
  final _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isAvatarUpdating = false;

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;

  String? _fullName;
  String? _email;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();

    // Split full name into first and last name
    final nameParts = widget.userProfile['full_name']?.split(' ') ?? ['', ''];
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    _firstNameController = TextEditingController(text: firstName);
    _lastNameController = TextEditingController(text: lastName);
    _emailController =
        TextEditingController(text: widget.userProfile['email'] ?? '');

    _fullName = widget.userProfile['full_name'];
    _email = widget.userProfile['email'];
    _avatarUrl = widget.userProfile['avatar_url'] as String?;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final fullName = '$firstName $lastName'.trim();

      // Only update if something has changed
      if (fullName != _fullName) {
        final success = await _supabaseService.updateUserProfile({
          'full_name': fullName,
        });

        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile updated successfully'),
                backgroundColor: Colors.green,
              ),
            );

            // Call the callback to refresh the profile screen
            widget.onProfileUpdated();

            // Pop back to profile screen
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to update profile'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Nothing changed, just go back
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showImageSourceActionSheet() async {
    if (_isAvatarUpdating) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;
    await _pickAndPreviewImage(source);
  }

  Future<void> _pickAndPreviewImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      // Read bytes rather than using picked.path: XFile.path has no real
      // filesystem backing on Flutter Web, so both the preview and the
      // upload work from bytes instead, which behave identically on web,
      // mobile, and desktop.
      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      final confirmed = await _showAvatarPreviewDialog(bytes);
      if (confirmed == true) {
        await _uploadAvatar(bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool?> _showAvatarPreviewDialog(Uint8List bytes) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Update profile photo?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.memory(
                bytes,
                width: 140,
                height: 140,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will replace your current profile photo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadAvatar(Uint8List bytes) async {
    setState(() {
      _isAvatarUpdating = true;
    });

    try {
      final result = await _supabaseService.uploadAvatar(bytes);

      if (result['success'] == true) {
        final newUrl = result['avatar_url'] as String?;

        if (mounted) {
          setState(() {
            _avatarUrl = newUrl;
          });

          context.read<UserProfileController>().updateAvatarUrl(newUrl);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated'),
              backgroundColor: Colors.green,
            ),
          );

          widget.onProfileUpdated();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update photo: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAvatarUpdating = false;
        });
      }
    }
  }

  Future<void> _confirmAndRemoveAvatar() async {
    if (_isAvatarUpdating) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Remove profile photo?'),
        content: const Text(
          'Your profile photo will be removed and replaced with your initials.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _removeAvatar();
  }

  Future<void> _removeAvatar() async {
    setState(() {
      _isAvatarUpdating = true;
    });

    try {
      final result = await _supabaseService.removeAvatar();

      if (result['success'] == true) {
        if (mounted) {
          setState(() {
            _avatarUrl = null;
          });

          context.read<UserProfileController>().updateAvatarUrl(null);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo removed'),
              backgroundColor: Colors.green,
            ),
          );

          widget.onProfileUpdated();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove photo: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAvatarUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Edit Profile'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _saveProfile,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(Icons.save,
                    color: Theme.of(context).colorScheme.onSurface),
            label: Text('Save',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .shadow
                                          .withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: UserAvatar(
                                  avatarUrl: _avatarUrl,
                                  name: (_fullName ??
                                          widget.userProfile['full_name'] ??
                                          _email ??
                                          widget.userProfile['id'] ??
                                          '?')
                                      .toString(),
                                  radius: 50,
                                ),
                              ),
                              InkWell(
                                onTap: _isAvatarUpdating
                                    ? null
                                    : _showImageSourceActionSheet,
                                customBorder: const CircleBorder(),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade400,
                                    shape: BoxShape.circle,
                                  ),
                                  child: _isAvatarUpdating
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                            ],
                          ),
                          if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                            TextButton.icon(
                              onPressed: _isAvatarUpdating
                                  ? null
                                  : _confirmAndRemoveAvatar,
                              icon: Icon(Icons.delete_outline,
                                  color: Colors.red.shade400, size: 18),
                              label: Text(
                                'Remove Photo',
                                style: TextStyle(color: Colors.red.shade400),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Personal Information',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        helperText: 'Email cannot be changed',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Role',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
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
                                widget.userProfile['role'] == 'admin'
                                    ? 'Team Admin'
                                    : 'Team Member',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.userProfile['role'] == 'admin'
                                    ? 'You have admin privileges'
                                    : 'Standard team member access',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
