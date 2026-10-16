# Changelog

## 0.2.0-beta — 2026-10-16

### Added

- Receiver information with reported hardware and software details. Confirmed tuner use and streams without a usable tuner assignment are shown separately; total tuner occupancy may remain unknown, including on FBC receivers.
- Swap a multiview picture with the main picture while keeping each player's audio and volume state.
- Record the original receiver stream to a local `.ts` file from the player or a small multiview tile. Stop the recording in the app and reveal the file in Finder.
- Ocean blue and cyan gradients, plus Ivory and Bronze themes with light and dark palettes and automatic appearance.
- Create a custom JSON theme from Appearance settings. The app supplies a template and guide, reloads the theme list while the settings pane is open, and supports optional diagonal background gradients.
- Homepage and GitHub links in the About tab.
- Label receiver usernames and passwords as optional when the receiver allows unauthenticated access.

### Changed

- Automatic Keychain reads disallow authentication UI. If access is unavailable, automatic connections try without a password while preserving saved credentials. Receivers that require authentication may reject that attempt.
- Refresh the native Icon Composer resources and register the built app at its final output location. Dev, Beta and Final continue to use separate settings and caches.

### Known limitations

- Receiver authentication can still require access to saved Keychain credentials. Keychain permission prompts after rebuilding remain under investigation.
- Recording captures the original stream to a local file. Receiver timer management is not included.
- The beta is ad-hoc signed and is not notarized. macOS may require approval before first launch.
- Automated tests and native playback checks ran on macOS 27. Compatibility with macOS 26 and different receiver images still needs testing.
- Playback requests VideoToolbox when supported, with software fallback available through the playback library. Actual hardware decoding and CPU impact have not been measured.

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
