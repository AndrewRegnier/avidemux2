# macOS validation

## Development build

Observed on October 4, 2026 on an Apple Silicon Mac running macOS 27.0,
using Xcode and Qt 6.11.2. The upstream baseline is `54010b3`; the fork uses
the 2.8.2 development engine and its bundled FFmpeg 9.0.1.

- The native editor, command-line executable and enabled plugins compiled.
- The packaged app contains 282 Mach-O files with ARM64 support. Recursive
  checks passed for dependency resolution inside the bundle and ad-hoc signing.
- The local bundle declares macOS 27.0. A Homebrew dependency requires 27.0,
  so this local package must not be advertised as compatible with macOS 14.
- The app launched and rendered a 640×360 H.264 video with AAC audio.
- A fresh configuration selected MP4 Muxer. File → Save displayed the native
  macOS save panel with an `.mp4` filename. The resulting stream-copy MP4 was
  readable by AVFoundation, with one video track, one audio track and duration
  2.0667 seconds.
- The `ffVTEncH264` VideoToolbox encoder produced a distinct H.264/AAC MP4,
  readable by AVFoundation with duration 2.0 seconds.
- Command-comma opened Preferences. The native application menu exposed About,
  Preferences and Quit; selecting Quit closed the app. The Window menu exposed
  Minimize, Zoom and Bring All to Front, and Help exposed Check for Updates.
- A small editor window showed the encoding inspector and selection controls
  without the earlier overlapping labels.
- The final preview prototype showed a centered empty prompt across the preview
  pane, rendered the loaded fixture and next frame without an OpenGL error,
  returned to frame zero with Home, and restored the empty prompt after closing
  the video. The renderer initializes before the empty page becomes active.
- Configuration migration checks covered recursive copying, symlinks, keeping
  the legacy directory intact, refusing to replace an existing fork directory,
  and creating a new configuration when no legacy directory exists.

## Portable CI baseline

GitHub Actions run [37226504338](https://github.com/AndrewRegnier/avidemux2/actions/runs/37226504338)
for `cca121e` completed successfully on macOS 14 ARM64. Compilation and packaging
took approximately ten minutes. The uploaded app ZIP was extracted locally;
all 282 Mach-O files passed ARM64, dependency and signing checks, and the highest
embedded minimum OS was 14.0, matching the app's declaration. The extracted app
launched on the development Mac and opened the H.264/AAC fixture through its
native Open panel; it detected 640×360 at 30 fps and one audio track. This
baseline precedes the final preview layout change.

## Remaining release checks

The final preview layout and its portable release package are still being
checked. CI verifies every bundled dependency against the declared deployment
target before uploading an app ZIP and disk image.

## Limits

The app is ad-hoc signed, not Developer ID signed or notarized. Runtime checks
cover the fixture and workflows above; they do not certify every codec,
filter, input format, macOS version or long editing session. Command-Q injected
through UI automation did not close the app, although the native Quit menu
worked and the action registers Qt's standard Quit shortcut. Physical keyboard
behavior requires confirmation.
