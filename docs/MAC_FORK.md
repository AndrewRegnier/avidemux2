# Avidemux Mac

Avidemux Mac is a macOS-focused fork of the GPL-licensed Avidemux editor.
The starting point is upstream commit `54010b3` (October 3, 2026), rather than
the older 2.8.1 downloadable release. Original authorship and license notices
remain in the source and application.

## Product scope

- A self-contained ARM64 application and disk image for Apple Silicon Macs.
- A familiar macOS editor window, with readable controls, a clear video preview,
  playback and selection controls, and an organized encoding inspector.
- Standard macOS menus, Command-key shortcuts, native file dialogs, Finder and
  Dock file opening, and system appearance support.
- Existing Avidemux editing, filters, codecs and stream-copy functionality.
- Repeatable build and packaging instructions, with architecture and launch
  checks for the distributed app.

The existing Qt 6 application is the foundation. Qt's macOS integration provides
native menus, window controls and dialogs while preserving the mature editor
and codec pipeline.

## Repository

Upstream: <https://github.com/mean00/avidemux2>

Fork: <https://github.com/AndrewRegnier/avidemux2>

The `upstream` remote tracks the original project. The `origin` remote points to
this fork. Development is on `mac-native`, reviewed against the fork's `master`.
Platform-specific UI changes should be guarded so upstream Linux and Windows
behavior remains available.

## Build and distribution

The macOS build requires Xcode, native ARM64 Homebrew dependencies and a
case-sensitive build filesystem. Clone the fork and its translations:

```sh
git clone --branch mac-native --recurse-submodules https://github.com/AndrewRegnier/avidemux2.git
cd avidemux2
brew install make cmake ninja yasm pkg-config bzip2 zlib sqlite \
  libogg libvorbis opus lame two-lame aom libvpx libass x264 x265 \
  qtbase qttools qttranslations faac faad2 xvid
```

Create a case-sensitive build volume if one is not already available. The
sparse image grows as build files are written:

```sh
mkdir -p buildlogs
hdiutil create -size 10g -type SPARSE -fs 'Case-sensitive APFS' \
  -volname AvidemuxBuild buildlogs/AvidemuxBuild.sparseimage
hdiutil attach buildlogs/AvidemuxBuild.sparseimage -mountpoint /Volumes/AvidemuxBuild
ADM_BUILD_ROOT=/Volumes/AvidemuxBuild bash scripts/macos_arm64_build.sh
```

The verified app and disk image are copied into `dist/`. Build logs are in
`buildlogs/macos-arm64`. For an incremental build, pass `--rebuild` to the script.
The app is named `Avidemux Mac.app`; drag it from the disk image into Applications.

The local build defaults to the host's macOS major version. A lower deployment
target can be requested with `ADM_MACOSX_DEPLOYMENT_TARGET`, but every bundled
dependency must support it. The verifier checks the declared minimum against
all bundled binaries and rejects dependencies outside the bundle.

The GitHub Actions workflow uses a macOS 14 ARM64 runner with a 14.0 deployment
target. Its app is archived with `ditto` before upload to preserve executable
permissions and symlinks. The successful workflow's artifacts contain the DMG
and app ZIP. The dependency scan determines whether that target is valid.

```sh
bash scripts/verify_macos_bundle.sh 'dist/Avidemux Mac.app'
```

Local builds use ad-hoc signing. Apple Developer ID signing and notarization
require the maintainer's certificate and credentials; ad-hoc signing does not
provide notarization. Distribution must include the GPL license and access to
the corresponding source.

## Settings and updates

The fork uses `~/Library/Application Support/Avidemux Mac/`. On first launch,
existing `~/.avidemux6/` data is copied through a staging directory and published
atomically. The original remains intact, and an existing fork configuration is
never replaced. If migration fails, the app falls back to the old directory.
Plugins built for an incompatible CPU are rejected by the plugin loader.

The Mac app follows the system appearance. Settings use Command-comma, and the
Window menu provides Minimize, Zoom and Bring All to Front. Help → Check for
Updates opens this fork's releases page.

## Validation

The delivered bundle should be checked recursively for ARM64 Mach-O binaries,
bundled runtime libraries, valid signing, successful launch and video editing
smoke checks. Results and known limits are recorded in
[MAC_VALIDATION.md](MAC_VALIDATION.md).
