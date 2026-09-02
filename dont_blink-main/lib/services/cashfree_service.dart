import 'dart:convert';

import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';
import 'package:http/http.dart' as http;

class CashfreeService {
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
          .setEnvironment(CFEnvironment.SANDBOX)
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
          onPaymentResult(returnedOrderId, 'SUCCESS');
        },
        (CFErrorResponse errorResponse, String returnedOrderId) {
          final String message = errorResponse.getMessage() ?? '';

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
