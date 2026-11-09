#!/usr/bin/env bash
# run-all.sh: run every Tools/regression/test-*.lua from the repository root under CI's interpreter, with a time and memory budget per file.
# The default needs no LUA: lua5.1, then ~/.local/bin/lua5.1, then luajit -joff. LUA=luajit is fast mode and does not predict CI.
# Tests run in parallel, JOBS at a time (default: the number of CPUs). run_all.py does the work; Tools/regression/README.md describes it.
here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
cd "$here/../.." || exit 2
exec python3 Tools/regression/run_all.py "$@"
