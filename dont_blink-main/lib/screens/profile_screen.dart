import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

import 'my_addresses_screen.dart';
import 'orders_screen.dart';
import 'admin_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  // ==========================================================
  // FIREBASE
  // ==========================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final AuthService _authService = AuthService();

  // ==========================================================
  // ANIMATION
  // ==========================================================

  late final AnimationController _controller;

  late final Animation<double> _fadeAnimation;

  late final Animation<Offset> _slideAnimation;

  // ==========================================================
  // PROFILE DATA
  // ==========================================================

  bool loadingProfile = true;

  String profileName = '';

  String profileEmail = '';

  String profilePhone = '';

  String profilePhoto = '';

  // ==========================================================
  // INIT
  // ==========================================================

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

  // ==========================================================
  // LOAD PROFILE
  // ==========================================================

  Future<void> _loadProfile() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          loadingProfile = false;
        });
      }

      return;
    }

    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();

      final data = snapshot.data();

      if (!mounted) {
        return;
      }

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

      if (!mounted) {
        return;
      }

      setState(() {
        profileEmail = user.email ?? '';

        profileName = user.displayName ?? '';

        profilePhone = user.phoneNumber ?? '';

        profilePhoto = user.photoURL ?? '';

        loadingProfile = false;
      });
    }
  }

  // ==========================================================
  // SAVE NAME
  // ==========================================================

  Future<void> _saveName(String newName) async {
    final String name = newName.trim();

    if (name.isEmpty) {
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      await user.updateDisplayName(name);

      await _firestore.collection('users').doc(user.uid).set({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      setState(() {
        profileName = name;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name updated successfully.'),
          backgroundColor: Colors.green,
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
  // EDIT NAME
  // ==========================================================

  Future<void> _editName() async {
    final TextEditingController controller = TextEditingController(
      text: profileName,
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),

              title: const Text(
                'Edit Name',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              content: TextField(
                controller: controller,

                textCapitalization: TextCapitalization.words,

                decoration: InputDecoration(
                  labelText: 'Full Name',

                  hintText: 'Enter your name',

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('CANCEL'),
                ),

                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (controller.text.trim().isEmpty) {
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          await _saveName(controller.text);

                          if (mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),

                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  // ==========================================================
  // ADD PHONE
  // ==========================================================

  Future<void> _addPhone() async {
    final String? phone = await _authService.getSavedPhoneNumber();

    if (phone != null && phone.trim().isNotEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A verified phone number is already linked to your account.',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    await _showPhoneDialog();

    await _loadProfile();
  }

  // ==========================================================
  // PHONE VERIFICATION DIALOG
  // ==========================================================

  Future<void> _showPhoneDialog() async {
    final TextEditingController phoneController = TextEditingController();

    final TextEditingController otpController = TextEditingController();

    String? verificationId;

    bool otpSent = false;

    bool loading = false;

    await showDialog(
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
                      : () {
                          Navigator.pop(dialogContext);
                        },

                  child: const Text('CANCEL'),
                ),

                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          // SEND OTP
                          if (!otpSent) {
                            final String phone = phoneController.text
                                .trim()
                                .replaceAll(RegExp(r'\s+'), '');

                            if (phone.length != 10) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Enter a valid 10-digit mobile number.',
                                  ),
                                ),
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

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(error),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              },
                            );

                            return;
                          }

                          // VERIFY OTP

                          final String otp = otpController.text.trim();

                          if (otp.length != 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enter the 6-digit OTP.'),
                              ),
                            );

                            return;
                          }

                          if (verificationId == null) {
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

                            if (!mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext);

                            await _loadProfile();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Mobile number verified successfully.',
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              loading = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
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
  // ==========================================================
  // PROFILE AVATAR
  // ==========================================================

  Widget _buildAvatar() {
    if (profilePhoto.isNotEmpty) {
      return CircleAvatar(
        radius: 45,
        backgroundColor: Colors.white,
        backgroundImage: NetworkImage(profilePhoto),
      );
    }

    return const CircleAvatar(
      radius: 45,
      backgroundColor: Colors.white,
      child: Icon(Icons.person, size: 50, color: Colors.green),
    );
  }

  // ==========================================================
  // PROFILE HEADER
  // ==========================================================

  Widget _buildProfileHeader() {
    final String displayName = profileName.isNotEmpty
        ? profileName
        : 'doorstepp User';

    return ScaleTransition(
      scale: Tween<double>(begin: 0.96, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      ),

      child: Container(
        width: double.infinity,

        padding: const EdgeInsets.all(24),

        decoration: BoxDecoration(
          color: Colors.green,

          borderRadius: BorderRadius.circular(22),

          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.20),
              blurRadius: 15,
              offset: const Offset(0, 7),
            ),
          ],
        ),

        child: Column(
          children: [
            // ==================================================
            // PROFILE PHOTO
            // ==================================================
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.7, end: 1),

              duration: const Duration(milliseconds: 600),

              curve: Curves.easeOutBack,

              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },

              child: _buildAvatar(),
            ),

            const SizedBox(height: 15),

            // ==================================================
            // NAME
            // ==================================================
            Text(
              displayName,

              textAlign: TextAlign.center,

              maxLines: 1,

              overflow: TextOverflow.ellipsis,

              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            // ==================================================
            // EMAIL
            // ==================================================
            Text(
              profileEmail.isNotEmpty ? profileEmail : 'No Email',

              textAlign: TextAlign.center,

              maxLines: 1,

              overflow: TextOverflow.ellipsis,

              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),

            const SizedBox(height: 10),

            // ==================================================
            // PHONE
            // ==================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Icon(
                  profilePhone.isNotEmpty
                      ? Icons.verified
                      : Icons.phone_android,

                  size: 16,

                  color: Colors.white,
                ),

                const SizedBox(width: 5),

                Flexible(
                  child: Text(
                    profilePhone.isNotEmpty
                        ? profilePhone
                        : 'Mobile number not added',

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      color: profilePhone.isNotEmpty
                          ? Colors.white
                          : Colors.white70,

                      fontSize: 13,

                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ==================================================
            // EDIT PROFILE
            // ==================================================
            SizedBox(
              height: 42,

              child: OutlinedButton.icon(
                onPressed: _editName,

                icon: const Icon(Icons.edit, size: 17),

                label: const Text('EDIT PROFILE'),

                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,

                  side: const BorderSide(color: Colors.white),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // PROFILE TILE
  // ==========================================================

  Widget buildTile({
    required IconData icon,

    required String title,

    VoidCallback? onTap,

    Color color = Colors.black,

    int index = 0,
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
              vertical: 4,
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

            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Future<void> _logout() async {
    await _authService.signOut();
  }

  // ==========================================================
  // LOGOUT DIALOG
  // ==========================================================

  void _showLogoutDialog(BuildContext context) {
    showDialog(
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

                await _logout();
              },

              child: const Text('LOGOUT'),
            ),
          ],
        );
      },
    );
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
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    // ==========================================================
    // ADMIN CHECK
    // ==========================================================

    final bool isAdmin =
        user?.email?.toLowerCase() == 'rongpharmahesh321@gmail.com';

    return Scaffold(
      backgroundColor: const Color(0xffF7F8FA),

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        elevation: 0,

        title: const Text('My Profile'),

        centerTitle: true,

        backgroundColor: Colors.green,

        foregroundColor: Colors.white,
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: loadingProfile
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : FadeTransition(
              opacity: _fadeAnimation,

              child: SlideTransition(
                position: _slideAnimation,

                child: RefreshIndicator(
                  color: Colors.green,

                  onRefresh: _loadProfile,

                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),

                    padding: const EdgeInsets.all(16),

                    children: [
                      // ==================================================
                      // PROFILE HEADER
                      // ==================================================
                      _buildProfileHeader(),

                      const SizedBox(height: 25),

                      // ==================================================
                      // ACCOUNT SECTION
                      // ==================================================
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 10),

                        child: Text(
                          'My Account',

                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      // ==================================================
                      // MY ORDERS
                      // ==================================================
                      buildTile(
                        icon: Icons.shopping_bag_outlined,

                        title: 'My Orders',

                        index: 0,

                        onTap: () {
                          Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (_) => const OrdersScreen(),
                            ),
                          );
                        },
                      ),

                      // ==================================================
                      // MY ADDRESSES
                      // ==================================================
                      buildTile(
                        icon: Icons.location_on_outlined,

                        title: 'My Addresses',

                        index: 1,

                        onTap: () {
                          Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (_) => MyAddressesScreen(),
                            ),
                          );
                        },
                      ),

                      // ==================================================
                      // MOBILE NUMBER
                      // ==================================================
                      buildTile(
                        icon: profilePhone.isEmpty
                            ? Icons.phone_android_outlined
                            : Icons.verified_outlined,

                        title: profilePhone.isEmpty
                            ? 'Add Mobile Number'
                            : 'Mobile Number',

                        index: 2,

                        onTap: _addPhone,
                      ),

                      // ==================================================
                      // ADMIN DASHBOARD
                      // ==================================================
                      if (isAdmin)
                        buildTile(
                          icon: Icons.admin_panel_settings_outlined,

                          title: 'Admin Dashboard',

                          index: 3,

                          onTap: () {
                            Navigator.push(
                              context,

                              MaterialPageRoute(
                                builder: (_) => const AdminScreen(),
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 10),

                      // ==================================================
                      // SETTINGS SECTION
                      // ==================================================
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 10),

                        child: Text(
                          'Preferences',

                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      // ==================================================
                      // SETTINGS
                      // ==================================================
                      buildTile(
                        icon: Icons.settings_outlined,

                        title: 'Settings',

                        index: 4,

                        onTap: () {
                          Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),

                      // ==================================================
                      // LOGOUT
                      // ==================================================
                      buildTile(
                        icon: Icons.logout,

                        title: 'Logout',

                        color: Colors.red,

                        index: 5,

                        onTap: () {
                          _showLogoutDialog(context);
                        },
                      ),

                      const SizedBox(height: 20),

                      // ==================================================
                      // BRAND
                      // ==================================================
                      const Center(
                        child: Text(
                          'doorstepp',

                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
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
            ),
    );
  }
}
