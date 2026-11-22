# Real Forever scenery plates

These are crops of the owner's actual World of Warcraft: Forever screenshots in
`C:\Users\leeba\.cache\kstyleui-backdrops\`. No scenery was painted, blurred,
inpainted, tiled or AI-generated. Only cropping, Lanczos resizing and JPEG
compression are used. `manifest.json` records source and output SHA-256 hashes.
All source screenshots are 5120x1440. Coordinates are left, top, right, bottom;
right and bottom are exclusive.

| Plate | Source | Crop box | Output |
| --- | --- | --- | --- |
| forest-1080.jpg | game_09.png, current build | 0, 300, 1520, 1155 | 1920x1080 |
| forest-ultrawide.jpg | game_09.png, current build | 0, 300, 2048, 876 | 5120x1440 |
| forest-mac.jpg | game_09.png, current build | 0, 300, 1296, 1138 | 3456x2234 |
| town-1080.jpg | game_03.png, older build, scenery only | 0, 400, 1440, 1210 | 1920x1080 |
| town-ultrawide.jpg | game_03.png, older build, scenery only | 0, 752, 1600, 1202 | 5120x1440 |
| town-mac.jpg | game_03.png, older build, scenery only | 0, 400, 1248, 1207 | 3456x2234 |
| minimap.png | game_09.png, current build | 4910, 70, 5038, 198 | 256x256 |

The forest crops show the dark ground and tree trunks left of the player's HUD;
the town crops show bright grass and a cobbled road. Each scenery crop excludes
all UI, names and the player's Medallions. The minimap is separately a real map
stand-in, including the game's player arrow, not a UI-free scenery plate.
The Mac crops have less than 0.04% aspect adjustment when resized.

The following conservative UI exclusion boxes are recorded in
`Tools/media/plates.py`. The plate test rejects scenery crops that intersect any
box for their source. The minimap stand-in above intentionally captures map UI
and is excluded from this scenery-only check. The town ultrawide crop ends at
y=1202, above the old chat frame; its previous bottom edge at y=1218 included
the chat header. Moving the crop upward 16 pixels removes it without painting
or reducing the crop's width.

| Source | UI region | Exclusion box |
| --- | --- | --- |
| game_03.png | Chat | 16, 1210, 464, 1440 |
| game_03.png | Active targets and items | 1680, 800, 1840, 960 |
| game_03.png | World labels | 1900, 400, 4640, 1000 |
| game_03.png | Central HUD | 1840, 1000, 3380, 1440 |
| game_03.png | Right rail | 4640, 0, 5120, 1440 |
| game_09.png | Chat | 16, 1180, 660, 1440 |
| game_09.png | Central HUD | 1500, 1180, 3400, 1440 |
| game_09.png | World labels and waypoint | 2100, 200, 2850, 900 |
| game_09.png | Right rail | 4380, 0, 5120, 1440 |

No source offers a UI-free full 5120-pixel width at 32:9. The honest ultrawide
crops above are 2048x576 and 1600x450, enlarged to 5120x1440 without extending
the scenery. They are previews over screenshot crops, not full-screen captures.
The Every screen pair keeps both Centred and Spread. Every scene uses the
current-build forest; the town crops stay for bright-ground checks.

Regenerate plates with `python Tools/media/plates.py` (needs the private source
screenshots). Retake all published pictures immediately before release:

```sh
python Tools/render/readme.py && python Tools/media/marketing.py --pages
```

The committed plates make retakes independent of those private screenshots.
Set `CHROME` and put LuaJIT and Git Bash on PATH on Windows; set
`KSTYLEUI_PYTHON=python`. `KSTYLEUI_MEDIA_WORK` can place intermediate renders
in a task's scratch directory. `--backdrop` receives Git Bash /c/... paths on
Windows; shoot.sh converts them to escaped native file URLs. `standins.py --internal-mockup-plate` is for
internal tests only; publishing always passes a committed real crop explicitly.
The package ignores docs/, so these plates never ship as addon assets.

Real captures would be better than these fixture previews: the Medallions HUD
at 1080p in combat; the Centred/Spread healer pair; unit-frame close-ups; raid frames in a populated raid; first-run setup with its live
preview; character-sheet and other Blizzard window skins; nameplates during a
pull; a populated party damage meter; and the map, quest and RestedXP rail.
Capture after the visual audit changes land, with chat/player names hidden as
needed, and retain the honest source captions when swapping them in.
