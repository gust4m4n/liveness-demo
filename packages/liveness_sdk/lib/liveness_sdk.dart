/// Reusable face liveness detection module.
///
/// Drop the `packages/liveness_sdk` folder into any Flutter project and add it
/// as a path dependency, then call [FlutterNewLiveness.start].
library;

export 'package:camera/camera.dart' show XFile;

export 'src/config/liveness_config.dart';
export 'src/detection/liveness_camera_page.dart';
export 'src/expression/expression.dart';
export 'src/liveness_sdk.dart';
export 'src/models/liveness_result.dart';
export 'src/theme/liveness_theme.dart';
