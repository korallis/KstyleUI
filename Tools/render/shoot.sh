#!/usr/bin/env bash
# shoot.sh: run a scene script, then screenshot it with headless Chrome.
#
#   Tools/render/shoot.sh <scene> [--ppu 1.426] [--out Tools/render/out/<scene>.png] [--json-only]
#
# <scene> is a file in Tools/render/scenes/ without .lua. The scene JSON lands in Tools/render/out/<scene>.json,
# the page in Tools/render/out/<scene>.html and the PNG next to them. LUA (default luajit) runs the scene.
# CHROME overrides the browser binary.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"

scene=${1:-}
if [ -z "$scene" ]; then
	echo "usage: Tools/render/shoot.sh <scene> [--ppu N] [--out file.png] [--json-only]" >&2
	exit 2
fi
shift
ppu=1.426
out=""
json_only=0
while [ $# -gt 0 ]; do
	case "$1" in
		--ppu) ppu=$2; shift 2 ;;
		--out) out=$2; shift 2 ;;
		--json-only) json_only=1; shift ;;
		*) echo "unknown option $1" >&2; exit 2 ;;
	esac
done

script="Tools/render/scenes/$scene.lua"
if [ ! -f "$script" ]; then
	echo "no scene script $script" >&2
	exit 2
fi
outdir="Tools/render/out"
mkdir -p "$outdir"
json="$outdir/$scene.json"
lua=${LUA:-luajit}
"$lua" "$script" "$json"
if [ ! -s "$json" ]; then
	echo "the scene wrote no JSON" >&2
	exit 1
fi
python3 - "$json" <<'PY'
import json, sys
scene = json.load(open(sys.argv[1]))
skipped = scene.get("skipped", {})
print(f"{len(scene['items'])} drawables; skipped hidden {skipped.get('hidden', 0)}, transparent {skipped.get('transparent', 0)}, unresolved {skipped.get('unresolved', 0)}")
for line in scene.get("log", []):
    print("  log: " + line)
PY
if [ "$json_only" = 1 ]; then
	exit 0
fi

page="$outdir/$scene.html"
width=$(python3 -c "import json,math,sys; s=json.load(open(sys.argv[1])); print(math.ceil(s['screen']['width']*float(sys.argv[2])))" "$json" "$ppu")
height=$(python3 -c "import json,math,sys; s=json.load(open(sys.argv[1])); print(math.ceil(s['screen']['height']*float(sys.argv[2])))" "$json" "$ppu")
{
	printf '<!doctype html><html><head><meta charset="utf-8"><title>%s</title>' "$scene"
	printf '<style>html,body{margin:0;background:#000;overflow:hidden}canvas{display:block}</style></head><body>\n'
	printf '<script>window.SCENE='
	cat "$json"
	printf ';window.RENDER_OPTIONS={ppu:%s,base:"file://%s/"};</script>\n' "$ppu" "$root"
	printf '<script src="file://%s/Tools/render/render.js"></script>\n' "$root"
	printf '<script src="file://%s/Tools/render/page.js"></script>\n' "$root"
	printf '</body></html>\n'
} > "$page"

if [ -z "$out" ]; then
	out="$outdir/$scene.png"
fi
chrome=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
if [ ! -x "$chrome" ]; then
	chrome=$(command -v google-chrome || command -v chromium || command -v chromium-browser || true)
fi
if [ -z "$chrome" ] || [ ! -x "$chrome" ]; then
	echo "no Chrome found; set CHROME. The page is at $page" >&2
	exit 1
fi
"$chrome" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
	--force-device-scale-factor=1 --window-size="$width,$height" --virtual-time-budget=30000 \
	--screenshot="$out" "file://$root/$page" >/dev/null 2>&1
# A second pass dumps the DOM to surface any JavaScript error the page recorded.
if "$chrome" --headless=new --disable-gpu --allow-file-access-from-files --virtual-time-budget=30000 \
	--dump-dom "file://$root/$page" 2>/dev/null | grep -q 'id="render-errors"'; then
	echo "the page reported JavaScript errors:" >&2
	"$chrome" --headless=new --disable-gpu --allow-file-access-from-files --virtual-time-budget=30000 \
		--dump-dom "file://$root/$page" 2>/dev/null | sed -n 's/.*<div id="render-errors">\(.*\)<\/div>.*/\1/p' >&2
fi
echo "wrote $out (${width}x${height} px at $ppu px/unit)"
