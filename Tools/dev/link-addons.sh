#!/usr/bin/env bash
# link-addons.sh: link the addon folders of the owner's checkout (~/KstyleUI, on staging) into Forever's AddOns folder.
#
# Usage: bash Tools/dev/link-addons.sh [--spike] [--dry-run]
#   --spike    also link Tools/spikes/KstyleUI_Spike
#   --dry-run  print what would change and change nothing
# KSTYLEUI_LIVE overrides the checkout and WOW_ADDONS the AddOns folder.
# The checkout must exist and hold KstyleUI.toc: the script never clones, switches branches or pulls.
# A target that exists and is not a symlink is never touched: the script prints it and exits 1.
set -euo pipefail

spike=0
dry=0
for arg in "$@"; do
	case "$arg" in
		--spike) spike=1 ;;
		--dry-run) dry=1 ;;
		*) echo "usage: bash Tools/dev/link-addons.sh [--spike] [--dry-run]" >&2; exit 2 ;;
	esac
done

live=${KSTYLEUI_LIVE:-$HOME/KstyleUI}
live=${live%/}
[[ "$live" = /* ]] || live="$PWD/$live"
addons=${WOW_ADDONS:-/Applications/World of Warcraft/_forever_/Interface/AddOns}
addons=${addons%/}
[[ "$addons" = /* ]] || addons="$PWD/$addons"

if [ ! -f "$live/KstyleUI.toc" ]; then
	echo "KstyleUI checkout not found: $live has no KstyleUI.toc. Clone the repository there or set KSTYLEUI_LIVE." >&2
	exit 1
fi

if [ "$dry" = 0 ] && [ ! -d "$addons" ]; then
	echo "AddOns folder not found: $addons" >&2
	exit 1
fi

targets=("$addons/KstyleUI")
sources=("$live")
for dir in "$live"/KstyleUI_*/; do
	[ -d "$dir" ] || continue
	name=$(basename "$dir")
	targets+=("$addons/$name")
	sources+=("$live/$name")
done

if [ "$spike" = 1 ]; then
	if [ -d "$live/Tools/spikes/KstyleUI_Spike" ]; then
		targets+=("$addons/KstyleUI_Spike")
		sources+=("$live/Tools/spikes/KstyleUI_Spike")
	else
		echo "skip: no spike addon in $live/Tools/spikes/KstyleUI_Spike"
	fi
fi

blocked=0
for target in "${targets[@]}"; do
	if [ -e "$target" ] && [ ! -L "$target" ]; then
		echo "not a symlink, left alone: $target"
		blocked=1
	fi
done
[ "$blocked" = 0 ] || exit 1

for i in "${!targets[@]}"; do
	target=${targets[$i]}
	source=${sources[$i]}
	if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
		echo "ok $target"
	else
		echo "link $target -> $source"
		[ "$dry" = 1 ] || ln -sfn "$source" "$target"
	fi
done
