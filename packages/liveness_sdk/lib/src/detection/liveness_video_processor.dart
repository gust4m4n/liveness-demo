import 'dart:io';
import 'dart:ui' show Size;

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/stream_information.dart';

/// Normalizes the raw camera recording before it leaves the SDK.
///
/// Rotates the clip upright, mirrors it so it matches what the user saw in the
/// selfie preview, and scales it down to fit inside [maxSize] without changing
/// its aspect ratio.
class LivenessVideoProcessor {
  const LivenessVideoProcessor({
    required this.maxSize,
    required this.mirror,
    required this.forcePortrait,
    required this.sensorOrientation,
    this.onLog,
  });

  final Size maxSize;
  final bool mirror;
  final bool forcePortrait;
  final int sensorOrientation;
  final void Function(String message)? onLog;

  /// Returns the processed file, or [source] when nothing had to be changed or
  /// the transcode failed.
  Future<File> process({
    required File source,
    required File destination,
  }) async {
    final filters = <String>[
      // CameraX can hand back a landscape track when VideoCapture is bound
      // alongside image analysis; matches the rotation applied to the preview.
      if (forcePortrait && await _isLandscape(source))
        sensorOrientation == 90 ? 'transpose=1' : 'transpose=2',
      if (mirror) 'hflip',
      // min(iw,w) keeps the filter from upscaling smaller recordings.
      "scale=w='min(iw,${maxSize.width.round()})'"
          ":h='min(ih,${maxSize.height.round()})'"
          ':force_original_aspect_ratio=decrease'
          ':force_divisible_by=2',
      'format=yuv420p',
    ];

    if (await destination.exists()) {
      await destination.delete();
    }

    final session = await FFmpegKit.executeWithArguments([
      '-hide_banner',
      '-y',
      '-i',
      source.path,
      '-vf',
      filters.join(','),
      '-c:v',
      'libx264',
      '-preset',
      'veryfast',
      '-crf',
      '26',
      '-an',
      '-movflags',
      '+faststart',
      destination.path,
    ]);

    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode) && await destination.exists()) {
      return destination;
    }

    onLog?.call(
      'FFmpeg failed (rc: $returnCode): ${await session.getFailStackTrace() ?? await session.getOutput()}',
    );
    return source;
  }

  /// Reports whether the clip is wider than tall once its rotation metadata is
  /// taken into account, which is what FFmpeg autorotate applies.
  Future<bool> _isLandscape(File source) async {
    try {
      final session = await FFprobeKit.getMediaInformation(source.path);
      final streams = session.getMediaInformation()?.getStreams() ?? const [];
      for (final stream in streams) {
        if (stream.getType() != 'video') continue;

        final width = stream.getWidth();
        final height = stream.getHeight();
        if (width == null || height == null) continue;

        final quarterTurned = _rotationOf(stream) % 180 != 0;
        final displayWidth = quarterTurned ? height : width;
        final displayHeight = quarterTurned ? width : height;
        onLog?.call('Recording is ${displayWidth}x$displayHeight');
        return displayWidth > displayHeight;
      }
    } catch (error) {
      onLog?.call('Could not probe recording: $error');
    }
    return false;
  }

  int _rotationOf(StreamInformation stream) {
    final properties = stream.getAllProperties();

    final sideData = properties?['side_data_list'];
    if (sideData is List) {
      for (final entry in sideData) {
        if (entry is Map && entry['rotation'] is num) {
          return (entry['rotation'] as num).round().abs() % 360;
        }
      }
    }

    final tag = properties?['tags'];
    if (tag is Map) {
      final rotate = int.tryParse('${tag['rotate']}');
      if (rotate != null) return rotate.abs() % 360;
    }

    return 0;
  }
}
