#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"
version="${1:-}"
build_number="${2:-1}"
[[ "$build_number" =~ ^[1-9][0-9]*$ ]] || { echo "Final build number must be a positive integer." >&2; exit 64; }
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-final$ ]] || { echo 'Usage: Scripts/package-final.sh X.Y.Z-final [build-number]' >&2; exit 64; }
[[ "$(git branch --show-current)" == main ]] || { echo 'Final packaging requires the main checkout.' >&2; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo 'Commit the reviewed source before packaging.' >&2; exit 1; }
[[ -z "$(git ls-files --others --exclude-standard)" ]] || { echo 'Untracked source files must be reviewed first.' >&2; exit 1; }
./Scripts/check-public-tree.sh HEAD
E2ATLAS_RELEASE_VERSION="$version" E2ATLAS_BUILD_NUMBER="$build_number" ./Scripts/build_final_app.sh
app_directory="${E2ATLAS_OUTPUT_DIRECTORY:-$root/Build/Final}"
case "$app_directory" in
  /*) ;;
  *) app_directory="$root/$app_directory" ;;
esac
app="$app_directory/e2Atlas.app"
plist="$app/Contents/Info.plist"
[[ "$(plutil -extract CFBundleIdentifier raw -o - "$plist")" == 'io.github.schrotty74.e2atlas' ]]
[[ "$(plutil -extract E2AtlasReleaseVersion raw -o - "$plist")" == "$version" ]]
[[ "$(plutil -extract CFBundleVersion raw -o - "$plist")" == "$build_number" ]]
[[ "$(plutil -extract CFBundleShortVersionString raw -o - "$plist")" == "${version%%-*}" ]]
[[ "$(plutil -extract E2AtlasBuildChannel raw -o - "$plist")" == final ]]
[[ "$(lipo -archs "$app/Contents/MacOS/e2Atlas")" == arm64 ]]
release_dir="dist/releases/final/$version"
[[ ! -e "$release_dir" ]] || { echo 'Release output already exists; do not replace a prepared release.' >&2; exit 1; }
mkdir -p "$release_dir"
ditto "$app" "$release_dir/e2Atlas.app"
# Strip and inspect every own Mach-O image, including any future sidecars.
while IFS= read -r -d '' executable; do
  [[ "$(file -b "$executable")" == *Mach-O* ]] || continue
  strip -S "$executable"
  while IFS= read -r rpath; do
    case "$rpath" in
      /*) install_name_tool -delete_rpath "$rpath" "$executable" ;;
    esac
  done < <(otool -l "$executable" | awk '$1 == "cmd" { command = $2 } command == "LC_RPATH" && $1 == "path" { print $2 }')
  if strings "$executable" | grep -E '/Users/|/Volumes/|/private/' > /dev/null; then
    echo 'Release binary contains a local development path.' >&2; exit 1
  fi
done < <(find "$release_dir/e2Atlas.app/Contents/MacOS" -type f -print0)
codesign --force --sign - --timestamp=none "$release_dir/e2Atlas.app"
codesign --verify --deep --strict "$release_dir/e2Atlas.app"
artifact="e2Atlas-$version-macos-arm64"
ditto -c -k --norsrc --keepParent "$release_dir/e2Atlas.app" "$release_dir/$artifact.zip"
staging="$(mktemp -d "$root/Build/final-dmg.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
ditto "$release_dir/e2Atlas.app" "$staging/e2Atlas.app"
applications_directory="$(xcrun swift -e 'import Foundation; if let url = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first { print(url.path) }')"
[[ -d "$applications_directory" ]] || { echo 'Applications directory is unavailable.' >&2; exit 1; }
ln -s "$applications_directory" "$staging/Applications"
hdiutil create -volname "e2Atlas $version" -srcfolder "$staging" -format UDZO "$release_dir/$artifact.dmg" > /dev/null
(
  cd "$release_dir"
  shasum -a 256 "$artifact.zip" "$artifact.dmg" > SHA256SUMS
  shasum -a 256 -c SHA256SUMS
)
printf '%s\n' "$release_dir/$artifact.zip" "$release_dir/$artifact.dmg" "$release_dir/SHA256SUMS"
