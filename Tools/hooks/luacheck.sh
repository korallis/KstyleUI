#!/usr/bin/env bash
# luacheck.sh FILE...: luacheck the files pre-commit passes; a change to .luacheckrc or the globals it loads re-checks the whole tree.
for path in "$@"; do
	case "$path" in
	.luacheckrc | Tools/data/forever_globals.lua) exec luacheck --no-color . ;;
	esac
done
exec luacheck --no-color -- "$@"
