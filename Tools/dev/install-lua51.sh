#!/usr/bin/env bash
# install-lua51.sh: build Lua 5.1.5, the interpreter CI runs the tests with, into ~/.local/bin/lua5.1, where run-all.sh finds it.
# PREFIX changes ~/.local. The script checks the tarball's SHA-256 and does nothing when the binary is already Lua 5.1.5.
set -euo pipefail

version=5.1.5
sha256=2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333
prefix=${PREFIX:-$HOME/.local}
target=$prefix/bin/lua5.1

if [ -x "$target" ] && "$target" -v 2>&1 | grep -q "^Lua $version "; then
	echo "$target is already Lua $version"
	exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tarball=$work/lua-$version.tar.gz
for url in "https://www.lua.org/ftp/lua-$version.tar.gz" "https://www.tecgraf.puc-rio.br/lua/ftp/lua-$version.tar.gz"; do
	if curl -fsSL --connect-timeout 15 --max-time 120 -o "$tarball" "$url"; then
		break
	fi
	echo "could not download $url" >&2
	rm -f "$tarball"
done
if [ ! -s "$tarball" ]; then
	echo "no mirror answered; download lua-$version.tar.gz by hand and check its SHA-256 is $sha256" >&2
	exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
	actual=$(sha256sum "$tarball" | cut -d' ' -f1)
else
	actual=$(shasum -a 256 "$tarball" | cut -d' ' -f1)
fi
if [ "$actual" != "$sha256" ]; then
	echo "lua-$version.tar.gz has SHA-256 $actual, expected $sha256" >&2
	exit 1
fi

tar -xzf "$tarball" -C "$work"
if [ "$(uname -s)" = "Darwin" ]; then
	platform=macosx
else
	platform=posix
fi
make -C "$work/lua-$version" "$platform" >"$work/build.log" 2>&1 || {
	tail -n 20 "$work/build.log" >&2
	exit 1
}
mkdir -p "$prefix/bin"
install -m 755 "$work/lua-$version/src/lua" "$target"
"$target" -v
