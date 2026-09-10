import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();

  final AuthService authService = AuthService();

  bool loading = false;

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              // ==================================================
              // DOORSTEPP LOGO
              // ==================================================
              SizedBox(
                width: 150,
                height: 125,
                child: CustomPaint(painter: _DoorsteppLogoPainter()),
              ),

              const SizedBox(height: 10),

              // ==================================================
              // DOORSTEPP TEXT
              // ==================================================
              const Text(
                'doorstepp',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.8,
                  color: Color(0xFF116A34),
                ),
              ),

              const SizedBox(height: 10),

              // ==================================================
              // TAGLINE
              // ==================================================
              const Text(
                'Groceries delivered in minutes',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xff777777),
                ),
              ),

              const SizedBox(height: 35),

              // ==================================================
              // MOBILE NUMBER
              // ==================================================
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,

                maxLength: 10,

                decoration: InputDecoration(
                  counterText: '',

                  filled: true,
                  fillColor: const Color(0xffF7F9F8),

                  prefixText: '+91 ',

                  prefixStyle: const TextStyle(
                    color: Color(0xFF116A34),
                    fontWeight: FontWeight.w600,
                  ),

                  hintText: 'Mobile Number',

                  hintStyle: const TextStyle(color: Color(0xff999999)),

                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 17,
                  ),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),

                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xffE1E8E4)),
                  ),

                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      color: Color(0xFF168A43),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ==================================================
              // CONTINUE BUTTON
              // ==================================================
              SizedBox(
                width: double.infinity,
                height: 55,

                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF168A43),

                    foregroundColor: Colors.white,

                    elevation: 0,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),

                  onPressed: loading
                      ? null
                      : () async {
                          final phone = phoneController.text.trim();

                          // ----------------------------------------
                          // PHONE VALIDATION
                          // ----------------------------------------

                          if (phone.length != 10) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter a valid 10-digit mobile number',
                                ),
                              ),
                            );

                            return;
                          }

                          // ----------------------------------------
                          // START LOADING
                          // ----------------------------------------

                          setState(() {
                            loading = true;
                          });

                          // ----------------------------------------
                          // SEND OTP
                          // ----------------------------------------

                          await authService.sendOtp(
                            phoneNumber: '+91$phone',

                            // --------------------------------------
                            // OTP SENT
                            // --------------------------------------
                            onCodeSent: (verificationId) {
                              if (!mounted) {
                                return;
                              }

                              setState(() {
                                loading = false;
                              });

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OtpScreen(
                                    phoneNumber: '+91$phone',
                                    verificationId: verificationId,
                                  ),
                                ),
                              );
                            },

                            // --------------------------------------
                            // ERROR
                            // --------------------------------------
                            onError: (error) {
                              if (!mounted) {
                                return;
                              }

                              setState(() {
                                loading = false;
                              });

                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(error)));
                            },
                          );
                        },

                  child: loading
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'CONTINUE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
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
}

// ================================================================
// DOORSTEPP LOGO PAINTER
// ================================================================

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
    // SMALL SPEED DOTS
    // ==========================================================

    canvas.drawCircle(const Offset(25, 43), 4, greenPaint);

    canvas.drawCircle(const Offset(36, 34), 3, greenPaint);

    // ==========================================================
    // SHOPPING BAG
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
