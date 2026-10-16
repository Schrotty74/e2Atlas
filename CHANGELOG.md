# Changelog

## 0.2.0-beta

### Added

- Receiver information with reported hardware and software details, confirmed tuner use and separately counted streams without a usable tuner assignment.
- Swap a small multiview picture with the main picture while preserving each player's audio and volume.
- Record the receiver's original stream to a local `.ts` file from the player or a multiview tile, stop the recording and reveal it in Finder.
- Ocean blue and cyan gradients, plus Ivory and Bronze themes with light and dark palettes.
- Create custom JSON themes from a template in Appearance settings, with automatic list refresh and optional background gradients.
- Homepage and GitHub links in the About tab.
- Mark receiver usernames and passwords as optional when the receiver allows unauthenticated access.

### Fixed

- Disallow authentication UI during automatic Keychain reads. If access is unavailable, try without a password while preserving saved credentials; protected receivers may reject that connection.
- Register the built app at its final output location for native Icon Composer resources.
- Exclude Xcode debug sidecars from distributed builds and remove local development paths from all own program binaries.

### Known limitations

- Total tuner occupancy may remain unknown when the receiver does not assign streams to tuners, including on FBC receivers.
- Receiver timer management is not included; recordings save the original stream locally.
- Keychain permission prompts after rebuilding remain under investigation. Protected receivers may require access to saved credentials.
- The beta is ad-hoc signed and not notarized. macOS may require first-launch approval; see the [Gatekeeper instructions](https://github.com/Schrotty74/e2Atlas/blob/beta/README.md#first-launch-gatekeeper).
- macOS 26 and further receiver images still need testing.
- Playback requests VideoToolbox when supported and can fall back to software decoding. Hardware use and CPU impact have not been measured.

### Validation

- 66 tests passed on macOS 27 with Xcode 27.
- Beta startup in demo mode, About version and links, theme selection and the recording control checked.
- Fresh checkout built successfully from a path with spaces.
- ZIP and DMG contents, app signatures, architecture and SHA-256 checksums verified; bundles checked for local home paths.

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
