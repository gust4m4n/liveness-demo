# Liveness Demo

A Flutter demo application (Android + iOS) that showcases on-device **face
liveness detection**. The app asks the user to perform a randomized set of
facial challenges in front of the selfie camera, records the session, and plays
the resulting verification clip back once every challenge passes.

Everything runs locally on the device — no backend, no network calls.

## What it does

1. The home screen offers a single **Start Liveness Demo** button.
2. A full-screen camera view opens and prompts the user, one step at a time, to:
   - smile
   - blink
   - look left
   - look right
3. Google ML Kit Face Detection analyzes the camera stream and validates each
   prompt (smile probability, eye-open probability for blink counting, head yaw
   angle for the poses).
4. The whole session is recorded. When all challenges pass, FFmpeg rotates the
   clip upright, mirrors it to match the selfie preview, and scales it down.
5. A success dialog plays the clip in a loop and saves it to the device gallery
   in a "Liveness Demo" album.

The session returns `null` — showing a "cancelled or timed out" message — if the
user backs out or the timer (32s by default) expires.

## Project layout

```
lib/
  main.dart                       demo app: home screen, result dialog, video preview
packages/
  liveness_sdk/                   reusable liveness module (see its own README)
android/ ios/                     platform projects
assets/icon/                      app icon / brand palette source
```

The detection logic lives entirely in `packages/liveness_sdk`, a self-contained
package that can be copied into any other Flutter project as a path dependency.
The root app is only a thin demo harness around it.

## The `liveness_sdk` package

```dart
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
  // Verified — result.video holds the recorded clip.
}
```

Behaviour is tuned through `LivenessConfig` (timeout, detection interval,
smile/eye/head-yaw thresholds, required blink count, challenge shuffling, video
recording and output size, localized strings) and appearance through
`LivenessTheme`. See [packages/liveness_sdk/README.md](packages/liveness_sdk/README.md)
for the full reference.

## Key dependencies

| Package                          | Purpose                                          |
| -------------------------------- | ------------------------------------------------ |
| `camera`                         | Camera preview, image stream and video recording |
| `google_mlkit_face_detection`    | On-device face landmark and classification       |
| `ffmpeg_kit_flutter_new_min_gpl` | Rotate, mirror and downscale the clip            |
| `path_provider`                  | Temporary/documents directory for the recording  |
| `video_player`                   | Playback of the verification clip                |
| `gal`                            | Saving the clip to the device gallery            |

## Requirements

- Flutter with Dart SDK `^3.8.1`
- Android `minSdk 24` with core library desugaring enabled
- iOS 15.5 or newer
- A physical device — the flow needs a real front-facing camera

Permissions already declared: `CAMERA` (plus legacy storage for gallery export)
on Android, and `NSCameraUsageDescription` / `NSPhotoLibraryAddUsageDescription`
on iOS.

## Running

```bash
flutter pub get
flutter run
```

To build release artifacts:

```bash
flutter build apk --release
flutter build ios --release
```
