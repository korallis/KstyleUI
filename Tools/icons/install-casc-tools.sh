#!/usr/bin/env bash
# Install the tools Tools/icons/casc_export.py runs to read the game's data tables offline.
#
# Usage: bash Tools/icons/install-casc-tools.sh [--root DIR] [--defs-ref COMMIT]
#
# Everything goes under DIR (default ~/.local/share/wow-dev). Nothing is installed system-wide and
# nothing is written to the game folder.
#   DIR/casc/TACTTool/TACTTool        TACTSharp's TACTTool 0.2.0-alpha1, reads CASC storage
#   DIR/casc/DBC2CSV/DBC2CSV.dll      DBC2CSV v1.0.11, converts DB2 files to wago.tools-style CSV
#   DIR/casc/DBC2CSV/definitions/     WoWDBDefs table layouts at COMMIT
#   DIR/dotnet/dotnet                 .NET runtime 10.0.14, which DBC2CSV needs
#
# The release zips are checked against pinned SHA-256 sums, and git checks the WoWDBDefs commit.
# After a game patch, newer table layouts may be needed: rerun with --defs-ref set to a newer
# WoWDBDefs commit. Rerunning replaces each tool.
set -euo pipefail

root="${HOME}/.local/share/wow-dev"
defs_ref="9662a03f6e2aee6c7e2c92c60be6287217307f1b"
while [ $# -gt 0 ]; do
	case "$1" in
	--root)
		root="$2"
		shift 2
		;;
	--defs-ref)
		defs_ref="$2"
		shift 2
		;;
	*)
		echo "usage: $0 [--root DIR] [--defs-ref COMMIT]" >&2
		exit 2
		;;
	esac
done

tact_version="0.2.0-alpha1"
dbc2csv_version="v1.0.11"
dbc2csv_zip="Release-osx-x64.zip" # DBC2CSV.dll is portable .NET code; `dotnet DBC2CSV.dll` runs it anywhere
dbc2csv_sha="4fd918eaae41c35ba954cbb42dcdaa5a84261d0bba46e61a8efc92619558c970"
dotnet_version="10.0.14"

case "$(uname -s)-$(uname -m)" in
Darwin-arm64)
	tact_zip="TACTTool-Release-osx-arm64.zip"
	tact_sha="62795f75d1e67c0636c3cfe24afa0da7d7bfb2d27f898ab6abea43d383eedf0f"
	;;
Linux-x86_64)
	tact_zip="TACTTool-Release-linux-x64.zip"
	tact_sha="1bff6cd1df4828192d9441ac86e10d3eb06efd6947aa830f21415255ede458dd"
	;;
*)
	echo "install-casc-tools: no pinned TACTTool build for $(uname -s) $(uname -m)" >&2
	exit 1
	;;
esac

sha256() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | cut -d' ' -f1
	else
		shasum -a 256 "$1" | cut -d' ' -f1
	fi
}

# fetch URL FILE SHA256: download URL to FILE and stop unless its checksum is SHA256.
fetch() {
	curl -fsSL --retry 3 -o "$2" "$1"
	local got
	got="$(sha256 "$2")"
	if [ "$got" != "$3" ]; then
		echo "install-casc-tools: checksum mismatch for $1" >&2
		echo "  expected $3" >&2
		echo "  got      $got" >&2
		exit 1
	fi
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$root/casc"

echo "TACTTool $tact_version"
fetch "https://github.com/Marlamin/TACTSharp/releases/download/$tact_version/$tact_zip" "$work/tact.zip" "$tact_sha"
rm -rf "$root/casc/TACTTool"
mkdir -p "$root/casc/TACTTool"
unzip -q "$work/tact.zip" -d "$root/casc/TACTTool"
chmod +x "$root/casc/TACTTool/TACTTool"

echo "DBC2CSV $dbc2csv_version"
fetch "https://github.com/Marlamin/DBC2CSV/releases/download/$dbc2csv_version/$dbc2csv_zip" "$work/dbc2csv.zip" "$dbc2csv_sha"
rm -rf "$root/casc/DBC2CSV"
mkdir -p "$root/casc/DBC2CSV"
unzip -q "$work/dbc2csv.zip" -d "$root/casc/DBC2CSV"

echo "WoWDBDefs $defs_ref"
git -C "$work" init -q defs
git -C "$work/defs" fetch -q --depth 1 https://github.com/wowdev/WoWDBDefs.git "$defs_ref"
git -C "$work/defs" checkout -q FETCH_HEAD
rm -rf "$root/casc/DBC2CSV/definitions"
cp -R "$work/defs/definitions" "$root/casc/DBC2CSV/definitions"

echo ".NET runtime $dotnet_version"
curl -fsSL --retry 3 -o "$work/dotnet-install.sh" https://dot.net/v1/dotnet-install.sh
bash "$work/dotnet-install.sh" --runtime dotnet --version "$dotnet_version" --install-dir "$root/dotnet" --no-path >/dev/null

"$root/casc/TACTTool/TACTTool" --version >/dev/null
"$root/dotnet/dotnet" --list-runtimes | grep -q "Microsoft.NETCore.App $dotnet_version"
echo "Installed the CASC tools under $root"
