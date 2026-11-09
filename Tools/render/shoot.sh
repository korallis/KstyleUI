#!/usr/bin/env bash
# shoot.sh: run a scene script, then screenshot it with headless Chrome.
#
#   Tools/render/shoot.sh <scene> [--ppu 1.426] [--out Tools/render/out/<scene>.png] [--json-only]
#                                [--class WARRIOR] [--backdrop [PNG]] [--backdrop-alpha 1] [--no-standins]
#                                [--report | --strict]
#
# <scene> is a file in Tools/render/scenes/ without .lua. The scene JSON lands in Tools/render/out/<scene>.json,
# the page in Tools/render/out/<scene>.html and the PNG next to them. LUA (default luajit) runs the scene.
# CHROME overrides the browser binary.
#
# Icons draw as a player with the icon pack installed sees them: set B's repaint for every file ID the pack has,
# else Blizzard's icon (scenes/_common.lua, Common.IconDirs). --class picks the class a HUD scene that names none
# renders (hud_dps_mac; one of the nine in scenes/_classes.lua, the warrior when absent); it sets RENDER_CLASS.
# --backdrop draws the HUD over a PNG scaled to the canvas, by default the
# backdrop standins.py makes (Tools/render/out/standins/backdrop.png): the UI-free clean plate of the mockup's
# scene when it exists (KSTYLEUI_PLATE, default ~/.local/share/kstyleui-handoff/scenery/clean.png), else the
# mockup's scenery with its UI blurred away, at --backdrop-alpha. Before the scene runs, standins.py refreshes
# the portraits, the minimap and the backdrop from the handoff mockup when it is there; --no-standins skips
# that, and a missing mockup is not an error.
#
# The render guard (Tools/render/guard.lua) then lists every text the page truncated to "..." and every piece of
# content that reaches past its glass card, minus Tools/render/guard_allow.tsv. By default a finding the allowlist
# does not cover fails the run (exit 3, after the PNG is written); --report lists every finding and never fails;
# --strict also fails on an allowlist line that matched nothing, so a fixed defect leaves the list. RENDER_GUARD
# (report, default or strict) sets the mode for callers such as gallery.py and classes.py.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"

scene=${1:-}
if [ -z "$scene" ]; then
	echo "usage: Tools/render/shoot.sh <scene> [--ppu N] [--out file.png] [--json-only] [--class CLASS] [--backdrop [PNG]] [--backdrop-alpha N] [--no-standins] [--report | --strict]" >&2
	exit 2
fi
shift
ppu=1.426
out=""
json_only=0
class=""
backdrop=""
backdrop_alpha=1
standins=1
guard=${RENDER_GUARD:-default}
while [ $# -gt 0 ]; do
	case "$1" in
		--ppu) ppu=$2; shift 2 ;;
		--out) out=$2; shift 2 ;;
		--json-only) json_only=1; shift ;;
		--class) class=$2; shift 2 ;;
		--backdrop)
			if [ $# -gt 1 ] && [ "${2#--}" = "$2" ]; then
				backdrop=$2; shift 2
			else
				backdrop="Tools/render/out/standins/backdrop.png"; shift
			fi ;;
		--backdrop-alpha) backdrop_alpha=$2; shift 2 ;;
		--no-standins) standins=0; shift ;;
		--report) guard=report; shift ;;
		--strict) guard=strict; shift ;;
		*) echo "unknown option $1" >&2; exit 2 ;;
	esac
done
if [ -n "$class" ]; then
	export RENDER_CLASS=$class
fi
if [ "$standins" = 1 ]; then
	python3 Tools/render/standins.py --quiet \
		--width "$(python3 -c "import math,sys; print(math.ceil(2383 / 1540 * 1080 * float(sys.argv[1])))" "$ppu")" \
		--height "$(python3 -c "import math,sys; print(math.ceil(1080 * float(sys.argv[1])))" "$ppu")"
fi

script="Tools/render/scenes/$scene.lua"
if [ ! -f "$script" ]; then
	echo "no scene script $script" >&2
	exit 2
fi
outdir="Tools/render/out"
mkdir -p "$outdir"
json="$outdir/$scene.json"
lua=${LUA:-luajit}
raw="$outdir/$scene.guard.tsv"
rm -f "$raw"
RENDER_PPU=$ppu "$lua" "$script" "$json"
if [ ! -s "$json" ]; then
	echo "the scene wrote no JSON" >&2
	exit 1
fi
python3 - "$json" <<'PY'
import json, sys
scene = json.load(open(sys.argv[1]))
skipped = scene.get("skipped", {})
print(f"{len(scene['items'])} drawables; skipped hidden {skipped.get('hidden', 0)}, transparent {skipped.get('transparent', 0)}, unresolved {skipped.get('unresolved', 0)}, clipped {skipped.get('clipped', 0)}")
for line in scene.get("log", []):
    print("  log: " + line)
PY
verdict() {
	"$lua" Tools/render/guard.lua "$scene" "$raw" "$guard" "$@"
}
if [ "$json_only" = 1 ]; then
	verdict json-only
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
	if [ -n "$backdrop" ]; then
		case "$backdrop" in
			/*) backdrop_url="file://$backdrop" ;;
			*) backdrop_url="file://$root/$backdrop" ;;
		esac
		printf ';window.RENDER_OPTIONS={ppu:%s,base:"file://%s/",backdrop:"%s",backdropAlpha:%s};</script>\n' "$ppu" "$root" "$backdrop_url" "$backdrop_alpha"
	else
		printf ';window.RENDER_OPTIONS={ppu:%s,base:"file://%s/"};</script>\n' "$ppu" "$root"
	fi
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
# A second pass dumps the DOM to surface any JavaScript error the page recorded and every text it truncated.
# The page sets its title to "rendered" when it has drawn every item; without that the page's truncations are
# unknown, so the guard fails closed (except in --report).
dom=$(mktemp)
paged=1
if ! "$chrome" --headless=new --disable-gpu --allow-file-access-from-files --virtual-time-budget=30000 \
	--dump-dom "file://$root/$page" 2>/dev/null > "$dom" || ! grep -q '<title>rendered</title>' "$dom"; then
	paged=0
	echo "guard: the page did not finish drawing, so the texts it truncated are unknown" >&2
fi
if grep -q 'id="render-errors"' "$dom"; then
	echo "the page reported JavaScript errors:" >&2
	sed -n 's/.*<div id="render-errors">\(.*\)<\/div>.*/\1/p' "$dom" >&2
fi
python3 - "$dom" "$raw" <<'PY'
import html, json, re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
match = re.search(r'<div id="render-truncated"[^>]*>(.*?)</div>', text, re.S)
if match:
    with open(sys.argv[2], "a", encoding="utf-8") as raw:
        for t in json.loads(html.unescape(match.group(1))):
            subject = re.sub(r"[\t\r\n]", " ", t["text"])
            raw.write(f"ellipsis\t{subject}\tthe page truncates it: needs {t['need']:.1f} units, has {t['has']:.1f}\t\n")
PY
rm -f "$dom"
echo "wrote $out (${width}x${height} px at $ppu px/unit)"
if [ "$paged" = 1 ]; then
	verdict
else
	verdict json-only || true
	if [ "$guard" != report ]; then
		echo "guard: $scene fails the render guard: the page step did not complete" >&2
		exit 3
	fi
fi
