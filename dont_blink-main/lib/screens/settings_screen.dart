import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  // SETTINGS TILE
  // ==========================================================

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required int index,
    VoidCallback? onTap,
    Color color = Colors.black,
    Widget? trailing,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,

      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },

      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 14),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),

        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,

          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 6,
            ),

            leading: CircleAvatar(
              backgroundColor: color == Colors.red
                  ? Colors.red.shade50
                  : Colors.green.shade100,

              child: Icon(
                icon,
                color: color == Colors.red ? Colors.red : Colors.green,
              ),
            ),

            title: Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),

            subtitle: Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),

            trailing:
                trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // NOTIFICATION SETTING
  // ==========================================================

  Widget _notificationTile() {
    return _buildTile(
      icon: Icons.notifications_outlined,
      title: 'Notifications',
      subtitle: notificationsEnabled
          ? 'Notifications are enabled'
          : 'Notifications are disabled',
      index: 0,
      trailing: Switch(
        value: notificationsEnabled,
        activeThumbColor: Colors.green,
        onChanged: (value) {
          setState(() {
            notificationsEnabled = value;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value ? 'Notifications enabled' : 'Notifications disabled',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // ACCOUNT INFORMATION
  // ==========================================================

  Widget _accountInformation() {
    final User? user = currentUser;

    final String email = user?.email ?? 'No email';

    final String phone = user?.phoneNumber?.trim().isNotEmpty == true
        ? user!.phoneNumber!
        : 'Not added';

    return _buildTile(
      icon: Icons.person_outline,
      title: 'Account Information',
      subtitle: '$email\nPhone: $phone',
      index: 1,
      onTap: _showAccountInformation,
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
      backgroundColor: const Color(0xffF7F8FA),

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: FadeTransition(
        opacity: _fadeAnimation,

        child: SlideTransition(
          position: _slideAnimation,

          child: ListView(
            padding: const EdgeInsets.all(16),

            children: [
              // ==================================================
              // ACCOUNT
              // ==================================================
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),

                child: Text(
                  'Account',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              _accountInformation(),

              // ==================================================
              // SECURITY
              // ==================================================
              _buildTile(
                icon: Icons.security_outlined,
                title: 'Security',
                subtitle: 'Manage your account security',
                index: 2,
                onTap: _showSecurityInfo,
              ),

              const SizedBox(height: 12),

              // ==================================================
              // PREFERENCES
              // ==================================================
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),

                child: Text(
                  'Preferences',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              // ==================================================
              // NOTIFICATIONS
              // ==================================================
              _notificationTile(),

              // ==================================================
              // LOCATION
              // ==================================================
              _buildTile(
                icon: Icons.location_on_outlined,
                title: 'Delivery Location',
                subtitle: 'Manage your saved delivery addresses',
                index: 4,
                onTap: () {
                  Navigator.pop(context);
                },
              ),

              // ==================================================
              // ABOUT
              // ==================================================
              const SizedBox(height: 12),

              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),

                child: Text(
                  'About',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              // ==================================================
              // ABOUT DOORSTEPP
              // ==================================================
              _buildTile(
                icon: Icons.info_outline,
                title: 'About doorstepp',
                subtitle: 'Version 1.0.0',
                index: 5,
                onTap: _showAbout,
              ),

              // ==================================================
              // TERMS
              // ==================================================
              _buildTile(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                subtitle: 'Read our terms and conditions',
                index: 6,
                onTap: () {
                  _showInformationDialog(
                    title: 'Terms & Conditions',
                    content:
                        'Terms and conditions for using doorstepp '
                        'will be available here.',
                  );
                },
              ),

              // ==================================================
              // PRIVACY
              // ==================================================
              _buildTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'Learn how your information is handled',
                index: 7,
                onTap: () {
                  _showInformationDialog(
                    title: 'Privacy Policy',
                    content:
                        'Your privacy is important to us. '
                        'The complete doorstepp privacy policy '
                        'will be available here.',
                  );
                },
              ),

              const SizedBox(height: 12),

              // ==================================================
              // DANGER ZONE
              // ==================================================
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),

                child: Text(
                  'Account Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              // ==================================================
              // DELETE ACCOUNT
              // ==================================================
              _buildTile(
                icon: Icons.delete_outline,
                title: 'Delete Account',
                subtitle: 'Permanently delete your doorstepp account',
                color: Colors.red,
                index: 8,
                onTap: _showDeleteAccountDialog,
              ),

              const SizedBox(height: 25),

              // ==================================================
              // BRAND
              // ==================================================
              const Center(
                child: Text(
                  'doorstepp',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              const Center(
                child: Text(
                  'Groceries delivered in minutes',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),

              const SizedBox(height: 20),
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
