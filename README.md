# e2Atlas

Native macOS player for Enigma2 receivers through OpenWebif. Requires an Apple Silicon Mac and macOS 26 or later.

## Build

Install Xcode 27 and select its command-line tools. Clone the `beta` branch, then run:

```sh
git clone --branch beta https://github.com/Schrotty74/e2Atlas.git
cd e2Atlas
./build_beta_app.sh
```

The app is written to `Build/Beta/e2Atlas Beta.app`. The build downloads the pinned VLCKit 3.7.3 package from VideoLAN and verifies its SHA-256 checksum. A local build uses ad-hoc signing by default.

Open `e2Atlas.xcodeproj` for development. The build scripts select the channel name and bundle identifier. `Scripts/generate-project.py` regenerates the Xcode project; `Scripts/test.sh` runs the tests through Xcode. The SwiftPM manifest also describes the modules, but the supported test runner is Xcode because of VLCKit runtime loading.

Dev builds stay local. Beta builds require a checkout on `beta`; Final builds require `main`. Build scripts never push or publish. `Scripts/package-beta.sh 0.1.0-beta.1` creates ZIP and DMG packages with checksums from a clean, committed Beta checkout.

## First launch

Enter the receiver address, username and password in the welcome window. OpenWebif and streaming must be accessible from the Mac. Up to three receivers can be saved. The Beta has its own settings and Keychain namespace, so Dev receiver profiles are not transferred automatically.

Choose a bouquet and channel to start playback. In multiview, choose the target image before selecting a channel. Click the active speaker control to mute it; click another image's speaker to change the audio source. The volume sliders control the active source.

Use the video-only button or Command–Shift–F for video-only fullscreen. Escape or a double-click returns to the app. The program guide offers 2-, 4- and 6-hour windows and configurable time shortcuts.

## Beta downloads

Download the first beta from [GitHub Releases](https://github.com/Schrotty74/e2Atlas/releases). The packages are ad-hoc signed and are not notarized. See [CHANGELOG.md](CHANGELOG.md) for known limitations.

## License

The app uses the repository's [GNU GPL v3 license](LICENSE). VLCKit is distributed as a replaceable dynamic framework under LGPL-2.1-or-later; its license and source links are included in `Resources` and in the app.
