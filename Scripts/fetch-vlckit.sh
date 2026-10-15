#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
dependency_dir="$root/Build/Dependencies"
archive="$dependency_dir/VLCKit-3.7.3.tar.xz"
framework="$dependency_dir/VLCKit - binary package/VLCKit.xcframework"
checksum='019afdae4e2e2d0f3ac325fac8f7ba0af25dca70b9d157df7d60db88e0be8e5d'
url='https://download.videolan.org/cocoapods/prod/VLCKit-3.7.3-319ed2c0-79128878.tar.xz'
if [[ -f "$dependency_dir/.vlckit-3.7.3-verified" && -f "$framework/Info.plist" && -f "$framework/macos-arm64_x86_64/VLCKit.framework/Versions/A/VLCKit" ]]; then exit 0; fi
mkdir -p "$dependency_dir"
if [[ ! -f "$archive" ]]; then
  /usr/bin/curl -fL --retry 2 "$url" -o "$archive.download"
  mv "$archive.download" "$archive"
fi
actual="$(/usr/bin/shasum -a 256 "$archive" | /usr/bin/awk '{print $1}')"
[[ "$actual" == "$checksum" ]] || { echo 'VLCKit checksum mismatch; the archive was not extracted.' >&2; exit 1; }
/usr/bin/tar -xf "$archive" -C "$dependency_dir"
[[ -f "$framework/Info.plist" ]] || { echo 'VLCKit framework is missing.' >&2; exit 1; }
/usr/bin/touch "$dependency_dir/.vlckit-3.7.3-verified"
