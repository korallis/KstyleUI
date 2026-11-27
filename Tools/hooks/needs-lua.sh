#!/usr/bin/env bash
# needs-lua.sh BASE: exit 0 when a file changed since BASE can change what a Lua test sees, 1 when none can, 2 on error.
# Only workflows, Python tests, scripts, research and documents skip the tests; any other file needs them. A document the
# nightly suite reads (the changelog, a module README) still skips them: a docs-only change runs no Lua tests.
# grep reads the list from a here-string, never a pipe, so an early exit cannot turn a large list into a skip.
set -uo pipefail
since=$(git merge-base "${1:?usage: needs-lua.sh BASE}" HEAD) || exit 2
changed=$(git diff --name-only --no-renames "$since" HEAD) || exit 2
unread='^(\.github/|Tools/tests/|scripts/|research_notes/|reports/|verify/|docs/)|^\.pre-commit-config\.yaml$|\.md$'
if [ -n "$changed" ] && grep -qvE "$unread" <<<"$changed"; then
	echo "Lua tests: needed, a changed file can reach them"
	exit 0
fi
echo "Lua tests: not needed, no changed file reaches them"
exit 1
