# Changelog

## 0.5.0-beta

### Added

- Export and import settings through a Backup tab: receiver profiles, favourites, multiview layouts, language, appearance, startup connection, guide refresh options, time shortcuts and valid custom themes. Preview imports before applying them; keep existing profiles and entries, and add imported items within the existing limits.
- A compact Now and Next view with bouquet/favourites filters, channel search, current programme progress, upcoming programmes and links to guide details or live playback. It uses the existing EPG loading and refresh schedule.

### Fixed

- Retain Now and Next data across view and bouquet changes, and reuse valid weekly EPG from memory or disk. Advance listings at programme start/end times, fetching only channels without an upcoming programme. Keep existing data visible during refreshes and apply a bounded retry delay after empty responses or errors. Manual and scheduled refresh remain available.
- Keep all five main navigation tabs visible with readable labels by using the segmented picker’s natural width. Remove the fixed width that clipped the outer labels.
- Route bouquet changes through one explicit loading action shared by TV and the compact view, with cancellation when the receiver changes.

### Known limitations

- Backups contain receiver addresses and usernames. Passwords, reminders, playback positions, recordings, recording folder permissions and EPG caches are excluded. Newly imported profiles require passwords to be entered again when authentication is needed. Receiver schedules are unchanged.
- General settings are replaced on import; existing receivers, favourites, layouts and themes are kept. The resulting configuration must fit the existing limits. Missing selected themes fall back to System.
- Now and Next depends on loaded EPG data. Progress updates once per minute, with additional updates at programme boundaries. Missing successors can trigger a channel-specific request; empty results or failures retry after five minutes or at an earlier known boundary. The user confirmed view changes and channel-specific loading after programme ends; import on another Mac remains unconfirmed.

### Validation

- Published as a GitHub prerelease under v0.5.0-beta. All three uploaded asset sizes and SHA-256 digests match the verified ZIP, DMG and SHA256SUMS.

- 34 targeted tests in four suites passed in the Beta checkout on macOS 27 with Xcode 27. They cover settings archives, import merging and rollback, programme selection and boundaries, cache reuse, selective fetching and guide regressions. This was not a full test run.
- The user confirmed settings export, readable navigation labels, retained Now and Next data after view changes, and channel-specific loading after a programme ends on the matching Dev source. Import with a real user configuration and separate Beta receiver checks remain open.
- Beta 0.5.0-beta, build 5, built successfully. Beta identity/channel, numeric version, arm64, macOS 26 minimum, both languages and signatures passed. ZIP CRC/content, mounted DMG content/signature and SHA-256 checks passed. Runtime sources, tests and resources match Dev byte for byte.
- The first package attempt carried build number 2 because the copied project generator retained an older value. Those unpublished packages were discarded; the generator was corrected to 5 and the Beta rebuilt. No application logic changed. No separate Beta launch or receiver check was performed.

## 0.4.0-beta

### Added

- Scroll through seven days of programme listings with a date indicator, per-receiver caching and search across the loaded range. Configure listing refresh with a six-hour default, custom intervals and a start time.
- Configure receiver-side EPGRefresh schedules with a time window, bouquet selection and channel dwell time.
- Browse and play receiver recordings, save playback positions, view receiver storage, and filter planned timers, running timers and library files in one view.
- Manage supported AutoTimer rules with title, channel/bouquet, weekday, time-window, recording-margin and duplicate options. Preview matches against loaded EPG.
- Set local programme reminders, open programme details from notifications, and adjust reminders when fresh EPG identifies a shifted broadcast unambiguously.
- Mark reminders and planned/running recordings in the guide, save favourites per receiver, and offer alternative loaded broadcasts after timer conflicts.

### Fixed

- Keep guide scrolling responsive and reuse cached data without fetching again on each scroll or zoom change.
- Detect EPGRefresh through its correct endpoint and retry transient manual-refresh failures within one refresh action.
- Accept supported UTF-8 AutoTimer defaults and preserve OpenPLi description flags so supported rules remain editable and deletable.
- Keep the German Homepage label and prevent a handled reminder from reopening on a later reconnection.

### Known limitations

- EPG data depends on the receiver. EPGRefresh and AutoTimer require compatible installed plugins; AutoTimer periodic search must be enabled separately. Advanced rules and unsupported defaults remain protected. Preview uses loaded EPG and the Mac's time zone; plugin filters and duplicate handling can change the results.
- OpenWebif does not reliably mark recording files as completed, so files are labelled Library. Further hardware checks remain for resume positions, other storage paths, authenticated playback and real timer conflicts.
- Reminder changes require fresh EPG and an unambiguous match. Expired revised reminder times are removed. Notification delivery depends on macOS permissions, Focus and the Mac being on; notification-click navigation still needs a cold-start user check.
- macOS 26, additional receiver images, Keychain prompts after rebuilds, real network recovery and local recording during shutdown or low-space conditions remain open. CPU impact and hardware decoding are not measured; total tuner occupancy may remain unknown without receiver-provided assignments.
- Ad-hoc signed and not notarized; macOS may require first-launch approval.

### Validation

- Dev builds 45/46 and signatures passed. The latest targeted run passed 63 tests in seven suites covering preferences/favourites, programme matching, reminders, playback checkpoint models, OpenWebif responses and guide cache/fresh-data behavior. Earlier affected feature tests passed as documented in the project context.
- The user confirmed fast guide scrolling, EPGRefresh setup and subsequent EPG population, the supported AutoTimer workflow, reminder delivery with the app closed, and the new Dev feature set generally. Real conflicts and shifted EPG times remain unconfirmed; these are not separate Beta hardware tests.
- Beta 0.4.0-beta, build 4, built successfully. Signature, beta identity/channel, numeric version, arm64, macOS 26 minimum and both languages passed. The own executable was stripped, checked for private development paths and signed again. ZIP CRC/content, mounted DMG content/signature and SHA-256 checks passed. Runtime sources, tests and resources match the checked Dev source byte for byte.

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

- Published as a GitHub prerelease under v0.3.0-beta. All three uploaded asset digests match the prepared ZIP, DMG and SHA256SUMS.
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
