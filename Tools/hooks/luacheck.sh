#!/usr/bin/env bash
# luacheck.sh FILE...: luacheck the files pre-commit passes. On this computer that is only the changed Lua files; on GitHub
# (GITHUB_ACTIONS=true) a change to .luacheckrc or the globals it loads re-checks the whole tree instead.
files=()
for path in "$@"; do
	case "$path" in
	.luacheckrc | Tools/data/forever_globals.lua)
		[ "${GITHUB_ACTIONS:-}" = true ] && exec luacheck --no-color .
		;;
	esac
	[ "$path" = .luacheckrc ] || files+=("$path")
done
[ ${#files[@]} -eq 0 ] && exit 0
exec luacheck --no-color -- "${files[@]}"
