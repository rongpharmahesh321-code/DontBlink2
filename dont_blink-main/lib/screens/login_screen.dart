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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              const Icon(Icons.flash_on, size: 90, color: Colors.white),

              const SizedBox(height: 20),

              const Text(
                "Don't Blink",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                "Enter your mobile number",
                style: TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 35),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,

                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  prefixText: "+91 ",
                  hintText: "Mobile Number",

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final phone = phoneController.text.trim();

                          if (phone.length != 10) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please enter a valid 10-digit mobile number",
                                ),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            loading = true;
                          });

                          await authService.sendOtp(
                            phoneNumber: "+91$phone",

                            onCodeSent: (verificationId) {
                              if (!mounted) return;

                              setState(() {
                                loading = false;
                              });

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OtpScreen(
                                    phoneNumber: "+91$phone",
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

                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(error)));
                            },
                          );
                        },
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "CONTINUE",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
