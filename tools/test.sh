#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
subway_test_dir=$(mktemp -d "${TMPDIR:-/tmp}/subway-tests.XXXXXX")
trap 'rm -rf "$subway_test_dir"' EXIT
export XDG_DATA_HOME="$subway_test_dir/data"
export XDG_CONFIG_HOME="$subway_test_dir/config"
export XDG_CACHE_HOME="$subway_test_dir/cache"
export SUBWAY_TEST_MODE=1
subway_godot_bin="${GODOT_BIN:-godot}"
"$subway_godot_bin" --headless --editor --import --quit 2>&1 | tee "$subway_test_dir/import.log"
if grep -E 'SCRIPT ERROR|Parse Error' "$subway_test_dir/import.log"; then exit 1; fi
"$subway_godot_bin" --headless --path . --script tests/test_runner.gd 2>&1 | tee "$subway_test_dir/test.log"
if grep -E 'SCRIPT ERROR|ERROR:' "$subway_test_dir/test.log"; then exit 1; fi
