#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"
version="${1:-}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-beta\.[0-9]+$ ]] || { echo 'Usage: Scripts/package-beta.sh VERSION-beta.NUMBER' >&2; exit 64; }
[[ "$(git branch --show-current)" == beta ]] || { echo 'Beta packaging requires the beta checkout.' >&2; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo 'Commit the reviewed source before packaging.' >&2; exit 1; }
[[ -z "$(git ls-files --others --exclude-standard)" ]] || { echo 'Untracked source files must be reviewed first.' >&2; exit 1; }
./Scripts/check-public-tree.sh HEAD
E2ATLAS_RELEASE_VERSION="$version" ./build_beta_app.sh
app='Build/Beta/e2Atlas Beta.app'
plist="$app/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" == 'io.github.schrotty74.e2atlas.beta' ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :E2AtlasReleaseVersion' "$plist")" == "$version" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")" == "${version%-beta.*}" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :E2AtlasBuildChannel' "$plist")" == beta ]]
[[ "$(/usr/bin/lipo -archs "$app/Contents/MacOS/e2Atlas Beta")" == arm64 ]]
release_dir="dist/releases/beta/$version"
[[ ! -e "$release_dir" ]] || { echo 'Release output already exists; do not replace a prepared release.' >&2; exit 1; }
mkdir -p "$release_dir"
/usr/bin/ditto "$app" "$release_dir/e2Atlas Beta.app"
executable="$release_dir/e2Atlas Beta.app/Contents/MacOS/e2Atlas Beta"
/usr/bin/strip -S "$executable"
while IFS= read -r rpath; do
  case "$rpath" in
    /*) /usr/bin/install_name_tool -delete_rpath "$rpath" "$executable" ;;
  esac
done < <(/usr/bin/otool -l "$executable" | /usr/bin/awk '$1 == "cmd" { command = $2 } command == "LC_RPATH" && $1 == "path" { print $2 }')
if /usr/bin/strings "$executable" | /usr/bin/grep -E '/Users/|/Volumes/|/private/' > /dev/null; then
  echo 'Release binary contains a local development path.' >&2; exit 1
fi
/usr/bin/codesign --force --sign - --timestamp=none "$release_dir/e2Atlas Beta.app"
/usr/bin/codesign --verify --deep --strict "$release_dir/e2Atlas Beta.app"
artifact="e2Atlas-Beta-$version-macos-arm64"
/usr/bin/ditto -c -k --norsrc --keepParent "$release_dir/e2Atlas Beta.app" "$release_dir/$artifact.zip"
staging="$(mktemp -d "$root/Build/beta-dmg.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
/usr/bin/ditto "$release_dir/e2Atlas Beta.app" "$staging/e2Atlas Beta.app"
ln -s /Applications "$staging/Applications"
/usr/bin/hdiutil create -volname "e2Atlas Beta $version" -srcfolder "$staging" -format UDZO "$release_dir/$artifact.dmg" > /dev/null
(
  cd "$release_dir"
  /usr/bin/shasum -a 256 "$artifact.zip" "$artifact.dmg" > SHA256SUMS
  /usr/bin/shasum -a 256 -c SHA256SUMS
)
printf '%s\n' "$release_dir/$artifact.zip" "$release_dir/$artifact.dmg" "$release_dir/SHA256SUMS"
