#!/usr/bin/env bash
# needs-lua.sh BASE: exit 0 when a file changed since BASE can change what a Lua test sees, 1 when none can (docs, workflows, Python tools), 2 on error.
# The pattern lists what the Lua tests load: addon code and its TOC/XML, the regression folder, media and the API data.
set -uo pipefail
since=$(git merge-base "${1:?usage: needs-lua.sh BASE}" HEAD) || exit 2
changed=$(git diff --name-only --no-renames "$since" HEAD) || exit 2
if grep -qE '\.(lua|toc|xml)$|^\.luacheckrc$|^Tools/regression/|^Tools/data/|^Media/' <<<"$changed"; then
	echo "Lua tests: needed, a changed file can reach them"
	exit 0
fi
echo "Lua tests: not needed, no changed file reaches them"
exit 1
