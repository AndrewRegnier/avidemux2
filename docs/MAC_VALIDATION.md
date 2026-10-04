# macOS validation

Build and runtime results will be recorded here when the native application is
ready. The initial development machine is an Apple Silicon Mac with macOS 27.0
and full Xcode installed.

Required checks:

- Build the editor and enabled plugins with the native ARM64 toolchain.
- Package the app and disk image with their required runtime dependencies.
- Inspect every bundled Mach-O binary for an ARM64 slice.
- Verify app signing and check for unresolved external runtime libraries.
- Launch the packaged app and inspect the main window.
- Open a video, play and seek, set selection boundaries, and export a clip.
- Check Command-key menus, native file dialogs and operating-system file opening.
- Check both light and dark appearance.

No successful build or runtime result is claimed until it is observed.
