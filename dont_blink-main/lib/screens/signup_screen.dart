import 'package:flutter/material.dart';
import '../services/email_auth_service.dart';
import 'signin_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  final EmailAuthService authService = EmailAuthService();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final userCredential = await authService.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await userCredential.user!.updateDisplayName(nameController.text.trim());

      await userCredential.user!.reload();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account created successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Widget buildField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "Enter $label";
          }

          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: suffix,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                // ==========================================================
                // DOORSTEPP LOGO
                // ==========================================================

                SizedBox(
                  width: 125,
                  height: 105,
                  child: CustomPaint(painter: _DoorsteppLogoPainter()),
                ),

                const SizedBox(height: 2),

                // ==========================================================
                // DOORSTEPP NAME
                // ==========================================================
                const Text(
                  'doorstepp',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.6,
                    color: Color(0xFF116A34),
                  ),
                ),

                const SizedBox(height: 6),

                // ==========================================================
                // TAGLINE
                // ==========================================================
                const Text(
                  'Groceries Delivered in Minutes',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 28),

                // ==========================================================
                // SIGNUP CARD
                // ==========================================================
                Card(
                  elevation: 3,
                  color: Colors.white,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Text(
                            "Create Account",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 30),

                          // ==================================================
                          // FULL NAME
                          // ==================================================
                          buildField(
                            controller: nameController,
                            label: "Full Name",
                          ),

                          // ==================================================
                          // EMAIL
                          // ==================================================
                          buildField(
                            controller: emailController,
                            label: "Email",
                            keyboard: TextInputType.emailAddress,
                          ),

                          // ==================================================
                          // PASSWORD
                          // ==================================================
                          buildField(
                            controller: passwordController,
                            label: "Password",
                            obscure: obscurePassword,
                            suffix: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),

                          // ==================================================
                          // CONFIRM PASSWORD
                          // ==================================================
                          buildField(
                            controller: confirmPasswordController,
                            label: "Confirm Password",
                            obscure: obscureConfirmPassword,
                            suffix: IconButton(
                              icon: Icon(
                                obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscureConfirmPassword =
                                      !obscureConfirmPassword;
                                });
                              },
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ==================================================
                          // CREATE ACCOUNT BUTTON
                          // ==========================================================
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: loading ? null : signUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF168A43),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      "CREATE ACCOUNT",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ==================================================
                          // SIGN IN
                          // ==========================================================
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignInScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              "Already have an account? Sign In",
                              style: TextStyle(
                                color: Color(0xFF116A34),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DOORSTEPP LOGO PAINTER
// ============================================================================

class _DoorsteppLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const Color green = Color(0xFF168A43);
    const Color darkGreen = Color(0xFF116A34);

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
