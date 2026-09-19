import 'package:camera/camera.dart';

/// Outcome of a completed liveness session.
class LivenessResult {
  const LivenessResult({this.video});

  /// Verification clip recorded after every expression was satisfied.
  ///
  /// Null when `LivenessConfig.enableVideoRecording` is disabled or when the
  /// recording failed while the challenges themselves still succeeded.
  final XFile? video;
}
