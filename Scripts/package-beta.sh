#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"
version="${1:-}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-(beta|bugfix)$ ]] || { echo 'Usage: Scripts/package-beta.sh X.Y.Z-beta or X.Y.Z-bugfix' >&2; exit 64; }
[[ "$(git branch --show-current)" == beta ]] || { echo 'Beta packaging requires the beta checkout.' >&2; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo 'Commit the reviewed source before packaging.' >&2; exit 1; }
[[ -z "$(git ls-files --others --exclude-standard)" ]] || { echo 'Untracked source files must be reviewed first.' >&2; exit 1; }
./Scripts/check-public-tree.sh HEAD
E2ATLAS_RELEASE_VERSION="$version" ./Scripts/build_beta_app.sh
app_directory="${E2ATLAS_OUTPUT_DIRECTORY:-$root/Build/Beta}"
case "$app_directory" in
  /*) ;;
  *) app_directory="$root/$app_directory" ;;
esac
app="$app_directory/e2Atlas Beta.app"
plist="$app/Contents/Info.plist"
[[ "$(plutil -extract CFBundleIdentifier raw -o - "$plist")" == 'io.github.schrotty74.e2atlas.beta' ]]
[[ "$(plutil -extract E2AtlasReleaseVersion raw -o - "$plist")" == "$version" ]]
[[ "$(plutil -extract CFBundleShortVersionString raw -o - "$plist")" == "${version%%-*}" ]]
[[ "$(plutil -extract E2AtlasBuildChannel raw -o - "$plist")" == beta ]]
[[ "$(lipo -archs "$app/Contents/MacOS/e2Atlas Beta")" == arm64 ]]
release_dir="dist/releases/beta/$version"
[[ ! -e "$release_dir" ]] || { echo 'Release output already exists; do not replace a prepared release.' >&2; exit 1; }
mkdir -p "$release_dir"
ditto "$app" "$release_dir/e2Atlas Beta.app"
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
done < <(find "$release_dir/e2Atlas Beta.app/Contents/MacOS" -type f -print0)
codesign --force --sign - --timestamp=none "$release_dir/e2Atlas Beta.app"
codesign --verify --deep --strict "$release_dir/e2Atlas Beta.app"
artifact="e2Atlas-Beta-$version-macos-arm64"
ditto -c -k --norsrc --keepParent "$release_dir/e2Atlas Beta.app" "$release_dir/$artifact.zip"
staging="$(mktemp -d "$root/Build/beta-dmg.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
ditto "$release_dir/e2Atlas Beta.app" "$staging/e2Atlas Beta.app"
applications_directory="$(xcrun swift -e 'import Foundation; if let url = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first { print(url.path) }')"
[[ -d "$applications_directory" ]] || { echo 'Applications directory is unavailable.' >&2; exit 1; }
ln -s "$applications_directory" "$staging/Applications"
hdiutil create -volname "e2Atlas Beta $version" -srcfolder "$staging" -format UDZO "$release_dir/$artifact.dmg" > /dev/null
(
  cd "$release_dir"
  shasum -a 256 "$artifact.zip" "$artifact.dmg" > SHA256SUMS
  shasum -a 256 -c SHA256SUMS
)
printf '%s\n' "$release_dir/$artifact.zip" "$release_dir/$artifact.dmg" "$release_dir/SHA256SUMS"
