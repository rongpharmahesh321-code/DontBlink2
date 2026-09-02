import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import '../services/auth_service.dart';

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

  late String verificationId;

  int? resendToken;

  int resendSeconds = 60;

  Timer? resendTimer;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    verificationId = widget.verificationId;

    _startResendTimer();
  }

  // ==========================================================
  // START COUNTDOWN
  // ==========================================================

  void _startResendTimer() {
    resendTimer?.cancel();

    setState(() {
      resendSeconds = 60;
    });

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

    setState(() {
      loading = true;
    });

    try {
      await authService.verifyOtp(verificationId: verificationId, otp: otp);

      if (!mounted) return;

      // ======================================================
      // IMPORTANT
      //
      // FirebaseAuth is now signed in.
      //
      // Return to the root AuthGate.
      // AuthGate will automatically display MainScreen.
      // ======================================================

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );

      // Clear incorrect OTP.
      otpController.clear();
    } finally {
      if (mounted) {
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
          if (!mounted) return;

          setState(() {
            verificationId = newVerificationId;
            resending = false;
          });

          otpController.clear();

          _startResendTimer();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A new OTP has been sent'),
              backgroundColor: Colors.green,
            ),
          );
        },

        onResendToken: (newToken) {
          if (!mounted) return;

          setState(() {
            resendToken = newToken;
          });
        },

        onError: (error) {
          if (!mounted) return;

          setState(() {
            resending = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

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
      backgroundColor: Colors.deepPurple,

      // ======================================================
      // APP BAR
      // ======================================================
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,

        foregroundColor: Colors.white,

        elevation: 0,
      ),

      // ======================================================
      // BODY
      // ======================================================
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
              const Icon(Icons.sms, size: 80, color: Colors.white),

              const SizedBox(height: 20),

              // ==================================================
              // TITLE
              // ==================================================
              const Text(
                'Verify OTP',
                style: TextStyle(
                  color: Colors.white,
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

                style: const TextStyle(color: Colors.white70, fontSize: 15),
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

                    color: Colors.deepPurple,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                focusedPinTheme: PinTheme(
                  width: 50,

                  height: 55,

                  textStyle: const TextStyle(
                    fontSize: 22,

                    fontWeight: FontWeight.bold,

                    color: Colors.deepPurple,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius: BorderRadius.circular(12),

                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // RESEND SECTION
              // ==================================================
              if (resendSeconds > 0)
                Text(
                  'Resend OTP in ${resendSeconds}s',

                  style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                      : const Icon(Icons.refresh, color: Colors.white),

                  label: Text(
                    resending ? 'SENDING OTP...' : 'RESEND OTP',

                    style: const TextStyle(
                      color: Colors.white,

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
                    backgroundColor: Colors.white,

                    foregroundColor: Colors.deepPurple,

                    disabledBackgroundColor: Colors.white.withValues(
                      alpha: 0.6,
                    ),

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

                            color: Colors.deepPurple,
                          ),
                        )
                      : const Text(
                          'VERIFY OTP',

                          style: TextStyle(
                            color: Colors.deepPurple,

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

                  style: TextStyle(color: Colors.white),
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
