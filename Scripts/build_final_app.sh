#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd "$script_dir/.." && pwd -P)"
# Keep logs at the local entry point even when the channel checkout is older.
if [[ "${E2ATLAS_LOG_ACTIVE:-}" != 1 && "${1:-}" != --plan && "${1:-}" != --help ]]; then
  exec python3 "$project_root/Scripts/run-logged.py" "Final" -- /bin/bash "$0" "$@"
fi
channel_checkout="$project_root/Local/Channels/Final"
if [[ -f "$channel_checkout/Scripts/build_app.sh" ]]; then
  # Build the reviewed channel source; never substitute the local Dev source.
  E2ATLAS_OUTPUT_DIRECTORY="${E2ATLAS_OUTPUT_DIRECTORY:-$project_root/Build/Final}" \
    APP_BUILD_CHANNEL=final "$channel_checkout/Scripts/build_app.sh" "$@"
else
  APP_BUILD_CHANNEL=final "$script_dir/build_app.sh" "$@"
fi
