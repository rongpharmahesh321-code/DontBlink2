import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfupi.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfupipayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfupi/cfupiutils.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';
import 'package:http/http.dart' as http;

class CashfreeService {
  // ==========================================================
  // CASHFREE ENVIRONMENT
  // ==========================================================
  // Set to SANDBOX for test credentials, PRODUCTION for live credentials.
  static const CFEnvironment environment = CFEnvironment.SANDBOX;

  // ==========================================================
  // FIREBASE CLOUD FUNCTIONS
  // ==========================================================

  static const String createOrderUrl =
      'https://asia-south1-dontblink-3d0f6.cloudfunctions.net/createCashfreeOrder';

  static const String verifyPaymentUrl =
      'https://asia-south1-dontblink-3d0f6.cloudfunctions.net/verifyCashfreePayment';

  // ==========================================================
  // CREATE CASHFREE ORDER
  // ==========================================================

  Future<CashfreeOrderResponse> createOrder({
    required String orderId,
    required double amount,
    required String customerId,
    required String customerName,
    required String customerPhone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(createOrderUrl),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orderId': orderId,
          'amount': amount,
          'customerId': customerId,
          'customerName': customerName,
          'customerPhone': customerPhone,
          'returnUrl':
              'https://asia-south1-dontblink-3d0f6.cloudfunctions.net/paymentReturn',
        }),
      );

      // ======================================================
      // DECODE RESPONSE
      // ======================================================

      Map<String, dynamic> data = {};

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        // Response was not valid JSON.
      }

      // ======================================================
      // HTTP ERROR
      // ======================================================

      if (response.statusCode != 200) {
        throw Exception(
          data['error']?.toString() ??
              'Unable to create Cashfree payment order.',
        );
      }

      // ======================================================
      // FUNCTION ERROR
      // ======================================================

      final success = data['success'] == true;

      if (!success) {
        throw Exception(
          data['error']?.toString() ?? 'Cashfree order creation failed.',
        );
      }

      // ======================================================
      // PAYMENT SESSION
      // ======================================================

      final paymentSessionId = data['paymentSessionId']?.toString() ?? '';

      final returnedOrderId = data['orderId']?.toString() ?? orderId;

      if (paymentSessionId.trim().isEmpty) {
        throw Exception('Cashfree did not return a payment session.');
      }

      return CashfreeOrderResponse(
        orderId: returnedOrderId,
        paymentSessionId: paymentSessionId,
      );
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ==========================================================
  // OPEN CASHFREE CHECKOUT
  // ==========================================================

  Future<void> openCheckout({
    required String orderId,
    required String paymentSessionId,
    required void Function(String orderId, String paymentStatus)
    onPaymentResult,
    required void Function(String message) onError,
  }) async {
    try {
      // ======================================================
      // VALIDATE INPUT
      // ======================================================

      if (orderId.trim().isEmpty) {
        onError('Cashfree order ID is missing.');
        return;
      }

      if (paymentSessionId.trim().isEmpty) {
        onError('Cashfree payment session is missing.');
        return;
      }

      // ======================================================
      // CREATE CASHFREE SESSION
      // ======================================================

      final session = CFSessionBuilder()
          .setEnvironment(environment)
          .setOrderId(orderId)
          .setPaymentSessionId(paymentSessionId)
          .build();

      // ======================================================
      // CREATE WEB CHECKOUT PAYMENT
      // ======================================================

      final payment = CFWebCheckoutPaymentBuilder().setSession(session).build();

      // ======================================================
      // CREATE PAYMENT SERVICE
      // ======================================================

      final service = CFPaymentGatewayService();

      // ======================================================
      // CASHFREE CALLBACKS
      // ======================================================

      service.setCallback(
        (String returnedOrderId) {
          debugPrint('CF_CHECKOUT_SUCCESS: $returnedOrderId');
          onPaymentResult(returnedOrderId, 'SUCCESS');
        },
        (CFErrorResponse errorResponse, String returnedOrderId) {
          final String message = errorResponse.getMessage() ?? '';
          final String code = errorResponse.getCode() ?? '';
          debugPrint('CF_CHECKOUT_ERROR: code=$code, message=$message');

          onError(
            message.trim().isNotEmpty
                ? message.trim()
                : 'Cashfree payment failed.',
          );
        },
      );

      // ======================================================
      // OPEN CASHFREE
      // ======================================================

      service.doPayment(payment);
    } on CFException catch (e) {
      final String message = e.message;

      onError(
        message.trim().isNotEmpty
            ? message.trim()
            : 'Unable to open Cashfree checkout.',
      );
    } catch (e) {
      onError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ==========================================================
  // GET INSTALLED UPI APPS
  // ==========================================================

  Future<List<Map<String, dynamic>>> getInstalledUPIApps() async {
    try {
      final List? apps = await CFUPIUtils().getUPIApps();
      debugPrint('CF_INSTALLED_UPI_APPS_RAW: $apps');
      if (apps != null && apps.isNotEmpty) {
        return apps
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (e) {
      debugPrint('Error getting installed UPI apps: $e');
    }
    return [];
  }

  // ==========================================================
  // OPEN UPI INTENT PAYMENT (Direct UPI App Selector)
  // ==========================================================

  Future<void> openUPIIntentPayment({
    required String orderId,
    required String paymentSessionId,
    String? appPackage,
    required void Function(String orderId, String paymentStatus) onPaymentResult,
    required void Function(String message) onError,
  }) async {
    try {
      if (orderId.trim().isEmpty || paymentSessionId.trim().isEmpty) {
        onError('Cashfree payment session is missing.');
        return;
      }

      final session = CFSessionBuilder()
          .setEnvironment(environment)
          .setOrderId(orderId)
          .setPaymentSessionId(paymentSessionId)
          .build();

      final cfupi = (appPackage != null && appPackage.trim().isNotEmpty)
          ? CFUPIBuilder()
              .setChannel(CFUPIChannel.INTENT)
              .setUPIID(appPackage.trim())
              .build()
          : CFUPIBuilder()
              .setChannel(CFUPIChannel.INTENT_WITH_UI)
              .build();

      final payment = CFUPIPaymentBuilder()
          .setSession(session)
          .setUPI(cfupi)
          .build();

      final service = CFPaymentGatewayService();

      service.setCallback(
        (String returnedOrderId) {
          debugPrint('CF_UPI_INTENT_SUCCESS: $returnedOrderId');
          onPaymentResult(returnedOrderId, 'SUCCESS');
        },
        (CFErrorResponse errorResponse, String returnedOrderId) {
          final String message = errorResponse.getMessage() ?? '';
          final String code = errorResponse.getCode() ?? '';
          debugPrint('CF_UPI_INTENT_ERROR: code=$code, message=$message');
          onError(message.trim().isNotEmpty ? message.trim() : 'UPI payment failed.');
        },
      );

      service.doPayment(payment);
    } on CFException catch (e) {
      onError(e.message.isNotEmpty ? e.message : 'Unable to open UPI payment.');
    } catch (e) {
      onError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ==========================================================
  // OPEN UPI COLLECT PAYMENT (Via VPA e.g. user@bank)
  // ==========================================================

  Future<void> openUPICollectPayment({
    required String orderId,
    required String paymentSessionId,
    required String upiId,
    required void Function(String orderId, String paymentStatus) onPaymentResult,
    required void Function(String message) onError,
  }) async {
    try {
      if (orderId.trim().isEmpty || paymentSessionId.trim().isEmpty) {
        onError('Cashfree payment session is missing.');
        return;
      }

      final session = CFSessionBuilder()
          .setEnvironment(environment)
          .setOrderId(orderId)
          .setPaymentSessionId(paymentSessionId)
          .build();

      final cfupi = CFUPIBuilder()
          .setChannel(CFUPIChannel.COLLECT)
          .setUPIID(upiId)
          .build();

      final payment = CFUPIPaymentBuilder()
          .setSession(session)
          .setUPI(cfupi)
          .build();

      final service = CFPaymentGatewayService();

      service.setCallback(
        (String returnedOrderId) {
          debugPrint('CF_UPI_COLLECT_SUCCESS: $returnedOrderId');
          onPaymentResult(returnedOrderId, 'SUCCESS');
        },
        (CFErrorResponse errorResponse, String returnedOrderId) {
          final String message = errorResponse.getMessage() ?? '';
          final String code = errorResponse.getCode() ?? '';
          debugPrint('CF_UPI_COLLECT_ERROR: code=$code, message=$message');
          onError(message.trim().isNotEmpty ? message.trim() : 'UPI collect failed.');
        },
      );

      service.doPayment(payment);
    } on CFException catch (e) {
      onError(e.message.isNotEmpty ? e.message : 'Unable to initiate UPI collect.');
    } catch (e) {
      onError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ==========================================================
  // VERIFY PAYMENT
  // ==========================================================

  Future<CashfreeVerificationResponse> verifyPayment({
    required String orderId,
  }) async {
    try {
      // ======================================================
      // VALIDATE ORDER ID
      // ======================================================

      if (orderId.trim().isEmpty) {
        throw Exception('Cashfree order ID is missing.');
      }

      // ======================================================
      // CALL FIREBASE FUNCTION
      // ======================================================

      final response = await http.post(
        Uri.parse(verifyPaymentUrl),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'orderId': orderId}),
      );

      // ======================================================
      // DECODE RESPONSE
      // ======================================================

      Map<String, dynamic> data = {};

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        // Invalid JSON handled below.
      }

      // ======================================================
      // HTTP ERROR
      // ======================================================

      if (response.statusCode != 200) {
        throw Exception(
          data['error']?.toString() ?? 'Unable to verify Cashfree payment.',
        );
      }

      // ======================================================
      // PAYMENT STATUS
      // ======================================================

      final success = data['success'] == true;

      final returnedOrderId = data['orderId']?.toString() ?? orderId;

      final paymentStatus = data['paymentStatus']?.toString() ?? 'FAILED';

      return CashfreeVerificationResponse(
        success: success,
        orderId: returnedOrderId,
        paymentStatus: paymentStatus,
      );
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}

// ============================================================
// CASHFREE ORDER RESPONSE
// ============================================================

class CashfreeOrderResponse {
  final String orderId;
  final String paymentSessionId;

  const CashfreeOrderResponse({
    required this.orderId,
    required this.paymentSessionId,
  });
}

// ============================================================
// CASHFREE VERIFICATION RESPONSE
// ============================================================

class CashfreeVerificationResponse {
  final bool success;
  final String orderId;
  final String paymentStatus;

  const CashfreeVerificationResponse({
    required this.success,
    required this.orderId,
    required this.paymentStatus,
  });

  // ==========================================================
  // CHECK WHETHER PAYMENT WAS SUCCESSFUL
  // ==========================================================

  bool get isPaid {
    return success && paymentStatus.toUpperCase() == 'SUCCESS';
  }
}
