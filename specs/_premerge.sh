# premerge <PR> [extra test names...]: merge the PR head into current origin/staging in a temp worktree, run the budget and the named tests, and show hosted CPU-budget warnings (Mac CI makes them fatal on staging)
premerge() {
	local n=$1; shift
	local root=/c/Projects/KstyleUI wt=/c/Users/leeba/.cache/wt-pm-$n
	(cd $root && git fetch -q origin staging && rm -rf $wt && git worktree add -q --detach $wt origin/staging) || return 1
	local br; br=$(cd $root && gh pr view $n --json headRefName --jq .headRefName)
	(cd $wt && git fetch -q origin "$br" && git merge -q --no-edit FETCH_HEAD >/dev/null 2>&1) || { echo "#$n CONFLICT with staging"; (cd $root && git worktree remove --force $wt); return 1; }
	local ok=0
	(cd $wt && lua5.1 Tools/regression/test-perf-path-budgets.lua 2>&1 | tail -1) || ok=1
	for t in "$@"; do [ -f "$wt/Tools/regression/test-$t.lua" ] || { echo "  $t (no such test)"; continue; }; (cd $wt && lua5.1 Tools/regression/test-$t.lua >/dev/null 2>&1) && echo "  $t ok" || { echo "  $t FAIL"; ok=1; }; done
	local run; run=$(cd $root && gh run list --branch "$br" --workflow checks.yml --limit 1 --json databaseId --jq '.[0].databaseId')
	[ -n "$run" ] && (cd $root && gh run view "$run" --log 2>/dev/null | grep -o -E 'WARN test-[a-z0-9-]+: used [0-9.]+ CPU s, over the [0-9]+ CPU s budget' | sort -u | head -10 | sed 's/^/  hosted CPU (Mac is ~0.35-0.6x): /')
	(cd $root && git worktree remove --force $wt)
	return $ok
}
