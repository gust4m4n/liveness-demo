import 'package:flutter/material.dart';

import 'config/liveness_config.dart';
import 'detection/liveness_camera_page.dart';
import 'expression/expression.dart';
import 'models/liveness_result.dart';
import 'theme/liveness_theme.dart';

/// Entry point of the liveness module.
///
/// ```dart
/// final result = await const LivenessSdk().start(
///   context: context,
///   expressions: const [Expression.smile, Expression.eyeblink],
/// );
/// ```
class LivenessSdk {
  const LivenessSdk({
    this.config = const LivenessConfig(),
    this.theme = const LivenessTheme(),
  });

  final LivenessConfig config;
  final LivenessTheme theme;

  /// Pushes the detection screen and waits for the user to finish.
  ///
  /// Returns a [LivenessResult] on success, or `null` when the user backs out
  /// or the session times out.
  ///
  /// Throws an [ArgumentError] when [expressions] is empty.
  Future<LivenessResult?> start({
    required BuildContext context,
    required List<Expression> expressions,
  }) {
    if (expressions.isEmpty) {
      throw ArgumentError.value(
        expressions,
        'expressions',
        'At least one expression is required.',
      );
    }

    return Navigator.of(context).push<LivenessResult>(
      MaterialPageRoute(
        builder: (_) => LivenessCameraPage(
          expressions: List<Expression>.unmodifiable(expressions),
          config: config,
          theme: theme,
        ),
      ),
    );
  }
}
