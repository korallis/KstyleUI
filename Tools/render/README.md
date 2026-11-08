# Render

Draws the UI from the addon's real Lua code, without the game. A scene script boots a stub environment (`Tools/regression/*_env.lua`), drives a module into a state, and `scene.lua` resolves every visible region to a drawable in screen units. `render.js` draws the drawables on a canvas; `shoot.sh` screenshots it with headless Chrome; `compare.py` puts a crop next to the design file, the mockup or an in-game screenshot at the same pixels per unit.

Screen units: the screen is 1080 units tall, x grows right and y grows down from the top left. That is KstyleUI's root unit at user scale 1. The owner's Mac draws 1.426 px per unit (2383 by 1540, UI scale 768 / 1080), the design file 2.0, the mockup 1.348.

## Run

From the repository root, with `luajit` and Google Chrome installed:

```bash
Tools/render/shoot.sh hud_dps_mac                                               # Tools/render/out/hud_dps_mac.png at 1.426 px/unit
Tools/render/shoot.sh components_mac                                            # the component sheet at the owner's density
Tools/render/shoot.sh components_mac --ppu 2.0 --out Tools/render/out/components_design.png   # the sheet at the design file's density
Tools/render/shoot.sh smoke --json-only                                         # the scene JSON only, no Chrome
```

`shoot.sh` prints the drawable count, the skipped counts (hidden, transparent, unresolved) and every log line: a texture with no local file, an unknown font object, a frame with no anchors, an atlas drawn as a grey box. Read the log before you trust a render. `Tools/render/out/` is ignored by git.

To look at a scene in a browser instead, open `Tools/render/out/<scene>.html` with Chrome started as `--allow-file-access-from-files`, or `render.html?scene=out/<scene>.json&ppu=1.426`.

## Compare

```bash
python3 Tools/render/compare.py \
  --render Tools/render/out/hud_dps_mac.png --render-ppu 1.426 --crop 300,740,560,180u \
  --ref ~/.local/share/kstyleui-handoff/screens/mockup-leveling-warrior-2574.png --ref-ppu 1.348 --ref-crop 300,740,560,180u \
  --out Tools/render/out/cmp_player.png --label-b mockup
```

A crop is `x,y,width,height` in that image's pixels, or in screen units with a `u` suffix. The reference crop is rescaled to the render's density, so one unit is the same number of pixels on both sides. `--scale` magnifies both halves. Crop each image with its own coordinates: the mockup is 1909 units wide and the owner's screen 1671, so right-anchored elements sit at different x. The component sheet rendered at 2.0 px per unit puts each section where the design file draws it, so the same pixel box works on both (`--crop 1560,260,990,240 --ref-crop 1560,260,990,240`), except the target frame, which sits further right because the addon's frames are 296 units wide and the design's 234. `compare.py` needs Pillow; it runs itself again with `~/.local/share/wow-dev/venv/bin/python` when the system Python has none.

## Add a scene

A scene script in `Tools/render/scenes/` builds one scene and ends with `return Common.Run(build)`:

```lua
local Common = dofile("Tools/render/scenes/_common.lua")
local U = dofile("Tools/regression/unitframes_env.lua")

return Common.Run(function()
	local env, K = U.New(Common.ScreenOpts({ saved = ... }))
	-- drive the module: set units, fire events, run env.RunTimers() and U.W.Tick(env, 0.05) for tweens
	return Common.Scene.Build(env, { time = env._time })
end)
```

- `Common.ScreenOpts(extra)` is the owner's screen for loaders that take `width`, `height` and `uiScale`. For a loader that does not, call `Common.ForceScreen(env)` in its `setup` hook.
- `Scene.Build(env, opts)` walks UIParent and every parentless frame. `opts.time` is the clock for timer bars and cooldown swipes; `opts.hover` is a set of frames whose HIGHLIGHT regions draw.
- `Scene.Merge({ sceneA, sceneB })` composites modules drawn in separate environments; every environment must use the same screen options.
- `Scene.Rect(env, frame)` gives one frame's resolved rect in screen units, for stand-ins the scene has to size itself.
- `Hud.Module(name)` in `hud.lua` builds one HUD module; `Hud.Build()` merges them all. `components.lua` holds the sheet's section origins.
- `Tools/regression/test-render-scenes.lua` builds every scene; add yours there so it fails when the code it draws breaks.

Saved data for a scene turns a module on and marks the first-run setup seen: `{ version = 2, profiles = { Default = { UnitFrames = { enabled = true } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }`.

## What the renderer models

- Anchors: `SetPoint` in every form, by frame or by name, `SetAllPoints`, two-point stretch, sizes, `SetScale` with offsets in the child's scale, parentless frames against the screen.
- Visibility and alpha chains with `SetIgnoreParentAlpha`; draw order by strata, frame level (`SetUsingParentLevel`), draw layer, sublevel, creation order; HIGHLIGHT only for hovered frames.
- Textures: file paths under `Interface\AddOns\` mapped to the repository (`KstyleUI\` is the root), numeric file IDs to `KstyleUI_IconsColour/Icons`, then `KstyleUI_Icons/Icons`, then `~/.local/share/wow-dev/icons/blizzard`; `SetColorTexture`, vertex colour (multiply), 4- and 8-value texcoords (affine), `ADD` as `lighter`, desaturation, rotation, gradients, REPEAT tiling at texel size, masks via `destination-in`.
- Status bars: the fill texture covers the bar times its fraction from `SetValue` over `SetMinMaxValues`, or from `SetTimerDuration` with a `{ start, finish }` object against the clock, honouring orientation and reverse fill; `SetStatusBarColor` tints the fill.
- Cooldown swipes from `SetCooldown(start, duration)` or a duration object with `start`/`finish` or `remaining`/`total`, with `SetReverse`, `SetSwipeColor`, the swipe texture as a mask, and countdown numbers unless hidden.
- Text: `SetText` and `SetFormattedText` (secrets revealed), fonts from `SetFont`, `SetFontObject` or the template name (Blizzard names map to Friz Quadrata sizes), colour, shadow, justify, word wrap, `|c`/`|r` colours, links and textures stripped. A text with no width of its own takes an estimated natural width in the solver and its measured width on the page, keeping its anchored side.
- Pixel snapping: every rect edge rounds to a device pixel.

## Known limitations

- The stub draws no world: portraits, the minimap and spell icons the icon sets lack are flat stand-ins or grey boxes. Blizzard atlases draw as grey boxes.
- Text widths that other frames depend on are estimated from average glyph widths, so a frame anchored to a text's edge can sit a few units off. The page measures the real glyphs for the text itself.
- Blizzard-owned layout is not modelled: the chat window's lines, the quest tracker's blocks and the tooltip's lines are laid out by the scene the way the game would, and say so in the log. Blizzard's POI buttons are not drawn.
- Fonts the repository lacks (`Fonts\FRIZQT__.TTF`, `ARIALN.TTF`) fall back to Source Sans on the page; the log names them.
- Tiled textures repeat at one texel per unit of the region's own scale, which is the game's behaviour as far as the owner's screenshots show; check the grain against a screenshot before trusting it.
- Motion is sampled: scenes tick tweens with `W.Tick` and hold the clock, so a fade or a cast reads mid-way, not at a precise frame.
- Hover glows use the addon's low alpha, so a hovered button reads close to a normal one; the design file's strong hover glow is a design difference, not a renderer one.
- Chrome's canvas does the compositing, so `multiply` tinting and `destination-in` masking are exact to 8 bits; the game's blend modes other than `BLEND` and `ADD` draw as `BLEND`.
