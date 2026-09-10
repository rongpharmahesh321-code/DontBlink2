import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================
  // SETTINGS STATE
  // ==========================================================

  bool notificationsEnabled = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================================
  // ANIMATION
  // ==========================================================

  late final AnimationController _controller;

  late final Animation<double> _fadeAnimation;

  late final Animation<Offset> _slideAnimation;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
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
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  // ==========================================================
  // CURRENT USER
  // ==========================================================

  User? get currentUser => FirebaseAuth.instance.currentUser;

  // ==========================================================
  // PROFILE BANNER
  // ==========================================================

  Widget _buildProfileBanner() {
    final user = currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['name']?.toString().trim() ??
            user.displayName?.trim() ??
            'doorstepp User';
        final email = user.email ?? data?['email']?.toString() ?? '';
        final phone = data?['phone']?.toString().trim() ??
            user.phoneNumber?.trim() ??
            '';
        final photoUrl = data?['photoUrl']?.toString().trim() ??
            user.photoURL?.trim() ??
            '';

        ImageProvider? avatarImage;
        if (photoUrl.isNotEmpty) {
          if (photoUrl.startsWith('data:image') ||
              photoUrl.startsWith('base64,')) {
            try {
              final clean = photoUrl.contains(',')
                  ? photoUrl.split(',').last
                  : photoUrl;
              avatarImage = MemoryImage(base64Decode(clean));
            } catch (_) {}
          } else {
            avatarImage = NetworkImage(photoUrl);
          }
        }

        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.tintGreen,
                child: ClipOval(
                  child: avatarImage != null
                      ? Image(
                          image: avatarImage,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Text(
                            initial,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        )
                      : Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email.isNotEmpty
                          ? email
                          : (phone.isNotEmpty ? phone : 'doorstepp Account'),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // GROUPED CONTAINERS & ITEMS
  // ==========================================================

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildGroupContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildGroupItem({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
    Color? iconBgColor,
    Color? titleColor,
    Widget? trailing,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBgColor ?? AppColors.tintGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: iconColor ?? AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: titleColor ?? Colors.black87,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.grey.shade400,
                    ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Divider(height: 1, color: Colors.grey.shade100),
          ),
      ],
    );
  }

  void _clearCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('App cache cleared successfully!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ==========================================================
  // ACCOUNT INFORMATION DIALOG
  // ==========================================================

  void _showAccountInformation() {
    final User? user = currentUser;

    if (user == null) {
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Account Information',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Email',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(user.email ?? 'Not available'),
              const SizedBox(height: 18),
              const Text(
                'Phone Number',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(user.phoneNumber ?? 'Not added'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // SECURITY
  // ==========================================================

  void _showSecurityInfo() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Security',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Your account is protected by Firebase Authentication. '
            'Never share your password or verification codes with anyone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // ABOUT DOORSTEPP
  // ==========================================================

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'doorstepp',
      applicationVersion: '1.0.0',
      applicationLegalese: 'Groceries delivered in minutes',
      children: const [
        SizedBox(height: 15),
        Text(
          'doorstepp makes everyday grocery shopping '
          'simple and convenient by bringing essential '
          'items directly to your doorstep.',
        ),
      ],
    );
  }

  // ==========================================================
  // DELETE ACCOUNT CONFIRMATION
  // ==========================================================

  Future<void> _showLegalDocument(String type) async {
    final title = type == 'terms' ? 'Terms & Conditions' : 'Privacy Policy';

    try {
      final snapshot = await _firestore
          .collection('legal_documents')
          .doc(type)
          .get();

      final data = snapshot.data();
      final content = data?['content']?.toString().trim() ?? '';

      if (!mounted) return;

      _showInformationDialog(
        title: title,
        content: content.isEmpty
            ? 'This document has not been added yet.'
            : content,
      );
    } catch (e) {
      if (!mounted) return;
      _showInformationDialog(
        title: title,
        content:
            'Unable to load this document right now. Please try again later.',
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Sign Out',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to sign out of doorstepp?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text('SIGN OUT'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Account?',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: const Text(
            'This action will permanently delete '
            'your Firebase account. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);

                await _deleteAccount();
              },
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // DELETE ACCOUNT
  // ==========================================================

  Future<void> _deleteAccount() async {
    final User? user = currentUser;

    if (user == null) {
      return;
    }

    try {
      await user.delete();

      if (!mounted) {
        return;
      }

      Navigator.popUntil(context, (route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      String message = 'Unable to delete account.';

      if (e.code == 'requires-recent-login') {
        message =
            'For security, please login again before deleting your account.';
      } else if (e.message != null) {
        message = e.message!;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.black87,
                  size: 19,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            children: [
              // User Profile mini summary banner
              _buildProfileBanner(),

              // SECTION 1: ACCOUNT & SECURITY
              _buildSectionHeader('ACCOUNT & SECURITY'),
              _buildGroupContainer(
                children: [
                  _buildGroupItem(
                    icon: Icons.person_outline_rounded,
                    title: 'Account Information',
                    subtitle: 'View linked email and phone details',
                    onTap: _showAccountInformation,
                  ),
                  _buildGroupItem(
                    icon: Icons.shield_outlined,
                    title: 'Security',
                    subtitle: 'Account security and protection',
                    onTap: _showSecurityInfo,
                    showDivider: false,
                  ),
                ],
              ),

              // SECTION 2: PREFERENCES
              _buildSectionHeader('PREFERENCES'),
              _buildGroupContainer(
                children: [
                  _buildGroupItem(
                    icon: Icons.notifications_outlined,
                    title: 'Push Notifications',
                    subtitle: notificationsEnabled
                        ? 'Order updates, deals & delivery alerts'
                        : 'Notifications are disabled',
                    trailing: Switch.adaptive(
                      value: notificationsEnabled,
                      activeTrackColor: AppColors.primary,
                      activeThumbColor: Colors.white,
                      onChanged: (value) {
                        setState(() {
                          notificationsEnabled = value;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? 'Notifications enabled'
                                  : 'Notifications disabled',
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  _buildGroupItem(
                    icon: Icons.cleaning_services_outlined,
                    title: 'Clear Cache',
                    subtitle: 'Free up local temporary memory and images',
                    onTap: _clearCache,
                    showDivider: false,
                  ),
                ],
              ),

              // SECTION 3: ABOUT & LEGAL
              _buildSectionHeader('ABOUT & LEGAL'),
              _buildGroupContainer(
                children: [
                  _buildGroupItem(
                    icon: Icons.info_outline_rounded,
                    title: 'About doorstepp',
                    subtitle: 'Version 1.0.6 • Build 18',
                    onTap: _showAbout,
                  ),
                  _buildGroupItem(
                    icon: Icons.description_outlined,
                    title: 'Terms & Conditions',
                    subtitle: 'Read our terms of service',
                    onTap: () => _showLegalDocument('terms'),
                  ),
                  _buildGroupItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'Learn how your data is protected',
                    onTap: () => _showLegalDocument('privacy'),
                    showDivider: false,
                  ),
                ],
              ),

              // SECTION 4: ACCOUNT ACTIONS
              _buildSectionHeader('ACCOUNT ACTIONS'),
              _buildGroupContainer(
                children: [
                  _buildGroupItem(
                    icon: Icons.logout_rounded,
                    iconColor: Colors.grey.shade800,
                    iconBgColor: Colors.grey.shade100,
                    title: 'Log Out',
                    subtitle: 'Sign out of your doorstepp account',
                    onTap: _showLogoutDialog,
                  ),
                  _buildGroupItem(
                    icon: Icons.delete_outline_rounded,
                    iconColor: Colors.red.shade700,
                    iconBgColor: Colors.red.shade50,
                    title: 'Delete Account',
                    titleColor: Colors.red.shade700,
                    subtitle: 'Permanently remove your account and all data',
                    onTap: _showDeleteAccountDialog,
                    showDivider: false,
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // BRAND
              const Center(
                child: Text(
                  'doorstepp',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 3),

              const Center(
                child: Text(
                  'Groceries delivered in minutes',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),

              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // INFORMATION DIALOG
  // ==========================================================

  void _showInformationDialog({
    required String title,
    required String content,
  }) {
    showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          content: SingleChildScrollView(
            child: Text(content, style: const TextStyle(height: 1.5)),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }
}
