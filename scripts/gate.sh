#!/usr/bin/env bash
# gate.sh [lint|lua|python|all|release] [run-all.sh options]: the one gate. Agents and CI both run it.
# lua runs Tools/regression/run-all.sh; with no options that is --affected against the base, and CI passes --shard I/N.
# python runs the Python suite with the venv interpreter. all (the default) runs the three groups.
# release is all with every Lua test file and LUA cleared: run it on the exact commit before pushing a v* tag. A pass ends "gate passed (release) at <commit>".
# Environment: GATE_BASE is the base ref (default origin/staging, CI passes HEAD^1); KSTYLEUI_PYTHON is the interpreter.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

group=${1:-all}
label=$group
[ $# -gt 0 ] && shift
base=${GATE_BASE:-origin/staging}
source Tools/regression/run-all.sh
pick_python || exit 2

case "$group" in
lint | lua | python | all) ;;
release)
	group=all
	set --
	export KSTYLEUI_FULL=1
	unset LUA
	;;
*)
	echo "usage: scripts/gate.sh [lint|lua|python|all|release] [run-all.sh options]" >&2
	exit 2
	;;
esac

failed=()

step() {
	local name=$1
	shift
	echo "== gate: $name"
	if "$@"; then
		return 0
	fi
	echo "== gate: $name FAILED" >&2
	failed+=("$name")
}

if [ "$group" = lint ] || [ "$group" = all ]; then
	step "crlf --check" "${py[@]}" Tools/dev/crlf.py --check
	step "pre-commit" env -u SKIP pre-commit run --all-files --show-diff-on-failure
	step "strings.py check" "${py[@]}" Tools/locale/strings.py check
	step "check-suppressions against $base" env SUPPRESSION_BASELINES=Tools/regression/pixel_allow.tsv bash scripts/check-suppressions.sh "$base"
fi

if [ "$group" = lua ] || [ "$group" = all ]; then
	[ $# -eq 0 ] && [ "$label" != release ] && set -- --affected "$base"
	step "run-all.sh $*" bash Tools/regression/run-all.sh "$@"
fi

if [ "$group" = python ] || [ "$group" = all ]; then
	step "python suite" "${py[@]}" -m unittest discover -s Tools/tests
fi

if [ ${#failed[@]} -gt 0 ]; then
	echo "gate FAILED: ${failed[*]}" >&2
	exit 1
fi
if [ "$label" != release ]; then
	echo "gate passed ($group)"
elif [ -n "$(git status --porcelain)" ]; then
	echo "gate passed (release) with uncommitted changes: commit them and run again before tagging"
else
	echo "gate passed (release) at $(git rev-parse HEAD)"
fi
