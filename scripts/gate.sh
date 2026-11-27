#!/usr/bin/env bash
# gate.sh [fast|lint|lua|python|all|release] [run-all.sh options]: the checks before a push; the checks workflow on GitHub runs the tests on each pull request.
# fast (the default) is lint with the pre-commit hooks, luacheck included, on the files changed against the base only: about 15 seconds.
# lint checks every file; both check that luacheck is 1.2.0 and pre-commit is 4.7.0 and, with PR_TITLE set, the pull request's wording
# (Tools/hooks/check-pr.sh reads PR_TITLE, PR_BODY or PR_BODY_FILE, and PR_LABELS).
# lua runs Tools/regression/run-all.sh; with no options that is --affected against the base.
# python runs the Python suite with the venv interpreter, one process per test file, 4 at a time, leaving out a tool's
# own tests when the tool is unchanged against the base (Tools/tests/run_suite.py). all runs lint, lua and python.
# release is all with every Lua and Python test file and LUA cleared, so run-all.sh picks its usual interpreter; the nightly workflow runs the same.
# A pass ends "gate passed (<group>) at <commit>" only when the working copy was clean and on that commit from start to end.
# Environment: GATE_BASE is the base ref (default origin/staging); KSTYLEUI_PYTHON is the interpreter.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

group=${1:-fast}
label=$group
[ $# -gt 0 ] && shift
base=${GATE_BASE:-origin/staging}
source Tools/regression/run-all.sh
pick_python || exit 2

case "$group" in
fast | lint | lua | python | all) ;;
release)
	group=all
	set --
	export KSTYLEUI_FULL=1 KSTYLEUI_RELEASE=1
	unset LUA
	;;
*)
	echo "usage: scripts/gate.sh [fast|lint|lua|python|all|release] [run-all.sh options]" >&2
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

start_commit=$(git rev-parse HEAD)
start_status=$(git status --porcelain)

if [ "$group" = fast ] || [ "$group" = lint ] || [ "$group" = all ]; then
	step "luacheck is 1.2.0" tool_version luacheck "Luacheck: 1.2.0"
	step "pre-commit is 4.7.0" tool_version pre-commit "pre-commit 4.7.0"
	[ -n "${PR_TITLE+set}" ] && step "check-pr against $base" bash Tools/hooks/check-pr.sh "$base"
	step "crlf --check" "${py[@]}" Tools/dev/crlf.py --check
	if [ "$group" = fast ]; then
		if since=$(git merge-base "$base" HEAD); then
			step "pre-commit on the files changed against $base" env -u SKIP pre-commit run --from-ref "$since" --to-ref HEAD --show-diff-on-failure
		else
			echo "== gate: cannot find the merge base with $base; checking every file" >&2
			step "pre-commit" env -u SKIP pre-commit run --all-files --show-diff-on-failure
		fi
	else
		step "pre-commit" env -u SKIP pre-commit run --all-files --show-diff-on-failure
	fi
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
end_commit=$(git rev-parse HEAD)
if [ -n "$start_status" ] || [ -n "$(git status --porcelain)" ]; then
	echo "gate passed ($label) with uncommitted changes: commit them and run again before you push"
elif [ "$end_commit" != "$start_commit" ]; then
	echo "gate passed ($label) on a working copy that moved from $start_commit to $end_commit during the run: run again on the new commit"
else
	echo "gate passed ($label) at $start_commit"
fi
