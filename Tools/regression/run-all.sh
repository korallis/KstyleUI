#!/usr/bin/env bash
# run-all.sh: run every Tools/regression/test-*.lua with $LUA (default lua5.1) from the repository root.
# On the Mac: LUA=luajit bash Tools/regression/run-all.sh
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2
lua=${LUA:-lua5.1}
if ! command -v "$lua" >/dev/null 2>&1; then
	echo "$lua not found. Install Lua 5.1, or set LUA (on the Mac: LUA=luajit)."
	exit 2
fi

shopt -s nullglob
tests=(Tools/regression/test-*.lua)
if [ "${#tests[@]}" -eq 0 ]; then
	echo "no tests found in Tools/regression"
	exit 1
fi

passed=0
failed=0
for test in "${tests[@]}"; do
	name=$(basename "$test" .lua)
	if output=$("$lua" "$test" 2>&1); then
		passed=$((passed + 1))
	else
		failed=$((failed + 1))
		echo "FAIL $name"
		printf '%s\n' "$output" | tail -n 5
	fi
done

echo "passed $passed, failed $failed"
[ "$failed" -eq 0 ]
