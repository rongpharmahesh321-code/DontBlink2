import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _brandOpacity;
  late final Animation<double> _dividerOpacity;
  late final Animation<double> _dotsOpacity;

  late final Animation<double> _cartOpacity;
  late final Animation<double> _cartScale;
  late final Animation<Offset> _cartSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // ----------------------------------------------------------
    // BRANDING
    // ----------------------------------------------------------

    _brandOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.30, curve: Curves.easeOut),
    );

    // ----------------------------------------------------------
    // DIVIDER + BAG
    // ----------------------------------------------------------

    _dividerOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.48, curve: Curves.easeOut),
    );

    // ----------------------------------------------------------
    // FOUR DOTS
    // ----------------------------------------------------------

    _dotsOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.48, 0.62, curve: Curves.easeOut),
    );

    // ----------------------------------------------------------
    // CART OPACITY
    // ----------------------------------------------------------

    _cartOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.70, 0.82, curve: Curves.easeOut),
    );

    // ----------------------------------------------------------
    // CART SCALE
    // ----------------------------------------------------------

    _cartScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.70, 1.00, curve: Curves.easeOutBack),
      ),
    );

    // ----------------------------------------------------------
    // CART SLIDES FROM LEFT
    // ----------------------------------------------------------

    _cartSlide = Tween<Offset>(begin: const Offset(-1.7, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.68, 1.00, curve: Curves.easeOutCubic),
          ),
        );

    // ----------------------------------------------------------
    // START
    // ----------------------------------------------------------

    _controller.forward().whenComplete(() {
      if (!mounted) {
        return;
      }

      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) {
          return;
        }

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return const AuthGate();
            },
            transitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // ------------------------------------------------
                // BACKGROUND ICONS
                // ------------------------------------------------
                _buildBackgroundIcons(constraints),

                // ------------------------------------------------
                // BOTTOM WAVE
                // ------------------------------------------------
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 165,
                  child: _BottomWave(),
                ),

                // ------------------------------------------------
                // CENTER CONTENT
                // ------------------------------------------------
                Center(child: _buildContent(constraints)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==========================================================
  // CONTENT
  // ==========================================================

  Widget _buildContent(BoxConstraints constraints) {
    final double width = constraints.maxWidth;

    final double cartWidth = math.min(180, width * 0.48);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ======================================================
        // DOORSTEPP + TAGLINE
        // ======================================================
        FadeTransition(
          opacity: _brandOpacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'doorstepp',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: math.min(40, width * 0.105),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.8,
                  height: 1.0,
                  color: const Color(0xFF116A34),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Groceries delivered in minutes',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: math.min(15, width * 0.040),
                  fontWeight: FontWeight.w400,
                  color: const Color(0xff333333),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        // ======================================================
        // DIVIDER + BAG
        // ======================================================
        FadeTransition(opacity: _dividerOpacity, child: const _DividerBag()),

        const SizedBox(height: 24),

        // ======================================================
        // FOUR DOTS
        // ======================================================
        FadeTransition(
          opacity: _dotsOpacity,
          child: _FourDots(controller: _controller),
        ),

        const SizedBox(height: 25),

        // ======================================================
        // FINAL CART
        //
        // IMPORTANT:
        // It is NOT visible at the beginning.
        // It enters from the LEFT at the end.
        // ======================================================
        SlideTransition(
          position: _cartSlide,
          child: FadeTransition(
            opacity: _cartOpacity,
            child: ScaleTransition(
              scale: _cartScale,
              child: SizedBox(
                width: cartWidth,
                height: cartWidth * 0.82,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _CartLogoPainter(progress: _controller.value),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // BACKGROUND ICONS
  // ==========================================================

  Widget _buildBackgroundIcons(BoxConstraints constraints) {
    return IgnorePointer(
      child: Stack(
        children: [
          _BackgroundIcon(
            icon: Icons.apple_outlined,
            left: constraints.maxWidth * 0.11,
            top: constraints.maxHeight * 0.10,
            size: 25,
          ),

          _BackgroundIcon(
            icon: Icons.local_drink_outlined,
            left: constraints.maxWidth * 0.43,
            top: constraints.maxHeight * 0.07,
            size: 28,
          ),

          _BackgroundIcon(
            icon: Icons.eco_outlined,
            right: constraints.maxWidth * 0.12,
            top: constraints.maxHeight * 0.12,
            size: 25,
          ),

          _BackgroundIcon(
            icon: Icons.local_drink_outlined,
            left: constraints.maxWidth * 0.07,
            top: constraints.maxHeight * 0.25,
            size: 28,
          ),

          _BackgroundIcon(
            icon: Icons.receipt_long_outlined,
            right: constraints.maxWidth * 0.07,
            top: constraints.maxHeight * 0.27,
            size: 27,
          ),

          _BackgroundIcon(
            icon: Icons.eco_outlined,
            left: constraints.maxWidth * 0.12,
            top: constraints.maxHeight * 0.41,
            size: 24,
          ),

          _BackgroundIcon(
            icon: Icons.shopping_basket_outlined,
            right: constraints.maxWidth * 0.11,
            top: constraints.maxHeight * 0.43,
            size: 26,
          ),

          _BackgroundIcon(
            icon: Icons.apple_outlined,
            left: constraints.maxWidth * 0.43,
            top: constraints.maxHeight * 0.52,
            size: 24,
          ),
        ],
      ),
    );
  }
}

// ================================================================
// BACKGROUND ICON
// ================================================================

class _BackgroundIcon extends StatelessWidget {
  final IconData icon;
  final double? left;
  final double? right;
  final double top;
  final double size;

  const _BackgroundIcon({
    required this.icon,
    this.left,
    this.right,
    required this.top,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: Icon(icon, size: size, color: const Color(0xffDCEFE4)),
    );
  }
}

// ================================================================
// DIVIDER + BAG
// ================================================================

class _DividerBag extends StatelessWidget {
  const _DividerBag();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 72, height: 1.5, color: const Color(0xff71BE8D)),

        const SizedBox(width: 14),

        SizedBox(
          width: 26,
          height: 30,
          child: CustomPaint(painter: _MiniBagPainter()),
        ),

        const SizedBox(width: 14),

        Container(width: 72, height: 1.5, color: const Color(0xff71BE8D)),
      ],
    );
  }
}

// ================================================================
// FOUR DOTS
// ================================================================

class _FourDots extends StatelessWidget {
  final Animation<double> controller;

  const _FourDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return SizedBox(
          width: 58,
          height: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) {
              final double phase = (controller.value * 4 + index * 0.65) % 1.0;

              final double wave = math.sin(phase * math.pi * 2);

              final double scale = 0.75 + ((wave + 1) * 0.10);

              final double opacity = 0.45 + ((wave + 1) * 0.25);

              return Opacity(
                opacity: opacity.clamp(0.35, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xff21A65A),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ================================================================
// MINI BAG PAINTER
// ================================================================

class _MiniBagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xff21A65A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 9, 18, 17),
        const Radius.circular(2),
      ),
      paint,
    );

    final Path handle = Path();

    handle.moveTo(8, 10);

    handle.cubicTo(8, 2, 18, 2, 18, 10);

    canvas.drawPath(handle, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// ================================================================
// CART LOGO
// ================================================================

class _CartLogoPainter extends CustomPainter {
  final double progress;

  const _CartLogoPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const Color green = Color(0xFF168A43);
    const Color darkGreen = Color(0xFF116A34);

    final double scaleX = size.width / 180;

    final double scaleY = size.height / 148;

    canvas.save();

    canvas.scale(scaleX, scaleY);

    // ==========================================================
    // SPEED TRAIL
    //
    // Only appears during the final cart entrance.
    // ==========================================================

    final double trail = Curves.easeOutCubic.transform(
      ((progress - 0.68) / 0.32).clamp(0.0, 1.0),
    );

    final double trailOpacity = (1.0 - trail).clamp(0.0, 1.0);

    final Paint speedPaint = Paint()
      ..color = green.withOpacity(trailOpacity)
      ..style = PaintingStyle.fill;

    _drawSpeedLine(canvas, speedPaint, 0, 67, 48, 7);

    _drawSpeedLine(canvas, speedPaint, 5, 80, 55, 7);

    _drawSpeedLine(canvas, speedPaint, 14, 93, 43, 7);

    // Small dots behind cart.

    if (trailOpacity > 0) {
      canvas.drawCircle(const Offset(18, 54), 4, speedPaint);

      canvas.drawCircle(const Offset(30, 46), 3, speedPaint);
    }

    // ==========================================================
    // MAIN CART
    // ==========================================================

    final Paint greenPaint = Paint()
      ..color = green
      ..style = PaintingStyle.fill;

    // ----------------------------------------------------------
    // BAG BODY
    // ----------------------------------------------------------

    final RRect body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(48, 48, 88, 70),
      const Radius.circular(11),
    );

    canvas.drawRRect(body, greenPaint);

    // ----------------------------------------------------------
    // DARK TOP
    // ----------------------------------------------------------

    final Paint darkFill = Paint()
      ..color = darkGreen
      ..style = PaintingStyle.fill;

    final RRect top = RRect.fromRectAndRadius(
      const Rect.fromLTWH(55, 42, 74, 30),
      const Radius.circular(9),
    );

    canvas.drawRRect(top, darkFill);

    // ----------------------------------------------------------
    // HANDLE
    // ----------------------------------------------------------

    final Paint handlePaint = Paint()
      ..color = darkGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final Path handle = Path();

    handle.moveTo(74, 50);

    handle.cubicTo(74, 27, 110, 27, 110, 50);

    canvas.drawPath(handle, handlePaint);

    // ----------------------------------------------------------
    // HANDLE DOTS
    // ----------------------------------------------------------

    canvas.drawCircle(const Offset(74, 50), 5, greenPaint);

    canvas.drawCircle(const Offset(110, 50), 5, greenPaint);

    // ==========================================================
    // WHITE D
    // ==========================================================

    final Paint whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path d = Path();

    d.moveTo(70, 67);

    d.lineTo(70, 102);

    d.moveTo(70, 67);

    d.lineTo(84, 67);

    d.cubicTo(104, 67, 104, 102, 84, 102);

    d.lineTo(70, 102);

    canvas.drawPath(d, whitePaint);

    // ==========================================================
    // WHEELS
    // ==========================================================

    final Paint wheelPaint = Paint()
      ..color = darkGreen
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(64, 126), 8, wheelPaint);

    canvas.drawCircle(const Offset(118, 126), 8, wheelPaint);

    final Paint wheelCenter = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(64, 126), 3, wheelCenter);

    canvas.drawCircle(const Offset(118, 126), 3, wheelCenter);

    // ==========================================================
    // SHADOW
    // ==========================================================

    final Paint shadowPaint = Paint()
      ..color = const Color(0xffDDEDE4)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(91, 140), width: 105, height: 9),
      shadowPaint,
    );

    canvas.restore();
  }

  void _drawSpeedLine(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double width,
    double height,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, height),
        Radius.circular(height / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CartLogoPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ================================================================
// BOTTOM WAVE
// ================================================================

class _BottomWave extends StatelessWidget {
  const _BottomWave();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _BottomWavePainter());
  }
}

// ================================================================
// BOTTOM WAVE PAINTER
// ================================================================

class _BottomWavePainter extends CustomPainter {
  const _BottomWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // ==========================================================
    // LIGHT WAVE
    // ==========================================================

    final Paint lightPaint = Paint()
      ..color = const Color(0xffA9DDBE)
      ..style = PaintingStyle.fill;

    final Path lightPath = Path();

    lightPath.moveTo(0, size.height * 0.24);

    lightPath.cubicTo(
      size.width * 0.18,
      size.height * 0.02,
      size.width * 0.32,
      size.height * 0.10,
      size.width * 0.48,
      size.height * 0.34,
    );

    lightPath.cubicTo(
      size.width * 0.64,
      size.height * 0.54,
      size.width * 0.78,
      size.height * 0.12,
      size.width,
      size.height * 0.28,
    );

    lightPath.lineTo(size.width, size.height);

    lightPath.lineTo(0, size.height);

    lightPath.close();

    canvas.drawPath(lightPath, lightPaint);

    // ==========================================================
    // DARK GREEN WAVE
    // ==========================================================

    final Paint greenPaint = Paint()
      ..color = const Color(0xFF168A43)
      ..style = PaintingStyle.fill;

    final Path greenPath = Path();

    greenPath.moveTo(0, size.height * 0.47);

    greenPath.cubicTo(
      size.width * 0.17,
      size.height * 0.21,
      size.width * 0.32,
      size.height * 0.40,
      size.width * 0.48,
      size.height * 0.58,
    );

    greenPath.cubicTo(
      size.width * 0.65,
      size.height * 0.73,
      size.width * 0.79,
      size.height * 0.27,
      size.width,
      size.height * 0.43,
    );

    greenPath.lineTo(size.width, size.height);

    greenPath.lineTo(0, size.height);

    greenPath.close();

    canvas.drawPath(greenPath, greenPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
