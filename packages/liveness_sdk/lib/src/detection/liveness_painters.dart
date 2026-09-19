import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../theme/liveness_theme.dart';

/// Dims the screen except for an oval cut-out and draws tick marks around it.
class HeadMaskPainter extends CustomPainter {
  const HeadMaskPainter({required this.theme});

  final LivenessTheme theme;

  static const int _tickCount = 48;
  static const double _tickGap = 6;
  static const double _shortTick = 6;
  static const double _longTick = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ovalWidth = size.width * 0.7;
    final ovalHeight = ovalWidth * 1.5;
    final ovalRect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    canvas.drawPath(
      Path()
        ..addRect(Offset.zero & size)
        ..addOval(ovalRect)
        ..fillType = PathFillType.evenOdd,
      Paint()
        ..color = theme.scrimColor
        ..style = PaintingStyle.fill,
    );

    final tickPaint = Paint()
      ..color = theme.guideColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final radiusX = ovalWidth / 2;
    final radiusY = ovalHeight / 2;

    for (var i = 0; i < _tickCount; i++) {
      final angleDegrees = i * 360 / _tickCount;
      final angle = angleDegrees * pi / 180;

      // Longer ticks mark each 45° increment so the oval reads as a target.
      final isCardinal = (angleDegrees % 45).abs() < 0.1;
      final tickLength = isCardinal ? _longTick : _shortTick;

      final x = center.dx + radiusX * cos(angle);
      final y = center.dy + radiusY * sin(angle);

      final normalX = cos(angle) / radiusX;
      final normalY = sin(angle) / radiusY;
      final normalLength = sqrt(normalX * normalX + normalY * normalY);
      final unitNormalX = normalX / normalLength;
      final unitNormalY = normalY / normalLength;

      canvas.drawLine(
        Offset(x + unitNormalX * _tickGap, y + unitNormalY * _tickGap),
        Offset(
          x + unitNormalX * (_tickGap + tickLength),
          y + unitNormalY * (_tickGap + tickLength),
        ),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HeadMaskPainter oldDelegate) =>
      oldDelegate.theme != theme;
}

/// Plots ML Kit landmarks and contours on top of the camera preview.
class FaceLandmarksPainter extends CustomPainter {
  const FaceLandmarksPainter({
    required this.face,
    required this.imageSize,
    required this.theme,
  });

  final Face face;
  final Size imageSize;
  final LivenessTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.landmarkColor
      ..style = PaintingStyle.fill;

    // The iOS camera plugin reports frame dimensions already rotated, while
    // Android delivers them swapped and mirrored for the front sensor.
    final xDivisor = Platform.isIOS ? imageSize.width : imageSize.height;
    final yDivisor = Platform.isIOS ? imageSize.height : imageSize.width;

    Offset transformPoint(Point<int> point) {
      final px = point.x.toDouble();
      final py = point.y.toDouble();
      final scaledX = px * size.width / xDivisor;
      final scaledY = py * size.height / yDivisor;
      return Platform.isIOS
          ? Offset(scaledX, scaledY)
          : Offset(size.width - scaledX, scaledY);
    }

    for (final landmark in face.landmarks.values) {
      final position = landmark?.position;
      if (position != null) {
        canvas.drawCircle(transformPoint(position), 3, paint);
      }
    }

    for (final contour in face.contours.values) {
      for (final point in contour?.points ?? const <Point<int>>[]) {
        canvas.drawCircle(transformPoint(point), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant FaceLandmarksPainter oldDelegate) =>
      oldDelegate.face != face ||
      oldDelegate.imageSize != imageSize ||
      oldDelegate.theme != theme;
}
