#!/usr/bin/env bash
# gate.sh [lint|lua|python|all] [run-all.sh options]: the one gate. Agents and CI both run it.
# lint runs crlf --check, pre-commit, luacheck, check_toc, strings.py check and check-suppressions.
# lua runs Tools/regression/run-all.sh; with no options that is --affected against the base, and CI passes --shard I/N.
# python runs the Python suite with the venv interpreter. all (the default) runs the three groups.
# Environment: GATE_BASE is the base ref (default origin/staging, CI passes HEAD^1); KSTYLEUI_PYTHON is the interpreter.
set -uo pipefail

cd "${BASH_SOURCE[0]%/*}/.." || exit 2

group=${1:-all}
[ $# -gt 0 ] && shift
base=${GATE_BASE:-origin/staging}
py=${KSTYLEUI_PYTHON:-$HOME/.local/share/wow-dev/venv/bin/python}
[ -x "$py" ] || py=python3

case "$group" in
lint | lua | python | all) ;;
*)
	echo "usage: scripts/gate.sh [lint|lua|python|all] [run-all.sh options]" >&2
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
	step "crlf --check" "$py" Tools/dev/crlf.py --check
	step "pre-commit" pre-commit run --all-files --show-diff-on-failure
	step "luacheck" luacheck --no-color .
	step "check_toc" "$py" Tools/hooks/check_toc.py
	step "strings.py check" "$py" Tools/locale/strings.py check
	step "check-suppressions against $base" bash scripts/check-suppressions.sh "$base"
fi

if [ "$group" = lua ] || [ "$group" = all ]; then
	[ $# -eq 0 ] && set -- --affected "$base"
	step "run-all.sh $*" bash Tools/regression/run-all.sh "$@"
fi

if [ "$group" = python ] || [ "$group" = all ]; then
	step "python suite" "$py" -m unittest discover -s Tools/tests
fi

if [ ${#failed[@]} -gt 0 ]; then
	echo "gate FAILED: ${failed[*]}" >&2
	exit 1
fi
echo "gate passed ($group)"
