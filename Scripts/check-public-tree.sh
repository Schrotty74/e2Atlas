#!/usr/bin/env bash
set -euo pipefail

# An allowlist is deliberate: .gitignore alone cannot protect files already tracked.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_root"
revision="${1:-HEAD}"
git rev-parse --verify "${revision}^{commit}" >/dev/null
list_file="$(mktemp "${TMPDIR:-.}/e2atlas-tree.XXXXXX")"
trap 'rm -f "$list_file"' EXIT
git ls-tree -r --name-only -z "$revision" > "$list_file"
failed=0
while IFS= read -r -d '' file; do
  case "$file" in
    Sources/*|Tests/*|Resources/*|Configuration/*|Scripts/*.sh|Scripts/generate-project.py|Scripts/git-hooks/pre-push|\
    e2Atlas.xcodeproj/project.pbxproj|e2Atlas.xcodeproj/xcshareddata/xcschemes/*.xcscheme|\
    e2Atlas.xcworkspace/contents.xcworkspacedata|\
    Package.swift|Package.resolved|.gitignore|README.md|README.de.md|SECURITY.md|SECURITY.de.md|CHANGELOG.md|LICENSE|LICENSE.*|NOTICE|THIRD-PARTY-NOTICES*|\
    build_app.sh|build_dev_app.sh|build_beta_app.sh|build_final_app.sh|\
    Documentation/Images/*.png|Documentation/Screenshots/full/*.png|Documentation/Screenshots/previews/*.png)
      case "$file" in
        */.DS_Store|*/xcuserdata/*|*.xcuserstate|*.log|*.dSYM/*)
          printf 'Generated or personal file cannot be published: %s\n' "$file" >&2; failed=1 ;;
      esac ;;
    *) printf 'File is outside the public app/build source set: %s\n' "$file" >&2; failed=1 ;;
  esac
done < "$list_file"
[[ "$failed" == 0 ]] || exit 1
echo 'Public source tree passed.'
