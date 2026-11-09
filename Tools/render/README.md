# Render

Draws the UI from the addon's real Lua code, without the game. A scene script boots a stub environment (`Tools/regression/*_env.lua`), drives a module into a state, and `scene.lua` resolves every visible region to a drawable in screen units. `render.js` draws the drawables on a canvas; `shoot.sh` screenshots it with headless Chrome; `compare.py` puts a crop next to the design file, the mockup or an in-game screenshot at the same pixels per unit.

Screen units: the screen is 1080 units tall, x grows right and y grows down from the top left. That is KstyleUI's root unit at user scale 1. The owner's Mac draws 1.426 px per unit (2383 by 1540, UI scale 768 / 1080), the design file 2.0, the mockup 1.348.

## Run

From the repository root, with `luajit` and Google Chrome installed:

```bash
Tools/render/shoot.sh hud_dps_mac                                               # Tools/render/out/hud_dps_mac.png at 1.426 px/unit
Tools/render/shoot.sh hud_dps_mac --class MAGE --backdrop                       # the same HUD for a mage (RENDER_CLASS does the same); see Classes below
Tools/render/shoot.sh hud_priest_mac --backdrop                                 # one class's HUD by its own scene, hud_<class>_mac
Tools/render/shoot.sh components_mac                                            # the component sheet at the owner's density
Tools/render/shoot.sh components_mac --ppu 2.0 --out Tools/render/out/components_design.png   # the sheet at the design file's density
Tools/render/shoot.sh buttons_mac --ppu 2.0                                     # every square icon button: the six states, bag slots, aura tiles, the micro menu and bag bar
Tools/render/shoot.sh buttons_toned                                             # the same with Widgets.SECONDARY_RIM at 0.5
Tools/render/shoot.sh tooltip_design --ppu 2.0 --out Tools/render/out/tooltip_design.png     # the design's item tooltip on GameTooltip, at the sheet's position
Tools/render/shoot.sh smoke --json-only                                         # the scene JSON only, no Chrome
Tools/render/shoot.sh nameplate                                                 # the target's plate on a base the game scaled to 0.58
Tools/render/shoot.sh databars                                                  # the experience bar and the data strip in the mockup's state
Tools/render/shoot.sh restedxp --backdrop                                       # the RestedXP windows the skin tests' fake builds, skinned, laid out as RestedXP lays them out (scenes/_restedxp.lua)
RENDER_BUFFS=16 Tools/render/shoot.sh auras_tracker --backdrop                  # the minimap, the aura rows beside it at 16 buffs and 3 debuffs, and the tracker at Edit Mode's preset
Tools/render/shoot.sh gallery_skins_mail --backdrop                             # one skinned Blizzard window (gallery_skins_<window>.lua, 19 of them); see Gallery below
```

`scenes/tooltip.lua` lays out a stand-in GameTooltip's lines as the game does (a 10-unit margin, each line pitched by its string height plus the custom line spacing, the padding inward); `hud.lua` uses it for its tooltip, and `tooltip_design.lua` draws the design file's item tooltip with it, so `--crop 2000,640,560,420` matches the design file's own crop at 2 px per unit.

`shoot.sh` prints the drawable count, the skipped counts (hidden, transparent, unresolved) and every log line: a texture with no local file, an unknown font object, a frame with no anchors, an atlas or a path texture the texture cache lacks (drawn as a grey box). Read the log before you trust a render. `Tools/render/out/` is ignored by git.

### Blizzard atlases and textures

```bash
python3 Tools/render/atlas.py build --scan                 # export the client's atlas tables, write the map, fetch every sheet and path texture the last renders asked for
python3 Tools/render/atlas.py build roleicon-tiny-tank     # the same, fetching the named atlases' sheets
python3 Tools/render/atlas.py fetch UI-HUD-MicroMenu-Questlog-Up --scan   # add sheets (and the scanned path textures) to an existing cache
python3 Tools/render/atlas.py paths 'Interface\TargetingFrame\UI-RaidTargetingIcons' --scan   # fetch textures named by file path
```

Run it with `~/.local/share/wow-dev/venv/bin/python` when the system Python has no Pillow; the BLP decoder needs it.

`SetAtlas(name)` draws a rectangle of a larger sheet. The UI source has no atlas data; the installed client does, in three DB2 tables (`UiTextureAtlas`, `UiTextureAtlasMember`, `UiTextureAtlasElement`). `atlas.py build` exports them with `Tools/icons/casc_export.py` (TACTTool and DBC2CSV read the game folder and never write to it), writes `~/.local/share/wow-dev/atlas/atlas.tsv`, one line per atlas name (its sheet's file ID and size, its rectangle in pixels, its size in units, its tiling flags), and fetches each named atlas's sheet into `textures/<fileID>.png`, decoded with alpha at its own size. The game looks an atlas up by its element name; an element can have a 1x member, a 2x member and Forever's own `-c60` art, and the map keeps Forever's art over the shared one and the 2x sheet over the 1x, with the size in 1x units (what `SetAtlas(name, true)` sizes a region to). The cache lives outside the repository and is never committed.

`scene.lua` reads the map when it exists: a known atlas whose sheet is in the cache draws as that sheet with the member's texture coordinates, and `useAtlasSize` gives an unsized region the member's size; a known atlas whose sheet is not fetched, or a name the client has no atlas for, draws as a grey box and is logged with the command that fetches it. Without the cache every atlas is a grey box, so CI needs none. `Scene.ATLAS` lets a test stand in for the file. `Tools/tests/test_render_atlas.py` covers the map and the fetch, `test-render-scene.lua` the drawing.

A texture the game names by file path (`SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")`) has no atlas entry. `atlas.py paths` fetches those by name through TACTTool's list mode, which looks each path up in the client's install manifest and then in the community listfile (downloaded once, 150 MB, into the cache's `tact/` folder), and decodes each into `~/.local/share/wow-dev/atlas/paths/<key>.png`, the key being the game path lowercased, with forward slashes and no extension (`interface/targetingframe/ui-raidtargetingicons`). `--scan` adds every path the scene JSON files report missing, and `build --scan` and `fetch --scan` fetch those too. `scene.lua` resolves a path through `Scene.PathKey` and draws the cached PNG when it exists; otherwise the texture is a grey box, logged with the command that fetches it, so CI needs no cache. `SetSpriteSheetCell(index, rows, columns)` draws one cell of a grid sheet, as the raid target icons are. `Scene.PATHS_DIR` lets a test point at its own folder.

### Icons, stand-ins and the backdrop

- Icons draw as a player with the icon pack installed sees them ([`docs/icons.md`](../../docs/icons.md)): a numeric file ID resolves to `Tools/icons/setB/Icons/<fileID>.png` when the pack has it, else to `~/.local/share/wow-dev/icons/blizzard/<fileID>.png`, Blizzard's own icon from the extract cache (`Common.IconDirs()` in `scenes/_common.lua`, the same list as `Scene.ICON_DIRS`). CI has neither folder and draws a flat box. The aura tiles show the repaints too: the engine sets a secret file ID, the scene reveals it, and the client would load the pack's file for it.
- `standins.py` runs before every render (`--no-standins` skips it) and cuts the renderer's stand-ins out of the handoff mockup (`~/.local/share/kstyleui-handoff/screens/mockup-leveling-warrior-2574.png`) into `Tools/render/out/standins/`: the orc and crocolisk faces that `SetPortraitTexture` would paint, the minimap's terrain, and the scenery. It also squares each class portrait it finds in `~/.local/share/kstyleui-handoff/scenery/portraits/<class>.png` (`--portraits DIR` or `KSTYLEUI_PORTRAITS`) into `portrait-player-<class>.png`; the HUD scene of that class paints it in the player portrait and falls back to the orc when the class has none. The scenes use a crop when its file exists and a flat colour when it does not, and say which in the log. Nothing from the mockup or the portraits folder is committed.
- `--backdrop [PNG]` draws the HUD over an image scaled to the canvas, by default `standins/backdrop.png`: the UI-free clean plate of the mockup's scene (`~/.local/share/kstyleui-handoff/scenery/clean.png`, or `KSTYLEUI_PLATE`, or `standins.py --plate`) scaled to the render's height and cropped to its width from the centre (the mockup is 1909 units wide, the owner's screen 1671); without a plate, the mockup's scenery with its own UI areas blurred away, which drew dark squares next to the panels. `standins.py` says which it used. `--backdrop-alpha` fades it. Measure on the flat render; the backdrop is for reading the HUD the way the game shows it.
- `glyphs.lua` holds the kit fonts' glyph advances, written by `gen_glyphs.py` from `Media/Fonts`; `scene.lua` measures a text in a kit font (or a Blizzard face the page draws as one) with them, so a chat row wraps where the page wraps it. Run `python3 Tools/render/gen_glyphs.py` when a font changes; `Tools/tests/test_render_standins.py` fails when the table is stale.

To look at a scene in a browser instead, open `Tools/render/out/<scene>.html` with Chrome started as `--allow-file-access-from-files`, or `render.html?scene=out/<scene>.json&ppu=1.426`.

## Lumen Rails

```bash
Tools/render/shoot.sh hud_lumen_questing --backdrop      # out of combat: three quests and the guide in the story slot, a party of three
Tools/render/shoot.sh hud_lumen_combat --backdrop        # in combat: a party of five, the boss card, the boss targeted and casting, the slow cards calmed
```

`scenes/_lumen.lua` builds both states of the Lumen mockup boards (`~/.local/share/kstyleui-handoff/arena2/parent/hud-questing.png` and `hud-combat.png`) on `hud.lua`. It reads the DPS layout's module settings, story slot and Apply sizes from the addon's own `Setup.Layouts`. Each module renders with the settings Layout > Apply writes. The RestedXP guide (its list resized shorter, as a player does with RestedXP's grabber) and the tracker sit in the story slot, where the setup asks the player to drop them. A free-sized element the layout sizes on Apply is sized the same way (`opts.sizes`), and the log says which. With `opts.combat`, each environment enters combat and runs half a second, so the combat calm has faded the slow cards. `Tools/regression/test-render-scenes-lumen.lua` checks the slot, the party sizes and the alphas of both states.

## Gallery

```bash
python3 Tools/render/gallery.py                      # every scenes/gallery_*.lua: render over the plate, crop each frame, write the manifest
python3 Tools/render/gallery.py gallery_widgets --no-render --out /tmp/gw   # reuse the last render; crops into /tmp/gw
```

A gallery scene (`scenes/gallery_<area>.lua`, built on `scenes/_gallery.lua`) draws one area's frames in a representative state and lists each one in `scene.frames` (`frames:Add(env, frame, { name, title, caption, grade, reference, match, pad })`): the grade it wears (`panel`, `window`, `button` or `bar`) and the mockup crop that shares that grade (`Gallery.REFERENCES`: `chat`, `tracker`, `player`, `target`, `cast`, `buffbars`, `actionbars`, `cluster`, `datastrip`, `minimap`, `nameplate`, `bufficons`, `xp`). `gallery.py` runs `shoot.sh <scene> --backdrop` for each, cuts every listed frame plus its padding out of the PNG into `~/.local/share/kstyleui-handoff/final/frames/kstyle_<name>.png`, cuts each named mockup reference at the render's density into `theme-crops/ref_<key>.png` (`REFERENCE_BOXES`, mockup pixels), and writes `kstyle_manifest.json`: a list of `{ file, title, caption, grade, reference, match, scene }`, the reference as a path relative to the frames folder. Every gallery scene renders as the owner's default does: `Gallery.Build` passes `Common.IconDirs()` to `Scene.Build`, so a numeric file ID draws set B's repaint when the pack has it, else Blizzard's icon. A scene that stands in for the aura engine sets each tile's icon as a secret (`env.Secret(fileID)`), as Forever's engine does; `scene.lua` reveals the secret when it draws, so the tiles show the pack's art as the client would. `Tools/regression/test-render-scenes-gallery.lua` builds every gallery scene and checks each frame names a grade and a reference and sits on the screen; `Tools/tests/test_render_gallery.py` covers the cropping and the manifest.

The RestedXP Guides windows the skin restyles are one gallery scene, `gallery_restedxp.lua`, built on `scenes/_restedxp.lua`: it lays the fake's v1 windows out with RestedXP's own sizes and anchors (read from the owner's screenshot and RestedXP's frame tree, written in that file's header), so the crops show how far RestedXP's text sits from the skin's glass; the active steps, the guide window, the item frame, the v2 window and the configurator are its frames. The Blizzard windows `KstyleUI_Skins` restyles are gallery scenes too: `scenes/gallery_skins_<window>.lua`, one per window (19), through `scenes/_skins.lua`, which builds the window from `Tools/regression/skins_windows.lua` (Blizzard's fields, sizes and anchors from Forever's XML, with the texts and icons a window shows in play; Blizzard's own layout is not modelled), lets the skin apply as in the game and lists the window as the frame `skins_<window>` with the grade it wears, so `gallery.py` writes `kstyle_skins_<window>.png` beside the other frames in the same manifest. `python3 Tools/render/gallery.py gallery_skins_mail` redoes one.

## Classes

```bash
python3 Tools/render/classes.py                      # every class: hud_<class>_mac over the plate, <class>.png, <class>_frames.png, manifest.json
python3 Tools/render/classes.py mage druid --no-render   # reuse the last renders; redo two classes' entries
python3 Tools/render/classes.py --notes /tmp/notes.json  # fill the manifest's notes from { "MAGE": "..." }
```

The HUD scene draws one class at a time: `hud_dps_mac` takes it from `RENDER_CLASS` (`shoot.sh --class`), and `hud_<class>_mac.lua` names it, one scene per class. `scenes/_classes.lua` holds what the game varies by class for the nine classes of WoW: Forever, in `CLASS_SORT_ORDER`: the class colour as `RAID_CLASS_COLORS` holds it, the power type and token (`Enum.PowerType`; the druid in caster form on mana), the player's cast with its cast time (none for the rogue), the two bars, the centre cluster, the buff bars and the buff row as `{ "Name", iconFileID }` pairs with the icon `Tools/data/abilities.json` gives that class's spell (so set B paints it), the stance bar's forms (the warrior's stances, the druid's forms, the rogue's Stealth), the pet (the hunter's boar, the warlock's imp) with its pet bar actions, and the rogue's combo points. The scene feeds these through the stubs' game API (`UnitClass`, `UnitPowerType`, `GetNumShapeshiftForms`, `GetPetActionInfo`, the `[@pet,exists]` driver, `GetComboPoints`), so the colour, the bars, the pet frame and the class resource come from the addon's own code paths; the player frame paints its power bar in the power type's colour (`Classes.POWER_COLORS`, the game's `PowerBarColor` lifted by `Theme.Brighten`, the module's default since the owner's ruling of 2026-11-08), so the power type reads as the fill's colour and fraction. `Hud.Build` writes the class to `scene.class` and the log. `classes.py` runs `shoot.sh hud_<class>_mac --backdrop` for each class, copies the render to `~/.local/share/kstyleui-handoff/final/classes/<class>.png`, cuts the frames close-up (`FRAMES_BOX`, the player frame, cast bar, centre cluster and bars at x 290 y 640, 1100 by 440 units, the handoff's frames crop) as `<class>_frames.png`, and writes `manifest.json`: `class`, `title`, `name`, `colour` (hex), `power`, `cast`, `file`, `frames`, `notes`. `Tools/regression/test-render-scenes-classes.lua` builds the class-driven modules for every class and checks the class colour on the health fill, the power fraction, the cast, the spells, the stance bar, the pet frame and bar and the combo points; `Tools/tests/test_render_classes.py` checks each spell pair against `abilities.json`, the colours against the stubs' table, the class portraits and the crops.

## Compare

```bash
python3 Tools/render/compare.py \
  --render Tools/render/out/hud_dps_mac.png --render-ppu 1.426 --crop 300,740,560,180u \
  --ref ~/.local/share/kstyleui-handoff/screens/mockup-leveling-warrior-2574.png --ref-ppu 1.348 --ref-crop 300,740,560,180u \
  --out Tools/render/out/cmp_player.png --label-b mockup
```

A crop is `x,y,width,height` in that image's pixels, or in screen units with a `u` suffix. The reference crop is rescaled to the render's density, so one unit is the same number of pixels on both sides. `--scale` magnifies both halves. Crop each image with its own coordinates: the mockup is 1909 units wide and the owner's screen 1671, so right-anchored elements sit at different x. The component sheet rendered at 2.0 px per unit puts each section where the design file draws it, so the same pixel box works on both (`--crop 1560,260,990,240 --ref-crop 1560,260,990,240`), except the target frame, which sits at the sheet's right end past the button states because the addon's 280-unit frames do not both fit before the design's button section, and the minimap, which starts 6 units left of the design's map because its element carries the button column outside the map. `compare.py` needs Pillow; it runs itself again with `~/.local/share/wow-dev/venv/bin/python` when the system Python has none.

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
- `Hud.Module(name, opts)` in `hud.lua` builds one HUD module; `Hud.Build(opts)` merges them all. `opts.icons` picks the icon set. `components.lua` holds the sheet's section origins. `_tracker.lua` holds the objective tracker stand-in both `hud.lua` and `tracker.lua` build, laid out as Blizzard_ObjectiveTracker lays the real one.
- `Common.StandIn(name)` gives a stand-in's path when `standins.py` has made it; `Common.IconDirs()` is the folder list a numeric icon file ID resolves through.
- The `Tools/regression/test-render-scenes-*.lua` tests build every scene (`-hud` the HUD's modules, `-classes` the class-driven modules for each class, `-focused` the focused scenes, `-gallery` the gallery scenes); add yours to the one it belongs to, or to a new file next to them, so it fails when the code it draws breaks. They share `render_scenes_lib.lua`, and a gallery scene is picked up by name.

Saved data for a scene turns a module on and marks the first-run setup seen: `{ version = 2, profiles = { Default = { UnitFrames = { enabled = true } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }`.

## What the renderer models

- Anchors: `SetPoint` in every form, by frame or by name, `SetAllPoints`, two-point stretch, sizes, `SetScale` with offsets in the child's scale, parentless frames against the screen.
- Visibility and alpha chains with `SetIgnoreParentAlpha`, and `SetAlphaFromBoolean(secret, on, off)` resolved from the revealed secret (the later of it and `SetAlpha` wins); draw order by strata, frame level (`SetUsingParentLevel`), draw layer, sublevel, creation order; HIGHLIGHT only for hovered frames.
- Textures: file paths under `Interface\AddOns\` mapped to the repository (`KstyleUI\` is the root), numeric file IDs to `Tools/icons/setB/Icons`, then `~/.local/share/wow-dev/icons/blizzard`; `SetColorTexture`, vertex colour (multiply), 4- and 8-value texcoords (affine), `ADD` as `lighter`, desaturation, rotation, gradients, REPEAT tiling at texel size, masks via `destination-in`.
- Status bars: the fill texture covers the bar times its fraction from `SetValue` over `SetMinMaxValues`, or from `SetTimerDuration` with a `{ start, finish }` object against the clock, honouring orientation and reverse fill; `SetStatusBarColor` tints the fill.
- Cooldown swipes from `SetCooldown(start, duration)` or a duration object with `start`/`finish` or `remaining`/`total`, with `SetReverse`, `SetSwipeColor`, the swipe texture as a mask, and countdown numbers unless hidden. A frame whose `GetCountdownFontString` was called draws the number through that font string, as the game does, so the addon's font, colour and anchor place it; any other cooldown draws a default 12-unit outlined number at its centre.
- Text: `SetText` and `SetFormattedText` (secrets revealed), fonts from `SetFont`, `SetFontObject` or the template name (Blizzard names map to Friz Quadrata sizes), colour, shadow, justify, word wrap, `|c`/`|r` colours, links and textures stripped. A text with no width of its own takes an estimated natural width in the solver and its measured width on the page, keeping its anchored side.
- Edit boxes draw their own text inside their text insets, from the left, and from the top when multi-line; an empty box draws nothing, so a placeholder shows through. A scroll frame's child (`SetScrollChild`) hangs from the frame's top left corner moved by the scroll offsets, as the game places it.
- A frame that clips its children (`SetClipsChildren`) bounds everything drawn under it: an item outside the frame's rect is dropped (counted as `clipped`), one across it carries the rect as `clip` and the page draws it through that rect.
- Pixel snapping: every rect edge rounds to a device pixel.
- A font string that wraps and has a width but no height of its own is as tall as its wrapped lines, counted with the glyph table at the solved width, so a text anchored under it sits under the whole paragraph (`WordWrap` off, or an explicit height, keeps one line).
- Animation groups: a group the addon played (`Play`, recorded by the stub at its clock `env._now`) is sampled at the scene's `time`: a `Translation` moves the frame by its offset times its progress (with the animation's start delay and `IN`, `OUT` and `IN_OUT` smoothing), an `Alpha` animation scales the frame's alpha between its from and to values, `REPEAT` looping wraps the clock, and a finished group leaves each animation at its end, as the game does until `OnFinished` runs. A scene that wants mid-flight numbers advances `env._now` as it ticks (`gallery_combattext.lua`). Scale animations and `SetOrder` (animations of a later order waiting for the earlier ones) are not modelled: every animation in a group starts with the group.

## Known limitations

- The stub draws no world: the portraits, the minimap and the scenery are crops of the mockup when `standins.py` has run, flat colours otherwise; the minimap's terrain draws through the mask the module set with `Minimap:SetMaskTexture` (`Hud.Terrain`), so its clipped corners read as the game draws them; icons no folder holds draw as flat boxes. A Blizzard atlas draws from the texture cache when `atlas.py` has fetched its sheet, a Blizzard texture named by file path when `atlas.py paths` has fetched it, else either is a grey box.
- Text widths that other frames depend on come from the kit fonts' glyph advances, or from average glyph widths for a face `glyphs.lua` does not list, so a frame anchored to a text in another face can sit a few units off. The page measures the real glyphs for the text itself.
- Blizzard-owned layout is not modelled: the chat window's lines and tabs, the quest tracker's blocks, the tooltip's lines and the world combat numbers over the target are laid out by the scene the way the game would, and say so in the log. Blizzard's POI buttons are not drawn, and the game fades chat tabs when the pointer is away.
- The HUD scene renders the unit frames with round portraits through a saved setting, the default the owner chose on 2026-11-08; `KstyleUI_UnitFrames` still defaults to chamfered until that change lands.
- Fonts the repository lacks (`Fonts\FRIZQT__.TTF`, `ARIALN.TTF`) fall back to Source Sans on the page; the log names them.
- Tiled textures repeat at one texel per unit of the region's own scale, which is the game's behaviour as far as the owner's screenshots show; check the grain against a screenshot before trusting it.
- Motion is sampled: scenes tick tweens with `W.Tick` and hold the clock, so a fade or a cast reads mid-way, not at a precise frame. Animation groups are sampled at the scene's clock as above; a `Scale` animation is not applied.
- The fake aura engine lays out no buttons, so a scene with the Auras module lays them out itself (`Hud.PlaceAuras`, from the container's flow anchor along its growth directions) and counts the rest as unresolved; the module's own preview tiles draw. The quest tracker stand-in sits where Forever's Edit Mode preset puts the real one (`TOPRIGHT` of `UIParent` at -110, -275); the owner's own Edit Mode layout may differ.
- Chrome's canvas does the compositing, so `multiply` tinting and `destination-in` masking are exact to 8 bits; the game's blend modes other than `BLEND` and `ADD` draw as `BLEND`.
