#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd "$script_dir/.." && pwd -P)"
channel_checkout="$project_root/Local/Channels/Final"
if [[ -f "$channel_checkout/Scripts/build_app.sh" ]]; then
  # Build the reviewed channel source; never substitute the local Dev source.
  E2ATLAS_OUTPUT_DIRECTORY="${E2ATLAS_OUTPUT_DIRECTORY:-$project_root/Build/Final}" \
    APP_BUILD_CHANNEL=final "$channel_checkout/Scripts/build_app.sh" "$@"
else
  APP_BUILD_CHANNEL=final "$script_dir/build_app.sh" "$@"
fi
