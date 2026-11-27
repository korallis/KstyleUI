#!/usr/bin/env bash
# needs-lua.sh BASE: exit 0 when a file changed since BASE can change what a Lua test sees, 1 when none can, 2 on error.
# Only files no Lua test reads skip the tests: workflows, Python tests, scripts, research and documents. A document a test
# reads (the changelog, a module README, the feature map, the element keys) still needs them, and so does any other file.
set -uo pipefail
since=$(git merge-base "${1:?usage: needs-lua.sh BASE}" HEAD) || exit 2
changed=$(git diff --name-only --no-renames "$since" HEAD) || exit 2
unread='^(\.github/|Tools/tests/|scripts/|research_notes/|reports/|verify/|docs/)|^\.pre-commit-config\.yaml$|\.md$'
read='^(CHANGELOG\.md|docs/feature-map\.md|docs/superpowers/plans/element-keys\.md|(Core|KstyleUI_[^/]+)/README\.md)$'
if grep -qE "$read" <<<"$changed" || grep -vE "$unread" <<<"$changed" | grep -q .; then
	echo "Lua tests: needed, a changed file can reach them"
	exit 0
fi
echo "Lua tests: not needed, no changed file reaches them"
exit 1
