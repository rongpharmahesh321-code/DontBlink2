import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'edit_profile_screen.dart';
import 'my_addresses_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  static const Color doorsteppGreen = Color(0xFF168A43);
  static const Color backgroundColor = Color(0xFFF7FAF8);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool loadingProfile = true;

  String profileName = '';
  String profileEmail = '';
  String profilePhone = '';
  String profilePhoto = '';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        loadingProfile = false;
      });

      return;
    }

    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();

      final data = snapshot.data();

      if (!mounted) return;

      setState(() {
        profileEmail = user.email ?? data?['email']?.toString() ?? '';

        profileName =
            data?['name']?.toString().trim() ?? user.displayName?.trim() ?? '';

        profilePhone =
            data?['phone']?.toString().trim() ?? user.phoneNumber?.trim() ?? '';

        profilePhoto =
            data?['photoUrl']?.toString().trim() ?? user.photoURL?.trim() ?? '';

        loadingProfile = false;
      });
    } catch (e) {
      debugPrint('Profile loading error: $e');

      if (!mounted) return;

      setState(() {
        profileEmail = user.email ?? '';
        profileName = user.displayName ?? '';
        profilePhone = user.phoneNumber ?? '';
        profilePhoto = user.photoURL ?? '';
        loadingProfile = false;
      });
    }
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          initialName: profileName,
          initialEmail: profileEmail,
          initialPhone: profilePhone,
          initialPhotoUrl: profilePhoto,
        ),
      ),
    );

    if (updated == true) {
      await _loadProfile();
    }
  }

  Future<void> _addPhone() async {
    final phone = await _authService.getSavedPhoneNumber();

    if (phone != null && phone.trim().isNotEmpty) {
      if (!mounted) return;

      _showMessage(
        'A verified phone number is already linked to your account.',
        success: true,
      );

      return;
    }

    await _showPhoneDialog();
    await _loadProfile();
  }

  Future<void> _showPhoneDialog() async {
    final phoneController = TextEditingController();
    final otpController = TextEditingController();

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
                otpSent ? 'Verify Mobile Number' : 'Add Mobile Number',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    otpSent
                        ? 'Enter the OTP sent to your mobile number.'
                        : 'Add a mobile number to your doorstepp account.',
                  ),
                  const SizedBox(height: 18),
                  if (!otpSent)
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        prefixText: '+91 ',
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  if (otpSent)
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 5,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (!otpSent) {
                            final phone = phoneController.text
                                .trim()
                                .replaceAll(RegExp(r'\s+'), '');

                            if (phone.length != 10) {
                              _showMessage(
                                'Enter a valid 10-digit mobile number.',
                              );
                              return;
                            }

                            setDialogState(() {
                              loading = true;
                            });

                            await _authService.sendOtpForCurrentUser(
                              phoneNumber: '+91$phone',
                              onCodeSent: (id) {
                                verificationId = id;

                                setDialogState(() {
                                  loading = false;
                                  otpSent = true;
                                });
                              },
                              onError: (error) {
                                setDialogState(() {
                                  loading = false;
                                });

                                _showMessage(error);
                              },
                            );

                            return;
                          }

                          final otp = otpController.text.trim();

                          if (otp.length != 6) {
                            _showMessage('Enter the 6-digit OTP.');
                            return;
                          }

                          if (verificationId == null) {
                            _showMessage(
                              'Verification expired. Please request a new OTP.',
                            );
                            return;
                          }

                          setDialogState(() {
                            loading = true;
                          });

                          try {
                            await _authService.verifyOtpAndLinkPhone(
                              verificationId: verificationId!,
                              otp: otp,
                            );

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            if (!mounted) return;

                            await _loadProfile();

                            _showMessage(
                              'Mobile number verified successfully.',
                              success: true,
                            );
                          } catch (e) {
                            setDialogState(() {
                              loading = false;
                            });

                            _showMessage(
                              e.toString().replaceFirst('Exception: ', ''),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: doorsteppGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
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

    phoneController.dispose();
    otpController.dispose();
  }

  Widget _buildAvatar() {
    ImageProvider? imageProvider;

    if (profilePhoto.isNotEmpty) {
      if (profilePhoto.startsWith('data:image') ||
          profilePhoto.startsWith('base64,')) {
        try {
          final cleanBase64 = profilePhoto.contains(',')
              ? profilePhoto.split(',').last
              : profilePhoto;
          imageProvider = MemoryImage(base64Decode(cleanBase64));
        } catch (_) {
          imageProvider = null;
        }
      } else {
        imageProvider = NetworkImage(profilePhoto);
      }
    }

    final initial = profileName.trim().isNotEmpty
        ? profileName.trim()[0].toUpperCase()
        : 'D';

    return CircleAvatar(
      radius: 44,
      backgroundColor: Colors.white,
      child: ClipOval(
        child: imageProvider != null
            ? Image(
                image: imageProvider,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildAvatarFallback(initial),
              )
            : _buildAvatarFallback(initial),
      ),
    );
  }

  Widget _buildAvatarFallback(String initial) {
    return Container(
      width: 88,
      height: 88,
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: doorsteppGreen,
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final displayName = profileName.isNotEmpty ? profileName : 'doorstepp User';
    final hasPhone = profilePhone.isNotEmpty;
    final hasEmail = profileEmail.isNotEmpty;

    return ScaleTransition(
      scale: Tween<double>(begin: 0.96, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
        decoration: BoxDecoration(
          color: doorsteppGreen,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: doorsteppGreen.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: _openEditProfile,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildAvatar(),
                  Positioned(
                    right: -2,
                    bottom: -1,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: doorsteppGreen,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 15, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'Verified Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (hasPhone || hasEmail)
              Column(
                children: [
                  if (hasPhone)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 15,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            profilePhone,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (hasEmail) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 15,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            profileEmail,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _openEditProfile,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 15, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Edit Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
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

  Widget buildTile({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
    Color color = Colors.black87,
    int index = 0,
    String? subtitle,
  }) {
    final bool isLogout = color == Colors.red;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index * 45),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        elevation: 1.5,
        margin: const EdgeInsets.only(bottom: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isLogout
                        ? Colors.red.shade50
                        : const Color(0xFFF0F9F2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isLogout ? Colors.red : doorsteppGreen,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await _authService.signOut();
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Logout?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _logout();
              },
              child: const Text('LOGOUT'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? doorsteppGreen : Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }

  // ==========================================================
  // PROMO CARD
  // ==========================================================

  Widget _buildDoorsteppPromo() {
    const promoCardColor = Color(0xFFF8FBF8);

    return Container(
      width: double.infinity,
      height: 132,
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: promoCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: doorsteppGreen.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final logoSectionWidth = (constraints.maxWidth * 0.20)
              .clamp(60.0, 72.0)
              .toDouble();
          final grocerySectionWidth = (constraints.maxWidth * 0.22)
              .clamp(64.0, 76.0)
              .toDouble();

          return Row(
            children: [
              SizedBox(
                width: logoSectionWidth,
                child: Center(
                  child: Image.asset(
                    'assets/images/doorstepp_logo.jpeg',
                    width: 56,
                    height: 54,
                    fit: BoxFit.contain,
                    color: promoCardColor,
                    colorBlendMode: BlendMode.multiply,
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 1,
                  height: 68,
                  color: doorsteppGreen.withValues(alpha: 0.14),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Groceries delivered in minutes',
                        style: TextStyle(
                          color: doorsteppGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fresh groceries, daily essentials & more '
                        'delivered to your doorstep.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: grocerySectionWidth,
                child: Center(
                  child: Image.asset(
                    'assets/images/grocery_delivery.jpeg',
                    width: 56,
                    height: 58,
                    fit: BoxFit.contain,
                    color: promoCardColor,
                    colorBlendMode: BlendMode.multiply,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: doorsteppGreen,
        foregroundColor: Colors.white,
      ),

      body: loadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: doorsteppGreen),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: RefreshIndicator(
                  color: doorsteppGreen,
                  onRefresh: _loadProfile,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    children: [
                      _buildProfileHeader(),

                      const SizedBox(height: 14),

                      const Padding(
                        padding: EdgeInsets.only(left: 3, bottom: 7),
                        child: Text(
                          'My Account',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      buildTile(
                        icon: Icons.location_on_outlined,
                        title: 'My Addresses',
                        subtitle: 'Manage your saved delivery addresses',
                        index: 0,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MyAddressesScreen(),
                            ),
                          );
                        },
                      ),

                      buildTile(
                        icon: profilePhone.isEmpty
                            ? Icons.phone_android_outlined
                            : Icons.verified_outlined,
                        title: profilePhone.isEmpty
                            ? 'Add Mobile Number'
                            : 'Mobile Number',
                        subtitle: profilePhone.isEmpty
                            ? 'Verify your mobile number'
                            : '$profilePhone • Verified',
                        index: 1,
                        onTap: _addPhone,
                      ),

                      const SizedBox(height: 5),

                      const Padding(
                        padding: EdgeInsets.only(left: 3, bottom: 7),
                        child: Text(
                          'Preferences',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      buildTile(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        subtitle: 'Manage app settings and account',
                        index: 2,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),

                      buildTile(
                        icon: Icons.logout,
                        title: 'Logout',
                        subtitle: 'Sign out from your account',
                        color: Colors.red,
                        index: 3,
                        onTap: () => _showLogoutDialog(context),
                      ),

                      const SizedBox(height: 7),

                      _buildDoorsteppPromo(),

                      const SizedBox(height: 12),

                      const Center(
                        child: Text(
                          'doorstepp',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 2),

                      const Center(
                        child: Text(
                          'Groceries delivered in minutes',
                          style: TextStyle(color: Colors.grey, fontSize: 10.5),
                        ),
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
