#!/usr/bin/env bash
# check-suppressions.sh [base-ref]
# Fails when the change adds a workaround marker or a lint/type suppression without a ticket id on the same line.
# Copied from Lee's quality-foundations skill; run by the repo's gate against the PR base.
set -euo pipefail

base="${1:-${GATE_BASE:-}}"
if [ -z "$base" ]; then
  base=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
fi
mb=$(git merge-base "$base" HEAD)

git diff -U0 --no-color --diff-filter=AMR "$mb" HEAD -- . \
  ':(exclude)*.md' ':(exclude)*.mdx' ':(exclude)*.txt' ':(exclude)*.lock' ':(exclude)*.resolved' \
  ':(exclude)**/check-suppressions.sh' |
awk '
  BEGIN {
    pat = "((^|[^a-z])hack[^a-z]|xxx|workaround|work around|eslint-disable|biome-ignore|@ts-ignore|@ts-expect-error|@ts-nocheck|# *noqa|type: *ignore|pyright: *ignore|pylint: *disable|swiftlint:disable|nolint|@suppresswarnings|phpstan-ignore|rubocop:disable|luacheck: *ignore)"
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
  }'
