import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Renders an emoji string onto a canvas and returns it as a
/// [BitmapDescriptor] suitable for Google Maps markers.
///
/// [emoji]   – the emoji character(s) to draw, e.g. '🛵' or '🏠'
/// [size]    – canvas size in logical pixels (default 80)
/// [scale]   – device pixel ratio multiplier (default 2.5 for crisp retina)
Future<BitmapDescriptor> emojiMarker(
  String emoji, {
  double size = 80,
  double scale = 2.5,
}) async {
  final int px = (size * scale).round();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final textPainter = TextPainter(textDirection: TextDirection.ltr)
    ..text = TextSpan(
      text: emoji,
      style: TextStyle(fontSize: size * 0.72),
    )
    ..layout();

  // Centre the emoji on the canvas.
  final double dx = (size - textPainter.width) / 2;
  final double dy = (size - textPainter.height) / 2;
  textPainter.paint(canvas, Offset(dx, dy));

  final picture = recorder.endRecording();
  final img = await picture.toImage(px, px);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

  return BitmapDescriptor.bytes(
    byteData!.buffer.asUint8List(),
    width: size,
    height: size,
  );
}
