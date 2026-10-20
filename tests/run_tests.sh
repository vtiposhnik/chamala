#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_log=$(mktemp)
trap 'rm -f "$test_log"' EXIT

run_check() {
    # Godot can return zero after a runtime script error; don't accept that as a pass.
    if ! godot --headless --path "$project_root" "$@" >"$test_log" 2>&1; then
        cat "$test_log"
        return 1
    fi
    if rg -q 'SCRIPT ERROR|ERROR:|FAIL:' "$test_log"; then
        cat "$test_log"
        return 1
    fi
    rg 'RESULT:' "$test_log" || true
}

run_check --editor --import --quit
for suite in milestone_test combat_test iteration3_test iteration4_test iteration5_test; do
    run_check --fixed-fps 60 --script "res://tests/$suite.gd"
done
for fps in 30 144; do
    run_check --fixed-fps "$fps" --script res://tests/frame_clock_test.gd
done
