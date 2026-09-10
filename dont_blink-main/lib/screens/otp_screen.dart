import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_gate.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // ==========================================================
  // CONTROLLERS
  // ==========================================================

  final TextEditingController otpController = TextEditingController();

  // ==========================================================
  // SERVICE
  // ==========================================================

  final AuthService authService = AuthService();

  // ==========================================================
  // STATE
  // ==========================================================

  bool loading = false;
  bool resending = false;
  bool _navigated = false;

  late String verificationId;

  int? resendToken;

  int resendSeconds = 60;

  Timer? resendTimer;
  StreamSubscription<User?>? _authSubscription;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    verificationId = widget.verificationId;

    _startResendTimer();

    // Listen for automatic background verification (instant verification / SMS auto-retrieval)
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && mounted && !_navigated) {
        _onLoginSuccess();
      }
    });
  }

  // ==========================================================
  // START COUNTDOWN
  // ==========================================================

  void _startResendTimer() {
    resendTimer?.cancel();

    resendSeconds = 60;

    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (resendSeconds <= 1) {
        timer.cancel();

        setState(() {
          resendSeconds = 0;
        });

        return;
      }

      setState(() {
        resendSeconds--;
      });
    });
  }

  // ==========================================================
  // ON LOGIN SUCCESS
  // ==========================================================

  Future<void> _onLoginSuccess() async {
    if (_navigated || !mounted) {
      return;
    }
    _navigated = true;

    try {
      await NotificationService.refreshUserToken();
    } catch (notificationError) {
      debugPrint(
        'Notification token registration failed: '
        '$notificationError',
      );
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  // ==========================================================
  // VERIFY OTP
  // ==========================================================

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid 6-digit OTP'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    if (loading || _navigated) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      // ======================================================
      // FIREBASE AUTHENTICATION
      // ======================================================

      await authService.verifyOtp(verificationId: verificationId, otp: otp);

      await _onLoginSuccess();
    } catch (e) {
      if (!mounted) {
        return;
      }

      // If user is already signed in (e.g. background auto-retrieval completed)
      if (FirebaseAuth.instance.currentUser != null) {
        await _onLoginSuccess();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );

      otpController.clear();
    } finally {
      if (mounted && !_navigated) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================================
  // RESEND OTP
  // ==========================================================

  Future<void> resendOtp() async {
    if (resendSeconds > 0 || resending || loading) {
      return;
    }

    setState(() {
      resending = true;
    });

    try {
      await authService.resendOtp(
        phoneNumber: widget.phoneNumber,

        resendToken: resendToken,

        onCodeSent: (newVerificationId) {
          if (!mounted) {
            return;
          }

          setState(() {
            verificationId = newVerificationId;
            resending = false;
          });

          otpController.clear();

          _startResendTimer();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A new OTP has been sent'),
              backgroundColor: AppColors.primary,
            ),
          );
        },

        onResendToken: (newToken) {
          if (!mounted) {
            return;
          }

          setState(() {
            resendToken = newToken;
          });
        },

        onError: (error) {
          if (!mounted) {
            return;
          }

          setState(() {
            resending = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        resending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _authSubscription?.cancel();
    resendTimer?.cancel();

    otpController.dispose();

    super.dispose();
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,

            children: [
              const SizedBox(height: 30),

              // ==================================================
              // ICON
              // ==================================================
              Column(
                children: [
                  SizedBox(
                    width: 125,
                    height: 105,
                    child: CustomPaint(painter: _DoorsteppLogoPainter()),
                  ),

                  const SizedBox(height: 2),

                  const Text(
                    'doorstepp',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.6,
                      color: AppColors.primaryDark,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Groceries Delivered in Minutes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),

              // ==================================================
              // TITLE
              // ==================================================
              const Text(
                'Verify OTP',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              // ==================================================
              // PHONE
              // ==================================================
              Text(
                'OTP sent to\n${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),

              const SizedBox(height: 40),

              // ==================================================
              // OTP INPUT
              // ==================================================
              Pinput(
                controller: otpController,

                length: 6,

                enabled: !loading && !resending,

                keyboardType: TextInputType.number,

                onCompleted: (_) {
                  if (!loading && !resending) {
                    verifyOtp();
                  }
                },

                defaultPinTheme: PinTheme(
                  width: 50,
                  height: 55,

                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),

                  decoration: BoxDecoration(
                    color: const Color(0xffF5F8F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                focusedPinTheme: PinTheme(
                  width: 50,
                  height: 55,

                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),

                  decoration: BoxDecoration(
                    color: const Color(0xffF5F8F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // RESEND
              // ==================================================
              if (resendSeconds > 0)
                Text(
                  'Resend OTP in ${resendSeconds}s',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                )
              else
                TextButton.icon(
                  onPressed: resending ? null : resendOtp,

                  icon: resending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.refresh,
                          color: AppColors.primary,
                        ),

                  label: Text(
                    resending ? 'SENDING OTP...' : 'RESEND OTP',

                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // ==================================================
              // VERIFY BUTTON
              // ==================================================
              SizedBox(
                width: double.infinity,
                height: 55,

                child: ElevatedButton(
                  onPressed: loading || resending ? null : verifyOtp,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,

                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                  child: loading
                      ? const SizedBox(
                          width: 25,
                          height: 25,

                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'VERIFY OTP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // CHANGE PHONE
              // ==================================================
              TextButton(
                onPressed: loading || resending
                    ? null
                    : () {
                        Navigator.pop(context);
                      },

                child: const Text(
                  'Change Phone Number',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

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
