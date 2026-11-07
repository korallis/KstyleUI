#!/usr/bin/env bash
# link-addons.sh: link the staging-live worktree's addon folders into Forever's AddOns folder.
#
# Usage: bash Tools/dev/link-addons.sh [--spike] [--dry-run]
#   --spike    also link Tools/spikes/KstyleUI_Spike
#   --dry-run  print what would change and change nothing
# KSTYLEUI_LIVE and WOW_ADDONS override the worktree and AddOns paths.
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

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
live=${KSTYLEUI_LIVE:-$HOME/KstyleUI.worktrees/staging-live}
live=${live%/}
[[ "$live" = /* ]] || live="$PWD/$live"
addons=${WOW_ADDONS:-/Applications/World of Warcraft/_forever_/Interface/AddOns}
addons=${addons%/}
[[ "$addons" = /* ]] || addons="$PWD/$addons"

if [ "$dry" = 0 ] && [ ! -d "$addons" ]; then
	echo "AddOns folder not found: $addons" >&2
	exit 1
fi

if [ ! -d "$live" ]; then
	echo "worktree $live (staging)"
	if [ "$dry" = 0 ]; then
		git -C "$script_dir" fetch --quiet origin staging
		if git -C "$script_dir" show-ref --verify --quiet refs/heads/staging; then
			git -C "$script_dir" worktree add --quiet "$live" staging
			git -C "$live" merge --ff-only --quiet origin/staging ||
				echo "warning: local staging cannot fast-forward to origin/staging" >&2
		else
			git -C "$script_dir" worktree add --quiet --track -b staging "$live" origin/staging
		fi
	fi
fi

# Folders relative to the live worktree. In a dry run without the worktree, read origin/staging.
list_dirs() {
	if [ -d "$live" ]; then
		for dir in "$live"/KstyleUI_*/; do
			[ -d "$dir" ] && basename "$dir"
		done
		if [ "$spike" = 1 ] && [ -d "$live/Tools/spikes/KstyleUI_Spike" ]; then
			echo "Tools/spikes/KstyleUI_Spike"
		fi
	else
		git -C "$script_dir" ls-tree -d --name-only origin/staging | grep '^KstyleUI_' || true
		if [ "$spike" = 1 ]; then
			git -C "$script_dir" ls-tree -d --name-only origin/staging -- Tools/spikes/KstyleUI_Spike
		fi
	fi
}

targets=("$addons/KstyleUI")
sources=("$live")
spike_found=0
while IFS= read -r rel; do
	[ -n "$rel" ] || continue
	targets+=("$addons/$(basename "$rel")")
	sources+=("$live/$rel")
	[ "$rel" != "Tools/spikes/KstyleUI_Spike" ] || spike_found=1
done < <(list_dirs)

if [ "$spike" = 1 ] && [ "$spike_found" = 0 ]; then
	echo "skip: no spike addon in $live/Tools/spikes/KstyleUI_Spike"
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
