#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
if [[ "${E2ATLAS_LOG_ACTIVE:-}" != 1 ]]; then
  exec python3 "$root/Scripts/run-logged.py" Tests -- /bin/bash "$0" "$@"
fi
cd "$root"
"$root/Scripts/fetch-vlckit.sh"
xcrun xcodebuild -project e2Atlas.xcodeproj -scheme e2Atlas \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$root/Build/DerivedData/Tests" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= test "$@"
