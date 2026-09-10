import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class UpiPaymentResult {
  final bool isSuccess;
  final String status; // 'SUCCESS', 'SUBMITTED', 'FAILURE', 'CANCELLED', 'ERROR', 'UNVERIFIED'
  final String? approvalRefNo;
  final String? txnId;
  final String? rawResponse;
  final String? errorMessage;

  const UpiPaymentResult({
    required this.isSuccess,
    required this.status,
    this.approvalRefNo,
    this.txnId,
    this.rawResponse,
    this.errorMessage,
  });
}

class UpiPaymentService {
  // ---------------------------------------------------------------------------
  // DEFAULT MERCHANT UPI CONFIGURATION
  // (PhonePe Merchant VPA registered under doorstepp)
  // ---------------------------------------------------------------------------
  static String defaultMerchantUpiId = 'Q442616990@ybl';
  static String defaultMerchantName = 'doorstepp';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const MethodChannel _nativeChannel =
      MethodChannel('com.doorstepp.app/upi_native');

  // Cached UPI config
  static String? _cachedUpiId;
  static String? _cachedMerchantName;

  /// Fetches the latest Merchant UPI ID and Name from Firestore (or fallback to defaults).
  static Future<Map<String, String>> getMerchantUpiDetails() async {
    if (_cachedUpiId != null && _cachedMerchantName != null) {
      return {
        'upiId': _cachedUpiId!,
        'merchantName': _cachedMerchantName!,
      };
    }

    try {
      final doc = await _firestore.collection('settings').doc('payment_config').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final upiId = data['upiId']?.toString().trim();
        final name = data['merchantName']?.toString().trim();

        if (upiId != null && upiId.isNotEmpty) {
          _cachedUpiId = upiId;
        }
        if (name != null && name.isNotEmpty) {
          _cachedMerchantName = name;
        }
      }
    } catch (e) {
      debugPrint('Error fetching UPI config from Firestore: $e');
    }

    return {
      'upiId': _cachedUpiId ?? defaultMerchantUpiId,
      'merchantName': _cachedMerchantName ?? defaultMerchantName,
    };
  }

  /// Sets or updates the Merchant UPI configuration in Firestore
  static Future<void> updateMerchantUpiConfig({
    required String upiId,
    required String merchantName,
  }) async {
    _cachedUpiId = upiId.trim();
    _cachedMerchantName = merchantName.trim();

    try {
      await _firestore.collection('settings').doc('payment_config').set({
        'upiId': _cachedUpiId,
        'merchantName': _cachedMerchantName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving UPI config to Firestore: $e');
    }
  }

  /// Generates the standard NPCI UPI URI string
  static String buildUpiUriString({
    required String upiId,
    required String merchantName,
    required double amount,
    required String orderId,
    String? transactionNote,
  }) {
    final note = transactionNote ?? 'Order #$orderId';
    final cleanUpi = upiId.trim();
    final cleanName = merchantName.trim();
    final cleanAmount = amount.toStringAsFixed(2);

    final encodedName = Uri.encodeComponent(cleanName);
    final encodedNote = Uri.encodeComponent(note);
    final encodedRef = Uri.encodeComponent(orderId);

    // Standard NPCI URI schema
    return 'upi://pay?pa=$cleanUpi&pn=$encodedName&am=$cleanAmount&cu=INR&tn=$encodedNote&tr=$encodedRef';
  }

  /// Initiates native Android UPI payment with Activity Result verification
  static Future<UpiPaymentResult> initiateNativeUpiPayment({
    required double amount,
    required String orderId,
    String? specificAppPackage,
  }) async {
    final details = await getMerchantUpiDetails();
    final upiId = details['upiId'] ?? defaultMerchantUpiId;
    final merchantName = details['merchantName'] ?? defaultMerchantName;

    final uriString = buildUpiUriString(
      upiId: upiId,
      merchantName: merchantName,
      amount: amount,
      orderId: orderId,
    );

    try {
      final dynamic rawResult = await _nativeChannel.invokeMethod(
        'startUpiPayment',
        {
          'uri': uriString,
          'package': specificAppPackage,
        },
      );

      if (rawResult == null) {
        return const UpiPaymentResult(
          isSuccess: false,
          status: 'CANCELLED',
          errorMessage: 'Payment was dismissed without completion.',
        );
      }

      final Map<String, dynamic> result = Map<String, dynamic>.from(rawResult as Map);

      final status = (result['status'] ?? '').toString().toUpperCase();
      final approvalRefNo = result['approvalRefNo']?.toString();
      final txnId = result['txnId']?.toString();
      final rawResponse = result['rawResponse']?.toString();
      final message = result['message']?.toString();

      debugPrint('NATIVE_UPI_RESPONSE status=$status, approvalRefNo=$approvalRefNo, raw=$rawResponse');

      if (status == 'SUCCESS') {
        final ref = (approvalRefNo != null && approvalRefNo.trim().isNotEmpty)
            ? approvalRefNo.trim()
            : (txnId != null && txnId.trim().isNotEmpty ? txnId.trim() : orderId);

        return UpiPaymentResult(
          isSuccess: true,
          status: 'SUCCESS',
          approvalRefNo: ref,
          txnId: txnId,
          rawResponse: rawResponse,
        );
      } else if (status == 'SUBMITTED') {
        return UpiPaymentResult(
          isSuccess: true,
          status: 'SUBMITTED',
          approvalRefNo: approvalRefNo ?? orderId,
          txnId: txnId,
          rawResponse: rawResponse,
        );
      } else if (status == 'CANCELLED') {
        return UpiPaymentResult(
          isSuccess: false,
          status: 'CANCELLED',
          errorMessage: message ?? 'Payment was cancelled in UPI app.',
        );
      } else {
        return UpiPaymentResult(
          isSuccess: false,
          status: 'FAILURE',
          errorMessage: message ?? 'Payment was declined or not completed.',
          rawResponse: rawResponse,
        );
      }
    } on MissingPluginException {
      debugPrint('Native UPI channel is not registered on this build.');
      return const UpiPaymentResult(
        isSuccess: false,
        status: 'ERROR',
        errorMessage: 'Payment verification service not connected. Please restart or reinstall the latest app build.',
      );
    } catch (e) {
      debugPrint('Native UPI payment error: $e');
      return UpiPaymentResult(
        isSuccess: false,
        status: 'ERROR',
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Launches the UPI app chooser via URL launcher (fallback)
  static Future<bool> launchUpiPayment({
    required double amount,
    required String orderId,
    String? specificAppPackage,
  }) async {
    final details = await getMerchantUpiDetails();
    final upiId = details['upiId'] ?? defaultMerchantUpiId;
    final merchantName = details['merchantName'] ?? defaultMerchantName;

    final uriString = buildUpiUriString(
      upiId: upiId,
      merchantName: merchantName,
      amount: amount,
      orderId: orderId,
    );

    final uri = Uri.parse(uriString);
    debugPrint('Launching UPI URI: $uriString');

    try {
      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) {
        debugPrint('Device cannot handle upi:// URI directly');
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      return launched;
    } catch (e) {
      debugPrint('Failed to launch UPI URL: $e');
      return false;
    }
  }

  /// Copies merchant UPI ID to clipboard
  static Future<void> copyUpiIdToClipboard() async {
    final details = await getMerchantUpiDetails();
    final upiId = details['upiId'] ?? defaultMerchantUpiId;
    await Clipboard.setData(ClipboardData(text: upiId));
  }
}
