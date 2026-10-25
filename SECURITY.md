# Security policy

[Deutsch](SECURITY.de.md)

## Supported versions

| Version | Status |
| --- | --- |
| 0.5.0-beta | Current beta; security reports welcome |
| Stable release | Not released yet |

## Security model

e2Atlas is a macOS client for user-configured Enigma2 receivers. It reads channel lists, program data, channel logos and TV streams through OpenWebif and the receiver's streaming service. It can schedule and manage supported receiver recording timers, configure EPGRefresh and supported AutoTimer rules, and record the receiver's MPEG-TS stream to a user-selected local file. It does not provide receiver system administration. The app does not install an elevated helper or add telemetry, analytics or a cloud account service.

Receiver passwords are stored in the macOS Keychain. Successfully read passwords also remain in process memory for the app session. Receiver names, addresses, usernames and display preferences are stored locally in Application Support. JSON settings backups can contain receiver addresses and usernames, but exclude passwords. Dev, Beta and Final use separate bundle identifiers and storage namespaces.

The OpenWebif API client uses an ephemeral URLSession without persistent cookies or a disk cache. It supplies HTTP Basic credentials only for a challenge from the configured origin and rejects cross-origin redirects. API HTTPS requests use macOS's default certificate validation. Media playback uses VLCKit or AVFoundation, with their own network and decoding behavior; the API client's redirect checks do not cover those engines.

## Network and playback boundaries

Use the receiver on a trusted local network or through a trusted VPN. HTTP is supported for receiver compatibility and does not encrypt credentials or media. Configuring HTTPS for OpenWebif does not by itself secure a separate streaming endpoint.

Receiver responses, program text, logos and media are external input. Failures should remain confined to the affected operation or stream, and credentials must not be embedded in URLs or exposed through error messages. Swift modules and separate playback slots are not process-level security boundaries: a media decoder failure can affect the app process.

VLCKit 3.7.3 is downloaded from VideoLAN with a pinned SHA-256 checksum and included as a replaceable dynamic framework. The checksum verifies the selected package; reports about dependency vulnerabilities are still relevant.

## Reporting a vulnerability

Please contact [Schrotty74](https://github.com/Schrotty74) privately before sharing vulnerability details. If you have no private contact route, open an issue asking for one without including the vulnerability details.

Include the e2Atlas and macOS versions, the affected component, reproduction steps, the expected result and the impact. Share sanitized logs or screenshots only. Remove passwords, authorization headers, receiver addresses, personal filenames and device identifiers.

Relevant reports include credential disclosure, unintended network access, redirect or authentication failures, unsafe handling of receiver data or media, local storage exposure, and tampering with dependencies or release packages. Feature requests and ordinary playback compatibility issues can be reported in public issues, provided they contain no private data.

## Known limitations

Published beta packages are ad-hoc signed and are not notarized with Apple Developer ID. Gatekeeper may require first-launch approval. Repeated Keychain permission prompts after rebuilding are still under investigation. This policy does not certify the app or its dependencies as free of vulnerabilities.
