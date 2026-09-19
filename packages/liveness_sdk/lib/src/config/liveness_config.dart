import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../expression/expression.dart';

/// User facing copy used by the liveness screen.
///
/// Override any field to localize the module without touching its source.
@immutable
class LivenessStrings {
  const LivenessStrings({
    this.initializing = 'Initializing...',
    this.processing = 'Processing...',
    this.smile = 'smile',
    this.eyeblink = 'blink',
    this.leftPose = 'look left',
    this.rightPose = 'look right',
  });

  final String initializing;
  final String processing;
  final String smile;
  final String eyeblink;
  final String leftPose;
  final String rightPose;

  String labelOf(Expression expression) {
    switch (expression) {
      case Expression.smile:
        return smile;
      case Expression.eyeblink:
        return eyeblink;
      case Expression.leftPose:
        return leftPose;
      case Expression.rightPose:
        return rightPose;
    }
  }

  /// Prompt rendered above the step counter, e.g. `Please smile`.
  String instructionOf(Expression expression) =>
      'Please ${labelOf(expression)}';

  /// Progress line rendered under the prompt.
  String stepOf(int current, int total) => 'Step $current of $total';
}

/// Tunable behaviour of the liveness detection flow.
@immutable
class LivenessConfig {
  const LivenessConfig({
    this.cameraResolution = ResolutionPreset.high,
    this.cameraStreamFps = 30,
    this.enableVideoRecording = true,
    this.videoTailDuration = const Duration(milliseconds: 800),
    this.maxVideoSize = const Size(768, 1024),
    this.mirrorVideo = true,
    this.forcePortraitVideo = true,
    this.timeout = const Duration(seconds: 32),
    this.instructionDelay = const Duration(seconds: 2),
    this.detectionInterval = const Duration(milliseconds: 500),
    this.smileThreshold = 0.5,
    this.eyeClosedThreshold = 0.2,
    this.requiredBlinkCount = 2,
    this.headTurnAngleThreshold = 10,
    this.shuffleExpressions = true,
    this.showFaceLandmarks = false,
    this.videoFileName = 'liveness_video.mp4',
    this.strings = const LivenessStrings(),
    this.enableLogging = kDebugMode,
  });

  final ResolutionPreset cameraResolution;
  final int cameraStreamFps;

  /// When false the flow resolves as soon as every expression is satisfied.
  ///
  /// When true the whole session is recorded, from the moment the camera is
  /// ready until the last expression is satisfied.
  final bool enableVideoRecording;

  /// Extra footage kept after the last expression so the muxer can flush the
  /// final frames instead of truncating them.
  final Duration videoTailDuration;

  /// Upper bound of the exported clip; the recording is scaled down to fit
  /// inside this box while keeping its aspect ratio, never upscaled.
  final Size maxVideoSize;

  /// Mirrors the exported clip so it matches the selfie preview.
  final bool mirrorVideo;

  /// Rotates the exported clip upright when the camera hands back a landscape
  /// track.
  final bool forcePortraitVideo;

  /// Total time the user has to complete every expression.
  final Duration timeout;

  /// Grace period before the first instruction appears.
  final Duration instructionDelay;

  /// Minimum spacing between two ML Kit inferences.
  final Duration detectionInterval;

  final double smileThreshold;
  final double eyeClosedThreshold;
  final int requiredBlinkCount;

  /// Minimum absolute head yaw (degrees) accepted for left/right poses.
  final double headTurnAngleThreshold;

  /// Randomizes the expression order so the challenge cannot be replayed.
  final bool shuffleExpressions;

  /// Draws the raw ML Kit landmark and contour dots over the preview.
  ///
  /// Useful while tuning thresholds; hidden by default so the user only sees
  /// the face guide.
  final bool showFaceLandmarks;

  /// File name used when copying the recording into the documents directory.
  final String videoFileName;

  final LivenessStrings strings;

  /// Emits diagnostic logs through `dart:developer`.
  final bool enableLogging;

  LivenessConfig copyWith({
    ResolutionPreset? cameraResolution,
    int? cameraStreamFps,
    bool? enableVideoRecording,
    Duration? videoTailDuration,
    Size? maxVideoSize,
    bool? mirrorVideo,
    bool? forcePortraitVideo,
    Duration? timeout,
    Duration? instructionDelay,
    Duration? detectionInterval,
    double? smileThreshold,
    double? eyeClosedThreshold,
    int? requiredBlinkCount,
    double? headTurnAngleThreshold,
    bool? shuffleExpressions,
    bool? showFaceLandmarks,
    String? videoFileName,
    LivenessStrings? strings,
    bool? enableLogging,
  }) {
    return LivenessConfig(
      cameraResolution: cameraResolution ?? this.cameraResolution,
      cameraStreamFps: cameraStreamFps ?? this.cameraStreamFps,
      enableVideoRecording: enableVideoRecording ?? this.enableVideoRecording,
      videoTailDuration: videoTailDuration ?? this.videoTailDuration,
      maxVideoSize: maxVideoSize ?? this.maxVideoSize,
      mirrorVideo: mirrorVideo ?? this.mirrorVideo,
      forcePortraitVideo: forcePortraitVideo ?? this.forcePortraitVideo,
      timeout: timeout ?? this.timeout,
      instructionDelay: instructionDelay ?? this.instructionDelay,
      detectionInterval: detectionInterval ?? this.detectionInterval,
      smileThreshold: smileThreshold ?? this.smileThreshold,
      eyeClosedThreshold: eyeClosedThreshold ?? this.eyeClosedThreshold,
      requiredBlinkCount: requiredBlinkCount ?? this.requiredBlinkCount,
      headTurnAngleThreshold:
          headTurnAngleThreshold ?? this.headTurnAngleThreshold,
      shuffleExpressions: shuffleExpressions ?? this.shuffleExpressions,
      showFaceLandmarks: showFaceLandmarks ?? this.showFaceLandmarks,
      videoFileName: videoFileName ?? this.videoFileName,
      strings: strings ?? this.strings,
      enableLogging: enableLogging ?? this.enableLogging,
    );
  }
}
