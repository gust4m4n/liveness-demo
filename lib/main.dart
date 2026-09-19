import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:liveness_sdk/liveness_sdk.dart';
import 'package:video_player/video_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const LivenessDemoApp());
}

/// Palette sampled from `assets/icon/app_icon.png`.
abstract final class BrandColors {
  static const Color primary = Color(0xFF056BC2);
  static const Color primaryDark = Color(0xFF043873);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFF5B7893);
}

const LivenessTheme _livenessTheme = LivenessTheme(
  primaryColor: BrandColors.primary,
  onPrimaryColor: BrandColors.onPrimary,
  guideColor: BrandColors.primary,
  landmarkColor: BrandColors.primary,
);

class LivenessDemoApp extends StatelessWidget {
  const LivenessDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liveness Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: BrandColors.surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: BrandColors.primary,
          primary: BrandColors.primary,
          onPrimary: BrandColors.onPrimary,
          surface: BrandColors.surface,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: BrandColors.primary,
            foregroundColor: BrandColors.onPrimary,
            disabledBackgroundColor: BrandColors.primary.withValues(alpha: 0.4),
            disabledForegroundColor: BrandColors.onPrimary,
            elevation: 0,
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: BrandColors.primary,
            minimumSize: const Size.fromHeight(48),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: BrandColors.primaryDark,
          contentTextStyle: TextStyle(color: BrandColors.onPrimary),
        ),
      ),
      home: const LivenessDemoPage(),
    );
  }
}

class LivenessDemoPage extends StatefulWidget {
  const LivenessDemoPage({super.key});

  @override
  State<LivenessDemoPage> createState() => _LivenessDemoPageState();
}

class _LivenessDemoPageState extends State<LivenessDemoPage> {
  static const List<Expression> _expressions = [
    Expression.smile,
    Expression.eyeblink,
    Expression.leftPose,
    Expression.rightPose,
  ];

  bool _running = false;

  Future<void> _startDemo() async {
    if (_running) return;
    setState(() => _running = true);

    LivenessResult? result;
    try {
      result = await const LivenessSdk(
        theme: _livenessTheme,
      ).start(context: context, expressions: _expressions);
    } finally {
      if (mounted) setState(() => _running = false);
    }

    if (!mounted) return;

    if (result != null) {
      await _showSuccessDialog(result.video);
    } else {
      _showFailureMessage();
    }
  }

  Future<void> _showSuccessDialog(XFile? video) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: BrandColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: BrandColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 44,
                  color: BrandColors.onPrimary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Liveness Verified',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: BrandColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'All liveness challenges were completed successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: BrandColors.muted),
              ),
              const SizedBox(height: 20),
              if (video != null)
                LivenessVideoPreview(video: video)
              else
                const Text(
                  'No verification clip was recorded for this session.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: BrandColors.muted),
                ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  void _showFailureMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Liveness demo was cancelled or timed out.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 120,
                        height: 120,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Liveness Demo',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: BrandColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Follow the on-screen prompts: smile, blink, look left, '
                      'then look right.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: BrandColors.muted),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _running ? null : _startDemo,
                        child: Text(
                          _running ? 'Running...' : 'Start Liveness Demo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Loops the recorded liveness clip and exports it to the device gallery.
class LivenessVideoPreview extends StatefulWidget {
  const LivenessVideoPreview({super.key, required this.video});

  final XFile video;

  @override
  State<LivenessVideoPreview> createState() => _LivenessVideoPreviewState();
}

class _LivenessVideoPreviewState extends State<LivenessVideoPreview> {
  static const String _album = 'Liveness Demo';

  VideoPlayerController? _controller;
  String? _previewError;
  bool _saving = true;
  bool _saved = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _saveToGallery();
  }

  Future<void> _initializePlayer() async {
    final file = File(widget.video.path);
    if (!file.existsSync()) {
      setState(() => _previewError = 'Recording file was not found.');
      return;
    }

    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
    } catch (error) {
      await controller.dispose();
      debugPrint('Liveness video preview failed: $error');
      if (mounted) {
        setState(
          () => _previewError = 'Preview is unavailable on this device.',
        );
      }
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() => _controller = controller);
    await controller.play();
  }

  Future<void> _saveToGallery() async {
    String message;
    bool saved = false;
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putVideo(widget.video.path, album: _album);
      saved = true;
      message = 'Saved to your gallery ($_album).';
    } on GalException catch (error) {
      message = switch (error.type) {
        GalExceptionType.accessDenied => 'Gallery permission was denied.',
        GalExceptionType.notEnoughSpace => 'Not enough storage space.',
        GalExceptionType.notSupportedFormat => 'Video format is not supported.',
        GalExceptionType.unexpected => 'Could not save the video.',
      };
    } catch (_) {
      message = 'Could not save the video.';
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = saved;
      _message = message;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildPreview() {
    final error = _previewError;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: BrandColors.onPrimary),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: BrandColors.onPrimary),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: BrandColors.primaryDark,
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: _buildPreview(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_saving)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BrandColors.muted,
                ),
              )
            else
              Icon(
                _saved ? Icons.check_circle_rounded : Icons.error_outline,
                size: 16,
                color: _saved ? BrandColors.primary : BrandColors.muted,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _message ?? 'Saving to gallery...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: BrandColors.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
