# Changelog

## 0.1.0-beta.1

### Added

- Native SwiftUI app for Apple Silicon Macs running macOS 26 or later.
- Welcome setup for up to three Enigma2 receivers, with passwords stored in the macOS Keychain.
- OpenWebif connection, bouquets, channel search and receiver-provided channel logos.
- Live TV and multiview with up to four streams and one active audio source.
- Mute controls and a shared volume slider. Volume and mute state survive channel changes.
- Video-only fullscreen with Escape and double-click to return to the app.
- Program guide with 2-, 4- and 6-hour windows, a 20:15 shortcut and custom time shortcuts.
- Automatic, light and dark appearance, System and Ocean themes, and an Icon Composer app icon.
- Separate Dev, Beta and Final build scripts, with verified VLCKit 3.7.3 downloads.

### Fixed

- Hide the loading indicator once a stream has displayed its first video frame.
- Keep VLC video output attached when entering or leaving fullscreen.

### Known limitations

- Recording and timer management are not included.
- This beta is ad-hoc signed and is not notarized. macOS may require approval before first launch.
- Keychain permission prompts after rebuilding remain under investigation.
- Automated tests and native playback checks ran on macOS 27. Compatibility with macOS 26 and different receiver images still needs testing.
