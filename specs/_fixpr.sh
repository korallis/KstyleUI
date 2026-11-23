# fixpr <PR> <review report path> <original spec name>: dispatch an author-fix round for a reviewed PR
fixpr() {
	local n=$1 rev=$2 spec=$3 sha
	sha=$(gh pr view $n --json headRefOid --jq .headRefOid)
	cat > specs/fix-$n.md <<EOF
# Task: fix PR #$n after review

PR https://github.com/korallis/KstyleUI/pull/$n, branch at \`$sha\`. Read:
- the review, \`$rev\`, with its probes and evidence beside it;
- the spec, \`C:/Projects/KstyleUI/specs/$spec\`.

Check out the PR branch, rebase onto \`origin/staging\` (for locale files take both sides' strings, then run \`python3 Tools/locale/strings.py sync\`), fix it, and push to the same branch.

**Fix every finding the review reproduces**, each with a regression built from its probe, committed before the fix. Apply its behaviour-identical cuts. Where the review disproves a README claim (for example, a row marked Present that isn't, or a wrong "Not possible" reason), correct the README. Defaults keep today's look.

**Evidence**: zero base-against-PR default pixel diffs, plus enabled-state renders at all four sizes (1920x1080, 2560x1440, 5120x1440, 3840x2160) over a real game backdrop, \`--strict\`, in the PR's evidence folder under \`fix/\`.

**Re-run**: lint, python, the module tests, \`test-taint-scan\` and \`test-perf-path-budgets\` under PUC Lua 5.1, then hosted CI.

**Constraints**: minimal code; CRLF/ASCII. Beast speed rule. Do not merge.

**Files it may edit**: the files PR #$n already touches, plus \`Tools/regression/**\` and \`Tools/render/**\`.

**Before worker_done**: follow \`C:/Users/leeba/orca-jev-router/WORKER.md\`. Report SHA and run id.
EOF
	node "C:/Users/leeba/orca-jev-router/orca-route.mjs" dispatch --spec-file specs/fix-$n.md --worktree new-child 2>&1 | grep -o -E '"(model|dispatchId)": *"[^"]+"' | head -2 | paste - -
}
# done <dispatch>: release a finished worker and remove its worktree and scratch
done_w() {
	local d=$1 w
	w=$(orca orchestration worker-show --dispatch $d 2>/dev/null | grep -o 'workspace=[^ ]*' | sed 's/.*:://')
	orca orchestration worker-release --dispatch $d >/dev/null 2>&1
	[ -n "$w" ] && orca worktree rm --worktree "path:$w" --delete-branch --force >/dev/null 2>&1
	rm -rf C:/Users/leeba/AppData/Local/Temp/orca-$d
}
