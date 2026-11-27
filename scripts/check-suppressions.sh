#!/usr/bin/env bash
# check-suppressions.sh [base-ref]
# Fails when the change adds a workaround marker or a lint/type suppression without a ticket id on the same line,
# or grows a bulk-suppression baseline file (eslint-suppressions.json, SwiftLint baselines, or SUPPRESSION_BASELINES).
# A baseline may gain entries only when a commit that changes it carries a "Baseline-Growth: <ticket id>" trailer.
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
    pat = "((^|[^a-z0-9])hack([^a-z0-9]|$)|(\\/\\/|#|\\/\\*|\\*|--) *xxx([^a-z0-9]|$)|workaround|work around|eslint-disable|biome-ignore|@ts-ignore|@ts-expect-error|@ts-nocheck|# *noqa|type: *ignore|pyright: *ignore|pylint: *disable|swiftlint:disable|nolint|@suppresswarnings|phpstan-ignore|rubocop:disable|luacheck: *ignore|shellcheck +disable|noinspection|nosec|#\\[allow\\(|@suppress)"
    tk = "[A-Z][A-Z0-9]+-[0-9]+"
  }
  /^\+\+\+ (b\/|\/dev\/null)/ { file = substr($0, 7); next }
  /^@@/ { match($0, /\+[0-9]+/); line = substr($0, RSTART + 1, RLENGTH - 1) - 1; next }
  /^\+/ {
    line++
    text = substr($0, 2)
    scan = text
    if (file == "docs/renders/index.html" || file == "docs/renders/phone.html") {
      gsub(/<img src="data:image\/png;base64,[a-zA-Z0-9+\/=]+"/, "<img src=\"[image]\"", scan)
    }
    if (tolower(scan " ") ~ pat && scan !~ tk) { printf "%s:%d: %s\n", file, line, scan; bad++ }
    next
  }
  END {
    if (bad) {
      printf "\n%d new workaround marker(s) or suppression(s) without a ticket id.\n", bad
      print "Fix the root cause. If that is out of scope, file a ticket and put its id (for example LEE-1234) on the same line."
      exit 1
    }
  }' || status=1

new_entries() {
  if [[ "$3" == *.json ]] && command -v node >/dev/null 2>&1; then
    node -e '
      const fs = require("fs");
      const read = p => { const t = fs.readFileSync(p, "utf8"); return t.trim() ? JSON.parse(t) : null; };
      const strip = v => Array.isArray(v) ? v.map(strip)
        : v && typeof v === "object" ? Object.fromEntries(Object.keys(v).sort()
            .filter(k => !["line", "character", "column", "startLine", "endLine"].includes(k)).map(k => [k, strip(v[k])]))
        : v;
      const bag = (v, path, out) => {
        if (Array.isArray(v)) v.forEach(x => { const k = path + "|" + JSON.stringify(strip(x)); out.set(k, (out.get(k) || 0) + 1); });
        else if (v && typeof v === "object" && typeof v.count === "number") out.set(path, (out.get(path) || 0) + v.count);
        else if (v && typeof v === "object") for (const [k, x] of Object.entries(v)) bag(x, path + "/" + k, out);
        return out;
      };
      const b = bag(read(process.argv[1]), "", new Map()), h = bag(read(process.argv[2]), "", new Map());
      let n = 0;
      for (const [k, c] of h) n += Math.max(0, c - (b.get(k) || 0));
      console.log(n);' "$1" "$2"
  elif [[ "$3" == *.tsv ]]; then
    awk -F '\t' '
      BEGIN { OFS = FS }
      /^[[:space:]]*(#|$)/ { next }
      { count = $NF + 0; NF--; key = $0 }
      FILENAME == ARGV[1] { before[key] = count; next }
      !(key in before) { added += count ? count : 1; next }
      count > before[key] { added += count - before[key] }
      END { print added + 0 }
    ' "$1" "$2"
  else
    sort "$1" | grep . > "$1.s" || true
    sort "$2" | grep . > "$2.s" || true
    comm -13 "$1.s" "$2.s" | grep -c . || true
  fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
baselines="eslint-suppressions.json .swiftlint-baseline.json swiftlint-baseline.json .swiftlint.baseline ${SUPPRESSION_BASELINES:-}"
for f in $baselines; do
  git cat-file -e "HEAD:$f" 2>/dev/null || continue
  git show "HEAD:$f" > "$tmp/head"
  if git cat-file -e "$mb:$f" 2>/dev/null; then git show "$mb:$f" > "$tmp/base"; else : > "$tmp/base"; fi
  added=$(new_entries "$tmp/base" "$tmp/head" "$f")
  [ "$added" -gt 0 ] || continue
  growth_ticket=$(git log --format=%B "$mb"..HEAD -- "$f" | grep -oE '^Baseline-Growth: *[A-Z][A-Z0-9]+-[0-9]+' | head -1 || true)
  if [ -n "$growth_ticket" ]; then
    echo "$f: $added new suppression(s), allowed by $growth_ticket."
  else
    echo "$f: $added new suppression(s). A baseline may only shrink. Fix the new violations, or add a \"Baseline-Growth: LEE-1234\" trailer to the commit that changes $f, naming the ticket that removes them."
    status=1
  fi
done

exit $status
