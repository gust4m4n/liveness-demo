# liveness_sdk

Self-contained face liveness detection module for Flutter (Android + iOS).

The user is asked to perform a randomized set of facial challenges (smile,
blink, look left, look right) in front of the selfie camera. Everything is
evaluated on-device with Google ML Kit — no network calls. The whole session is
recorded, and once every challenge passes the clip is rotated upright, mirrored,
downscaled and returned.

## Install in another project

1. Copy the whole `packages/liveness_sdk` folder into the target project.
2. Add the path dependency:

   ```yaml
   dependencies:
     liveness_sdk:
       path: packages/liveness_sdk
   ```

3. Add the native permissions and build settings.

`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>
<uses-feature android:name="android.hardware.camera.front" android:required="false"/>
```

`android/app/build.gradle.kts` — `minSdk = 24` and core library desugaring
enabled (required by `google_mlkit_face_detection`):

```kotlin
android {
    compileOptions { isCoreLibraryDesugaringEnabled = true }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

`ios/Runner/Info.plist` — iOS 15.5 or newer:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to verify that you are a live person</string>
```

The module bundles `camera`, `google_mlkit_face_detection`, `path_provider` and
`ffmpeg_kit_flutter_new_min_gpl`; they are pulled in transitively, nothing else
has to be declared.

## Usage

```dart
import 'package:liveness_sdk/liveness_sdk.dart';

final result = await const LivenessSdk().start(
  context: context,
  expressions: const [
    Expression.smile,
    Expression.eyeblink,
    Expression.leftPose,
    Expression.rightPose,
  ],
);

if (result != null) {
  // Verified. result.video holds the verification clip (may be null when
  // recording is disabled or failed).
}
```

`start` pushes a full screen `MaterialPageRoute` and resolves with:

- a `LivenessResult` when every expression was satisfied in time,
- `null` when the user backs out or the session times out.

It throws an `ArgumentError` when `expressions` is empty. Passing a subset is
fine — only the listed challenges are asked.

## Public API

| Symbol               | Role                                                      |
| -------------------- | --------------------------------------------------------- |
| `LivenessSdk`        | Facade; holds `config` + `theme` and exposes `start(...)` |
| `Expression`         | `smile`, `eyeblink`, `leftPose`, `rightPose`              |
| `LivenessResult`     | Session outcome; `video` is the recorded `XFile?`         |
| `LivenessConfig`     | Behaviour and thresholds (`copyWith` available)           |
| `LivenessStrings`    | User facing copy, for localization                        |
| `LivenessTheme`      | Colors and corner radius of the detection screen          |
| `LivenessCameraPage` | The detection screen, if you prefer to route it yourself  |

`XFile` is re-exported from `package:camera` so callers do not need a direct
dependency on it.

## Customization

Both hooks are optional and immutable, so a shared `const` instance can be
reused.

```dart
const LivenessSdk(
  theme: LivenessTheme(
    primaryColor: Color(0xFF056BC2),
    backgroundColor: Colors.black,
  ),
  config: LivenessConfig(
    timeout: Duration(seconds: 45),
    enableVideoRecording: false,
    maxVideoSize: Size(768, 1024),
    mirrorVideo: true,
    requiredBlinkCount: 3,
    strings: LivenessStrings(
      initializing: 'Menyiapkan kamera...',
      smile: 'tersenyum',
      eyeblink: 'berkedip',
      leftPose: 'menoleh ke kiri',
      rightPose: 'menoleh ke kanan',
    ),
  ),
)
```

### `LivenessConfig`

| Field                    | Default                 | Description                                                              |
| ------------------------ | ----------------------- | ------------------------------------------------------------------------ |
| `cameraResolution`       | `ResolutionPreset.high` | Preset handed to `CameraController`                                      |
| `cameraStreamFps`        | `30`                    | Requested capture frame rate                                             |
| `enableVideoRecording`   | `true`                  | Record the session; when false `LivenessResult.video` is null            |
| `videoTailDuration`      | `800ms`                 | Extra footage kept after the last expression so the muxer can flush      |
| `maxVideoSize`           | `768x1024`              | Bounding box of the exported clip; never upscales                        |
| `mirrorVideo`            | `true`                  | Mirror the clip to match the selfie preview                              |
| `forcePortraitVideo`     | `true`                  | Rotate upright when the camera returns a landscape track                 |
| `timeout`                | `32s`                   | Total time to complete every expression; starts once the camera is ready |
| `instructionDelay`       | `2s`                    | Grace period before the first prompt appears                             |
| `detectionInterval`      | `500ms`                 | Minimum spacing between two ML Kit inferences                            |
| `smileThreshold`         | `0.5`                   | Minimum smile probability                                                |
| `eyeClosedThreshold`     | `0.2`                   | Eye-open probability below which the eyes count as closed                |
| `requiredBlinkCount`     | `2`                     | Closed→open transitions needed for `eyeblink`                            |
| `headTurnAngleThreshold` | `10`                    | Minimum absolute head yaw (degrees) for left/right poses                 |
| `shuffleExpressions`     | `true`                  | Randomize the challenge order so it cannot be replayed                   |
| `showFaceLandmarks`      | `false`                 | Draw the raw ML Kit landmark/contour dots over the preview               |
| `videoFileName`          | `liveness_video.mp4`    | Name of the file written to the documents directory                      |
| `strings`                | `LivenessStrings()`     | User facing copy                                                         |
| `enableLogging`          | `kDebugMode`            | Emit diagnostics through `dart:developer`                                |

### `LivenessStrings`

`initializing`, `processing`, `smile`, `eyeblink`, `leftPose`, `rightPose`.
The prompt is composed as `instructionOf(expression)` (`Please smile`) and the
progress line as `stepOf(current, total)` (`Step 1 of 4`) — override those two
methods for languages with a different sentence structure.

### `LivenessTheme`

`primaryColor`, `onPrimaryColor`, `backgroundColor`, `scrimColor`,
`overlayColor`, `guideColor`, `landmarkColor`, `borderRadius`. Defaults follow a
blue `#056BC2` on white palette.

## How detection works

The front camera stream is throttled to `detectionInterval` and fed to ML Kit
with contours and classification enabled. Each expression has its own check:

- **smile** — `smilingProbability` above `smileThreshold`
- **eyeblink** — `requiredBlinkCount` closed→open transitions, where "closed"
  means both eye-open probabilities are below `eyeClosedThreshold`
- **leftPose / rightPose** — `headEulerAngleY` beyond `headTurnAngleThreshold`

Challenges are validated one at a time, in shuffled order, and the screen pops
with a result as soon as the last one passes.

## Video output

Recording starts as soon as the camera is ready and stops `videoTailDuration`
after the last expression, so the returned clip covers the entire session.
FFmpeg then rotates it upright when the camera hands back a landscape track
(`forcePortraitVideo`), mirrors it horizontally (`mirrorVideo`) and scales it
down to fit inside `maxVideoSize` while keeping the aspect ratio — recordings
already smaller than that box are left untouched. The result is re-encoded as
H.264 / yuv420p with `+faststart` and no audio track. If the transcode fails the
raw recording is returned instead.

## Layout

```
lib/
  liveness_sdk.dart                     public barrel
  src/
    liveness_sdk.dart                   LivenessSdk facade
    config/liveness_config.dart         LivenessConfig, LivenessStrings
    theme/liveness_theme.dart           LivenessTheme
    expression/expression.dart          Expression enum
    models/liveness_result.dart         LivenessResult
    detection/liveness_camera_page.dart detection screen
    detection/liveness_painters.dart    oval mask + landmark overlays
    detection/liveness_video_processor.dart mirror + downscale via FFmpeg
```

## Notes

- Requires a physical device; without a front camera the module falls back to
  the first available lens and the pose challenges will not pass.
- The screen locks to portrait while it is on top of the navigation stack.
- Saving the clip to the gallery is not part of this module — see the demo app
  in `lib/main.dart` for an example using `gal`.