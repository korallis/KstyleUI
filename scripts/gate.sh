#!/usr/bin/env bash
# gate.sh [lint|lua|python|all|release] [run-all.sh options]: the one gate, run on the computer that made the change. Nothing runs it on GitHub Actions.
# lint also checks that luacheck is 1.2.0 and pre-commit is 4.7.0 and, with PR_TITLE set, the pull request's wording
# (Tools/hooks/check-pr.sh reads PR_TITLE, PR_BODY or PR_BODY_FILE, and PR_LABELS).
# lua runs Tools/regression/run-all.sh; with no options that is --affected against the base.
# python runs the Python suite with the venv interpreter, one process per test file, 4 at a time, leaving out a tool's
# own tests when the tool is unchanged against the base (Tools/tests/run_suite.py). all (the default) runs the three groups.
# release is all with every Lua and Python test file and LUA cleared, so run-all.sh picks its usual interpreter: run it on the exact commit before pushing a v* tag.
# A pass with nothing uncommitted ends "gate passed (<group>) at <commit>", the line the pull request's "local gate" mark quotes.
# Environment: GATE_BASE is the base ref (default origin/staging); KSTYLEUI_PYTHON is the interpreter.
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
	export KSTYLEUI_FULL=1 KSTYLEUI_RELEASE=1
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

tool_version() {
	local found
	found=$("$1" --version 2>&1 | tr -d '\r')
	grep -qxF "$2" <<<"$found" && return 0
	echo "want '$2', found: ${found%%$'\n'*}" >&2
	return 1
}

if [ "$group" = lint ] || [ "$group" = all ]; then
	step "luacheck is 1.2.0" tool_version luacheck "Luacheck: 1.2.0"
	step "pre-commit is 4.7.0" tool_version pre-commit "pre-commit 4.7.0"
	[ -n "${PR_TITLE+set}" ] && step "check-pr against $base" bash Tools/hooks/check-pr.sh "$base"
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
	step "python suite" env -u PR_TITLE -u PR_BODY -u PR_BODY_FILE -u PR_LABELS "${py[@]}" Tools/tests/run_suite.py "$base"
fi

if [ ${#failed[@]} -gt 0 ]; then
	echo "gate FAILED: ${failed[*]}" >&2
	exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
	echo "gate passed ($label) with uncommitted changes: commit them and run again before posting the local gate mark"
else
	echo "gate passed ($label) at $(git rev-parse HEAD)"
fi
