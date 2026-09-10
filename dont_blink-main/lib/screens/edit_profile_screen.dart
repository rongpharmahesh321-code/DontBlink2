import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String initialPhone;
  final String initialPhotoUrl;

  const EditProfileScreen({
    super.key,
    required this.initialName,
    required this.initialEmail,
    required this.initialPhone,
    required this.initialPhotoUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  File? _selectedImageFile;
  String _currentPhotoUrl = '';
  bool _removePhoto = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _phoneController = TextEditingController(
      text: widget.initialPhone.replaceAll('+91', '').trim(),
    );
    _currentPhotoUrl = widget.initialPhotoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // IMAGE SELECTION & UPLOAD
  // ---------------------------------------------------------------------------

  Future<void> _showPhotoPickerSheet() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Profile Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _photoOptionButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                    _photoOptionButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                    if (_currentPhotoUrl.isNotEmpty || _selectedImageFile != null)
                      _photoOptionButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'Remove',
                        color: Colors.red,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          setState(() {
                            _selectedImageFile = null;
                            _currentPhotoUrl = '';
                            _removePhoto = true;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _photoOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 480,
        maxHeight: 480,
        imageQuality: 75,
      );

      if (file == null) return;

      setState(() {
        _selectedImageFile = File(file.path);
        _removePhoto = false;
      });
    } catch (e) {
      _showSnackbar('Failed to select image: $e', isError: true);
    }
  }

  Future<String?> _uploadImageToStorage(File file, String userId) async {
    try {
      final bytes = await file.readAsBytes();
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(userId)
          .child(fileName);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public,max-age=31536000,immutable',
      );

      final uploadTask = ref.putData(bytes, metadata);
      // Timeout after 6 seconds if storage network hangs or is blocked
      await uploadTask.timeout(const Duration(seconds: 6));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Firebase Storage upload failed: $e. Falling back to Base64...');
      try {
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64String';
      } catch (fallbackError) {
        debugPrint('Base64 fallback failed: $fallbackError');
        return null;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PHONE LINKING DIALOG
  // ---------------------------------------------------------------------------

  Future<void> _linkPhoneDialog() async {
    final phoneInputController = TextEditingController(
      text: _phoneController.text.trim(),
    );
    final otpInputController = TextEditingController();

    String? verificationId;
    bool otpSent = false;
    bool loading = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                otpSent ? 'Verify Mobile Number' : 'Link Mobile Number',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    otpSent
                        ? 'Enter the 6-digit OTP sent to your phone.'
                        : 'Enter your 10-digit mobile number for order updates.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!otpSent)
                    TextField(
                      controller: phoneInputController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        prefixText: '+91 ',
                        counterText: '',
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  if (otpSent)
                    TextField(
                      controller: otpInputController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (!otpSent) {
                            final rawPhone = phoneInputController.text
                                .trim()
                                .replaceAll(RegExp(r'\s+'), '');
                            if (rawPhone.length != 10) {
                              _showSnackbar(
                                'Enter a valid 10-digit mobile number.',
                                isError: true,
                              );
                              return;
                            }

                            setDialogState(() => loading = true);

                            await _authService.sendOtpForCurrentUser(
                              phoneNumber: '+91$rawPhone',
                              onCodeSent: (id) {
                                verificationId = id;
                                setDialogState(() {
                                  loading = false;
                                  otpSent = true;
                                });
                              },
                              onError: (err) {
                                setDialogState(() => loading = false);
                                _showSnackbar(err, isError: true);
                              },
                            );
                            return;
                          }

                          final otp = otpInputController.text.trim();
                          if (otp.length != 6) {
                            _showSnackbar('Enter the 6-digit OTP.', isError: true);
                            return;
                          }

                          if (verificationId == null) {
                            _showSnackbar(
                              'Verification expired. Please request a new OTP.',
                              isError: true,
                            );
                            return;
                          }

                          setDialogState(() => loading = true);

                          try {
                            await _authService.verifyOtpAndLinkPhone(
                              verificationId: verificationId!,
                              otp: otp,
                            );

                            final rawPhone = phoneInputController.text.trim();
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (mounted) {
                              setState(() {
                                _phoneController.text = rawPhone;
                              });
                              _showSnackbar(
                                'Mobile number verified and linked!',
                                isError: false,
                              );
                            }
                          } catch (e) {
                            setDialogState(() => loading = false);
                            _showSnackbar(
                              e.toString().replaceFirst('Exception: ', ''),
                              isError: true,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(otpSent ? 'VERIFY' : 'SEND OTP'),
                ),
              ],
            );
          },
        );
      },
    );

    phoneInputController.dispose();
    otpInputController.dispose();
  }

  // ---------------------------------------------------------------------------
  // SAVE CHANGES
  // ---------------------------------------------------------------------------

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      String? photoUrl = _currentPhotoUrl;

      // If a new photo was selected, upload it
      if (_selectedImageFile != null) {
        setState(() => _isUploadingPhoto = true);
        final uploadedUrl = await _uploadImageToStorage(
          _selectedImageFile!,
          user.uid,
        );
        if (uploadedUrl != null) {
          photoUrl = uploadedUrl;
        }
      } else if (_removePhoto) {
        photoUrl = '';
      }

      // Update Firebase Auth DisplayName & PhotoUrl
      await user.updateDisplayName(name);
      if (photoUrl.isNotEmpty && photoUrl.startsWith('http')) {
        try {
          await user.updatePhotoURL(photoUrl);
        } catch (_) {}
      } else if (photoUrl.isEmpty) {
        try {
          await user.updatePhotoURL(null);
        } catch (_) {}
      }

      // Update Firestore document
      final updateData = <String, dynamic>{
        'name': name,
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // If phone was entered without OTP verification but already has a value
      final phone = _phoneController.text.trim();
      if (phone.isNotEmpty && phone.length == 10) {
        updateData['phone'] = '+91$phone';
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      if (!mounted) return;

      _showSnackbar('Profile updated successfully!', isError: false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar(
        'Failed to save profile: ${e.toString().replaceFirst('Exception: ', '')}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploadingPhoto = false;
        });
      }
    }
  }

  void _showSnackbar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : AppColors.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // UI BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isGoogleUser = user != null &&
        user.providerData.any(
          (p) => p.providerId == 'google.com',
        );

    final hasVerifiedPhone = user?.phoneNumber?.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar Section
              _buildAvatarPicker(),

              const SizedBox(height: 8),

              Text(
                'Tap avatar to change photo',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 28),

              // Personal Information Card
              _buildSectionCard(
                title: 'Personal Information',
                icon: Icons.person_outline_rounded,
                children: [
                  // Name Field
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hintText: 'Enter your full name',
                    icon: Icons.person_rounded,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      if (val.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // Email Field
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hintText: 'Enter your email address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: true,
                    helperText: isGoogleUser
                        ? 'Linked with Google Account'
                        : 'Registered Doorstepp email',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tintGreen,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.tintGreenBorder),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Phone Field
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Mobile Number',
                    hintText: '98765 43210',
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    prefixText: '+91 ',
                    readOnly: hasVerifiedPhone,
                    maxLength: 10,
                    trailing: hasVerifiedPhone
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.tintGreen,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.tintGreenBorder,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Linked',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : TextButton.icon(
                            onPressed: _linkPhoneDialog,
                            icon: const Icon(
                              Icons.add_link_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            label: const Text(
                              'Verify',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Save Changes Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isUploadingPhoto
                                  ? 'Uploading photo...'
                                  : 'Saving changes...',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AVATAR PICKER WIDGET
  // ---------------------------------------------------------------------------

  Widget _buildAvatarPicker() {
    ImageProvider? imageProvider;

    if (_selectedImageFile != null) {
      imageProvider = FileImage(_selectedImageFile!);
    } else if (_currentPhotoUrl.isNotEmpty && !_removePhoto) {
      if (_currentPhotoUrl.startsWith('data:image') ||
          _currentPhotoUrl.startsWith('base64,')) {
        try {
          final cleanBase64 = _currentPhotoUrl.contains(',')
              ? _currentPhotoUrl.split(',').last
              : _currentPhotoUrl;
          imageProvider = MemoryImage(base64Decode(cleanBase64));
        } catch (_) {
          imageProvider = null;
        }
      } else {
        imageProvider = NetworkImage(_currentPhotoUrl);
      }
    }

    final initialLetter = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()[0].toUpperCase()
        : 'D';

    return Center(
      child: GestureDetector(
        onTap: _isSaving ? null : _showPhotoPickerSheet,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.tintGreen,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: imageProvider != null
                    ? Image(
                        image: imageProvider,
                        fit: BoxFit.cover,
                        width: 104,
                        height: 104,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackAvatar(initialLetter),
                      )
                    : _buildFallbackAvatar(initialLetter),
              ),
            ),
            if (_isUploadingPhoto)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String initial) {
    return Container(
      color: AppColors.tintGreen,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FORM CARDS & TEXT FIELDS
  // ---------------------------------------------------------------------------

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.tintGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    String? prefixText,
    String? helperText,
    Widget? trailing,
    bool readOnly = false,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            trailing ?? const SizedBox.shrink(),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          maxLength: maxLength,
          validator: validator,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: readOnly ? Colors.grey.shade700 : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              icon,
              color: readOnly ? Colors.grey.shade500 : AppColors.primary,
              size: 20,
            ),
            prefixText: prefixText,
            prefixStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            counterText: '',
            helperText: helperText,
            helperStyle: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade600,
            ),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF9FAF9) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.border,
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.red.shade400,
                width: 1.2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
