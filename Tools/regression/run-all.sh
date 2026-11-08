#!/usr/bin/env bash
# run-all.sh: run every Tools/regression/test-*.lua with $LUA (default lua5.1) from the repository root.
# On the Mac: LUA=luajit bash Tools/regression/run-all.sh
# Tests run in parallel, JOBS at a time (default: the number of CPUs); each test is its own process and
# writes only to its own temporary paths. Results print in file order, as a serial run would.
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

jobs=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}
results=$(mktemp -d)
trap 'rm -rf "$results"' EXIT

printf '%s\n' "${tests[@]}" | xargs -P "$jobs" -I{} sh -c '
	name=$(basename "$1" .lua)
	if "$2" "$1" >"$3/$name.out" 2>&1; then
		echo pass >"$3/$name.status"
	else
		echo fail >"$3/$name.status"
	fi
' _ {} "$lua" "$results"

passed=0
failed=0
for test in "${tests[@]}"; do
	name=$(basename "$test" .lua)
	if [ "$(cat "$results/$name.status" 2>/dev/null)" = "pass" ]; then
		passed=$((passed + 1))
	else
		failed=$((failed + 1))
		echo "FAIL $name"
		tail -n 5 "$results/$name.out" 2>/dev/null
	fi
done

echo "passed $passed, failed $failed"
[ "$failed" -eq 0 ]
