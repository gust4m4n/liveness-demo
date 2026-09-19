import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

import '../config/liveness_config.dart';
import '../expression/expression.dart';
import '../models/liveness_result.dart';
import '../theme/liveness_theme.dart';
import 'liveness_painters.dart';
import 'liveness_video_processor.dart';

/// Full screen camera experience that walks the user through [expressions].
///
/// Pops with a [LivenessResult] on success and `null` on timeout or cancel.
class LivenessCameraPage extends StatefulWidget {
  const LivenessCameraPage({
    super.key,
    required this.expressions,
    this.config = const LivenessConfig(),
    this.theme = const LivenessTheme(),
  });

  final List<Expression> expressions;
  final LivenessConfig config;
  final LivenessTheme theme;

  @override
  State<LivenessCameraPage> createState() => _LivenessCameraPageState();
}

class _LivenessCameraPageState extends State<LivenessCameraPage> {
  late final List<Expression> _challenges;
  late final FaceDetector _faceDetector;

  CameraController? _cameraController;
  CameraDescription? _camera;

  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  bool _isRecording = false;
  bool _isCompleted = false;
  bool _isCameraDisposed = false;
  bool _isImageStreamActive = false;
  bool _isProcessing = false;
  bool _rawSensorPreview = false;
  bool _showInstruction = false;
  bool _loggedImageInfo = false;

  int _currentActionIndex = 0;
  int _blinkCount = 0;
  bool _previousEyesClosed = false;

  DateTime? _lastDetectionTime;
  Timer? _timeoutTimer;
  late int _remainingSeconds;

  Face? _detectedFace;
  Size? _imageSize;

  LivenessConfig get _config => widget.config;
  LivenessTheme get _theme => widget.theme;

  @override
  void initState() {
    super.initState();

    _challenges = List<Expression>.of(widget.expressions);
    if (_config.shuffleExpressions) {
      _challenges.shuffle();
    }

    _remainingSeconds = _config.timeout.inSeconds;
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableContours: true,
        enableClassification: true,
        minFaceSize: 0.15,
      ),
    );

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initializeCamera();
  }

  void _log(String message) {
    if (_config.enableLogging) {
      developer.log('[Liveness] $message');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (candidate) => candidate.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camera = camera;
      _log('Camera sensorOrientation: ${camera.sensorOrientation}');

      final controller = CameraController(
        camera,
        _config.cameraResolution,
        fps: _config.cameraStreamFps,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      _cameraController = controller;
    } catch (error) {
      _log('Camera initialization failed: $error');
      if (mounted) Navigator.pop(context);
      return;
    }

    await _startFaceDetection();
    setState(() => _isCameraInitialized = true);

    // The countdown starts only once the camera is ready so model loading does
    // not eat into the user's liveness window.
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _log('Detection timed out after ${_config.timeout.inSeconds}s');
        Navigator.pop(context);
      }
    });

    await Future<void>.delayed(_config.instructionDelay);
    if (mounted) setState(() => _showInstruction = true);
  }

  /// Binds image analysis and, when enabled, video capture in one shot so the
  /// whole session ends up in the recording.
  Future<void> _startFaceDetection() async {
    if (_isImageStreamActive) return;
    final controller = _cameraController;
    if (controller == null) return;

    if (_config.enableVideoRecording) {
      try {
        await controller.startVideoRecording(onAvailable: _onCameraImage);
        _isRecording = true;
        _isImageStreamActive = true;
        // Binding VideoCapture makes CameraX hand back the raw sensor frame:
        // landscape and no longer mirrored for the front lens.
        _rawSensorPreview =
            Platform.isAndroid &&
            _camera?.lensDirection == CameraLensDirection.front;
        _log('Session recording started');
        return;
      } catch (error) {
        _log('Could not start session recording: $error');
      }
    }

    await controller.startImageStream(_onCameraImage);
    _isImageStreamActive = true;
  }

  void _onCameraImage(CameraImage image) {
    if (_isCompleted || _isCameraDisposed || !mounted || _isDetecting) return;

    final now = DateTime.now();
    if (_lastDetectionTime != null &&
        now.difference(_lastDetectionTime!) < _config.detectionInterval) {
      return;
    }
    _lastDetectionTime = now;

    _isDetecting = true;
    _detectFaces(image).whenComplete(() => _isDetecting = false);
  }

  InputImageRotation _rotationFromSensor(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        _log('Unknown sensorOrientation: $sensorOrientation, using 270');
        return InputImageRotation.rotation270deg;
    }
  }

  Future<void> _detectFaces(CameraImage image) async {
    final camera = _camera;
    if (camera == null) return;

    try {
      final allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }

      final rotation = _rotationFromSensor(camera.sensorOrientation);
      if (!_loggedImageInfo) {
        _loggedImageInfo = true;
        _log(
          'Image ${image.width}x${image.height}, '
          'sensor ${camera.sensorOrientation}, rotation $rotation, '
          'format ${image.format.group}, planes ${image.planes.length}',
        );
      }

      final inputImage = InputImage.fromBytes(
        bytes: allBytes.done().buffer.asUint8List(),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: Platform.isAndroid
              ? InputImageFormat.nv21
              : InputImageFormat.bgra8888,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted || _isCompleted) return;

      if (faces.isEmpty) {
        if (_detectedFace != null) setState(() => _detectedFace = null);
        return;
      }

      final face = faces.first;
      // Only repaint for the overlay when it is actually visible.
      if (_config.showFaceLandmarks) {
        setState(() {
          _detectedFace = face;
          _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        });
      }
      await _checkChallenge(face);
    } catch (error) {
      _log('Error in face detection: $error');
    }
  }

  bool _isExpressionSatisfied(Expression expression, Face face) {
    switch (expression) {
      case Expression.smile:
        final probability = face.smilingProbability;
        return probability != null && probability > _config.smileThreshold;

      case Expression.eyeblink:
        final left = face.leftEyeOpenProbability;
        final right = face.rightEyeOpenProbability;
        final eyesClosed =
            left != null &&
            right != null &&
            left < _config.eyeClosedThreshold &&
            right < _config.eyeClosedThreshold;

        // Count only the open -> closed transition so a held blink is one blink.
        if (eyesClosed && !_previousEyesClosed) {
          _blinkCount++;
          _log('Blink detected, count: $_blinkCount');
        }
        _previousEyesClosed = eyesClosed;
        return _blinkCount >= _config.requiredBlinkCount;

      case Expression.leftPose:
      case Expression.rightPose:
        final yaw = face.headEulerAngleY;
        if (yaw == null) return false;
        // iOS reports the yaw sign inverted compared to Android.
        final normalizedYaw = Platform.isIOS ? -yaw : yaw;
        return expression == Expression.leftPose
            ? normalizedYaw > _config.headTurnAngleThreshold
            : normalizedYaw < -_config.headTurnAngleThreshold;
    }
  }

  Future<void> _checkChallenge(Face face) async {
    final expression = _challenges[_currentActionIndex];
    if (!_isExpressionSatisfied(expression, face)) return;

    _log('Completed "${expression.name}" (step ${_currentActionIndex + 1})');
    _currentActionIndex++;
    _blinkCount = 0;
    _previousEyesClosed = false;

    if (_currentActionIndex < _challenges.length) {
      setState(() {});
      return;
    }

    if (_isCompleted) return;
    _isCompleted = true;
    _timeoutTimer?.cancel();
    setState(() {
      _showInstruction = false;
      _isProcessing = _isRecording;
    });

    // Gives the muxer room to flush the last frames instead of truncating them.
    if (_isRecording) {
      await Future<void>.delayed(_config.videoTailDuration);
    }

    final recording = await _stopRecording();
    await _stopImageStream();
    await _disposeCamera();

    final video = recording == null ? null : await _exportVideo(recording);

    if (mounted) {
      Navigator.pop(context, LivenessResult(video: video));
    }
  }

  Future<XFile?> _stopRecording() async {
    if (!_isRecording) return null;
    try {
      final recording = await _cameraController?.stopVideoRecording();
      _isRecording = false;
      _isImageStreamActive = false;
      _log('Session recording stopped');
      return recording;
    } catch (error) {
      _isRecording = false;
      _log('Error stopping session recording: $error');
      return null;
    }
  }

  Future<XFile?> _exportVideo(XFile recording) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final destination = File('${appDocDir.path}/${_config.videoFileName}');
      if (await destination.exists()) {
        await destination.delete();
      }

      final processor = LivenessVideoProcessor(
        maxSize: _config.maxVideoSize,
        // Only the raw sensor feed still needs mirroring; AVFoundation already
        // mirrors the front camera track, so flipping again would invert it.
        mirror: _config.mirrorVideo && _rawSensorPreview,
        forcePortrait: _config.forcePortraitVideo,
        sensorOrientation: _camera?.sensorOrientation ?? 270,
        onLog: _log,
      );
      final exported = await processor.process(
        source: File(recording.path),
        destination: destination,
      );

      // Falls back to the untouched recording when FFmpeg could not transcode.
      if (exported.path != destination.path) {
        await exported.copy(destination.path);
      }

      final sizeKb = (await destination.length()) / 1024;
      _log(
        'Video saved: ${destination.path} (${sizeKb.toStringAsFixed(1)} KB)',
      );
      return XFile(destination.path);
    } catch (error) {
      _log('Error exporting verification video: $error');
      return null;
    }
  }

  Future<void> _stopImageStream() async {
    if (!_isImageStreamActive) return;
    try {
      await _cameraController?.stopImageStream();
      _isImageStreamActive = false;
      _log('Image stream stopped');
    } catch (error) {
      _log('Error stopping image stream: $error');
    }
  }

  /// Disposing before popping avoids a race between the route teardown and
  /// pending CameraX callbacks.
  Future<void> _disposeCamera() async {
    if (_isCameraDisposed) return;
    _isCameraDisposed = true;
    final controller = _cameraController;
    // Dropping the reference first keeps CameraPreview from rebuilding against
    // a disposed controller while the video is still being processed.
    if (mounted) {
      setState(() {
        _cameraController = null;
        _isCameraInitialized = false;
      });
    } else {
      _cameraController = null;
    }
    try {
      await controller?.dispose();
      _log('Camera disposed');
    } catch (error) {
      _log('Error disposing camera: $error');
    }
  }

  @override
  void dispose() {
    _isCompleted = true;
    _timeoutTimer?.cancel();

    if (!_isCameraDisposed) {
      _isCameraDisposed = true;
      final controller = _cameraController;
      if (controller != null) {
        final teardown = _isRecording
            ? controller.stopVideoRecording()
            : (_isImageStreamActive
                  ? controller.stopImageStream()
                  : Future<void>.value());
        teardown
            .catchError((Object error) => _log('Error stopping camera: $error'))
            .whenComplete(controller.dispose);
      }
    }

    _faceDetector.close().catchError(
      (Object error) => _log('Error closing face detector: $error'),
    );

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _theme.backgroundColor,
        body: _isCameraInitialized && controller != null
            ? Stack(
                children: [
                  Positioned.fill(child: _buildCameraPreview(controller)),
                  Positioned.fill(
                    child: CustomPaint(painter: HeadMaskPainter(theme: _theme)),
                  ),
                  if (_config.showFaceLandmarks &&
                      _detectedFace != null &&
                      _imageSize != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: FaceLandmarksPainter(
                          face: _detectedFace!,
                          imageSize: _imageSize!,
                          theme: _theme,
                        ),
                      ),
                    ),
                  Positioned(top: 60, right: 20, child: _buildTimer()),
                  if (_showInstruction &&
                      _currentActionIndex < _challenges.length)
                    Positioned(
                      bottom: 60,
                      left: 16,
                      right: 16,
                      child: _buildInstruction(),
                    ),
                  if (_isProcessing)
                    Positioned.fill(
                      child: ColoredBox(
                        color: _theme.backgroundColor.withValues(alpha: 0.85),
                        child: _buildLoading(_config.strings.processing),
                      ),
                    ),
                ],
              )
            : _buildLoading(
                _isProcessing
                    ? _config.strings.processing
                    : _config.strings.initializing,
              ),
      ),
    );
  }

  /// Undoes the raw sensor orientation CameraX falls back to while recording:
  /// rotate upright for the current device orientation, then mirror so it reads
  /// like a selfie.
  Widget _buildCameraPreview(CameraController controller) {
    return ValueListenableBuilder<CameraValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final quarterTurns = _previewQuarterTurns(value.deviceOrientation);

        Widget preview = CameraPreview(controller);
        if (quarterTurns != 0) {
          preview = RotatedBox(quarterTurns: quarterTurns, child: preview);
        }
        if (_rawSensorPreview) {
          preview = Transform.scale(scaleX: -1, child: preview);
        }

        final previewSize = value.previewSize;
        if (previewSize == null) return preview;

        final isQuarterTurned = quarterTurns.isOdd;
        var width = isQuarterTurned ? previewSize.height : previewSize.width;
        var height = isQuarterTurned ? previewSize.width : previewSize.height;
        // iOS reports previewSize in sensor (landscape) space, so normalise it
        // to the portrait-locked layout instead of stretching the texture.
        if (!isQuarterTurned && width > height) {
          final swap = width;
          width = height;
          height = swap;
        }

        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: width, height: height, child: preview),
        );
      },
    );
  }

  int _previewQuarterTurns(DeviceOrientation deviceOrientation) {
    if (!_rawSensorPreview) return 0;

    final deviceDegrees = switch (deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final sensorDegrees = _camera?.sensorOrientation ?? 270;

    return ((sensorDegrees + deviceDegrees) % 360) ~/ 90;
  }

  Widget _buildTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _theme.overlayColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _theme.primaryColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: _theme.onPrimaryColor, size: 16),
          const SizedBox(width: 6),
          Text(
            '${_remainingSeconds}s',
            style: TextStyle(
              color: _theme.onPrimaryColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruction() {
    final strings = _config.strings;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _theme.overlayColor,
        borderRadius: BorderRadius.circular(_theme.borderRadius),
      ),
      child: Column(
        children: [
          Text(
            strings.instructionOf(_challenges[_currentActionIndex]),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _theme.onPrimaryColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.stepOf(_currentActionIndex + 1, _challenges.length),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _theme.onPrimaryColor.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _theme.primaryColor),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              color: _theme.onPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
