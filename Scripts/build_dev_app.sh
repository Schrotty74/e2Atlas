#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
APP_BUILD_CHANNEL=dev "$script_dir/build_app.sh" "$@"
