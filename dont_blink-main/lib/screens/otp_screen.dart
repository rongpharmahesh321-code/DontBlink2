import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';

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
  final TextEditingController otpController = TextEditingController();

  final AuthService authService = AuthService();

  bool loading = false;

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,

      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 30),

            const Icon(Icons.sms, size: 80, color: Colors.white),

            const SizedBox(height: 20),

            const Text(
              "Verify OTP",
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              "OTP sent to\n${widget.phoneNumber}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 40),

            Pinput(controller: otpController, length: 6),

            const SizedBox(height: 35),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (otpController.text.trim().length != 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Enter a valid 6-digit OTP"),
                            ),
                          );
                          return;
                        }

                        setState(() {
                          loading = true;
                        });

                        try {
                          await authService.verifyOtp(
                            verificationId: widget.verificationId,
                            otp: otpController.text.trim(),
                          );

                          if (!mounted) return;

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                            (route) => false,
                          );
                        } catch (e) {
                          if (!mounted) return;

                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        } finally {
                          if (mounted) {
                            setState(() {
                              loading = false;
                            });
                          }
                        }
                      },
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "VERIFY OTP",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            TextButton(
              onPressed: loading
                  ? null
                  : () {
                      Navigator.pop(context);
                    },
              child: const Text(
                "Change Phone Number",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
