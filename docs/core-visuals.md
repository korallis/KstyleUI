# Core visuals reference

The core's visual service files carry one comment each, their first line, so their contracts live here, as [`core-services.md`](core-services.md) does for the other services. The roadmap's [Core public API](superpowers/plans/2026-11-07-kstyleui-roadmap.md#core-public-api) names stay binding. This page adds the details and the extra functions. Tests: `Tools/regression/test-tokens.lua`, `test-theme.lua`, `test-pixels.lua`, `test-motion.lua` and `test-appearance.lua`.

## Tokens

`Core/Tokens.lua` is the only addon file where a colour literal may appear. `test-tokens.lua` runs `Tools/regression/color_lint.lua` over every TOC-loaded Lua and XML file and fails on a hex string, a `|cAARRGGBB` escape, a six or eight-digit `0x` number, a `*Color(` or `*Colour(` call whose first three arguments are numbers, a `{ r = , g = , b = }` table of numbers, or an XML `<...Color r= g= b=>`. Every accessor raises an error for an unknown name, so a typo fails its module's test.

### Colours

`Color(name) -> r, g, b, a`, each from 0 to 1.

| Name | Value | Use |
| --- | --- | --- |
| `surface` | `#151a20` at 97% | Panels: the mockup's glass, measured against the UI-free plate of its scene (fill #14191e to #161c22, alpha 0.97 to 1.0 on every panel) |
| `raised` | `#1c1c1c` | The tone a pressed, cooling or unusable icon button lifts its body toward; no chrome fills with it (`test-grades.lua`) |
| `edgeOuter` | `#000000` at 80% | The dark line on every panel's edge, the mockup's #101214 line outside the light one |
| `edgeInner` | `#ffffff` at 28% | The light line one border inside the edge: the mockup's panel line reads lum 85 to 100 over its fill |
| `edgeFaint` | `#ffffff` at 8% | Neutral dividers |
| `edgeBar` | `#ffffff` at 16% | The bar grade's light line: the mockup's buff bars and cast bar wear a fainter edge (lum 40 to 78) |
| `buttonFill` | `#101214` | The button body, the mockup's one solid dark tone: see [Grades](#grades) for every element that wears it |
| `text` | `#ababab` | Body text at rest |
| `textEmphasis` | `#ffffff` | Titles and values, the design's TEXT-HI |
| `textHover` | `#ffffff` | Text under the mouse |
| `textDisabled` | `#666666` | Disabled text |
| `rare`, `epic` | `#4fc3ff`, `#b67cff` | Item quality |
| `hostile`, `neutral`, `friendly` | `#e5534b`, `#e8c14f`, `#5fcf72` | Reactions, tuned for the glass |
| `healthHostile` | `#e03b3f` | A hostile unit frame's health fill, the kit sheet's red under the Glass texture |
| `accentDefault` | `#aad372` | The kit's accent: the fallback and the default custom accent |
| `shadow` | `#000000` at 60% | Panel shadow tint; the mockup's panels darken the scene to 0.4 to 0.8 just outside the edge |
| `textShadow` | `#000000` at 80% | Text shadow |
| `track` | `#000000` at 45% | The empty part of bars and sliders |
| `white`, `black` | | Plain tints, such as resetting a vertex colour |
| `schoolPhysical`, `schoolHoly`, `schoolFire`, `schoolNature`, `schoolFrost`, `schoolShadow`, `schoolArcane` | `#d8c3a0`, `#ffe27a`, `#ff8a3d`, `#6fdc5a`, `#6fd6ff`, `#9d7bff`, `#e07bff` | Spell school tints for icon set A, read through `KstyleUI.Icons.SchoolColor` |
| `accent` | live | `Theme.Accent()` at full alpha |

### Grades

The mockup draws three backdrop grades (`~/.local/share/kstyleui-handoff/THEME_SPEC.md`), and every chrome in the addon wears one of them; `test-grades.lua` fails on a chrome filled with any other tone. Where each grade is used today, after the theme work of 2026-11-08:

| Grade | Chrome | Worn by |
| --- | --- | --- |
| Glass panel | `surface` fill at `panelOpacity`, the `edgeOuter` line outside the bevelled `edgeInner` line and its fade row, a corner cut of 30% of the shorter side up to the shape's cap (`chamferPanel` 12, `chamferWindow` 12), the drop shadow | Every `Widgets.Panel` and window (the options and setup windows, the bags, the meters, the chat glass and tabs, the quest tracker, the RestedXP and Blizzard window skins in `Core/Skin.lua`), the unit frames' glass, the cast bar's glass, the group frames' tiles, the nameplate frame, the minimap footer, the dropdown's shared menu, tooltips |
| Button | `buttonFill` body, one border of the rim colour, a `buttonBezel` plate outside the rim on icon buttons, no shadow of its own | Action buttons, bag slots, cooldown icons, aura tiles and the bezel around them; the kit's inputs and controls: `Button`, `EditBox`, `TextArea`, the `Dropdown` box, `ColorSwatch`, the `Tabs` strip, the tooltip's item icon; the unit frames' portrait frame and level badge, the group frames' level disc, the minimap's column plates and N plate, the data strip pill, the combat text preview's sample frame |
| Bar / track | `surface` fill, the bevelled `edgeBar` line, a cut of 30% of the height up to the tile cap (`chamferTile` 6), no shadow | `Widgets.StatusBar` chrome: buff bars, the cast bar's track, the experience, reputation and honour bars, the meters' swing bar; the hairline under a unit frame's health track |
| Track inside a bar | `buttonFill`, no edge | The empty part of the unit frames' health and power bars and of the group frames' bars: the mockup's dark #101214 track |

`raised` fills no chrome. It is only the tone an icon button's body tints toward while pressed, cooling or unusable. Rows in the options window have no chrome of their own: they sit on the window's glass and light their text on hover.

### Sizes, durations and easings

`Size(name)` returns root units at the 1080 reference: the corner-cut caps `chamferPanel` 12, `chamferTile` 6 and `chamferWindow` 12 (a chrome cuts `Share("chamfer")` of its shorter side, 30%, up to its shape's cap; see [Corner sizes](../Core/Widgets/README.md#corner-sizes)), `shadow` 10 (how far the shadow reaches out), `shadowOffset` 2 (how far it drops), `buttonBezel` 3 (the dark plate outside an icon button's rim), `actionButton` 34, `actionGap` 3, `cooldownEssential` 40, `cooldownUtility` 30, `unitFrameWidth` 220, `unitFrameHeight` 46, `portrait` 46, `buffBarWidth` 180, `buffBarHeight` 18, the type sizes `display` 24, `heading` 16, `body` 11, `caption` 9, `number` 11 and `world` 12, `textShadowOffset` 0.6, `pressOffset` 1, `panelRise` 16, `panelOvershoot` 2, the gaps `gapTiny` 2, `gapSmall` 4, `gapMedium` 8, `gapLarge` 12 and `gapHuge` 16, `panelPadding` 16 and `rowHeight` 24.

`Share(name)` returns a plain fraction: `chamfer` 0.3, the corner cut as a share of a backdrop's shorter side, measured on the mockup's cast bar (11 of 37 units), data strip, nameplate frame and unit frames; and `chamferIcon` 0.12, an icon button's cut as a share of its side (the mockup's cluster buttons cut 13%, its action buttons 10 to 12%).

`Duration(name)` returns seconds and `Easing(name)` the name of a `Motion.Ease` function:

| Name | Duration | Easing |
| --- | --- | --- |
| `hover` | 0.15 | `outQuart` |
| `panelOpen` | 0.25 | `outSine` |
| `panelRise` | 0.4 | `outBack` |
| `panelClose` | 0.15 | `outQuad` |
| `fade` | 0.2 | `outQuad` |
| `listStagger` | 0.05 | |
| `castSheen` | 0.6 | |
| `procPulse` | 1.2 | |

### Fonts

`Font(role) -> path, size, flags`.

| Role | Face | Size | Flags | Tracking | Uppercase |
| --- | --- | --- | --- | --- | --- |
| `display` | the UI face | 24 | `""` | -0.5 | |
| `heading` | the UI face | 16 | `""` | -0.3 | |
| `body` | the UI face | 11 | `""` | 0 | |
| `caption` | the UI face | 9 | `""` | 1.5 | yes |
| `number` | Source Sans 3 Semibold | 11 | `""` | 0 | |
| `world` | the UI face | 12 | `"OUTLINE"` | 0 | |

The UI face is `Theme.FontFace()`, Source Sans 3 Semibold by default: a key of `MediaList("font")`, or a font file path such as a LibSharedMedia font. Every role but `world` is multiplied by `Theme.FontScale()`, the Appearance page's text size, so `Font("body")` at a text size of 1.2 is 13.2 units; text over the 3D world keeps its size. `number` always uses Source Sans 3 Semibold because its digits are tabular, so health and timers keep their width. UI text takes a soft shadow (`textShadow`, offset `textShadowOffset`) instead of an outline; text over the 3D world takes the thin outline. `SLUG` is not set: the spec allows it only after the font spike confirms it renders cleanly.

`TextStyle(role) -> tracking, uppercase` gives the kit's letter spacing in units. The game has no letter-spacing setter, so widgets treat it as a hint.

`FontPath(key)` returns a face's file, or `nil` for an unknown key. `DEFAULT_FONT_FACE` is `"SourceSans3Semibold"`.

### Media lists

`MediaList(kind) -> { { key, label, path }, ... }`, a fresh copy, for `"font"` (Source Sans 3 Semibold, Source Sans 3, Inter SemiBold) and `"statusbar"` (Glass, Soft, Flat).

### Textures

`Texture(name) -> path, sliceTexels, sliceUnits`. `Media/PROVENANCE.md` describes each file and how it was drawn.

| Name | File | Slice margin | Corner piece |
| --- | --- | --- | --- |
| `chamferPanel` | `ChamferPanel.png`, 128x128 | 32 texels | drawn at 8 units; `Chrome` stretches the corner piece to the cut it computes |
| `chamferTile` | `ChamferTile.png`, 32x32 | 14 texels | drawn at 3.5 units, stretched the same way |
| `chamferWindow` | `ChamferWindow.png`, 128x128 | 48 texels | drawn at 12 units |
| `line` | `Line.png`, 4x4: one opaque row (row 1) between clear rows | | mapped onto each chamfer's diagonal by `Widgets.LayoutLine` |
| `shadow` | `Shadow.png`, 128x128 | 24 texels | 12 units in the texture; `Chrome` draws the corner at twice `Size("shadow")`, so the shadow reaches 10 units out, and drops it `shadowOffset` |
| `iconMask` | `ChamferIconMask.png`, a 3-unit chamfer on a 34-unit square | | |
| `ringBevel` | `RingBevel.png`, 128x128: a 5-texel line from radius 57 to 62 whose colour channels shade it dark outside, lit in the middle and three quarters inside | | tinted once (the accent lifted 30% toward white) it is the mockup's thin metal ring; a portrait inside starts `Widgets.RING_INSET` (8/128 of the size) in |
| `glow`, `divider`, `noise`, `ring`, `barFlat`, `barSoft`, `barGlass`, `minimapMask`, `logo`, `logoLarge` | | | |
| `dot`, `pill` | `Dot.png` 64x64, `Pill.png` 64x32 | | |
| `glyphChevron`, `glyphClose` | `GlyphChevron.png`, `GlyphClose.png`, 32x32 | | |

`dot` and `pill` are the knobs and tracks of toggles and sliders. Each round cap of the pill is a quarter of its width, so a widget three-slices it at any length. `glyphChevron` and `glyphClose` are line glyphs for dropdowns, scroll steppers and close buttons; flip the chevron's texture coordinates to point it up.

Shapes are white with their coverage in alpha: tint them with `SetVertexColor`. A sliced texture has the same row and column everywhere between its margins, so it stretches cleanly as a native slice (`SetTextureSliceMargins`), as nine `SetTexCoord` pieces, or as a mask on a square region. Draw a corner piece at `Scale.Snap(sliceUnits)` so it covers whole pixels. Bevel lines are drawn in code by `Widgets.Line`: the straight edges as solid textures `Scale.Border()` thick, and each corner as the `line` strip mapped onto the chamfer's diagonal, so a line is one border thick while the chamfer keeps its size in units on every screen. Blizzard's Forever code never slices a mask, so use `iconMask` on square icons and portraits rather than a sliced mask.

## Theme

`Core/Theme.lua` resolves the accent and gives colours for classes, items and reactions.

| Function | Behaviour |
| --- | --- |
| `Accent() -> r, g, b` | The player's class colour, or the custom colour. |
| `Class() -> classFile` | The player's class, such as `"MAGE"`, or `nil` while it is unknown. |
| `AccentSource()`, `SetAccentSource(source) -> ok` | `"class"` or `"custom"`. |
| `CustomAccent()`, `SetCustomAccent(r, g, b) -> ok` | Each channel a plain number from 0 to 1; a secret, NaN or a string is refused. |
| `FontFace()`, `SetFontFace(face) -> ok` | A key of `Tokens.MediaList("font")`, or a font file path that `IsFontPath` accepts. Anything else is refused. |
| `IsFontPath(path) -> boolean` | True for a string of up to 260 characters with a `\` or `/`, ending in `.ttf` or `.otf` in any case, with no control character and no `\|`. |
| `FontScale()`, `SetFontScale(scale) -> ok` | The text size, a plain number from `MIN_FONT_SCALE` 0.8 to `MAX_FONT_SCALE` 1.3, default 1. A secret, NaN or a value out of range is refused. A change fires `ThemeChanged`, which restyles every kit text. |
| `ClassColor(classFile) -> r, g, b` | Any unit's class colour as plain numbers, safe for arithmetic such as `Brighten`. An unknown or secret class gives the `text` colour: the colour the game returns for a secret class has secret channels, so it is never used here. |
| `ClassColorForWidget(classFile) -> r, g, b` | For widget setters only (`SetStatusBarColor`, `SetTextColor`, `SetVertexColor` and the kit's `SetBarColor`). A secret class name goes to `C_ClassColor.GetClassColor(file):GetRGB()` inside `pcall`, and the secret channels are passed on whole. Never compare them or do arithmetic on them. A plain class gives `ClassColor`. |
| `ThreatColor(status) -> r, g, b` | A threat status from `UnitThreatSituation`: 1 `neutral`, 2 halfway from `neutral` to `hostile`, 3 `hostile`. Any other status, a secret or `nil` gives `nil`. Unit frames, group frames and nameplates use it, so one threat state has one colour across the HUD. |
| `QualityColor(quality) -> r, g, b` | Rare and epic from the tokens. Other qualities from `C_Item.GetItemQualityColor`, else `ITEM_QUALITY_COLORS`, lifted by `Brighten`. |
| `ReactionColor(reaction) -> r, g, b` | 1 to 3 `hostile`, 4 `neutral`, 5 to 8 `friendly`. A secret or missing reaction gives `neutral`. |
| `Brighten(r, g, b) -> r, g, b` | Mixes toward white until the relative luminance reaches `MIN_LUMINANCE` (0.3), so the hue stays. |

The class colour comes from `C_ClassColor.GetClassColor`, then `RAID_CLASS_COLORS`, then `accentDefault`. A secret or missing class gives `accentDefault` and a devlog line. Colour values that are not plain numbers are never used.

The accent resolves on first use without firing anything, and again at `PLAYER_LOGIN`. A login on a class other than the last one announced fires `ClassChanged(newClass, oldClass)` and then, when the accent changed, `ThemeChanged`. The new accent is in place before either fires, so every open window restyles from its `ThemeChanged` handler (Review Focus item 1). A login on the same class fires nothing. Each setter fires `ThemeChanged` only when the result changes.

## Scale

`Core/Scale.lua` owns `KstyleUI_Root` and the whole-pixel maths.

| Function | Behaviour |
| --- | --- |
| `Root() -> Frame` | `KstyleUI_Root`, created at load on `UIParent` with `SetAllPoints(UIParent)`. |
| `Pixel(n) -> units` | `n` whole physical pixels in root units. |
| `Border() -> units` | The border line: about one unit, in whole pixels. |
| `Snap(units) -> units` | The nearest whole physical pixel. |
| `UserScale()`, `SetUserScale(size) -> ok` | The size setting, clamped to `MIN_USER_SCALE` 0.75 and `MAX_USER_SCALE` 1.5. |

The root's scale is `768 / 1080 / UIParent:GetEffectiveScale() * size`, so it is `1080 / size` units tall on every screen. One pixel is `768 / (physicalHeight * root:GetEffectiveScale())` units, read from the root's real effective scale. The border is `max(1, round(pixels per unit))` pixels: 1 px at 1080p and 1440p and 2 px at 4K and on a 3456x2234 Mac at a size of 1. A larger size thickens the border with everything else.

The root rescales at `PLAYER_LOGIN`, `UI_SCALE_CHANGED` and `DISPLAY_SIZE_CHANGED`, plus one recheck on the next frame for a size the engine settles late. `ScaleChanged` fires when the screen height, `UIParent`'s scale or the size changed since the last rescale. Redraw borders and snapped sizes in a `ScaleChanged` handler (Review Focus item 2).

Secure frames on the root make `SetScale` protected in combat. A rescale in combat waits for `Combat.Queue`, once however many events arrive. `PLAYER_LOGIN` rescales even in combat, the one moment protected setup may run after a reload. A secret or missing screen size falls back to 1080 lines and a devlog line.

## Motion

`Core/Motion.lua` holds the easings, the tween driver and the fades.

`Ease[name](t)` for `linear`, `outSine`, `inOutSine`, `outQuad`, `outQuart`, `outQuint` and `outBack` (Penner's formulas, `outBack` peaking about 10% past the end). Each clamps `t` to 0..1.

| Function | Behaviour |
| --- | --- |
| `Tween(obj, setter, from, to, duration, easing, onDone) -> handle` | `setter` is `function(obj, value)` or a method name such as `"SetAlpha"`. `easing` is a name, a function, or `outQuad` by default; an unknown name raises an error. The start value is set at once. A new tween on the same object and setter replaces the old one, whose `onDone` never runs. `onDone(obj)` runs after the end value is set. |
| `Stop(handle, finish) -> stopped` | Stops a tween. With `finish`, sets the end value and runs `onDone`. A stale handle does nothing. |
| `IsPlaying(handle) -> boolean` | |
| `FadeIn(frame, duration, alpha) -> handle` | Shows a hidden frame at alpha 0 and fades it to `alpha` (1) over `duration` (`panelOpen`). |
| `FadeOut(frame, duration) -> handle` | Fades a shown frame to 0 over `duration` (`panelClose`), hides it and restores the alpha the last FadeIn aimed at, so a plain `Show` later shows it. A FadeIn during a FadeOut cancels the hide. A hidden frame returns `nil`. |
| `Level()`, `SetLevel(level) -> ok` | `"full"`, `"reduced"` or `"off"`; anything else is refused. `"off"` finishes every running tween. |
| `ReducedMotion() -> boolean` | True at `"reduced"` and `"off"`. Widgets check it to skip movement: the panel rise and overshoot, the scroll bounce, the cast sheen and the proc pulse. |
| `SetReducedMotion(on) -> ok` | `SetLevel("off")` or `SetLevel("full")`, for callers that only switch motion on and off. |

At `"reduced"` tweens still play, so fades, hover transitions and eased scrolling stay; only movement stops.

`Tween` returns `nil` and sets the end value at once, running `onDone` before it returns, when the level is `"off"`, for a duration that is not a positive number, or when `from` or `to` is a secret. Secrets reach the setter untouched; the engine animates them. Otherwise `from` and `to` must be numbers, or `Tween` raises an error. A setter that fails on the start value raises its error to the caller and leaves nothing registered.

One driver frame runs one `OnUpdate`, only while a tween plays. Records come from a pool and handles are numbers, so a stale handle never reaches a reused record. Each frame stamps the records it steps, so a tween that a callback starts or moves is stepped at most once per frame. The step allocates nothing: `test-motion.lua` runs 1000 frames of 20 tweens with the garbage collector stopped. A failing easing, setter or `onDone` goes to `geterrorhandler()` and drops only its tween.

`IsShown`, `GetAlpha` and `IsProtected` can return secrets on Forever, so the fades never branch on one: a secret visibility changes alpha only. On a protected frame in combat a fade changes alpha only, because `Show` and `Hide` are protected there.

The spec's AnimationGroup presets (proc pulse, cast sheen, panel rise) belong to the widgets that play them. Their timings are in `Tokens`.

## Appearance

`Core/Appearance.lua` holds the player's look settings and hands them to `Theme`, `Scale` and `Motion`. It loads after `Options.lua`, registers its defaults with `Store.RegisterDefaults("Appearance", defaults)` and its settings page with `Options.Register("Appearance", schema)` at load.

| Setting | Default | Row | Drives |
| --- | --- | --- | --- |
| `accentSource` | `"class"` | dropdown: class colour or custom colour | `Theme.SetAccentSource` |
| `accentColor` | the kit's accent, from `Tokens.Color("accentDefault")` | colour, shown only for a custom accent | `Theme.SetCustomAccent` |
| `font` | `"SourceSans3Semibold"` | dropdown: the three bundled faces, then LibSharedMedia's fonts | `Theme.SetFontFace` |
| `fontScale` | `1` | slider from 0.8 to 1.3 in steps of 0.05 | `Theme.SetFontScale` |
| `uiScale` | `1` | slider from 0.75 to 1.5 in steps of 0.05 | `Scale.SetUserScale` |
| `motion` | `"full"` | dropdown: full, reduced or off | `Motion.SetLevel` |

The font is a dropdown, not a `font` row, because a bundled face is stored by its key of `Tokens.MediaList("font")`. Its options are a function, built when the list opens: the bundled faces, then each LibSharedMedia font (from `Widgets.MediaOptions("font")`) stored by its path, skipping paths the bundled faces already cover. A profile that names a LibSharedMedia font the importing player does not have fails `Store.Import`'s choice check, as any unknown dropdown value does.

| Function | Behaviour |
| --- | --- |
| `Get(key) -> value` | The active profile's value. A value the setting does not allow (an unknown accent source or face, a colour channel outside 0 to 1) gives the default and a devlog line. A size outside 0.75 to 1.5, or a text size outside 0.8 to 1.3, is clamped. Before the saved data loads, the default. An unknown key raises an error. |
| `Apply()` | Hands every setting to its service. The custom colour goes before the accent source, so switching to a custom accent fires `ThemeChanged` once. |
| `defaults`, `schema` | The tables registered with `Store` and `Options`. |

When the settings apply:

1. `ADDON_LOADED` for `KstyleUI`, right after `Store` loads the saved data, so the size and the accent are right before `PLAYER_LOGIN` builds frames.
2. `PLAYER_LOGIN`, again, in case the saved data loaded late.
3. `SettingChanged` for the `Appearance` page: the one setting that changed. The settings window writes through `Options.Write`, which fires it.
4. `ProfileChanged`: every setting of the new profile.

The accent itself is never saved. A profile shared by characters of different classes stores only the accent source and the custom colour, so each character gets its own class colour at login.

### LibSharedMedia

At `PLAYER_LOGIN`, if `LibStub` is loaded and `LibStub("LibSharedMedia-3.0", true)` returns the library, `Appearance` registers the three fonts and the three status bar textures under `KstyleUI <label>`, for example `KstyleUI Source Sans 3 Semibold` and `KstyleUI Glass`. It does this once. KstyleUI never loads or embeds the library. A library that raises an error while registering is counted in a devlog line and never stops login.

## Fonts

This client loads a font file only when something first asks for it during a loading screen. A file first asked for later makes `SetFont` return `false` for the rest of the session, so the text falls back to `GameFontHighlight`. The first in-game test showed this: Source Sans 3 Semibold failed in the setup window, which opens after loading, and loaded after the reload. Fonts declared in XML, as Narcissus does, are asked for while loading.

`Core/Fonts.lua` loads after `Appearance.lua`. It keeps one hidden `Font` object per font path and asks for:

- the three bundled faces, when the file loads;
- every font path in the active profile, at any depth, at KstyleUI's `ADDON_LOADED` and again at `PLAYER_LOGIN`;
- a font path in a changed setting (`SettingChanged`), and every font path in a new profile (`ProfileChanged`).

A font that fails while the game loads, such as one from a removed addon, gets one devlog line. A font chosen later that the game refuses prints `KstyleUI: the font <file> shows after you type /reload.` once per font. After the reload, `Fonts.lua` asks for it while loading.

| Function | Behaviour |
| --- | --- |
| `Fonts.Request(path) -> loaded` | Asks the game for the font at `path` and returns whether it loaded. A loaded font is not asked for again. A value that is not a `.ttf` or `.otf` path, or a client without `CreateFont`, returns `false` and raises nothing. |
| `Fonts.IsLoaded(path) -> boolean` | Whether `path` has loaded this session. |

Tests: `Tools/regression/test-fonts.lua`.
