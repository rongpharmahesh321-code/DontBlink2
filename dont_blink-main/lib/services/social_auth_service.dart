import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SocialAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void>? _googleInitialization;

  // ==========================================================
  // GOOGLE INITIALIZATION
  // ==========================================================

  Future<void> _initializeGoogle() {
    _googleInitialization ??= GoogleSignIn.instance.initialize();

    return _googleInitialization!;
  }

  // ==========================================================
  // GOOGLE SIGN IN
  // ==========================================================

  Future<UserCredential> signInWithGoogle() async {
    await _initializeGoogle();

    final GoogleSignIn googleSignIn = GoogleSignIn.instance;

    if (!googleSignIn.supportsAuthenticate()) {
      throw Exception('Google Sign-In is not supported on this platform.');
    }

    final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    final String? idToken = googleAuth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Google authentication failed. No ID token was received.',
      );
    }

    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: idToken,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(
      credential,
    );

    final user = userCredential.user;

    if (user != null) {
      await _createOrUpdateUserDocument(user, provider: 'google');
    }

    return userCredential;
  }

  // ==========================================================
  // CREATE / UPDATE USER DOCUMENT
  // ==========================================================

  Future<void> _createOrUpdateUserDocument(
    User user, {
    required String provider,
  }) async {
    final userRef = _firestore.collection('users').doc(user.uid);

    final existing = await userRef.get();

    final Map<String, dynamic> data = {
      'email': user.email ?? '',
      'displayName': user.displayName ?? '',
      'phoneNumber': user.phoneNumber ?? '',
      'photoUrl': user.photoURL ?? '',
      'provider': provider,
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    // Never overwrite an existing role.
    // This is important for admin/rider accounts.
    if (!existing.exists) {
      data['role'] = 'customer';
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await userRef.set(data, SetOptions(merge: true));
  }

  // ==========================================================
  // PHONE OTP
  // ==========================================================

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
    required void Function(PhoneAuthCredential credential)
    onVerificationCompleted,
  }) async {
    final phone = phoneNumber.trim();

    if (phone.isEmpty) {
      onError('Please enter your phone number.');
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,

        timeout: const Duration(seconds: 60),

        // ====================================================
        // ANDROID AUTOMATIC VERIFICATION
        // ====================================================
        verificationCompleted: (PhoneAuthCredential credential) {
          onVerificationCompleted(credential);
        },

        // ====================================================
        // VERIFICATION FAILED
        // ====================================================
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Phone verification failed.');
        },

        // ====================================================
        // OTP SENT
        // ====================================================
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },

        // ====================================================
        // AUTO RETRIEVAL TIMEOUT
        // ====================================================
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  // ==========================================================
  // VERIFY OTP
  // ==========================================================

  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final code = smsCode.trim();

    if (code.length != 6) {
      throw Exception('Please enter the 6-digit OTP.');
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(
      credential,
    );

    final user = userCredential.user;

    if (user != null) {
      await _createOrUpdateUserDocument(user, provider: 'phone');
    }

    return userCredential;
  }

  // ==========================================================
  // AUTO VERIFY PHONE CREDENTIAL
  // ==========================================================

  Future<UserCredential> signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    final UserCredential userCredential = await _auth.signInWithCredential(
      credential,
    );

    final user = userCredential.user;

    if (user != null) {
      await _createOrUpdateUserDocument(user, provider: 'phone');
    }

    return userCredential;
  }
}
