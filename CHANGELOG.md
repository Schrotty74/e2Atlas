# Changelog

## 0.3.0-beta

### Added

- German and English interfaces with a saved language choice. Views switch immediately; native macOS menus and dialogs use the choice after reopening.
- Receiver recording timers: schedule from the guide, list timers, edit supported single recordings and confirm deletion.
- Saved multiview layouts per receiver, including channels, audio source, volume and mute state.
- Independent playback recovery with up to three retries per picture and a cancel control.
- Search loaded programme titles and descriptions, show programme progress and other loaded broadcasts of the same title.
- Local recording folder and duration options, programme titles in filenames and a stop when disk space runs low.
- A sleep timer that stops playback while local recordings continue.
- An optional automatic startup connection under Settings → Receiver, enabled by default, with two retries for unreachable services.

### Fixed

- Start restored multiview streams in stages, with the selected audio source first; leave unchanged mute and volume settings intact during buffering.
- Avoid reconnect timeouts while VLC continues displaying new pictures.
- Reload failed receiver metadata after restoring layouts and refresh EPG even when channel IDs stay the same. Current-programme queries include saved channels outside the selected bouquet.
- Reload receiver data without stopping playback and identify web-interface errors separately from ongoing streams.
- Quit the application when the main window closes, including when auxiliary windows remain open.
- Preserve older settings files when the new language, layout and startup options are absent.

### Known limitations

- Timer editing supports ordinary single recordings; unknown or special timer types remain read-only. Actual timer execution, further receiver images and conflict handling need hardware validation.
- EPG search covers the loaded bouquet and time window.
- macOS 26, Keychain permission prompts after rebuilds, longer sessions, real network recovery and local recording during shutdown or low-space conditions remain open.
- Hardware decoding and CPU impact have not been measured. Total tuner occupancy may remain unknown without a receiver-provided stream assignment.
- Ad-hoc signed and not notarized; macOS may require first-launch approval.

### Validation

- ZIP contents and CRC, mounted DMG contents and signatures, arm64, version/build metadata and SHA-256 checksums verified. Both downloads contain the sanitized own executable.
- Beta 0.3.0-beta, build 3, built successfully. Signature, beta identity/channel, numeric version, arm64, macOS 26 minimum, both languages and absence of a debug sidecar verified.
- Own executable stripped and checked for private development paths; app signature renewed and verified. Runtime sources, resources and tests match the tested Dev source byte for byte.
- Dev user checks confirmed timer creation, stable playback, restored multiview audio, EPG loading, startup connection, the Receiver settings control and full quit from the main-window close button. These are not separate Beta hardware checks.
- 96 test functions passed across the initial run and targeted follow-ups on matching Dev sources. The initial run was stopped for a VLC teardown lock; the five outstanding functions then passed in isolated runs. No production change, additional test app or project copy was needed.

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

- Remove local development paths from the distributed binaries without changing the app version or features.
- Hide the loading indicator once a stream has displayed its first video frame.
- Keep VLC video output attached when entering or leaving fullscreen.

### Known limitations

- Recording and timer management are not included.
- This beta is ad-hoc signed and is not notarized. macOS may require approval before first launch.
- Keychain permission prompts after rebuilding remain under investigation.
- Automated tests and native playback checks ran on macOS 27. Compatibility with macOS 26 and different receiver images still needs testing.
