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
case-sensitive build filesystem. The build scripts and installer are being
updated together; the final command and artifact locations will be recorded
here after a successful build.

Local builds use ad-hoc signing. Apple Developer ID signing and notarization
require the maintainer's certificate and credentials; ad-hoc signing does not
provide notarization. Distribution must include the GPL license and access to
the corresponding source.

## Validation

The delivered bundle should be checked recursively for ARM64 Mach-O binaries,
bundled runtime libraries, valid signing, successful launch and video editing
smoke checks. Results and known limits are recorded in
[MAC_VALIDATION.md](MAC_VALIDATION.md).
