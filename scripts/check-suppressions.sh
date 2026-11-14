#!/usr/bin/env bash
# check-suppressions.sh [base-ref]
# Fails when the change adds a workaround marker or a lint/type suppression without a ticket id on the same line,
# or grows a bulk-suppression baseline file (eslint-suppressions.json, SwiftLint baselines, or SUPPRESSION_BASELINES).
# A baseline may grow only when a commit in the range carries a "Baseline-Growth: <ticket id>" trailer.
# Copied from Lee's quality-foundations skill; run by the repo's gate against the PR base.
set -euo pipefail

base="${1:-${GATE_BASE:-}}"
if [ -z "$base" ]; then
  base=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
fi
mb=$(git merge-base "$base" HEAD)
status=0

git diff -U0 --no-color --diff-filter=ACMR "$mb" HEAD -- . \
  ':(exclude)*.md' ':(exclude)*.mdx' ':(exclude)*.txt' ':(exclude)*.lock' ':(exclude)*.resolved' \
  ':(exclude)**/check-suppressions.sh' |
awk '
  BEGIN {
    pat = "((^|[^a-z0-9])hack([^a-z0-9]|$)|(\\/\\/|#|\\/\\*|\\*|--) *xxx([^a-z0-9]|$)|workaround|work around|eslint-disable|biome-ignore|@ts-ignore|@ts-expect-error|@ts-nocheck|# *noqa|type: *ignore|pyright: *ignore|pylint: *disable|swiftlint:disable|nolint|@suppresswarnings|phpstan-ignore|rubocop:disable|luacheck: *ignore)"
    tk = "[A-Z][A-Z0-9]+-[0-9]+"
  }
  /^\+\+\+ (b\/|\/dev\/null)/ { file = substr($0, 7); next }
  /^@@/ { match($0, /\+[0-9]+/); line = substr($0, RSTART + 1, RLENGTH - 1) - 1; next }
  /^\+/ {
    line++
    text = substr($0, 2)
    if (tolower(text " ") ~ pat && text !~ tk) { printf "%s:%d: %s\n", file, line, text; bad++ }
    next
  }
  END {
    if (bad) {
      printf "\n%d new workaround marker(s) or suppression(s) without a ticket id.\n", bad
      print "Fix the root cause. If that is out of scope, file a ticket and put its id (for example LEE-1234) on the same line."
      exit 1
    }
  }' || status=1

count_entries() {
  if [[ "$1" == *.json ]] && command -v node >/dev/null 2>&1; then
    node -e '
      const d = JSON.parse(require("fs").readFileSync(0, "utf8"));
      const walk = v => Array.isArray(v) ? v.length
        : v && typeof v === "object" ? (typeof v.count === "number" ? v.count : Object.values(v).reduce((s, x) => s + walk(x), 0))
        : 0;
      console.log(walk(d));'
  else
    grep -c . || true
  fi
}

growth_ticket=$(git log --format=%B "$mb"..HEAD | grep -oE '^Baseline-Growth: *[A-Z][A-Z0-9]+-[0-9]+' | head -1 || true)
baselines="eslint-suppressions.json .swiftlint-baseline.json swiftlint-baseline.json .swiftlint.baseline ${SUPPRESSION_BASELINES:-}"
for f in $baselines; do
  git cat-file -e "HEAD:$f" 2>/dev/null || continue
  after=$(git show "HEAD:$f" | count_entries "$f")
  before=0
  if git cat-file -e "$mb:$f" 2>/dev/null; then before=$(git show "$mb:$f" | count_entries "$f"); fi
  if [ "$after" -gt "$before" ]; then
    if [ -n "$growth_ticket" ]; then
      echo "$f: grew from $before to $after suppressions, allowed by $growth_ticket."
    else
      echo "$f: grew from $before to $after suppressions. A baseline may only shrink. Fix the new violations, or add a \"Baseline-Growth: LEE-1234\" trailer naming the ticket that removes them."
      status=1
    fi
  fi
done

exit $status
