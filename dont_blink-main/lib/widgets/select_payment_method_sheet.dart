import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cashfree_service.dart';
import '../theme/app_colors.dart';

class PaymentSelection {
  final String type; // 'UPI_INTENT', 'UPI_COLLECT', 'CARD', 'WALLET', 'COD'
  final String title;
  final String subtitle;
  final String? upiId;
  final String? appPackage;
  final String? iconBase64;
  final String? cardNumber;
  final String? cardExpiry;
  final String? cardCvv;
  final String? cardHolder;

  const PaymentSelection({
    required this.type,
    required this.title,
    this.subtitle = '',
    this.upiId,
    this.appPackage,
    this.iconBase64,
    this.cardNumber,
    this.cardExpiry,
    this.cardCvv,
    this.cardHolder,
  });
}

// =============================================================================
// PAYMENT BRAND ICON (Renders decoded photo or branded vector fallback)
// =============================================================================

class PaymentBrandIcon extends StatelessWidget {
  final PaymentSelection payment;
  final double size;

  const PaymentBrandIcon({
    super.key,
    required this.payment,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    if (payment.iconBase64 != null && payment.iconBase64!.trim().isNotEmpty) {
      try {
        final bytes = base64Decode(payment.iconBase64!.trim());
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.25),
            border: Border.all(color: const Color(0xFFE2EEE5), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _buildFallback(),
            ),
          ),
        );
      } catch (_) {
        // Fall back to branded icon
      }
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    final titleLower = payment.title.toLowerCase();
    final pkgLower = (payment.appPackage ?? '').toLowerCase();

    // PhonePe
    if (titleLower.contains('phonepe') || pkgLower.contains('phonepe')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF5F259F),
          borderRadius: BorderRadius.circular(size * 0.25),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5F259F).withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'पे',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.52,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    // Google Pay / GPay
    if (titleLower.contains('google') ||
        titleLower.contains('gpay') ||
        pkgLower.contains('paisa')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.25),
          border: Border.all(color: const Color(0xFFE2EEE5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: size * 0.32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
              children: const [
                TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
                TextSpan(text: 'Pay', style: TextStyle(color: Color(0xFF5F6368))),
              ],
            ),
          ),
        ),
      );
    }

    // Paytm
    if (titleLower.contains('paytm') || pkgLower.contains('paytm')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.25),
          border: Border.all(
            color: const Color(0xFF00B9F1).withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: size * 0.28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
              children: const [
                TextSpan(text: 'pay', style: TextStyle(color: Color(0xFF002E6E))),
                TextSpan(text: 'tm', style: TextStyle(color: Color(0xFF00B9F1))),
              ],
            ),
          ),
        ),
      );
    }

    // Amazon Pay
    if (titleLower.contains('amazon') || pkgLower.contains('amazon')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF232F3E),
          borderRadius: BorderRadius.circular(size * 0.25),
        ),
        child: Center(
          child: Text(
            'a pay',
            style: TextStyle(
              color: const Color(0xFFFF9900),
              fontSize: size * 0.30,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    // CRED
    if (titleLower.contains('cred') || pkgLower.contains('cred')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(size * 0.25),
        ),
        child: Center(
          child: Text(
            'CRED',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    // BHIM
    if (titleLower.contains('bhim') || pkgLower.contains('bhim')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.25),
          border: Border.all(color: const Color(0xFFE2EEE5)),
        ),
        child: Center(
          child: Text(
            'BHIM',
            style: TextStyle(
              color: const Color(0xFF00897B),
              fontSize: size * 0.30,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    // Slice
    if (titleLower.contains('slice') || pkgLower.contains('slice')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF7A1FA2),
          borderRadius: BorderRadius.circular(size * 0.25),
        ),
        child: Center(
          child: Text(
            'slice',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.30,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    // Generic UPI
    if (payment.type == 'UPI_INTENT' || payment.type == 'UPI_COLLECT') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.25),
          border: Border.all(color: const Color(0xFF168A43), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF168A43).withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF168A43),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'UPI',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.30,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      );
    }

    // Cards
    if (payment.type == 'CARD') {
      final titleLower = payment.title.toLowerCase();
      String brandText = '';
      Color brandColor = const Color(0xFF1976D2);

      if (titleLower.contains('visa')) {
        brandText = 'VISA';
        brandColor = const Color(0xFF1A1F71);
      } else if (titleLower.contains('mastercard') || titleLower.contains('mc')) {
        brandText = 'MC';
        brandColor = const Color(0xFFEB001B);
      } else if (titleLower.contains('rupay')) {
        brandText = 'RuPay';
        brandColor = const Color(0xFF005696);
      } else if (titleLower.contains('amex')) {
        brandText = 'AMEX';
        brandColor = const Color(0xFF007CC3);
      }

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(size * 0.25),
          border: Border.all(color: const Color(0xFFBBDEFB), width: 1),
        ),
        child: Center(
          child: brandText.isNotEmpty
              ? Text(
                  brandText,
                  style: TextStyle(
                    color: brandColor,
                    fontSize: size * 0.27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                )
              : Icon(
                  Icons.credit_card_rounded,
                  color: const Color(0xFF1976D2),
                  size: size * 0.55,
                ),
        ),
      );
    }

    // Wallet
    if (payment.type == 'WALLET') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(size * 0.25),
        ),
        child: Icon(
          Icons.account_balance_wallet_rounded,
          color: const Color(0xFFE65100),
          size: size * 0.55,
        ),
      );
    }

    // COD
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Icon(
        Icons.payments_rounded,
        color: const Color(0xFF168A43),
        size: size * 0.55,
      ),
    );
  }
}

class SelectPaymentMethodSheet extends StatefulWidget {
  final PaymentSelection currentSelection;
  final double totalAmount;
  final bool isCodAvailable;

  const SelectPaymentMethodSheet({
    super.key,
    required this.currentSelection,
    required this.totalAmount,
    required this.isCodAvailable,
  });

  static Future<PaymentSelection?> show(
    BuildContext context, {
    required PaymentSelection currentSelection,
    required double totalAmount,
    required bool isCodAvailable,
  }) {
    return showModalBottomSheet<PaymentSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SelectPaymentMethodSheet(
        currentSelection: currentSelection,
        totalAmount: totalAmount,
        isCodAvailable: isCodAvailable,
      ),
    );
  }

  @override
  State<SelectPaymentMethodSheet> createState() =>
      _SelectPaymentMethodSheetState();
}

class _SelectPaymentMethodSheetState extends State<SelectPaymentMethodSheet> {
  final CashfreeService _cashfreeService = CashfreeService();
  List<Map<String, dynamic>> _installedUpiApps = [];
  bool _loadingUpiApps = true;

  @override
  void initState() {
    super.initState();
    _fetchUpiApps();
  }

  Future<void> _fetchUpiApps() async {
    try {
      final apps = await _cashfreeService.getInstalledUPIApps();
      debugPrint('FETCHED_UPI_APPS: $apps');
      if (mounted) {
        setState(() {
          _installedUpiApps = apps;
          _loadingUpiApps = false;
        });
      }
    } catch (e) {
      debugPrint('FETCH_UPI_APPS_ERR: $e');
      if (mounted) {
        setState(() {
          _loadingUpiApps = false;
        });
      }
    }
  }

  void _selectMethod(PaymentSelection selection) {
    Navigator.pop(context, selection);
  }

  Future<void> _showAddUpiIdDialog() async {
    final upiController = TextEditingController();
    String? errorMessage;

    final result = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Add UPI ID',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your UPI ID / VPA to receive a payment request.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: upiController,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'e.g. mobile@upi or name@okaxis',
                      errorText: errorMessage,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final upi = upiController.text.trim();
                    if (!upi.contains('@') || upi.length < 4) {
                      setDialogState(() {
                        errorMessage = 'Please enter a valid UPI ID (e.g. name@bank)';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, upi);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('PROCEED'),
                ),
              ],
            );
          },
        );
      },
    );

    upiController.dispose();

    if (result != null && result.trim().isNotEmpty && mounted) {
      _selectMethod(
        PaymentSelection(
          type: 'UPI_COLLECT',
          title: 'UPI ($result)',
          subtitle: 'Payment request will be sent to $result',
          upiId: result.trim(),
        ),
      );
    }
  }

  Future<void> _showAddCardDialog() async {
    final cardNumberController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    final nameController = TextEditingController();
    String? errorMessage;
    String detectedBrand = 'Card';

    final result = await showDialog<PaymentSelection>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.tintGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.credit_card_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Card',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          'Credit or Debit Card',
                          style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: Colors.red),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(fontSize: 11.5, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Card Number
                    const Text(
                      'CARD NUMBER',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: cardNumberController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                        _CardNumberFormatter(),
                      ],
                      onChanged: (val) {
                        final clean = val.replaceAll(' ', '');
                        String brand = 'Card';
                        if (clean.startsWith('4')) {
                          brand = 'Visa';
                        } else if (clean.startsWith(RegExp(r'5[1-5]')) || clean.startsWith(RegExp(r'2[2-7]'))) {
                          brand = 'Mastercard';
                        } else if (clean.startsWith(RegExp(r'(508|60|65|81|82)'))) {
                          brand = 'RuPay';
                        } else if (clean.startsWith(RegExp(r'3[47]'))) {
                          brand = 'Amex';
                        }
                        if (brand != detectedBrand) {
                          setDialogState(() {
                            detectedBrand = brand;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        hintText: '1234 5678 9012 3456',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            detectedBrand != 'Card' ? detectedBrand : 'CARD',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: detectedBrand == 'Visa'
                                  ? const Color(0xFF1A1F71)
                                  : detectedBrand == 'Mastercard'
                                      ? const Color(0xFFEB001B)
                                      : detectedBrand == 'RuPay'
                                          ? const Color(0xFF005696)
                                          : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Expiry & CVV Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'VALID THRU',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: expiryController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                  _CardExpiryFormatter(),
                                ],
                                decoration: InputDecoration(
                                  hintText: 'MM/YY',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CVV',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: cvvController,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                decoration: InputDecoration(
                                  hintText: '•••',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Name on Card
                    const Text(
                      'NAME ON CARD',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Cardholder Name',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 100% Safe Badge
                    Row(
                      children: [
                        const Icon(Icons.lock_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '100% Safe & Bank-grade 256-bit encryption',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Shortcut to pay via Cashfree card portal directly
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(
                            dialogContext,
                            const PaymentSelection(
                              type: 'CARD',
                              title: 'Credit / Debit Card',
                              subtitle: 'Pay securely using any bank card',
                            ),
                          );
                        },
                        child: const Text(
                          'Or pay via Card at checkout →',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          final cleanNum = cardNumberController.text.replaceAll(' ', '').trim();
                          final expiry = expiryController.text.trim();
                          final cvv = cvvController.text.trim();
                          final holder = nameController.text.trim();

                          if (cleanNum.isNotEmpty && cleanNum.length < 12) {
                            setDialogState(() {
                              errorMessage = 'Please enter a valid card number.';
                            });
                            return;
                          }

                          if (expiry.isNotEmpty) {
                            final parts = expiry.split('/');
                            final month = int.tryParse(parts.first) ?? 0;
                            if (month < 1 || month > 12) {
                              setDialogState(() {
                                errorMessage = 'Invalid expiry month (01-12).';
                              });
                              return;
                            }
                          }

                          final last4 = cleanNum.length >= 4
                              ? cleanNum.substring(cleanNum.length - 4)
                              : '';

                          final title = last4.isNotEmpty
                              ? '$detectedBrand (•••• $last4)'
                              : 'Credit / Debit Card';

                          final subtitle = holder.isNotEmpty
                              ? '$holder • Debit / Credit Card'
                              : 'Pay securely using any bank card';

                          Navigator.pop(
                            dialogContext,
                            PaymentSelection(
                              type: 'CARD',
                              title: title,
                              subtitle: subtitle,
                              cardNumber: cleanNum.isNotEmpty ? cleanNum : null,
                              cardExpiry: expiry.isNotEmpty ? expiry : null,
                              cardCvv: cvv.isNotEmpty ? cvv : null,
                              cardHolder: holder.isNotEmpty ? holder : null,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('PROCEED', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    cardNumberController.dispose();
    expiryController.dispose();
    cvvController.dispose();
    nameController.dispose();

    if (result != null && mounted) {
      _selectMethod(result);
    }
  }

  // ---------------------------------------------------------------------------
  // UI BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFFF7FAF8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // 1. RECOMMENDED SECTION
                _buildSectionHeader('Recommended'),
                _buildCardContainer(_buildRecommendedItems()),

                const SizedBox(height: 18),

                // 2. CARDS SECTION
                _buildSectionHeader('Cards'),
                _buildCardContainer([
                  if (widget.currentSelection.type == 'CARD') ...[
                    _buildPaymentRow(
                      iconWidget: PaymentBrandIcon(
                        payment: widget.currentSelection,
                        size: 44,
                      ),
                      title: widget.currentSelection.title,
                      subtitle: widget.currentSelection.subtitle,
                      onTap: () => _selectMethod(widget.currentSelection),
                    ),
                    _buildDivider(),
                  ],
                  _buildPaymentRow(
                    iconWidget: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(
                        Icons.credit_card_rounded,
                        color: Colors.black87,
                        size: 22,
                      ),
                    ),
                    title: widget.currentSelection.type == 'CARD'
                        ? 'Add another card'
                        : 'Add credit or debit cards',
                    actionWidget: _buildActionTag('ADD'),
                    onTap: _showAddCardDialog,
                  ),
                ]),

                const SizedBox(height: 18),

                // 3. PAY BY ANY UPI APP
                _buildSectionHeader('Pay by any UPI app'),
                _buildCardContainer([
                  _buildPaymentRow(
                    iconWidget: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          'UPI',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ),
                    title: 'Add new UPI ID',
                    subtitle: 'Pay using any registered UPI handle',
                    actionWidget: _buildActionTag('ADD'),
                    onTap: _showAddUpiIdDialog,
                  ),
                ]),

                const SizedBox(height: 18),

                // 4. PAY ON DELIVERY
                _buildSectionHeader('Pay on Delivery'),
                _buildCardContainer([
                  _buildPaymentRow(
                    iconWidget: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: widget.isCodAvailable
                            ? AppColors.tintGreen
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.payments_rounded,
                        color: widget.isCodAvailable
                            ? AppColors.primary
                            : Colors.grey.shade500,
                        size: 22,
                      ),
                    ),
                    title: 'Cash on Delivery',
                    subtitle: widget.isCodAvailable
                        ? 'Pay cash or UPI when order arrives'
                        : 'Unavailable between 10:00 PM and 7:00 AM',
                    enabled: widget.isCodAvailable,
                    onTap: widget.isCodAvailable
                        ? () => _selectMethod(
                              const PaymentSelection(
                                type: 'COD',
                                title: 'Cash on Delivery',
                                subtitle: 'Pay when your order arrives',
                              ),
                            )
                        : null,
                  ),
                ]),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER COMPONENTS
  // ---------------------------------------------------------------------------

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8EFE9), width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 24,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Select Payment Method',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          Text(
            '₹${widget.totalAmount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EEE5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildPaymentRow({
    required Widget iconWidget,
    required String title,
    String? subtitle,
    Widget? actionWidget,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    final isSelected = widget.currentSelection.title == title;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Opacity(
              opacity: enabled ? 1.0 : 0.45,
              child: iconWidget,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: enabled ? Colors.black87 : Colors.grey.shade500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled ? Colors.grey.shade600 : Colors.red.shade400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actionWidget != null)
              IgnorePointer(child: actionWidget)
            else if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 22,
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade100,
      indent: 68,
      endIndent: 14,
    );
  }

  Widget _buildActionTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.tintGreen,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.tintGreenBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _formatUpiTitle(String rawName, String package) {
    String name = rawName.trim();
    if (name.isEmpty || name.toLowerCase() == 'null') {
      final pkg = package.toLowerCase();
      if (pkg.contains('paisa') || pkg.contains('google')) {
        name = 'Google Pay';
      } else if (pkg.contains('phonepe')) {
        name = 'PhonePe';
      } else if (pkg.contains('paytm')) {
        name = 'Paytm';
      } else if (pkg.contains('amazon')) {
        name = 'Amazon Pay';
      } else if (pkg.contains('cred')) {
        name = 'CRED';
      } else if (pkg.contains('bhim')) {
        name = 'BHIM';
      } else {
        name = 'UPI';
      }
    }

    // Clean any duplicated "UPI UPI"
    name = name
        .replaceAll(RegExp(r'\bUPI\s+UPI\b', caseSensitive: false), 'UPI')
        .trim();

    if (name.toUpperCase() == 'UPI') {
      return 'UPI';
    }

    return name;
  }

  List<Widget> _buildRecommendedItems() {
    if (!_loadingUpiApps && _installedUpiApps.isNotEmpty) {
      final List<Widget> items = [];
      for (int i = 0; i < _installedUpiApps.length; i++) {
        final app = _installedUpiApps[i];
        final rawName = app['displayName']?.toString() ??
            app['appName']?.toString() ??
            app['app_name']?.toString() ??
            app['name']?.toString() ??
            '';
        final appPackage = app['id']?.toString() ??
            app['appPackage']?.toString() ??
            app['app_package']?.toString() ??
            app['package']?.toString();
        final iconBase64 = app['icon']?.toString() ??
            app['base64Icon']?.toString() ??
            app['appIcon']?.toString();

        final title = _formatUpiTitle(rawName, appPackage ?? '');
        final subtitle = title == 'UPI'
            ? 'Pay directly via UPI'
            : 'Pay directly via $title';

        final selection = PaymentSelection(
          type: 'UPI_INTENT',
          title: title,
          subtitle: subtitle,
          appPackage: appPackage,
          iconBase64: iconBase64,
        );

        if (i > 0) items.add(_buildDivider());
        items.add(
          _buildPaymentRow(
            iconWidget: PaymentBrandIcon(
              payment: selection,
              size: 44,
            ),
            title: title,
            subtitle: subtitle,
            onTap: () => _selectMethod(selection),
          ),
        );
      }
      return items;
    }

    return [
      _buildPaymentRow(
        iconWidget: const PaymentBrandIcon(
          payment: PaymentSelection(
            type: 'UPI_INTENT',
            title: 'PhonePe',
            appPackage: 'com.phonepe.app',
          ),
          size: 44,
        ),
        title: 'PhonePe',
        subtitle: 'Pay directly via PhonePe',
        onTap: () => _selectMethod(
          const PaymentSelection(
            type: 'UPI_INTENT',
            title: 'PhonePe',
            subtitle: 'Pay directly via PhonePe',
            appPackage: 'com.phonepe.app',
          ),
        ),
      ),
      _buildDivider(),
      _buildPaymentRow(
        iconWidget: const PaymentBrandIcon(
          payment: PaymentSelection(
            type: 'UPI_INTENT',
            title: 'Google Pay',
            appPackage: 'com.google.android.apps.nbu.paisa.user',
          ),
          size: 44,
        ),
        title: 'Google Pay',
        subtitle: 'Pay directly via Google Pay',
        onTap: () => _selectMethod(
          const PaymentSelection(
            type: 'UPI_INTENT',
            title: 'Google Pay',
            subtitle: 'Pay directly via Google Pay',
            appPackage: 'com.google.android.apps.nbu.paisa.user',
          ),
        ),
      ),
      _buildDivider(),
      _buildPaymentRow(
        iconWidget: const PaymentBrandIcon(
          payment: PaymentSelection(
            type: 'UPI_INTENT',
            title: 'Paytm',
            appPackage: 'net.one97.paytm',
          ),
          size: 44,
        ),
        title: 'Paytm',
        subtitle: 'Pay directly via Paytm',
        onTap: () => _selectMethod(
          const PaymentSelection(
            type: 'UPI_INTENT',
            title: 'Paytm',
            subtitle: 'Pay directly via Paytm',
            appPackage: 'net.one97.paytm',
          ),
        ),
      ),
    ];
  }
}

// =============================================================================
// CARD FORMATTERS
// =============================================================================

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) {
      return oldValue;
    }
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) {
        buffer.write(' ');
      }
    }
    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll('/', '');
    if (text.length > 4) {
      return oldValue;
    }
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && text.length > 2) {
        buffer.write('/');
      }
    }
    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

