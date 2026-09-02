import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';

import '../services/email_auth_service.dart';
import '../services/auth_service.dart';

import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import 'otp_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  // ==========================================================
  // FORM
  // ==========================================================

  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();

  // ==========================================================
  // SERVICES
  // ==========================================================

  final EmailAuthService emailAuthService = EmailAuthService();
  final AuthService authService = AuthService();

  // ==========================================================
  // STATE
  // ==========================================================

  bool loading = false;
  bool obscurePassword = true;

  // ==========================================================
  // COUNTRY
  // ==========================================================

  Country selectedCountry = Country(
    phoneCode: '91',
    countryCode: 'IN',
    e164Sc: 356,
    geographic: true,
    level: 1,
    name: 'India',
    example: '9123456789',
    displayName: 'India (भारत)',
    displayNameNoCountryCode: 'India',
    e164Key: '91-IN-0',
  );

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // ==========================================================
  // EMAIL SIGN IN
  // ==========================================================

  Future<void> signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await emailAuthService.signIn(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login Successful'),
          backgroundColor: Color(0xff08A84F),
        ),
      );

      // AuthGate handles navigation automatically.
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================================
  // GOOGLE SIGN IN
  // ==========================================================

  Future<void> signInWithGoogle() async {
    setState(() {
      loading = true;
    });

    try {
      await authService.signInWithGoogle();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Sign-In Successful'),
          backgroundColor: Color(0xff08A84F),
        ),
      );

      // AuthGate handles navigation.
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================================
  // COUNTRY PICKER
  // ==========================================================

  void showCountrySelector() {
    if (loading) return;

    showCountryPicker(
      context: context,
      showPhoneCode: true,
      favorite: const ['IN', 'US', 'GB', 'AE'],

      countryListTheme: CountryListThemeData(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        bottomSheetHeight: 600,
        searchTextStyle: const TextStyle(fontSize: 16),
        inputDecoration: InputDecoration(
          hintText: 'Search country',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      onSelect: (Country country) {
        setState(() {
          selectedCountry = country;
        });
      },
    );
  }

  // ==========================================================
  // PHONE OTP
  // ==========================================================

  Future<void> sendOtp() async {
    final phone = phoneController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your phone number'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');

    if (cleanPhone.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid phone number'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final fullPhoneNumber = '+${selectedCountry.phoneCode}$cleanPhone';

    setState(() {
      loading = true;
    });

    try {
      await authService.sendOtp(
        phoneNumber: fullPhoneNumber,

        onCodeSent: (verificationId) {
          if (!mounted) return;

          setState(() {
            loading = false;
          });

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                phoneNumber: fullPhoneNumber,
                verificationId: verificationId,
              ),
            ),
          );
        },

        onError: (error) {
          if (!mounted) return;

          setState(() {
            loading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  // ==========================================================
  // TEXT FIELD
  // ==========================================================

  Widget buildField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        enabled: !loading,

        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Enter $label';
          }

          return null;
        },

        decoration: InputDecoration(
          labelText: label,

          labelStyle: const TextStyle(color: Color(0xff777777)),

          filled: true,
          fillColor: const Color(0xffF7F9F8),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xffE0E8E3)),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xff08A84F), width: 1.5),
          ),

          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Colors.red),
          ),

          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),

          suffixIcon: suffix,
        ),
      ),
    );
  }

  // ==========================================================
  // GOOGLE BUTTON
  // ==========================================================

  Widget googleButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,

      child: OutlinedButton.icon(
        onPressed: loading ? null : signInWithGoogle,

        icon: const Text(
          'G',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),

        label: const Text(
          'CONTINUE WITH GOOGLE',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),

        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,

          side: const BorderSide(color: Color(0xffDDE5E0)),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // PHONE INPUT
  // ==========================================================

  Widget phoneInput() {
    return TextFormField(
      controller: phoneController,

      enabled: !loading,

      keyboardType: TextInputType.phone,

      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: 'Enter phone number',

        filled: true,
        fillColor: const Color(0xffF7F9F8),

        prefixIcon: InkWell(
          onTap: showCountrySelector,

          borderRadius: BorderRadius.circular(12),

          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),

            child: Row(
              mainAxisSize: MainAxisSize.min,

              children: [
                Text(
                  selectedCountry.flagEmoji,
                  style: const TextStyle(fontSize: 21),
                ),

                const SizedBox(width: 6),

                Text(
                  '+${selectedCountry.phoneCode}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff08783F),
                  ),
                ),

                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xffE0E8E3)),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xff08A84F), width: 1.5),
        ),
      ),
    );
  }

  // ==========================================================
  // PHONE OTP BUTTON
  // ==========================================================

  Widget phoneOtpButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,

      child: OutlinedButton.icon(
        onPressed: loading ? null : sendOtp,

        icon: const Icon(Icons.phone_android, color: Color(0xff08783F)),

        label: const Text(
          'CONTINUE WITH PHONE OTP',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),

        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xff08783F),

          side: const BorderSide(color: Color(0xff08783F)),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // DIVIDER
  // ==========================================================

  Widget divider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),

          child: Text(
            'OR',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),

        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),

            child: Card(
              elevation: 0,

              color: Colors.white,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),

                side: const BorderSide(color: Color(0xffEDF2EF)),
              ),

              child: Padding(
                padding: const EdgeInsets.all(22),

                child: Form(
                  key: _formKey,

                  child: Column(
                    children: [
                      // ==========================================
                      // DOORSTEPP LOGO
                      // ==========================================
                      SizedBox(
                        width: 125,
                        height: 105,

                        child: CustomPaint(painter: _DoorsteppLogoPainter()),
                      ),

                      const SizedBox(height: 4),

                      // ==========================================
                      // DOORSTEPP
                      // ==========================================
                      const Text(
                        'doorstepp',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.6,
                          color: Color(0xff08783F),
                        ),
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'Groceries delivered in minutes',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xff777777),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // ==========================================
                      // WELCOME BACK
                      // ==========================================
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff202522),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ==========================================
                      // EMAIL
                      // ==========================================
                      buildField(
                        controller: emailController,
                        label: 'Email',
                        keyboard: TextInputType.emailAddress,
                      ),

                      // ==========================================
                      // PASSWORD
                      // ==========================================
                      buildField(
                        controller: passwordController,
                        label: 'Password',
                        obscure: obscurePassword,

                        suffix: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: const Color(0xff777777),
                          ),

                          onPressed: loading
                              ? null
                              : () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                        ),
                      ),

                      // ==========================================
                      // FORGOT PASSWORD
                      // ==========================================
                      Align(
                        alignment: Alignment.centerRight,

                        child: TextButton(
                          onPressed: loading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgotPasswordScreen(),
                                    ),
                                  );
                                },

                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Color(0xff08783F),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 5),

                      // ==========================================
                      // SIGN IN
                      // ==========================================
                      SizedBox(
                        width: double.infinity,
                        height: 54,

                        child: ElevatedButton(
                          onPressed: loading ? null : signIn,

                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff08A84F),

                            foregroundColor: Colors.white,

                            elevation: 0,

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),

                          child: loading
                              ? const SizedBox(
                                  width: 23,
                                  height: 23,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'SIGN IN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ==========================================
                      // OR
                      // ==========================================
                      divider(),

                      const SizedBox(height: 20),

                      // ==========================================
                      // GOOGLE
                      // ==========================================
                      googleButton(),

                      const SizedBox(height: 20),

                      // ==========================================
                      // PHONE LABEL
                      // ==========================================
                      Align(
                        alignment: Alignment.centerLeft,

                        child: Text(
                          'Phone Number',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 7),

                      // ==========================================
                      // PHONE
                      // ==========================================
                      phoneInput(),

                      const SizedBox(height: 12),

                      // ==========================================
                      // PHONE OTP
                      // ==========================================
                      phoneOtpButton(),

                      const SizedBox(height: 17),

                      // ==========================================
                      // SIGN UP
                      // ==========================================
                      TextButton(
                        onPressed: loading
                            ? null
                            : () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                              },

                        child: const Text(
                          "Don't have an account? Sign Up",
                          style: TextStyle(
                            color: Color(0xff08783F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// DOORSTEPP LOGO PAINTER
// ================================================================

class _DoorsteppLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const Color green = Color(0xff08A84F);

    const Color darkGreen = Color(0xff08783F);

    final double scaleX = size.width / 150;

    final double scaleY = size.height / 125;

    canvas.save();

    canvas.scale(scaleX, scaleY);

    // ==========================================================
    // SPEED LINES
    // ==========================================================

    final Paint greenPaint = Paint()
      ..color = green
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 55, 34, 7),
        const Radius.circular(5),
      ),
      greenPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 67, 40, 7),
        const Radius.circular(5),
      ),
      greenPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(15, 79, 27, 7),
        const Radius.circular(5),
      ),
      greenPaint,
    );

    // ==========================================================
    // SPEED DOTS
    // ==========================================================

    canvas.drawCircle(const Offset(25, 43), 4, greenPaint);

    canvas.drawCircle(const Offset(36, 34), 3, greenPaint);

    // ==========================================================
    // BAG BODY
    // ==========================================================

    final RRect bag = RRect.fromRectAndRadius(
      const Rect.fromLTWH(40, 43, 82, 66),
      const Radius.circular(10),
    );

    canvas.drawRRect(bag, greenPaint);

    // ==========================================================
    // DARK TOP
    // ==========================================================

    final Paint darkFill = Paint()
      ..color = darkGreen
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(47, 39, 68, 27),
        const Radius.circular(8),
      ),
      darkFill,
    );

    // ==========================================================
    // HANDLE
    // ==========================================================

    final Paint handlePaint = Paint()
      ..color = darkGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final Path handle = Path();

    handle.moveTo(67, 45);

    handle.cubicTo(67, 23, 99, 23, 99, 45);

    canvas.drawPath(handle, handlePaint);

    // ==========================================================
    // WHITE D
    // ==========================================================

    final Paint whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path dPath = Path();

    dPath.moveTo(63, 59);

    dPath.lineTo(63, 94);

    dPath.moveTo(63, 60);

    dPath.lineTo(76, 60);

    dPath.cubicTo(95, 60, 95, 94, 76, 94);

    dPath.lineTo(63, 94);

    canvas.drawPath(dPath, whitePaint);

    // ==========================================================
    // WHEELS
    // ==========================================================

    final Paint wheelPaint = Paint()
      ..color = darkGreen
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(59, 113), 7, wheelPaint);

    canvas.drawCircle(const Offset(106, 113), 7, wheelPaint);

    final Paint wheelCenter = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(59, 113), 3, wheelCenter);

    canvas.drawCircle(const Offset(106, 113), 3, wheelCenter);

    // ==========================================================
    // SHADOW
    // ==========================================================

    final Paint shadowPaint = Paint()
      ..color = const Color(0xffDDEDE4)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(82, 125), width: 90, height: 8),
      shadowPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
