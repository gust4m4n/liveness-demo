import 'package:flutter/material.dart';

/// Visual styling for the liveness detection screen.
///
/// Defaults follow the app icon palette (blue `#056BC2` on white).
@immutable
class LivenessTheme {
  const LivenessTheme({
    this.primaryColor = const Color(0xFF056BC2),
    this.onPrimaryColor = Colors.white,
    this.backgroundColor = Colors.black,
    this.scrimColor = const Color(0x8C000000),
    this.overlayColor = const Color(0xB3000000),
    this.guideColor = const Color(0xFF056BC2),
    this.landmarkColor = const Color(0xFF56A9F0),
    this.borderRadius = 16,
  });

  /// Accent color used for the face guide, timer and progress indicator.
  final Color primaryColor;

  /// Foreground color drawn on top of [primaryColor] surfaces.
  final Color onPrimaryColor;

  /// Screen background shown behind the camera preview.
  final Color backgroundColor;

  /// Dim layer covering everything outside the face oval.
  final Color scrimColor;

  /// Background of the instruction and timer panels.
  final Color overlayColor;

  /// Color of the oval outline ticks surrounding the face.
  final Color guideColor;

  /// Color of the detected face landmark/contour dots.
  final Color landmarkColor;

  /// Corner radius used by the overlay panels.
  final double borderRadius;

  LivenessTheme copyWith({
    Color? primaryColor,
    Color? onPrimaryColor,
    Color? backgroundColor,
    Color? scrimColor,
    Color? overlayColor,
    Color? guideColor,
    Color? landmarkColor,
    double? borderRadius,
  }) {
    return LivenessTheme(
      primaryColor: primaryColor ?? this.primaryColor,
      onPrimaryColor: onPrimaryColor ?? this.onPrimaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      scrimColor: scrimColor ?? this.scrimColor,
      overlayColor: overlayColor ?? this.overlayColor,
      guideColor: guideColor ?? this.guideColor,
      landmarkColor: landmarkColor ?? this.landmarkColor,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}
