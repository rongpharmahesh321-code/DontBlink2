import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // ==========================================================
  // FIREBASE
  // ==========================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================================
  // GOOGLE SIGN-IN
  // ==========================================================

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static const String _serverClientId =
      '522053783800-bu8s55cifjeiult2kgabr6mhjo62ma8m.apps.googleusercontent.com';

  bool _googleInitialized = false;

  // ==========================================================
  // CURRENT USER
  // ==========================================================

  User? get currentUser => _auth.currentUser;

  // ==========================================================
  // AUTH STATE
  // ==========================================================

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==========================================================
  // INITIALIZE GOOGLE
  // ==========================================================

  Future<void> _initializeGoogle() async {
    if (_googleInitialized) {
      return;
    }

    await _googleSignIn.initialize(serverClientId: _serverClientId);

    _googleInitialized = true;
  }

  // ==========================================================
  // GOOGLE SIGN-IN
  // ==========================================================

  Future<void> signInWithGoogle() async {
    try {
      await _initializeGoogle();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Unable to get Google ID token.');
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      await _auth.signInWithCredential(credential);

      await createUserIfNeeded();
    } on GoogleSignInException catch (e) {
      throw Exception(
        'Google Sign-In failed: '
        '${e.description ?? e.code.name}',
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Firebase authentication failed.');
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  // ==========================================================
  // NORMAL PHONE LOGIN
  //
  // Used by SignInScreen.
  //
  // If the user is not logged in, this signs them in
  // using phone authentication.
  // ==========================================================

  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    Function(int? resendToken)? onResendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,

      // ------------------------------------------------------
      // AUTOMATIC VERIFICATION
      // ------------------------------------------------------
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final User? user = _auth.currentUser;

          if (user == null) {
            await _auth.signInWithCredential(credential);
          } else {
            await user.linkWithCredential(credential);
          }

          await createUserIfNeeded();
        } catch (e) {
          onError(e.toString());
        }
      },

      // ------------------------------------------------------
      // VERIFICATION FAILED
      // ------------------------------------------------------
      verificationFailed: (FirebaseAuthException e) {
        onError(_friendlyAuthError(e));
      },

      // ------------------------------------------------------
      // OTP SENT
      // ------------------------------------------------------
      codeSent: (String verificationId, int? resendToken) {
        onResendToken?.call(resendToken);

        onCodeSent(verificationId);
      },

      // ------------------------------------------------------
      // TIMEOUT
      // ------------------------------------------------------
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  // ==========================================================
  // RESEND NORMAL PHONE OTP
  // ==========================================================

  Future<void> resendOtp({
    required String phoneNumber,
    required int? resendToken,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    Function(int? resendToken)? onResendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,

      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final User? user = _auth.currentUser;

          if (user == null) {
            await _auth.signInWithCredential(credential);
          } else {
            await user.linkWithCredential(credential);
          }

          await createUserIfNeeded();
        } catch (e) {
          onError(e.toString());
        }
      },

      verificationFailed: (FirebaseAuthException e) {
        onError(_friendlyAuthError(e));
      },

      codeSent: (String verificationId, int? newResendToken) {
        onResendToken?.call(newResendToken);

        onCodeSent(verificationId);
      },

      forceResendingToken: resendToken,

      codeAutoRetrievalTimeout: (_) {},
    );
  }

  // ==========================================================
  // VERIFY NORMAL PHONE OTP
  // ==========================================================

  Future<void> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      final User? user = _auth.currentUser;

      if (user == null) {
        await _auth.signInWithCredential(credential);
      } else {
        await user.linkWithCredential(credential);
      }

      await createUserIfNeeded();
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  // ==========================================================
  // CHECKOUT PHONE OTP
  //
  // IMPORTANT:
  //
  // This is DIFFERENT from normal phone login.
  //
  // The customer is already logged in with:
  //
  // - Email/password
  // - Google
  //
  // We verify the new phone and LINK it to the
  // existing Firebase account.
  // ==========================================================

  Future<void> sendOtpForCurrentUser({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    Function(int? resendToken)? onResendToken,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      onError('Please login before adding your phone number.');

      return;
    }

    // --------------------------------------------------------
    // ALREADY LINKED
    // --------------------------------------------------------

    final existingPhone = user.phoneNumber?.trim() ?? '';

    if (existingPhone.isNotEmpty) {
      onError('A phone number is already linked to this account.');

      return;
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,

      // ------------------------------------------------------
      // AUTOMATIC VERIFICATION
      // ------------------------------------------------------
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final User? currentUser = _auth.currentUser;

          if (currentUser == null) {
            onError('Your session expired. Please login again.');

            return;
          }

          await currentUser.linkWithCredential(credential);

          await createUserIfNeeded();
        } on FirebaseAuthException catch (e) {
          onError(_friendlyAuthError(e));
        } catch (e) {
          onError(e.toString());
        }
      },

      // ------------------------------------------------------
      // FAILED
      // ------------------------------------------------------
      verificationFailed: (FirebaseAuthException e) {
        onError(_friendlyAuthError(e));
      },

      // ------------------------------------------------------
      // OTP SENT
      // ------------------------------------------------------
      codeSent: (String verificationId, int? resendToken) {
        onResendToken?.call(resendToken);

        onCodeSent(verificationId);
      },

      // ------------------------------------------------------
      // TIMEOUT
      // ------------------------------------------------------
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  // ==========================================================
  // VERIFY CHECKOUT OTP
  //
  // Links the verified phone to the CURRENT account.
  // ==========================================================

  Future<void> verifyOtpAndLinkPhone({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw Exception('Please login before adding a phone number.');
      }

      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      // ------------------------------------------------------
      // LINK TO EXISTING ACCOUNT
      // ------------------------------------------------------

      await user.linkWithCredential(credential);

      // ------------------------------------------------------
      // REFRESH USER
      // ------------------------------------------------------

      await user.reload();

      // ------------------------------------------------------
      // SAVE TO FIRESTORE
      // ------------------------------------------------------

      final User? refreshedUser = _auth.currentUser;

      if (refreshedUser == null) {
        throw Exception('Unable to refresh your account.');
      }

      await _firestore.collection('users').doc(refreshedUser.uid).set({
        'phone': refreshedUser.phoneNumber ?? '',
        'phoneVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  // ==========================================================
  // GET SAVED PHONE
  //
  // First checks Firebase Authentication.
  // Then checks Firestore.
  // ==========================================================

  Future<String?> getSavedPhoneNumber() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final authPhone = user.phoneNumber?.trim() ?? '';

    if (authPhone.isNotEmpty) {
      return authPhone;
    }

    final snapshot = await _firestore.collection('users').doc(user.uid).get();

    final data = snapshot.data();

    final firestorePhone = data?['phone']?.toString().trim() ?? '';

    if (firestorePhone.isNotEmpty) {
      return firestorePhone;
    }

    return null;
  }

  // ==========================================================
  // CREATE / UPDATE USER PROFILE
  // ==========================================================

  Future<void> createUserIfNeeded() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final userRef = _firestore.collection('users').doc(user.uid);

    final snapshot = await userRef.get();

    final authPhone = user.phoneNumber ?? '';

    // --------------------------------------------------------
    // NEW USER
    // --------------------------------------------------------

    if (!snapshot.exists) {
      await userRef.set({
        'uid': user.uid,

        'email': user.email ?? '',

        'name': user.displayName ?? '',

        'phone': authPhone,

        'phoneVerified': authPhone.isNotEmpty,

        'photoUrl': user.photoURL ?? '',

        'role': 'customer',

        'createdAt': FieldValue.serverTimestamp(),

        'updatedAt': FieldValue.serverTimestamp(),
      });

      return;
    }

    // --------------------------------------------------------
    // EXISTING USER
    // --------------------------------------------------------

    final Map<String, dynamic> updates = {
      'uid': user.uid,

      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (user.email != null && user.email!.trim().isNotEmpty) {
      updates['email'] = user.email;
    }

    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      updates['name'] = user.displayName;
    }

    if (user.photoURL != null && user.photoURL!.trim().isNotEmpty) {
      updates['photoUrl'] = user.photoURL;
    }

    if (authPhone.trim().isNotEmpty) {
      updates['phone'] = authPhone;

      updates['phoneVerified'] = true;
    }

    await userRef.set(updates, SetOptions(merge: true));
  }

  // ==========================================================
  // FRIENDLY FIREBASE ERRORS
  // ==========================================================

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'The OTP is incorrect. Please try again.';

      case 'session-expired':
        return 'The OTP has expired. Please request a new one.';

      case 'credential-already-in-use':
        return 'This phone number is already linked to another account.';

      case 'provider-already-linked':
        return 'A phone number is already linked to this account.';

      case 'invalid-phone-number':
        return 'Please enter a valid phone number.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'quota-exceeded':
        return 'SMS limit reached. Please try again later.';

      case 'operation-not-allowed':
        return 'Phone authentication is not enabled.';

      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  // ==========================================================
  // SIGN OUT
  // ==========================================================

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Google may not have been used.
    }

    await _auth.signOut();
  }
}
