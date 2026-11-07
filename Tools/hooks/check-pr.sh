#!/usr/bin/env bash
# check-pr.sh: check a pull request's changelog line and version changes against <base-ref>.
# Usage: PR_BODY=<body> PR_LABELS=<labels> bash Tools/hooks/check-pr.sh <base-ref>
# PR_LABELS holds label names separated by commas or newlines. Exit 0 passes, 1 fails, 2 is a usage error.
set -uo pipefail

base=${1:-}
if [ -z "$base" ] || ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
	echo "check-pr: unknown base ref '${base}'. Usage: bash Tools/hooks/check-pr.sh <base-ref>" >&2
	exit 2
fi
if ! merge_base=$(git merge-base "$base" HEAD); then
	echo "check-pr: '$base' and HEAD share no history" >&2
	exit 2
fi

# Folders that never ship. Every other path is part of the addon.
dev_dirs=(Tools docs research_notes reports .github)
excludes=()
for dir in "${dev_dirs[@]}"; do
	excludes+=(":!$dir/")
done

is_shipped() {
	local dir
	for dir in "${dev_dirs[@]}"; do
		[[ $1 == "$dir"/* ]] && return 1
	done
	return 0
}

has_label() {
	local want label
	want=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
	while IFS= read -r label; do
		label=$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		[ "$label" = "$want" ] && return 0
	done < <(printf '%s\n' "${PR_LABELS:-}" | tr ',' '\n')
	return 1
}

# Print 1 when PR_BODY has a line under "## Changelog" that starts Added:, Changed: or Fixed: and says
# something. A level 1 or 2 heading ends the section. Text inside HTML comments does not count.
has_changelog() {
	printf '%s\n' "${PR_BODY:-}" | awk '
		{
			sub(/\r$/, "")
			line = $0
			out = ""
			while (1) {
				if (incomment) {
					i = index(line, "-->")
					if (!i) { line = ""; break }
					line = substr(line, i + 3)
					incomment = 0
				}
				i = index(line, "<!--")
				if (!i) { out = out line; break }
				out = out substr(line, 1, i - 1)
				line = substr(line, i + 4)
				incomment = 1
			}
		}
		out ~ /^##?[ \t]/ {
			section = (out ~ /^##[ \t]+[Cc]hangelog[ \t]*$/)
			next
		}
		section && out ~ /^[ \t]*([-*+][ \t]+)?(Added|Changed|Fixed):[ \t]*[^ \t]/ { found = 1 }
		END { print found ? 1 : 0 }
	'
}

# Read file text on stdin and print the release markers it sets: "## Version:" lines when $1 is toc,
# CODE_BUILD assignments when $1 is lua. Line endings, spacing and Lua comments do not count.
marker_values() {
	awk -v toc="$([ "$1" = toc ] && echo 1)" '
		{ sub(/\r$/, "") }
		toc && /^##[ \t]*Version[ \t]*:/ {
			sub(/^##[ \t]*Version[ \t]*:[ \t]*/, "")
			sub(/[ \t]+$/, "")
			print $0
		}
		!toc && /CODE_BUILD[ \t]*=([^=]|$)/ {
			sub(/^.*CODE_BUILD[ \t]*=[ \t]*/, "")
			sub(/[ \t]*--.*$/, "")
			sub(/[ \t;]+$/, "")
			print $0
		}
	'
}

# The markers one file sets at a revision.
file_markers() {
	git show "$1:$2" 2>/dev/null | marker_values "${2##*.}"
}

# Every distinct marker value that the shipped files of one kind (toc or lua) set at a revision.
# This catches a marker that moves to another file, which a per-file comparison misses.
tree_markers() {
	local rev=$1 kind=$2 needle out status
	needle=$([ "$kind" = toc ] && echo Version || echo CODE_BUILD)
	out=$(git grep -h -I -F -e "$needle" "$rev" -- "*.$kind" "${excludes[@]}")
	status=$?
	if [ "$status" -gt 1 ]; then
		echo "check-pr: git grep failed at $rev" >&2
		return 2
	fi
	printf '%s\n' "$out" | marker_values "$kind" | sort -u
}

joined() {
	if [ -z "$1" ]; then
		echo "none"
	else
		printf '%s' "${1//$'\n'/, }"
	fi
}

changes=$(mktemp) || exit 2
trap 'rm -f "$changes"' EXIT
if ! git diff -z --name-status -M "$merge_base" HEAD >"$changes"; then
	echo "check-pr: git diff against '$base' failed" >&2
	exit 2
fi

shipped=()
marker_changes=()
while IFS= read -r -d '' status && IFS= read -r -d '' old; do
	path=$old
	case $status in
		R* | C*) IFS= read -r -d '' path || break ;;
	esac
	is_shipped "$old" && shipped+=("$old")
	[ "$path" != "$old" ] && is_shipped "$path" && shipped+=("$path")
	case $status in
		M | R*) ;;
		*) continue ;;
	esac
	is_shipped "$old" && is_shipped "$path" || continue
	[[ $path == *.toc || $path == *.lua ]] || continue
	if [ "$(file_markers "$merge_base" "$old")" != "$(file_markers HEAD "$path")" ]; then
		marker_changes+=("$path")
	fi
done <"$changes"

marker_moves=()
for kind in toc lua; do
	before=$(tree_markers "$merge_base" "$kind") || exit 2
	after=$(tree_markers HEAD "$kind") || exit 2
	if [ "$before" != "$after" ]; then
		name=$([ "$kind" = toc ] && echo "the TOC '## Version' values" || echo "CODE_BUILD")
		marker_moves+=("$name change from $(joined "$before") to $(joined "$after")")
	fi
done

failed=0
if [ "${#shipped[@]}" -gt 0 ] && ! has_label "no changelog" && [ "$(has_changelog)" != 1 ]; then
	echo "check-pr: this PR changes shipped files (${shipped[0]}$([ "${#shipped[@]}" -gt 1 ] && echo " and $((${#shipped[@]} - 1)) more"))."
	echo "  Add a line under '## Changelog' in the PR body that starts 'Added:', 'Changed:' or 'Fixed:'."
	echo "  A PR that changes only tooling or docs takes the label 'no changelog' instead."
	failed=1
fi
if [ $((${#marker_changes[@]} + ${#marker_moves[@]})) -gt 0 ] && ! has_label "release"; then
	for path in ${marker_changes[@]+"${marker_changes[@]}"}; do
		echo "check-pr: $path changes its '## Version' line or CODE_BUILD."
	done
	for move in ${marker_moves[@]+"${marker_moves[@]}"}; do
		echo "check-pr: $move."
	done
	echo "  Only a PR labelled 'release' may change a version or CODE_BUILD."
	failed=1
fi

if [ "$failed" -eq 0 ]; then
	echo "check-pr: ok (${#shipped[@]} shipped files changed)"
fi
exit "$failed"
