# Core visuals reference

The core's visual service files carry one comment each, their first line, so their contracts live here, as [`core-services.md`](core-services.md) does for the other services. The roadmap's [Core public API](superpowers/plans/2026-11-07-kstyleui-roadmap.md#core-public-api) names stay binding. This page adds the details and the extra functions. Tests: `Tools/regression/test-tokens.lua`, `test-theme.lua`, `test-pixels.lua`, `test-motion.lua` and `test-appearance.lua`.

## Tokens

`Core/Tokens.lua` is the only addon file where a colour literal may appear. `test-tokens.lua` runs `Tools/regression/color_lint.lua` over every TOC-loaded Lua and XML file and fails on a hex string, a `|cAARRGGBB` escape, a six or eight-digit `0x` number, a `*Color(` or `*Colour(` call whose first three arguments are numbers, a `{ r = , g = , b = }` table of numbers, or an XML `<...Color r= g= b=>`. Every accessor raises an error for an unknown name, so a typo fails its module's test.

### Colours

`Color(name) -> r, g, b, a`, each from 0 to 1. The Lumen palette comes from the mockup's `:root` (`~/.local/share/kstyleui-handoff/arena2/parent/index.html`); the older names map onto it, so modules that ask for them draw Lumen.

| Name | Value | Use |
| --- | --- | --- |
| `deep`, `surface` | `#0e1217` at 75% | The card fill of the owner's picture of 2026-11-09; `surface` is the name every chrome fills with |
| `rim` | `#d6eeff` at 55% | The mockup's rim light, for callers that still draw one |
| `edgeInner` | `#869094` at 16% | A card's muted rim, one line inside its edge, as the picture draws it |
| `socketEdge` | `#000000` at 94% | The near-black edge line of tiles, sockets and buttons |
| `rimSoft` | `#d6eeff` at 18% | The rim-soft line on its own |
| `edgeFaint` | `#d6eeff` at 8% | Neutral dividers |
| `edgeBar` | `#d6eeff` at 14% | The bar grade's faint rim, the mockup's `.bar` inset line |
| `edgeOuter` | `#000000` at 55% | A card's dark edge line |
| `giltLit`, `gilt`, `giltDim` | `#f3dca4`, `#d3b574`, `#8a6c34` | Gold as punctuation: `gilt` is the picture's L-tick gold; gems, caption heads and the proc edge are `giltLit` |
| `buttonFill` | `#0e1217` at 50% | The socket body: icon buttons, tiles and the kit's controls |
| `raised` | `#1a2633` at 85% | The tone a pressed, cooling or unusable icon button lifts its body toward; no chrome fills with it (`test-grades.lua`) |
| `track` | `#05090e` at 70% | The empty part of bars and sliders, the mockup's `.bar` track |
| `text`, `muted` | `#a9b6c2` | Body text at rest; the mockup's muted tone |
| `textEmphasis` | `#f2f5f8` | Titles and values, the mockup's text colour |
| `textHover` | `#ffffff` | Text under the mouse |
| `textDisabled`, `dim` | `#6f7d8a` | Disabled and dim text |
| `rare`, `epic` | `#4fc3ff`, `#b67cff` | Item quality |
| `hostile`, `neutral`, `friendly` | `#e2524f`, `#e8c14f`, `#62d58d` | Reactions; `friend` is the same green |
| `magic`, `quest` | `#5aa9ff`, `#f6d27a` | The mockup's signal colours for magic and quests |
| `questGold` | `#f2cf55` | The quest titles on the story card, as the owner's picture of 2026-11-09 draws them (242, 207, 85); the quest card and the tracker skin read it through `Lumen.Color("questGold")` |
| `healthHostile` | `#e03b3f` | A hostile unit frame's health fill |
| `accentDefault` | `#aad372` | The fallback and default custom accent; the class colour stays the accent |
| `shadow` | `#000000` at 45% | The card shadow's tint |
| `textShadow` | `#000000` at 85% | Text shadow |
| `white`, `black` | | Plain tints, such as resetting a vertex colour |
| `schoolPhysical`, `schoolHoly`, `schoolFire`, `schoolNature`, `schoolFrost`, `schoolShadow`, `schoolArcane` | `#d8c3a0`, `#ffe27a`, `#ff8a3d`, `#6fdc5a`, `#6fd6ff`, `#9d7bff`, `#e07bff` | Spell school colours; the combat text's school colour mode reads them |
| `accent` | live | `Theme.Accent()` at full alpha |

### Grades

Every chrome wears one of the kit's grades: the card (panel, card, window and rail, each with gilt L-ticks), the socket (tile and socket) and the bar (a pill track). [Chrome](../Core/Widgets/README.md#chrome) lists each grade's layers; `test-lumen-material.lua` holds them, and `test-grades.lua` fails on a chrome filled with `raised` or on any use of the retired chamfer drawing. Rows in the options window have no chrome of their own: they sit on the window's glass and light their text on hover.

### Sizes, durations and easings

`Size(name)` returns root units at the 1080 reference: the padding radii `radius` 14 (cards, panels, windows, rails) and `radiusTile` 8 (tiles and sockets), with the older names `chamferPanel` 14, `chamferWindow` 14 and `chamferTile` 8 reading the same values; the corners drawn are whole border lines, not these (see [Corner sizes](../Core/Widgets/README.md#corner-sizes)); `shadow` 14 (how far the card shadow reaches) and `shadowOffset` 3 (its drop, baked into `lumenShadow`); `tick` 15 (how far a gilt L-tick reaches from the card's edge) and `gem` 16 (the gem texture's square); Lumen's spacing scale `gapSmall` 4, `gapMedium` 8, `gapLarge` 12, `gapHuge` 16, `gapXLarge` 20 and `gapXXLarge` 28, with `gapTiny` 2; the rail column `railWidth` 318, `railPadding` 20, `sectionGap` 22, `rowGap` 12, `socketGap` 8 and `screenMargin` 17 (the owner's picture of 2026-11-09; it was 28); `actionButton` 34, `actionGap` 3, `cooldownEssential` 40, `cooldownUtility` 30, `unitFrameWidth` 220, `unitFrameHeight` 46, `portrait` 46, `buffBarWidth` 180, `buffBarHeight` 18; the type sizes `display` 22, `heading` 16, `body` 12, `caption` 9, `number` 12 and `world` 13; `textShadowOffset` 0.6, `pressOffset` 1, `panelRise` 16, `panelOvershoot` 2 and `rowHeight` 24. Body, number and world sizes are one unit up from Source Sans's because Alegreya Sans's x-height is smaller (458 to 465 against 491 per 1000), so each role keeps its apparent size and the frames their footprints; the mockup's larger type scale (body 15) comes with the layout. A panel's content inset is not a token: `Widgets.Inset(frame, radius, gap)` derives it from the radius and the rim (see [Chrome](../Core/Widgets/README.md#chrome)).

`Share(name)` returns a plain fraction. No share is defined now: `radiusSocket` is retired, because a socket's corner is three border lines at every size.

`Duration(name)` returns seconds and `Easing(name)` the name of a `Motion.Ease` function:

| Name | Duration | Easing |
| --- | --- | --- |
| `hover` | 0.12 | `outQuad` |
| `combatIn` | 0.24 | `outCubic` |
| `combatOut` | 0.6, after `combatOutDelay` 3 | `inOutSine` |
| `panelOpen` | 0.25 | `outSine` |
| `panelRise` | 0.4 | `outBack` |
| `panelClose` | 0.15 | `outQuad` |
| `fade` | 0.2 | `outQuad` |
| `listStagger` | 0.05 | |
| `castSheen` | 0.6 | |
| `procPulse` | 0.7, Lumen's proc breathing (alpha only) | |

### Fonts

`Font(role) -> path, size, flags`.

| Role | Lumen face | Size | Flags | Tracking | Uppercase |
| --- | --- | --- | --- | --- | --- |
| `display` | Cinzel SemiBold | 22 | `""` | 0.6 | |
| `heading` | Cinzel SemiBold | 16 | `""` | 0.4 | |
| `body` | Alegreya Sans Tabular | 12 | `""` | 0 | |
| `caption` | Cinzel SemiBold | 9 | `""` | 1.4 | yes |
| `caps` | Cinzel Caps (Medium, spaced 0.065 em) | 10 | `""` | 0 | yes |
| `names` | Cinzel Names (Medium, spaced 0.02 em) | 10 | `""` | 0 | yes |
| `number` | Alegreya Sans Tabular Bold | 12 | `""` | 0 | |
| `world` | Alegreya Sans Tabular Medium | 13 | `"OUTLINE"` | 0 | |

The face comes from `Theme.FontFace()`. Its default, `"Lumen"`, is a font set: each role takes the face in the table. Any other choice (a key of `MediaList("font")`, such as Source Sans 3 Semibold, or a font file path such as a LibSharedMedia font) sets every role to that face, except `number`, which then uses Source Sans 3 Semibold for its tabular digits. The game applies no OpenType features, so Alegreya Sans's `tnum` and `lnum` cannot be turned on; the bundled Alegreya Sans Tabular files map the digits to the font's own tabular lining figures instead (`Media/PROVENANCE.md`), so numbers keep their width without a fixed-width reservation. The caption role is Cinzel, tracked, for rail section caps; a module that sets dense small text in `caption` reads it in Cinzel until it moves that text to `body` or `number`. Every role but `world` is multiplied by `Theme.FontScale()`, the Appearance page's text size; text over the 3D world keeps its size. UI text takes a soft shadow (`textShadow`, offset `textShadowOffset`) instead of an outline; text over the 3D world takes the thin outline.

`TextStyle(role) -> tracking, uppercase` gives the kit's letter spacing in units. The game has no letter-spacing setter, so widgets treat it as a hint.

Two roles carry the picture's letter-spaced Cinzel capitals, both at 10 units (a 21-pixel face on the owner's screen), each from its own file whose advances hold the spacing, because the game has no letter-spacing call and Cinzel has no thin space. `caps` is the gold captions (SKYBORNE, QUESTS, DAMAGE, the chat tabs): `Media/Fonts/CinzelCaps-Medium.ttf`, Cinzel Medium with every advance 0.065 em wider, drawn without a text shadow, in `capsGold` (#d3b574) for card captions. `names` is the white names (the zone, unit, spell and nameplate names): `Media/Fonts/CinzelNames-Medium.ttf`, the same weight 0.02 em wider, with the kit's soft shadow, in the text colour of the module that uses it (the picture's white headings fit almost no tracking). `Media/PROVENANCE.md` has the proof from the Forever source and how each number was measured. Both faces draw each lowercase letter as its capital, so a name Lua cannot uppercase (a secret) still reads in capitals. `Tokens.FaceTracking(path) -> em` is the face's tracking (0.065 and 0.02) and 0 for every other path, including the game's own font that stands in for them on `ruRU`, `zhCN`, `zhTW` and `koKR`. `Tokens.FaceShadow(path)` is false for the caps file, whose text `Widgets.ApplyFont` and `Widgets.TextShadow` leave without a shadow, and true for every other path. The files stay out of `MediaList("font")`, so no picker offers them; `Tokens.RoleFontPaths()` lists them for `Fonts` to request while the game loads. Text set in either leaves a tracking-wide gap after its last letter, which `Widgets.ApplyFont` and `Widgets.SyncTracking` take back (`Widgets/README.md`).

`FontPath(key)` returns a face's file, or `nil` for an unknown key; `FontPath("Lumen")` is the body face. `DEFAULT_FONT_FACE` is `"Lumen"`.

### Media lists

`MediaList(kind) -> { { key, label, path }, ... }`, a fresh copy, for `"font"` (Cinzel SemiBold, Alegreya Sans, Alegreya Sans Medium, Alegreya Sans Bold, Source Sans 3 Semibold, Source Sans 3, Inter SemiBold: real faces, which path pickers list and LibSharedMedia registers), `"fontSet"` (Lumen, which only the Appearance face list offers) and `"statusbar"` (Glass, Soft, Flat).

### Textures

`Texture(name) -> path, sliceTexels, sliceUnits`. `Media/PROVENANCE.md` describes each file and how it was drawn; `Tools/media/make_media.py` draws them all.

| Name | File | Slice margin | Use |
| --- | --- | --- | --- |
| `lumenShape` | `LumenShape.png`, 128x128 | 56 texels (14 units) | The rounded card: chrome fills, the dispel tint |
| `cardShape` | `CardShape.png`, 128x128 | 56 texels | The card fill: the same rounded shape, a file of its own so the render guard tells a card from a socket |
| `ringLine2` to `ringLine6`, `ringLine8`, `10`, `12`, `16`, `20`, `24`, `32` | `RingLineN.png`, 128x128 | 64 texels | A ring one line thick on a corner N lines round: a card's edge (6), its rim and tick arcs (5), a socket's edge (3) and rim (2); the larger counts serve pinned corners and discs |
| `lumenOutline` | `LumenOutline.png`, 128x128 | 32 texels | An even outline at the 8-unit radius: highlight rings, the proc rim |
| `lumenShadow` | `LumenShadow.png`, 128x128 | 56 texels at 2 per unit | The card shadow with its drop baked in and the card cut out |
| `chamferTile` | `LumenShape.png` | 56 texels | The older name, kept for modules that slice it |
| `gem` | `LumenGem.png` | | The section cap gem, its facets shaded in the colour channels |
| `pillCapLeft`, `pillCapRight`, `barSheen` | | | The bar fill's round-end masks (set with `CLAMPTOWHITE`) and its top sheen |
| `lensMask` | `LensMask.png`, 512x512 | | A round mask, for round portraits and discs |
| `ruleFade` | `RuleFade.png`, 256x4 | | A rule that fades out to the right |
| `iconMask` | `SocketMask.png`, 128x128 | | Every square icon, rounded 3 units on 44 to meet the socket's inner corner |
| `portraitMask` | `PortraitMask.png`, 128x128 | | The square portrait, rounded 8 units on 44 inside its frame's rounder corner |
| `shadow` | `Shadow.png`, 128x128 | 24 texels | A square soft falloff for glows (unit frame glows, a bar's own-colour glow) |
| `ringBevel` | `RingBevel.png`, 128x128: a 5-texel line from radius 57 to 62 whose colour channels shade it dark outside, lit in the middle and three quarters inside | | tinted once (the accent lifted 30% toward white) it is the mockup's thin metal ring; a portrait inside starts `Widgets.RING_INSET` (8/128 of the size) in |
| `minimapMask` | `MinimapMask.png`, 512x512 | | The minimap's chamfered square mask; its cut is a share of the side, which `KstyleUI_Minimap/Format.lua` gives the rim's chamfer |
| `glow`, `divider`, `noise`, `ring`, `barFlat`, `barSoft`, `barGlass`, `logo`, `logoLarge` | | | |
| `dot`, `pill` | `Dot.png` 64x64, `Pill.png` 64x32 | | |
| `glyphChevron`, `glyphClose` | `GlyphChevron.png`, `GlyphClose.png`, 32x32 | | |

`dot` and `pill` are the knobs and tracks of toggles and sliders. Each round cap of the pill is a quarter of its width, so a widget three-slices it at any length. `glyphChevron` and `glyphClose` are line glyphs for dropdowns, scroll steppers and close buttons; flip the chevron's texture coordinates to point it up.

Shapes are white with their coverage in alpha: tint them with `SetVertexColor`. Between its margins a sliced texture has the same column everywhere, and the same row everywhere, so it stretches cleanly as nine `SetTexCoord` pieces. Draw a corner piece at `Scale.Snap(radius)` so it covers whole pixels. A ring line has no centre: its corner pieces meet in the middle and the kit draws its straight runs as solid lines. The new textures need a full client restart the first time.

## Theme

`Core/Theme.lua` resolves the accent and gives colours for classes, items and reactions.

| Function | Behaviour |
| --- | --- |
| `Accent() -> r, g, b` | The player's class colour, or the custom colour. |
| `Class() -> classFile` | The player's class, such as `"MAGE"`, or `nil` while it is unknown. |
| `AccentSource()`, `SetAccentSource(source) -> ok` | `"class"` or `"custom"`. |
| `CustomAccent()`, `SetCustomAccent(r, g, b) -> ok` | Each channel a plain number from 0 to 1; a secret, NaN or a string is refused. |
| `FontFace()`, `SetFontFace(face) -> ok` | `"Lumen"` (the default font set), a key of `Tokens.MediaList("font")`, or a font file path that `IsFontPath` accepts. Anything else is refused. |
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
| `UserScale()`, `SetUserScale(size) -> ok` | The requested size, clamped to `MIN_USER_SCALE` 0.6 and `MAX_USER_SCALE` 1.5, without rewriting the saved setting. |
| `AppliedUserScale()`, `MaxUserScale()` | The applied size and the current preset's screen-fit maximum. The root uses the smaller of the request and maximum. |

The root's scale is `768 / 1080 / UIParent:GetEffectiveScale() * appliedSize`, so it is `1080 / appliedSize` units tall on the normal UIParent canvas. One pixel is `768 / (physicalHeight * root:GetEffectiveScale())` units, read from the root's real effective scale. The border is `max(1, round(pixels per unit))` pixels: 1 px at 1080p and 1440p and 2 px at 4K and on a 3456x2234 Mac at a size of 1. A larger size thickens the border with everything else.

`Setup.Layouts.ScaleLimit(width, height, preset)` computes the largest fit to sub-pixel search precision, never below the shipped `16 / 19`. It checks the preset's default footprints and story slot, not saved positions or sizes. It snaps each footprint’s size first, then aligns its anchored bottom-left as Layout.Place does; all bounds and unintended overlaps are strict, with only the micro-menu/bag-bar shared dock boundary permitted at most one physical pixel of vertical contact. Docked content and mutually exclusive party/raid frames are intentional intersections. A descending search handles quantization islands before refining the last boundary; a monotonic binary search alone can stop at the wrong island. The result is cached per preset and screen dimensions. At 2383x1540 the caps are about 0.891 DPS, 0.890 Tank and 0.973 Healer; widening the aspect can restore more of a saved larger request. A higher-resolution screen with the same aspect does not make the proportional layout larger: it changes rounding, not the available reference units.

The Interface size slider displays the applied value and the fit maximum, while the settings schema keeps its storage range of 0.6–1.5 so profiles retain larger requests. Display, preset and profile changes recompute the applied size. Resizes and moves a player made in Layout Mode never lower the cap.

The root rescales at `PLAYER_LOGIN`, `UI_SCALE_CHANGED` and `DISPLAY_SIZE_CHANGED`, plus one recheck on the next frame for a size the engine settles late. `ScaleChanged` fires when either screen dimension, `UIParent`'s scale, the size or the fit maximum changed since the last rescale. Redraw borders, snapped sizes and fonts in a `ScaleChanged` handler (Review Focus item 2).

Secure frames on the root make `SetScale` protected in combat. A rescale in combat waits for `Combat.Queue`, once however many events arrive. `PLAYER_LOGIN` rescales even in combat, the one moment protected setup may run after a reload. A secret or missing screen size falls back to 1080 lines and a devlog line.

The source contract was checked against Forever 1.60.1.70862 (`~/.capy/work/wow-ui-source-70862/Interface/AddOns`): `Blizzard_SharedXML/PixelUtil.lua` derives pixels from `768 / physicalHeight` and the region's effective scale; `ScreenDocumentation.lua` documents `GetPhysicalScreenSize`; `SimpleFrameAPIDocumentation.lua` marks effective scale as potentially secret and scale setters as protected; `VideoDocumentation.lua` and `UIManagerDocumentation.lua` define both display/scale events. These documentation files live under `Blizzard_APIDocumentationGenerated`. `Blizzard_SettingsDefinitions_Shared/Graphics.lua` owns the `useUiScale` and `uiscale` CVars (0.65–1.15); KstyleUI does not write them and compensates the actual UIParent scale instead. Texture texel snapping is separate from layout/font sizing: `SimpleTextureBaseAPIDocumentation.lua` documents the texture setters, and `Blizzard_SharedXML/NineSlice.lua` disables texel snapping for sliced artwork. Font strings have font-height and shadow methods, not texture texel-snapping methods. Native `SetRoundLayoutToNearestPixel` exists but is protected; this change does not rely on undocumented inheritance or native rasterization behavior.

The regression matrix measures the Lua values before the renderer rounds anything. The canvas renderer cannot prove Forever's glyph hinting, texture filtering, masks, live secret status-bar fills, engine aura flow, moving nameplates or UIParent's notch/debug-bar placement. Inspect those in the client after a display change and a combat-deferred rescale; a smooth animation intentionally passes through sub-pixel positions between its snapped endpoints.

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
| `uiScale` | `16 / 19` (`Scale.DEFAULT_USER_SCALE`) | slider from 0.6 to 1.5 in steps of 0.05 | `Scale.SetUserScale` |
| `motion` | `"full"` | dropdown: full, reduced or off | `Motion.SetLevel` |

The font is a dropdown, not a `font` row, because a bundled face is stored by its key of `Tokens.MediaList("font")`. Its options are a function, built when the list opens: the bundled faces, then each LibSharedMedia font (from `Widgets.MediaOptions("font")`) stored by its path, skipping paths the bundled faces already cover. A profile that names a LibSharedMedia font the importing player does not have fails `Store.Import`'s choice check, as any unknown dropdown value does.

| Function | Behaviour |
| --- | --- |
| `Get(key) -> value` | The active profile's value. A value the setting does not allow (an unknown accent source or face, a colour channel outside 0 to 1) gives the default and a devlog line. A size outside 0.6 to 1.5, or a text size outside 0.8 to 1.3, is clamped. Before the saved data loads, the default. An unknown key raises an error. |
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
