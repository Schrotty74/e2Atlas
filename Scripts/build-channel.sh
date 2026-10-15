#!/usr/bin/env bash
# Sourced by the build entry points. Compatible with macOS system Bash.

configure_channel() {
  case "$1" in
    dev)
      channel_name='Dev'
      app_name='e2Atlas Dev'
      bundle_id='io.github.schrotty74.e2atlas.dev'
      build_configuration='Debug'
      expected_branch='dev'
      ;;
    beta)
      channel_name='Beta'
      app_name='e2Atlas Beta'
      bundle_id='io.github.schrotty74.e2atlas.beta'
      build_configuration='Debug'
      expected_branch='beta'
      ;;
    final)
      channel_name='Final'
      app_name='e2Atlas'
      bundle_id='io.github.schrotty74.e2atlas'
      build_configuration='Release'
      expected_branch='main'
      ;;
    *) printf 'Unknown build channel: %s\n' "$1" >&2; return 64 ;;
  esac
}

require_channel_checkout() {
  local root="$1" channel="$2" actual_root actual_branch
  if ! actual_root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)"; then
    if [[ "$channel" == dev ]]; then return 0; fi
    echo 'Beta and Final require their own Git checkout.' >&2
    return 1
  fi
  if [[ "$(cd "$actual_root" && pwd -P)" != "$(cd "$root" && pwd -P)" ]]; then
    echo 'The project must be the Git repository root.' >&2
    return 1
  fi
  actual_branch="$(git -C "$root" branch --show-current)"
  if [[ "$actual_branch" != "$expected_branch" ]]; then
    printf 'Channel %s must be built on branch %s, not %s.\n' "$channel" "$expected_branch" "$actual_branch" >&2
    return 1
  fi
}
