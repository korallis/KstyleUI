#!/usr/bin/env bash
# check-package.sh: check the packager's zip in [release-dir] (default .release) against the TOCs in the current folder.
# Run it from the repository root after the BigWigs packager. Exit 0 passes, 1 fails, 2 is a usage error.
# The TOC walker runs with $LUA, or the first of lua5.1, luajit and lua on PATH.
set -uo pipefail
export LC_ALL=C

release=${1:-.release}
if [ ! -d "$release" ]; then
	echo "check-package: no folder '$release'. Run the packager first." >&2
	exit 2
fi

walker="$(cd "$(dirname "${BASH_SOURCE[0]}")/../regression" && pwd)/toc_files.lua"
lua=${LUA:-}
if [ -z "$lua" ]; then
	for candidate in lua5.1 luajit lua; do
		if command -v "$candidate" >/dev/null 2>&1; then
			lua=$candidate
			break
		fi
	done
fi
if [ -z "$lua" ] || ! command -v "$lua" >/dev/null 2>&1; then
	echo "check-package: no Lua found. Install lua5.1, or set LUA." >&2
	exit 2
fi

shopt -s nullglob
tocs=(*.toc)
if [ "${#tocs[@]}" -ne 1 ]; then
	echo "check-package: expected one core TOC in $(pwd), found ${#tocs[@]}" >&2
	exit 2
fi
package=${tocs[0]%.toc}

zips=("$release"/*.zip)
if [ "${#zips[@]}" -ne 1 ]; then
	echo "check-package: expected exactly one zip in $release, found ${#zips[@]}"
	exit 1
fi
zip=${zips[0]}
if ! entries=$(unzip -Z1 "$zip" 2>&1); then
	echo "check-package: cannot read $zip: $entries"
	exit 1
fi

# Every file the game loads, as a path inside the zip. The packager's move-folders puts each
# <package>_<Module> folder at the top level and everything else under <package>/.
if ! loaded=$(KSTYLEUI_WALKER="$walker" "$lua" -e 'for _, p in ipairs(dofile(os.getenv("KSTYLEUI_WALKER"))()) do print(p) end'); then
	echo "check-package: the TOC walker failed" >&2
	exit 2
fi
expected=$(
	{
		printf '%s\n' "${tocs[0]}"
		for toc in "$package"_*/*.toc; do
			printf '%s\n' "$toc"
		done
		[ -n "$loaded" ] && printf '%s\n' "$loaded"
	} | awk -v pkg="$package" '
		{ top = substr($0, 1, index($0, "/") - 1) }
		index(top, pkg "_") == 1 { print; next }
		{ print pkg "/" $0 }
	' | sort -u
)

problems=$(
	comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$entries" | sort -u) | sed 's/^/missing: /'
	printf '%s\n' "$entries" | awk -v pkg="$package" '
		$0 == "" { next }
		index($0, "/") == 0 { print "file outside an addon folder: " $0; next }
		{ top = substr($0, 1, index($0, "/") - 1) }
		top != pkg && index(top, pkg "_") != 1 {
			if (!(top in seen)) print "folder that is not " pkg " or " pkg "_*: " top "/"
			seen[top] = 1
			next
		}
		{
			n = split($0, parts, "/")
			for (i = 2; i < n; i++) {
				if (parts[i] ~ /^(Tools|docs|research_notes|reports|\.github)$/) { print "development folder: " $0; next }
			}
			if (parts[n] ~ /^(\.luacheckrc|\.pre-commit-config\.yaml|\.pkgmeta|AGENTS\.md)$/) print "development file: " $0
		}
	'
)

if [ -n "$problems" ]; then
	printf '%s\n' "$problems" | sed "s#^#check-package: $zip: #"
	exit 1
fi
echo "check-package: ok ($zip holds all $(printf '%s\n' "$expected" | wc -l | tr -d ' ') loaded files)"
