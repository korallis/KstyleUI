# Widget kit

`KstyleUI.Widgets` is the component kit every KstyleUI window and module builds its UI from. Each component matches [`docs/design/mockups/05_kit_hunter.jpg`](../../docs/design/mockups/05_kit_hunter.jpg). `Core/Widgets/Widgets.xml` loads the files in order: `Base.lua` first, then one file per component.

The roadmap's [Core public API](../../docs/superpowers/plans/2026-11-07-kstyleui-roadmap.md#core-public-api) names stay binding. This page lists every function, its options and its behaviour. Tests: `Tools/regression/test-widgets-*.lua`, which load the core through `Tools/regression/widget_env.lua`.

## Rules every component follows

- Colours, sizes, durations, easings, fonts and textures come from `KstyleUI.Tokens` only.
- Sizes and offsets are snapped to whole physical pixels in each frame's own scale, with `Widgets.Snap`. Lines are one `Widgets.Border(frame)` thick. `Widgets.Crisp(texture)` gives solid lines `SetSnapToPixelGrid(true)` and `SetTexelSnappingBias(0)`. Sliced art instead disables texel snapping with `SetSnapToPixelGrid(false)` and zero bias, as Forever’s `Blizzard_SharedXML/NineSlice.lua` does; its geometry is already snapped by the kit. Both setters are guarded for a client without them. The straight runs of an edge line, a rim and an outline (`ringLine2` to `ringLine6`, `lumenOutline`) are solid lines one border thick; only the four corners sample the texture. The texture's 3-texel line is 0.75 px at 1080p and 1.07 px on a 2383 x 1540 screen at UI scale 768 / 1080, so it landed between pixels (owner pass 1). `test-pixels.lua` checks both screens.
- Text sizes and shadows land on whole physical pixels: `Widgets.ApplyFont(text, path, size, flags) -> ok` snaps `size` in the text's own scale (`Widgets.FontSize(text, size)`) and sets a one-border shadow down and right in `textShadow`, or none for flagged faces (`Widgets.TextShadow(text, flags)`). `StyleText` and every module that sets its own font use it. A frame whose scale changes outside `ScaleChanged`, such as a Layout Mode element, calls `Widgets.RestyleUnder({ [frame] = true })` or its own `Restyle()` to redraw. Layout does this for each scalable element, once per frame however many wheel ticks arrive.
- Every component registers with `Widgets.Track`, so it restyles on `ThemeChanged`, `ScaleChanged`, `ProfileChanged`, a change to a setting on the `Widgets` page, and a change to the Appearance page's `motion` setting.
- Hover and press run through `KstyleUI.Motion`: hover is `Tokens.Duration("hover")` with `outQuart`, and press moves the content down `Tokens.Size("pressOffset")`.
- Components hook scripts with `HookScript`. A component built on a secure template keeps the template's own `OnClick`.
- A protected frame is never moved in combat. Content offsets and chrome anchors wait, and chrome re-anchors through `Combat.Queue` once combat ends.
- Secret values are never compared. A secret string reaches `SetText` untouched.
- Components never call `SetScript`, `Hide` or `SetParent` on a Blizzard frame, and never write fields onto one.

## Settings

The kit registers the `Widgets` settings page with `Store.RegisterDefaults` and `Options.Register` at load.

| Key | Default | Row | Effect |
| --- | --- | --- | --- |
| `cardMaterial` | `ForgedBrackets`, the owner's choice of 2026-11-10 | dropdown: Glass, Flat, Slate, ForgedTicks, ForgedBrackets | The card-grade surface and caption finish; no changes to bars or sockets |
| `panelOpacity` | the `surface` token's alpha, 0.75 | slider, 0.5 to 1 in steps of 0.01 | Absolute Glass alpha; other materials scale their authored fill and grain opacity relative to 0.75 |
| `shadows` | `true` | toggle | Shows the shadow of panels, windows and tooltips |
| `sounds` | `true` | toggle | Plays the kit's click and open sounds |
| `tooltipScale` | `1` | slider, 0.75 to 1.5 in steps of 0.05 | The scale of `Widgets.Tooltip()` |

`Widgets.Setting(key) -> value` returns the active profile's value, or the default before the saved data loads or when the saved value is not allowed. An unknown key raises an error. `Widgets.defaults` and `Widgets.schema` hold the registered tables.

## Shared helpers (`Base.lua`)

| Function | Behaviour |
| --- | --- |
| `Track(widget) -> widget` | Adds `widget` to the restyle registry. `widget:Restyle()` runs on every restyle event. A failing `Restyle` is reported through `KstyleUI.Call` and the rest still run. |
| `RestyleAll()` | Runs every tracked `Restyle`. |
| `RestyleUnder(roots)` | Runs the `Restyle` of each tracked widget inside one of the frames in the set `roots` (`{ [frame] = true }`), found through `GetParent`. A widget is its own frame, or the `owner`, `holder`, `frame`, `bar` or `button` of a handle. A handle with none of these restyles too, to be safe. |
| `FontString(parent, layer) -> FontString` | A font string in `layer` (default `OVERLAY`) that already has a font: a private copy of `GameFontHighlight` with no shadow. In the game, `SetText` on a font string with no font raises "Font not set" and stops the caller, so addon code makes every font string here and styles it after. `Tools/regression/test-fontstrings.lua` fails on any other `CreateFontString` call. |
| `Cover(overlay, visual) -> placed` | Anchors `overlay` to `UIParent` exactly over `visual`'s screen rect, at the overlay's scale, and sizes it to match. It never anchors to `visual`: the game refuses to anchor a protected frame to a region, or to a frame whose anchors lead to one. Every shared secure overlay (Reload, the minimap's buttons, the data strip) uses it. While the overlay shows, a 0.1 second ticker re-places it when `visual`'s rect changes, out of combat only, and stops when the overlay hides. Returns `false`, and changes nothing, when `visual` has no rect yet. |
| `Text(parent, role, colorName, layer) -> FontString` | A font string in the role's font (`Tokens.Font`), with the soft `textShadow` shadow offset by `textShadowOffset`, coloured `colorName` (default `text`), in `layer` (default `OVERLAY`). A face change restyles every text made here. |
| `StyleText(text, role)` | Applies a role's font and shadow to any font string and adds it to the face-change list. A font the game cannot load falls back to `GameFontHighlight` and logs once. A role with font flags, such as `world`, gets no shadow. |
| `SetText(text, value)` | Sets the text. A role whose `Tokens.TextStyle` is upper case, such as `caption`, upper-cases it. `nil` clears it. A secret passes through untouched. |
| `TextColor(text, name, alphaScale)` | Sets a token colour on a font string. |
| `TextWidth(text, fallback)`, `TextHeight(text, fallback)` | The string's size, or `fallback` when the game gives no plain number. A text in a tracked face (the `caps` role) measures to its last letter's ink: the tracking the font leaves after the last letter, `TrackPad(text)`, is not part of the width. |
| `TrackPad(text) -> units` | The tracking a tracked face leaves after the last letter, 0 for any other font. Anchor something to the right edge of tracked text with `gap - TrackPad(text)` to leave `gap` from the ink. |
| `SyncTracking(text)` | Reads the text's font and takes the trailing tracking back, whichever call set the font (`Widgets.ApplyFont` calls it; `Style.ApplyFont` in Skins does too). A text in a tracked face has its anchors shifted by half the pad when it is centred and by the whole pad when it is right-aligned, so the ink, not the box, sits where the caller put it: the first anchor's side decides for a text that shrinks to its string, the justification for one with a width or anchors on both sides. `GetPoint` still answers the caller's offsets. |
| `Rgba(name, alphaScale) -> r, g, b, a` | A token colour with its alpha scaled. |
| `Tint(region, name, alphaScale)` | `SetVertexColor` with a token colour. |
| `Mix(r1, g1, b1, a1, r2, g2, b2, a2, t)`, `MixTokens(nameA, alphaA, nameB, alphaB, t)` | Linear mix of two colours. |
| `ScaleFactor(frame) -> number` | The frame's effective scale over `KstyleUI_Root`'s: 1 for a frame at the root's scale, 1.25 for a tooltip at a size of 1.25. A secret or missing scale gives 1. |
| `Snap(frame, units) -> units`, `Border(frame) -> units` | `Scale.Snap` and `Scale.Border` in the frame's own units, so a frame with its own scale still draws whole pixels. Every component snaps through these. |
| `Inset(frame, radius, gap) -> units`, `WindowInset(frame) -> units` | The one content-inset rule: where text and art start inside a chrome's edge. Half the corner radius (a corner rounded `r` units only needs 0.29 `r`, so half clears the arc with room), plus the rim (`Border(frame)`), plus a gap token, `gapSmall` by default (about 12 units at the 14-unit card radius) or `gapMedium` for windows (about 16, the padding every window and dialog uses; `WindowInset` is that at the card radius). Snapped in the frame's own units; `frame` may be nil for root units. A chrome answers it for its own radius as `chrome:Inset(gap)`. Every text panel pads with it: the kit's panels, dialogs and tooltips, the meters, the chat glass, the data strip, the tracker's caption row and the RestedXP glass, so nothing sits in a corner's arc or on the rim, and `Tools/regression/test-widgets-inset.lua` holds the rule. |
| `Size(frame, width, height)` | `SetSize` snapped to whole pixels in the frame's units. |
| `Clamp(v, low, high)` | |
| `Hover(widget, on)`, `Press(widget, down)` | Tween `widget.hoverT` and `widget.pressT` between 0 and 1 and call `widget:Paint()` on each step. |
| `PressOffset(widget) -> units` | How far the content sits below rest, snapped. |
| `MayMove(frame) -> boolean` | False for a protected frame in combat. A secret `IsProtected` counts as protected. |
| `HookPointer(frame)` | Hooks `OnEnter`, `OnLeave`, `OnMouseDown`, `OnMouseUp`, `OnEnable`, `OnDisable` and `OnClick`. Hover and press call `Hover` and `Press`. A click plays `U_CHAT_SCROLL_BUTTON` and runs `frame.onClick(frame, mouseButton)`. |
| `EscapeCloses(frame, fn)` | Escape runs `fn(frame)` while the frame is shown; every other key reaches the game. See [Escape](#escape). |
| `Place(frame, key, position, opts)` | Puts the frame at `position = { anchor, x, y }` on `KstyleUI_Root`, then calls `KstyleUI.Layout.Register(frame, key, position, opts)`. Without the Layout service it logs the key and keeps the default position. |
| `Sound(kit)` | `PlaySound(SOUNDKIT[kit])` while the `sounds` setting is on. Silent when `PlaySound`, `SOUNDKIT` or the kit is missing. |
| `Log(message)`, `LogOnce(key, message)` | Devlog lines under the `Widgets` module. |
| `IsSecret(value) -> boolean` | `issecretvalue`, false when the function is missing. |

### Escape

`SetPropagateKeyboardInput` is protected in combat, so:

- Out of combat the frame takes the keyboard with propagation on. Escape turns propagation off for that key only, then runs `fn`.
- Hiding the frame and `PLAYER_REGEN_DISABLED`, which fires before lockdown, turn propagation back on, so a frame never swallows keys in combat.
- In combat Escape still runs `fn`, and the key also reaches the game.
- A frame made in combat takes the keyboard through `Combat.Queue` once combat ends.

## Chrome

`opts.popup = true` marks an existing floating surface at construction: non-Glass materials paint an opaque fill even on a tile, while a tile retains its small edge dimensions and never receives the card's forged frame/brackets. Flat and Slate apply their material rim tint. The flag is forwarded by Panel and Skin backdrop/window helpers. Glass stays unchanged; ordinary embedded tiles are not opted in. See [Popup surfaces](../../docs/popup-materials.md) for consumers and deliberate exceptions.

The layer and corner recipes below describe the retained Glass treatment. Since the owner's 2026-11-10 choice (LEE-106), card-grade chrome defaults to `ForgedBrackets`: the fill keeps its geometry but uses opaque charcoal, a repeating interior grain and a pixel-density-specific forged frame. Four brackets replace the gilt ticks. `ForgedTicks` keeps the ticks; Flat and Slate keep the legacy borders. Explicit edges and proc rims remain above the forged frame. Deferred or too-small frames keep their legacy border until the forged frame can be placed. [Card materials](../../docs/card-materials.md) covers the five choices, profile inheritance and native checks. This does not alter socket or bar chrome, content insets or typography.

`Chrome(owner, opts) -> chrome` draws a component's material on `owner`'s own layers, the owner's picture of 2026-11-09: baked textures from `Tools/media/make_media.py`, white with their coverage in alpha and tinted with tokens, so nothing is blurred live.

An owner exposing the native menu compositor's `AttachTexture` uses that pool instead of raw `CreateTexture`, including deferred frame/grain allocation during resize. Such chrome is acquisition-local: it does not enter the persistent widget restyle registry. The caller must call `chrome:Release()` on menu release and discard it, then close/rebuild its menu when settings change. Release invalidates size, restyle and queued material/layout work without touching released regions. Blizzard's pool reset is documented to call `FreeScripts`; whether that removes every extrinsic size hook is not proven in game, so the released-state guard makes a surviving hook inert. Ordinary widget owners keep their existing allocation and restyle lifecycle.

| Part | Layer | What it is |
| --- | --- | --- |
| `chrome.shadow` | `BACKGROUND` -8 | The nine-sliced `lumenShadow` texture, corner pieces twice `Size("shadow")` centred on the owner's corners, tinted `shadow`. Its 3-unit drop is baked in and the card's rounded shape is cut out of it. Shown only while the `shadows` setting is on, which it is not by default: the owner's picture casts none. |
| `chrome.fill` | `BACKGROUND` -7 | The nine-sliced fill one border line inside the edge: `cardShape` for cards, panels, windows and rails, `lumenShape` for tiles and sockets, its corner pieces one line less than the corner (see [Corner sizes](#corner-sizes)), tinted with the fill token: `surface` for cards, `buttonFill` for tiles and sockets. |
| `chrome.line` | `BORDER` -3 | The edge line, one border thick on the owner's edge: the nine-sliced `ringLineN` on an N-line corner, its straight runs solid lines. `edgeOuter` on cards, `socketEdge` on tiles and sockets; `giltLit` while a proc is up. |
| `chrome.rim` | `BORDER` -2 | The rim, one border thick and one line inside the edge line, on the fill's corner. Tinted with the edge token (`edgeInner` by default); hover, selection and an icon's quality colour light it. |
| `chrome.gilt` | `BORDER` -1 | Cards, panels, windows and rails: two gilt L-ticks, at the top left and the bottom right, each the rim's corner arc and two legs one border thick, reaching `Size("tick")` units from the outer edge, snapped to whole pixels, tinted `gilt`. A frame shorter than two ticks, or a chrome with a pinned radius, shows none. |
| Bars | | A bar's `fill` is `lumenShape` and its `rim` the even `lumenOutline`, at a radius of half the bar's short side, so the track is a capsule whether the bar lies down or stands up. No shadow, edge line or gilt. |

`opts`: `shape` (`"panel"`, `"card"`, `"window"`, `"rail"`, `"tile"`, `"socket"` or `"bar"`), `radius` (units, pinning the corner; `chamfer` is the older name for it), `share` (the corner as a share of the owner's shorter side), `fill` (a colour token; `surface` by default, `buttonFill` for tiles and sockets), `edge` (the rim's token, default `edgeInner`; bars default to `edgeBar`), `shadow` (wanted by default on cards, panels, windows and rails, off for tiles, sockets and bars; the `shadows` setting shows it), `gilt` (`false` leaves a card's ticks off). The field `shapeName` holds the shape. Every chrome hooks its owner's `OnSizeChanged` and re-lays itself out when its corner or its ticks change.

The grades follow the owner's picture of 2026-11-09 ("let the picture win"); the frost glass and grain of the mockup's surface recipes are retired:

| Grade | Shapes | Chrome | Used by |
| --- | --- | --- | --- |
| Card | `panel`, `card`, `window`, `rail` | the `surface` fill, the `edgeOuter` edge line, the `edgeInner` rim, six-line corners and gilt L-ticks at the top left and bottom right | every backdrop, titled panels, dialogs, tooltips, Blizzard window skins, the rails and the HUD cards, the story card included |
| Socket | `tile`, `socket` | the `buttonFill` body at 50%, the near-black `socketEdge` line on three-line corners and a rim one line in, no gilt; the edge turns gold (`giltLit`) only while `SetProc(true)` | icon buttons, aura tiles, bag slots, text buttons, edit boxes, tab strips and the other controls |
| Bar | `bar` | a capsule track (`surface` with the faint `edgeBar` rim, corners half the short side); a bordered horizontal `StatusBar` adds the fill's round caps, top sheen and own-colour glow | status bars, swing timers, skinned timer and progress bars |

No chrome fills with the `raised` tone; `Tools/regression/test-grades.lua` fails on one, on any use of the retired chamfer drawing (`Line`, `LayoutLine`, `ColorLine`, the `chamferPanel`, `chamferWindow` and `line` textures) and on any name of the retired frost glass. `raised` remains the tone a pressed, cooling or unusable icon button lifts its body toward. `test-lumen-material.lua` holds the grades.

A Glass `surface` fill takes its alpha from the `panelOpacity` setting. Other materials multiply their authored alpha by `panelOpacity / 0.75`, capped at 1; forged frames and brackets follow that strength too. A pinned `radius`/`chamfer`, a proportional `share`, or `grain = false` opts out of material replacement, preserving custom silhouettes such as nameplate badges. The shadow shows only while `shadows` is on.

| Method | Behaviour |
| --- | --- |
| `SetFill(name, alphaScale)`, `SetFillRGBA(r, g, b, a)` | Recolours the fill. A caller's colour, or a token at a scaled alpha, stays through a restyle. Both reuse one table per chrome, so they allocate nothing on combat paths. |
| `SetEdge(name, alphaScale)`, `SetEdgeRGBA(r, g, b, a)` | Recolours the rim, the line that hover and selection light up. |
| `SetProc(on)` | Lights the edge line gold (`giltLit`) while on; the edge colour returns when it ends. |
| `SetRadius(units)`, `SetChamfer(units)` | Pins the corner to `units` (never more than half the shorter side) and re-lays the chrome out when it differs; `nil` unpins it. `Radius()`, and `Chamfer()` for older callers, return the corner drawn: the pinned value, or the shape's line count times `Border(owner)`, at most half the owner's shorter side. |
| `Inset(gap)` | `Widgets.Inset(owner, PadRadius(), gap)`: where the owner's content starts inside this chrome's edge. `PadRadius()` keeps the old 14 and 8 unit caps (`radius`, `radiusTile`), so content sits where it did before the corners became whole lines. |
| `SetShadow(on)`, `SetShown(shown)` | `SetShown` hides and shows every layer. |
| `Restyle()` | Re-anchors every piece in whole pixels and repaints. |

`Pill(box, layer, sublevel) -> list` draws the `pill` texture over a frame as a left cap, a middle and a right cap; `LayoutPill(pill, height)` makes each cap half the height wide. `NineSlice(owner, textureName, layer, sublevel) -> list`, `LayoutSlice(slice, owner, cornerUnits, outsetUnits, dropUnits, scaleFrame)`, `ColorSlice(slice, r, g, b, a)` and `ShowSlice(slice, shown)` build and place any sliced texture; `cornerUnits` and `outsetUnits` are units snapped to whole pixels in `scaleFrame`'s units (the owner by default; a region that is not a frame, such as a status bar's fill, passes its frame), so a `lumenOutline` slice laid out with a chrome's `Radius()` lines up with it. `TEXTURE_TEXELS` holds each sliced texture's size in texels; `test-widgets-kit.lua` checks it against the PNG files.

### Corner sizes

Forged card frames use 8, 16 or 24 physical-pixel corner slices for one-, two- or three-pixel borders. Their art changes the finish only; `PadRadius()` and the card fill's anchors are unchanged. The following ring rules remain the Glass, socket and fallback recipes.

A corner is a whole number of border lines, so the edge line, its arc and the straight runs land on the same physical pixels on every screen (the owner's picture of 2026-11-09): six lines for cards, panels, windows and rails, three for tiles and sockets, at every size. No corner is more than half the owner's shorter side, so a short strip becomes a pill. The fill and the rim sit one line inside the edge line, on a corner one line smaller. `make_media.py` draws a ring texture for the line counts 2 to 6, 8, 10, 12, 16, 20, 24 and 32, and `Chrome` picks the one nearest the corner it lays out, so a pinned corner (the minimap, a portrait, a nameplate disc) keeps an arc about one line thick:

| Piece | Texels | Drawn |
| --- | --- | --- |
| Edge line (`ringLineN`) | 64 | `N` border lines square, `N` the corner's line count |
| Fill (`cardShape`, `lumenShape`) and rim (`ringLineN`) | 56 and 64 | one line less, one line inside the edge |
| Gilt L-tick | | the rim's corner arc, and legs one line thick out to `Snap(Size("tick"))` from the edge |
| Shadow (`lumenShadow`) | 56 | `Snap(2 * Size("shadow"))`, centred on the corner |

Content padding does not follow the drawn corner: `PadRadius()` keeps `Size("radius")` (14) for cards and `Size("radiusTile")` (8) for tiles and sockets, at most half the shorter side. `test-pixels.lua` checks every corner on the four screens at sizes 0.75 to 1.5: the edge line, the fill, the rim and every tick piece are whole pixels, and a tick reaches the nearest whole pixel to the token.

## Section cap

With either forged material, `PaintCapMaterial` substitutes the original forged diamond and tapered rule in `materialGold`; their rectangles, the caption's font and the count's position do not change. The owner's LEE-106 material ruling permits that finish change. The following solid-diamond/flat-rule recipe remains the Glass, Flat and Slate treatment.

`SectionCap(parent, opts) -> Frame` heads a rail section as the owner's picture draws it (LEE-70, the picture wins over the faceted gem and the fading rule): the card's solid flat diamond (the kit's `diamond` texture, `capsGold`, 8 root units from point to point, 14 pixels on the reference panel: the one mark the Skins caption bullet draws too; `test-widgets-sectioncap.lua` holds it within a pixel on nine screens), the caption in the `caps` role at 12 units (Cinzel Medium spaced by its own font file, upper case, `capsGold`, the rule starting one gap after the last letter), a flat rule one border line thick in `capsGold` at half strength that does not fade, and an optional count at the right end in the `number` role, muted. Options: `text`, `count`, `width` (default 278, a rail's width inside its padding), `name`. `SetText(text)` and `SetCount(value)` (nil hides it; a secret reaches the font string untouched) change them; the rule runs from the caption to the count, or to the cap's right end. For a count another frame draws at the right end, `MeasureCount(text)` returns the text's width in the count's font, measured on a ruler font string that is never shown, and `SetReserve(width)` (nil clears it) stops the rule that width and a gap short of the right end; the cap's own count stays hidden and empty. Never park placeholder text in `count` and hide it with alpha: the client can draw it again on a later `SetTextColor`. `test-widgets-sectioncap.lua` holds it.

`SetWrapWidth(width) -> height` opts a count-free section cap into wrapping within that width. Options uses it for localized headers: a long caption takes as many lines as it needs and hides the rule, and the caller gives the row the returned height plus its padding. A short caption keeps the normal single-line rule. Text changes and restyles refit the caption; caps that never opt in keep their existing geometry.

`Widgets.RING_INSET` (8/128) is where a portrait starts inside the `ringBevel` texture: the ring's line runs from radius 57 to 62 of 64, so a round portrait insets `size * RING_INSET` each side and the dark disc under it shows outside the line and between the line and the image, the mockup's thin metal ring on a dark band. The unit frames tint it with the accent lifted 30% toward white; the texture's shading turns that into a dark bronze outer edge, the bright line and the accent inside.

## Panel

`Panel(parent, opts) -> Frame`. The default parent is `KstyleUI_Root`.

| Option | Effect |
| --- | --- |
| `width`, `height` | Snapped size |
| `title` | Adds the title bar: an upper-case `body` title, as the design's PANEL TITLE, and a drag area when `movable` is set. As on the kit's glass panel, no line sits under the title. |
| `close` | Adds a close button that calls `panel:Close()` |
| `onClose(panel)` | Runs when the panel closes |
| `escape` | Escape closes the panel |
| `movable`, `onMoved(panel)` | Drag by the title bar, clamped to the screen |
| `shape`, `fill`, `shadow` | Passed to `Chrome`. The default shape is `window` for a panel with a title bar (`title`, `close` or `movable`) and `panel` otherwise. |
| `strata`, `name`, `hidden` | |
| `layout = { key, position, options }` | Calls `Widgets.Place` with them |

Fields: `chrome`, `content` (a frame one `chrome:Inset("gapMedium")` inside, below the title bar), `titleBar`, `titleText`, `closeButton`, `rise` and `riseParts` (the open animation).

| Method | Behaviour |
| --- | --- |
| `Open()` | Fades in over `panelOpen` and plays the rise: down `panelRise`, up past rest by `panelOvershoot`, then back. The three translations add up to 0, so nothing jumps when the group ends. Reduced motion skips the rise. |
| `Close()` | Fades out over `panelClose`, hides, and runs `onClose`. |
| `Toggle()`, `SetTitle(text)`, `Restyle()` | |

## Button

`Button(parent, opts) -> Button`: a rounded tile on the button grade's body (`buttonFill`) with a centred label.

Options: `text`, `width` (default: the text plus `gapLarge` each side, at least 80), `height` (default `rowHeight` + `gapSmall`), `onClick(button, mouseButton)`, `primary` (the hairline rests on the accent and the text on `textEmphasis`), `template`, `name`, `tooltip` (see [Tooltip](#tooltip)).

| State | Hairline | Text |
| --- | --- | --- |
| Rest | `edgeInner` | `text` |
| Hover | `accent` | `textHover` |
| Pressed | | Moves down `pressOffset` |
| Disabled (`button:Disable()`) | `edgeInner` | `textDisabled` |

Methods: `SetText(text)` (resizes an automatic width), `GetText()`, `Paint()`, `Restyle()`. Field: `label`.

`CloseButton(parent, onClick) -> Button`: a 20-unit button with the `glyphClose` cross, `text` at rest and `textHover` under the mouse.

## IconButton

`IconButton(parent, opts) -> Button`: a rounded socket for action, cooldown and aura icons.

Options: `size` (default `actionButton`, 34), `icon`, `template` (such as `SecureActionButtonTemplate`), `name`, `onClick`, `tooltip`, `crop` (`false` keeps the full texture; Blizzard icons are cropped 7% each side), `hideNumbers` (hides the cooldown countdown), `countdownCorner` (the countdown hangs right-aligned in the top right corner, a fifth of the side in and a tenth down, as the composition mockup's centre cluster reads "4s"; the default is the design's centred number low on the button), `silent` (no click sound, for buttons that keys press, such as action buttons), `primary` (an action button: its rim is always the full accent rim; see [Icon chrome](#icon-chrome) for the secondary rim strength every other icon button follows).

The body is the socket's `buttonFill`, its near-black edge line on corners three border lines round, drawn by [`IconChrome`](#icon-chrome), the picture's action button; the soft card shadow under it shows only while the `shadows` setting is on. The icon sits two borders inside the edge, inside the edge line and the rim, so hover, selection and the accent hairline stay visible (one border on a button under 20 borders across), masked to rounded corners by `iconMask` (3 units on a 44-unit icon) so it meets the socket's inner corner. The cooldown swipe uses the same mask. A proc lights the edge line gold and glows gold (`giltLit`), the one gold a socket wears; the hotkey is in the `number` face, upper case. The states match the design file's ACTION BUTTON STATES row (measured against it at 2 px per unit with `Tools/render/scenes/buttons.lua`):

| State | Hairline | Body | Icon |
| --- | --- | --- | --- |
| Rest | `accent` mixed 15% toward `textHover` | `buttonFill` | Full colour |
| Hover | `accent` mixed 25% toward `textHover`, a selection glow 10 units out at 30% of the `shadow` falloff (the design's +25 luminance beside the rim), and the glow's inner wash over the icon at 20% of the accent | `buttonFill` | |
| Pressed | Mixes toward `text` at 77% | Lifts three quarters of the way to `raised` | Desaturated, dims to 55% and moves down `pressOffset` |
| Cooldown running | `text` at 62% | Lifts three quarters of the way to `raised` | Dims to 40%; swipe in `black` at 65%; the countdown, the cooldown's own font string in the `number` font and `textEmphasis`, is centred a quarter of the height above the bottom |
| Ready (a real cooldown's `OnCooldownDone`) | as at rest | as at rest | `button.ready`, a `textHover` wash in `ADD` masked to the icon, lights to 35% and settles to nothing over `castSheen`, played by the animation group `button.readyFlash` (its fade is `button.readyFade`) so no Lua runs each frame: the theme's cooldown flash, since the swipe's own bling is off. It reads the frame's event, so no time is compared; the GCD alone, a frame a module drives directly and a hidden button never flash, and with motion off it does not show |
| Proc (`SetProc(true)`) | the edge line in `giltLit` | `buttonFill` | The gold proc glow breathes inside the rim: its inner glow and star, with the outer halo at 10%, because Lumen's proc glows inside the socket, never past it |
| Selected (`SetSelected(true)`) | `accent` | `buttonFill` | |
| Unusable (`SetUsable(false)` or `Disable()`) | `textDisabled` | Lifts three quarters of the way to `raised` | Desaturated at 45% brightness |

The icon's brightness and desaturation go through `Widgets.ShadeIcon(texture, r, g, b, desaturated)`, which sets the vertex colour and keeps the texture's alpha (a `nil` `desaturated` leaves the desaturation alone); the Cooldowns module uses it to grey a cooling icon.

| Method | Behaviour |
| --- | --- |
| `SetIcon(texture)` | `SetTexture` on the icon, with a file ID or a path. The repainted icons are a loose-file pack the client applies itself ([`docs/icons.md`](../../docs/icons.md)). |
| `SetCooldown(start, duration, gcd) -> ok` | Plain numbers only. `Cooldown:SetCooldown` refuses secret arguments from addon code, so a secret is refused, logged once, and returns `false`. |
| `SetCooldownFromDuration(durationObject, gcd) -> ok` | `Cooldown:SetCooldownFromDurationObject`, for secret cooldowns. Returns `false` and logs once when the method is missing. |
| `ClearCooldown()` | Clears the cooldown and forgets `gcd`. |

`gcd = true` says the cooldown is only the global cooldown: the swipe runs, but the button stays ready, with the accent rim and a bright icon. The global cooldown alone never dims an icon or greys its rim. The ActionBars module reads `isOnGCD` from `C_ActionBar.GetActionCooldown` and `C_Spell.GetSpellCooldown` and passes it. The cooldown state (grey rim, dim icon) applies only to a real cooldown set through these setters: a module that drives `button.cooldown` directly, as the Cooldowns mirror does for its buff timers, keeps a bright button and draws its own state. `button.cooling` still says whether the cooldown frame shows.
| `SetProc(on)`, `SetUsable(on)`, `SetSelected(on)` | |
| `SetHotkey(text)`, `SetCount(text)` | Caption text at the top right (upper case) and `number` text at the bottom right, above the swipe |
| `SetTint(r, g, b)` | Multiplies the icon's shade in every state, such as red while out of range. No arguments return it to white. |
| `SetAccent(r, g, b)` | Gives this button its own accent for the hairline, the hover glow and the proc glow, kept through theme changes. No arguments follow the theme accent again. |
| `SetChargeCooldownFromDuration(durationObject) -> ok`, `ClearChargeCooldown()` | A second Cooldown, `chargeCooldown`, made on first use, that draws only its edge and no numbers: the recharge of a spell with charges left. Returns `false` and logs once when the method is missing. |

Fields: `icon`, `mask`, `cooldown`, `countdown` (the cooldown's countdown font string, when the client gives one), `chargeCooldown` (made on first use), `overlay`, `hotkey`, `count`, `chrome`, `hoverGlow`, `procGlow` (made on the first `SetProc(true)`). `Restyle()` restyles both glows, so a button that changes size (a `size` option a module rewrites) keeps its glow geometry.

## Slot

`Slot(parent, opts) -> Button`: the action slot every tray shares, the Frames tray, the Orbs forged tray and the cooldown rows alike. It is an [`IconButton`](#iconbutton) with the KSTY-44 bible's slot (section 3.9 and the mock-ups' `.slot`), and takes the same options plus `rim` (the token of the resting rim, `slotRim` by default; a module with its own accent sets `button.rimToken` to `nil` and paints the rim itself).

| Part | What it is |
| --- | --- |
| Body | `slotFill` at full alpha, so an empty slot is opaque wherever it shows, and a dark well (`slotWell` on the `glow` texture, masked to the icon) under the icon, so an empty slot still reads as a socket |
| Rim | The near-black `socketEdge` line outside, the lit `slotRim` band inside it, and a black hairline at 80% round the icon (`button.innerLine`) |
| Bevel | Two masked gradients over the icon: white from 24% to nothing over the top 16% (`bevelTop`), black from 60% to nothing over the bottom 20% (`bevelBottom`). Without `Texture:SetGradient` or `CreateColor` they hide and log once |
| Key | `hotkey` 3 units in from the top left, left-justified |
| Cooldown | The kit's masked swipe with its edge drawn (`SetDrawEdge(true)`) in `slotEdge` through `SetEdgeColor`, and the countdown centred on the icon in `slotNumber` |
| Hover | `hoverLayer`: a `textHover` ring at 70% over the rim band and a 12% white wash over the icon, faded in and out over `hover` by `hoverIn` and `hoverOut` |
| Press | `pressLayer`: a 30% white wash over the icon, a `slotPress` ring one line outside the slot and a soft halo 6 units out, played by `button.press`: in over `pressIn` (0.06 s), out over `pressOut` (0.18 s). A press flashes once on its way down: a key's down click or a mouse down; the release and a held key do not flash again |
| Proc | `SetProc(on)`: the edge line in `giltLit`, a gilt glow inside the icon and a gilt halo 10 units out (`lumenGlow`, with `lumenGlow.texture` and `procHalo`), breathing between 1 and 0.45 over `procPulse` (`lumenGlow.breath`, `BOUNCE`). With reduced motion it holds still |
| Ready | The kit's ready flash in `giltLit`, from 60% to nothing over `readyFlash` (0.3 s) |

Every state is set on an event and every motion is an animation group the client runs: `Widgets.Hover` and `Widgets.Press` call the slot's `AnimateHover` and `AnimatePress` instead of tweening `hoverT` and `pressT`, so no hover, press, proc or ready motion repaints the slot or runs Lua each frame. With motion off a press and a ready flash do not show and hover shows at once. `Tools/regression/test-widgets-slot.lua` covers it and `Tools/render/scenes/slots.lua` renders every state.

### Icon chrome

Every square icon in KstyleUI draws the same body and rim through one helper, so the action buttons, the bag slots, the aura tiles of the Auras, UnitFrames, GroupFrames and Nameplates modules, the skins' item rims, the tooltip's item icon, the micro menu, the bag bar, the cooldown icons and the flyouts all look like the design's button.

| Function | Behaviour |
| --- | --- |
| `IconChrome(owner, opts) -> chrome` | A [`Chrome`](#chrome) with the `socket` shape and the `buttonFill` body. The corner is three border lines at every size. `opts.shadow` asks for the soft card shadow, which the `shadows` setting shows, as `IconButton` does; a tile without it (aura tiles, bag slots, skin rims, the tooltip icon) has none. The chrome gains `SetRim` and `SetRimAccent`, and its `Paint` repaints the rim on every restyle. |
| `chrome:SetRim(r, g, b, a)` | Paints the rim in that colour. With no colour, the plain `edgeInner` rim: an empty bag slot, or a skinned item with no quality colour. Allocates nothing, so Paint paths may call it every frame. |
| `chrome:SetRimAccent(r, g, b, strength)` | Rests the rim on `IconRim(r, g, b, strength)`, and derives it again on every restyle, so a tile that gives no colour follows the theme accent through `ThemeChanged`. A module with its own accent setting passes its colour each time it styles the tile. |
| `IconRim(r, g, b, strength, lift) -> r, g, b, a` | The rim colour of a filled icon at rest: the accent (the theme's, or the plain numbers given) mixed `lift` (default 15%) toward `textHover`. A `strength` under 1 mixes that from the plain `edgeInner` hairline, so 0.5 is halfway between the grey hairline and the accent rim. |
| `Widgets.SECONDARY_RIM` | The rim strength of every icon button that is not `primary`: the micro menu, the bag bar, the cooldown icons, the flyouts and the minimap column. `1`, the default, is the full accent rim the action buttons wear. The owner can tone those buttons down in this one number; `Tools/render/scenes/buttons_toned.lua` renders the scene at 0.5. |

## Tabs

`Tabs(parent, opts) -> Frame`: a strip of upper-case tabs on the button grade's body. The selected tab's text is `textEmphasis`, and an underline slides to it over `fade` (0.2 s): a line one border thick on the strip's bottom edge, `accent` mixed 60% toward `textHover`, spanning the tab's full width, with a 5-unit accent glow (`underGlow`, the `shadow` falloff, additive, peaking at 25%) fading upward from it.

Options: `tabs = { { value, label, disabled }, ... }`, `value` (the selected tab, default the first), `onSelect(value, tabs)`, `width` (equal tab widths that fill it; without it each tab fits its label, at least 64 units), `height` (default 32), `name`.

| Method | Behaviour |
| --- | --- |
| `Select(value, silent) -> ok` | Selects a tab and runs `onSelect` unless `silent`. Returns `false` for an unknown or disabled tab. Selecting the selected tab does nothing. |
| `GetValue()` | |
| `SetTabs(tabs, value)` | Replaces the tabs, reusing buttons and hiding the extras. |
| `SetTabEnabled(value, enabled)` | A disabled tab shows `textDisabled` and cannot be clicked. |

Fields: `buttons` (each with `value`, `label`, `x`, `w` and `inset`), `underline`, `underGlow`, `chrome`.

## Toggle

`Toggle(parent, opts) -> Button`: an on and off switch, the design's 58 by 28 pill with an 18-unit round knob 5 units in from either end, and an optional label to its right.

Options: `value` (default `false`), `onChange(value, toggle)`, `label`, `name`, `tooltip`.

| State | Border | Fill | Knob |
| --- | --- | --- | --- |
| Off | `white` at 40%, 70% under the mouse | `surface` | Left, light grey: `text` mixed 63% toward `textHover` |
| On | `accent` | `surface` mixed 30% toward `accent` | Right, `textHover` |
| Disabled (`SetEnabled(false)`) | | | The label is `textDisabled` and clicks do nothing |

The knob slides over `hover` (0.15 s, `outQuart`). Clicks play `IG_MAINMENU_OPTION_CHECKBOX_ON` or `_OFF`.

Methods: `GetValue()`, `SetValue(value, silent)` (runs `onChange` when the value changes, unless `silent`), `Paint()`, `Restyle()`. Fields: `trackBox`, `track` and `fill` (pills), `knob`, `label`.

## Slider

`Slider(parent, opts) -> Frame`: a 4-unit pill track with an accent fill up to a ringed 12-unit knob, the value above the knob, and the minimum and maximum below the track ends.

Options: `min` (default 0), `max` (default 1), `step`, `value`, `onChange(value, slider)`, `format(value) -> text` for the readout, `width` (default 200), `name`, `tooltip`. `min` must be below `max`.

`Quantize(value, min, max, step) -> number | nil` gives every value the slider takes: it clamps to the range, then snaps to the nearest step counted from `min`, rounded to the decimals of the step or of `min`, whichever is finer, so 0.75 plus three steps of 0.05 is exactly 0.9 and a minimum of 0.05 with a step of 0.1 keeps 0.05. When the range is not a whole number of steps, a value nearer `max` than the last step becomes `max`. It returns `nil` for NaN, a secret or anything that is not a number.

| Input | Effect |
| --- | --- |
| Press on the slider | Jumps to the cursor and drags until release, through `GetCursorPosition`. Disabling the slider ends a drag. |
| Mouse wheel | One step up or down, or a hundredth of the range without a step |
| `SetValue(value, silent)` | Quantizes; runs `onChange` when the result changes, unless `silent` |

The readout and range labels use `format`, or the step's decimals: `68` for a step of 1, `1.00` for a step of 0.05, and hundredths of the range without a step.

Methods: `GetValue()`, `SetValue(value, silent)`, `SetRange(min, max, step)` (keeps the value inside the new range), `SetEnabled(enabled)`, `IsEnabled()`, `Paint()`, `Restyle()`. Fields: `trackBox`, `track`, `fillBox`, `fill`, `knob`, `ring`, `readout`, `minText`, `maxText`.

## EditBox

`EditBox(parent, opts) -> EditBox`: a tile on the button grade's body in the `body` font with `textEmphasis` text and a `textDisabled` placeholder. It never takes focus by itself.

Options: `text`, `placeholder`, `width` (default 200), `height` (default `rowHeight` + `gapSmall`), `maxLetters`, `numeric`, `name`, `tooltip`, and the callbacks `onEnter(text, box)`, `onEscape(box)`, `onChange(text, box, userInput)`, `onFocus(box)`, `onBlur(box)`.

- The hairline is `accent` while the box has focus, and mixes toward `accent` at 60% under the mouse.
- The placeholder shows while the box is empty and has no focus.
- Enter runs `onEnter`, then clears focus. Escape clears focus, then runs `onEscape`.

## ScrollList

`ScrollList(parent, opts) -> Frame`: a virtualised list. It makes only the rows that fit the view plus one, and recycles them as the list scrolls.

Options: `width`, `height`, `rowHeight` (default `rowHeight`, 24), `createRow(list) -> row`, `updateRow(row, item, index, list)`, `onClick(item, index, list)` for the default rows, `stagger` (`false` turns off the row fade), `name`.

The default row is a button with a `body` label that shows `item.label`, or the item itself when it is a string, and lights under the mouse. A custom row is any frame. `updateRow` runs only when a row moves to another item, or on `Refresh(true)`.

| Method | Behaviour |
| --- | --- |
| `SetData(items, keepOffset)` | Shows a new list from the top, or at the same offset with `keepOffset`. Rows fade in one after another, `listStagger` (0.05 s) apart, each over `fade`. |
| `Scroll(delta)` | One wheel step: three rows, eased over `fade`. A step past either end overshoots by `gapMedium` and settles back on the end over `hover`. Content that fits does not move. Reduced motion scrolls at once and skips the bounce. |
| `ScrollTo(offset, instant)`, `ScrollToIndex(index, instant)` | `ScrollToIndex` scrolls only as far as needed to show the row. |
| `GetOffset()`, `GetMaxOffset()`, `GetData()`, `Refresh(force)`, `SetOffset(offset)` | `SetOffset` is the tween setter: it moves the rows at once. |

Rows sit at whole-pixel offsets in a view that clips them. A 3-unit scroll bar shows while the content overflows: its thumb is `text` at 35% and turns `accent` under the mouse. Dragging the thumb keeps the grabbed point under the pointer; pressing the bar elsewhere centres the thumb there. When the list grows taller, the offset clamps to the new range. The wheel works anywhere over the list.

Fields: `view`, `rows` (each with `index` and `list`), `bar`, `track`, `thumb`, `items`.

## TextArea

`TextArea(parent, opts) -> Frame`: a multi-line text field for text the player reads, edits or copies, such as a chat log or a long string. A tile on the button grade's body holds a clipped `ScrollFrame` whose scroll child is a multi-line `EditBox` in the `body` font with `textEmphasis` text. It never takes focus by itself.

Options: `width` and `height` (default 300 by 160; without both, a size set by anchors is kept), `text`, `readOnly`, `maxLetters`, `onChange(text, area, userInput)`, `name`.

| Input | Effect |
| --- | --- |
| Mouse wheel | Three lines up or down, eased over `fade`, clamped to the text |
| Moving the caret | Scrolls only as far as needed to keep the caret's line in view |
| Press on the tile | Focuses the box |
| Escape | Clears focus |
| Typing in a read-only area | Puts the text back and selects it, so Ctrl+C still copies |

A 3-unit scroll bar shows while the text overflows, as in `ScrollList`: its thumb is `text` at 35% and turns `accent` under the pointer, and it can be dragged. The tile's hairline is `accent` while the box has focus. A secret text reaches the box untouched.

| Method | Behaviour |
| --- | --- |
| `SetText(text)`, `GetText()` | |
| `SetReadOnly(on)` | |
| `Scroll(delta)`, `ScrollTo(offset, instant)`, `ScrollToBottom(instant)` | Offsets clamp to `0` to `GetMaxOffset()`, which is the scroll frame's `GetVerticalScrollRange()` |
| `GetOffset()`, `GetMaxOffset()`, `Refresh()` | `Refresh` clamps the offset after the text changes and repaints the bar |
| `SelectAll()` | Focuses the box and highlights all of its text |

Fields: `chrome`, `scroll`, `box`, `bar`, `track`, `thumb`.

## Dropdown

`Dropdown(parent, opts) -> Button`: a box on the button grade's body with the chosen label, or a placeholder, and a chevron.

Options: `options` (a list of `{ value, label }`, or a function that returns one), `value`, `onChange(value, dropdown)`, `placeholder` (default `Select Option`), `width` (default 200), `height` (default `rowHeight` + `gapTiny`, the design's 26), `maxRows` (default 8), `renderRow(row, option, dropdown)` to customise a menu row, `unknownLabel(value) -> label` for a value no option holds, `name`, `tooltip`.

A click opens the one shared menu, `DropdownMenu()`, below the box at the box's width on screen, also when the box has its own scale, in the `FULLSCREEN_DIALOG` strata:

- A `ScrollList` of 24-unit rows, up to `maxRows`, scrolled to show the chosen option.
- The chosen row has a one-border `accent` bar on its left and an `accent` wash at 12%. Other rows wash white at 5% under the mouse.
- A row click chooses that option and closes the menu. A click anywhere else (on `menu.catcher`, a full-screen button under the menu) and Escape close it too, as does hiding the dropdown.
- While open, the box's hairline is `accent` and its chevron points up.

A function in `options` runs through `KstyleUI.Call`, so an error is reported once and the menu shows empty.

| Method | Behaviour |
| --- | --- |
| `SetValue(value, silent) -> ok` | Returns `false` for a value no option holds. Runs `onChange` when the value changes, unless `silent`. |
| `GetValue()`, `GetOptions()` | |
| `SetOptions(options)` | Replaces the options and refills an open menu. The value stays; a value the new options lack shows the placeholder. |
| `Open()`, `Close()`, `Toggle()`, `IsOpen()` | A disabled dropdown (`Disable()`) does not open. |

Menu rows have `label`, `mark`, `wash` and `sample` (a hidden texture). Each row is reset to the `body` font, a hidden sample and the default label anchors before `renderRow` runs.

## FontPicker and TexturePicker

`InheritedFontOptions()` returns the font media list with an empty-path "Interface font" choice first. A schema `font` row opts in through its `options` field only when its reader resolves an empty path dynamically. Ordinary font pickers never offer that sentinel. The preview uses the body face for the inherited label; the consuming module chooses its semantic role.

`MediaOptions(kind) -> { { value = path, label }, ... }` lists KstyleUI's own media from `Tokens.MediaList(kind)` first, then LibSharedMedia's, in its order, when `LibStub("LibSharedMedia-3.0", true)` returns the library. A path already listed is skipped, so KstyleUI's own media, which `Appearance` registers with LibSharedMedia, appear once. A font must be a path; other kinds may also be file IDs. A kind KstyleUI has no media for lists LibSharedMedia's only.

`FontPicker(parent, opts) -> Button` and `TexturePicker(parent, opts) -> Button` are `Dropdown`s over `MediaOptions("font")` and `MediaOptions(opts.kind or "statusbar")`. Their values are paths, as the settings schema's `font` and `texture` rows store. Each font row draws its label in that font; each texture row shows a 64-unit `accent`-tinted sample. A path no list knows shows its file name.

## ColorSwatch

`ColorSwatch(parent, opts) -> Button`: a rounded tile on the button grade's body, filled with the colour.

Options: `color = { r, g, b, a }`, `hasAlpha`, `onChange(r, g, b, a, swatch)`, `size` (default 20), `name`, `tooltip`.

A click calls `ColorPickerFrame:SetupColorPickerAndShow`, Blizzard's public setup function, with the colour, `opacity` and `hasOpacity`. Picking reads `ColorPickerFrame:GetColorRGB()` and, for an alpha swatch, `GetColorAlpha()`, then sets the colour and runs `onChange`. Cancel restores the colour the picker opened on and runs `onChange` with it. A value that is secret or outside 0 to 1 is ignored.

| Method | Behaviour |
| --- | --- |
| `GetColor() -> r, g, b, a` | |
| `SetColor(r, g, b, a, silent) -> ok` | Refuses a channel outside 0 to 1. A missing alpha is 1. |
| `Open() -> ok` | Returns `false` and logs once when `ColorPickerFrame` or its setup function is missing. |

## StatusBar

`StatusBar(parent, opts) -> StatusBar`: a bar for health, power, casts, experience and timers. Lua never reads its value: values go only to the engine's setters, so secret health and power work as they are.

Options: `texture` (a key of `Tokens.MediaList("statusbar")`, `Glass` by default, or a path), `color` (a token, default `accent`), `background` (a token, default `track`, or `false` for none), `smooth` (the engine eases each change with `Enum.StatusBarInterpolation.ExponentialEaseOut`), `spark`, `sheen`, `border` (the bar grade's pill track two borders outside the bar; a horizontal bar's fill is then rounded at both ends by two `CLAMPTOWHITE` cap masks, `pillCapLeft` fixed at the bar's start and `pillCapRight` riding the fill's moving end, with the `barSheen` top sheen over it at 35% and a soft `shadow` glow behind it in the fill's own colour: `SetStatusBarColor` colours the glow too, secrets included, since `SetVertexColor` takes them), `orientation` (`HORIZONTAL` or `VERTICAL`), `reverse`, `min`, `max`, `value`, `width` and `height` (default `buffBarWidth` by `buffBarHeight`, 180 by 18), `name`.

| Method | Behaviour |
| --- | --- |
| `SetBarValue(value)` | `SetValue(value)`, with the ease-out when `smooth` is set and the client has the enum. A secret reaches the engine untouched. |
| `SetBarRange(min, max)` | `SetMinMaxValues(min, max)`. |
| `SetBarDuration(durationObject) -> ok` | `SetTimerDuration`, for cast bars driven by a duration object. Returns `false` and logs once when the method is missing. |
| `SetColorToken(name)` | Colours the fill with a token. An `accent` bar follows the class colour on `ThemeChanged`. |
| `SetBarColor(r, g, b, a)` | The bar's own colour, plain or secret. |
| `SetHealthUnit(unit)` | With `opts.lowHealth`, on every `SetHealth` and restyle, sets the alpha of a `healthLow` fill laid on the bar's fill (under the sheen) to `UnitHealthPercent(unit, true, curve)`, a `C_CurveUtil.CreateCurve` step curve that answers 1 below 35% and 0 above. The secret number goes straight to `SetAlpha`, which takes secrets (`SimpleRegionAPIDocumentation.lua`, `SetAlpha`: `SecretArguments = "AllowedWhenTainted"`), so the red does not depend on the bar's colour and nothing reads the percentage. `nil` hides the red. The unit frames pass no unit for a hostile, disconnected or tapped unit. |
| `SetLoss(on)` | Turns the band on or off. |

Timings are tokens: `hitFlash` 0.18 s, `lossHold` 0.5 s, `sparkHold` 0.25 s then `sparkFade` 0.35 s. At motion Reduced the band and its hold stay and the flash and spark do not show; at Off the band is off and the fill snaps. No part has an `OnUpdate`. `Tools/regression/test-widgets-unitbar.lua` drives the band, the flash, the spark and the curve with secret values that raise on any comparison or arithmetic.

## Popup and Confirm

KstyleUI's own dialogs. They never use `StaticPopupDialogs`. One dialog shows at a time in a shared glass panel, `DialogHost()`, in the `DIALOG` strata, 360 units wide. It registers with Layout as `Widgets.Dialog` (scalable, 120 units above the centre by default), so the player can move and resize it.

`Popup(opts) -> handle`. Options: `title` (default `KstyleUI`), `text`, `buttons = { { label, onClick(handle), primary, reload }, ... }` (default one OK button), `editBox = { text, placeholder, maxLetters }`, `onCancel(handle)`, `key`.

- A button click runs its `onClick`, then closes the dialog. A `reload` button is a [reload button](#reload-button) whose `onClick` runs before `/reload`.
- Escape runs `onCancel`, then closes the dialog. Enter in the edit box presses the primary button. The edit box spans the dialog and takes focus on the next frame, so a queued edit-box dialog keeps it.
- A second popup waits until the first closes. A popup whose `key` is shown or waiting returns that handle instead of queueing again.

| Handle method | Behaviour |
| --- | --- |
| `Close()` | Closes a shown dialog and shows the next, or drops a waiting one. |
| `IsShown() -> boolean` | |
| `GetText() -> text` | The edit box's text. |

Field: `editBox`, when the popup has one.

`Confirm(opts) -> handle` is a popup with a Cancel button and a primary Accept button. Options: `title`, `text`, `acceptLabel`, `cancelLabel`, `onAccept(handle)`, `onCancel(handle)`, `reload` (Accept becomes a reload button), `key`.

`ReloadPrompt(text) -> handle` is a confirm titled "Reload needed" with **Later** and a **Reload now** reload button. Its key keeps it from stacking.

## Reload button

`ReloadButton(parent, opts) -> Button`: a primary [button](#button) labelled Reload. Options: `text`, `width`, `height`, `name`, `tooltip`, `beforeReload(button)`, which runs from the secure button's `PreClick`, before the macro. The field `button.beforeReload` can be changed later.

`ReloadUI()` is blocked for addon code, so the click goes to one shared `SecureActionButtonTemplate` button with the attributes `type = "macro"`, `macrotext = "/reload"` and `useOnKeyDown = false`, registered for `AnyUp`:

- It is made on the first hover out of combat, parented to `UIParent` so no KstyleUI frame becomes protected.
- On hover it is anchored over the reload button, in its strata, five levels above. It forwards hover and press to the visible button, and hides when the pointer leaves or the button hides.
- `PLAYER_REGEN_DISABLED` fires before lockdown: the secure button hides and unanchors, and every reload button disables until `PLAYER_REGEN_ENABLED`. No attribute, anchor or visibility of the secure button changes in combat.
- A reload button made in combat starts disabled. A click that reaches the visible button anyway prints "Type /reload to reload the interface."

## Glow

`Glow(frame, opts) -> handle`: a glow drawn from the `shadow` falloff with additive blending, on a frame one level behind `frame`, so the frame's own fill hides the inside.

Options: `kind` (`"proc"`, the default, or `"selection"`), `color` (a token, default `accent`), `spread` (units the glow reaches out, default `gapMedium`), `alpha` (the glow's full strength, default 1 for a proc and 60% for a selection; an icon button's proc glow passes 10%, so only its inner glow and star show), `core` (for a selection glow: the strength of an additive inner wash over the frame, as a share of the colour at full intensity, such as the icon button's 20% hover wash; off by default).

- A proc glow fades in, then pulses from 45% to 100% alpha and back over `procPulse` (0.7 s, Lumen's proc breathing) on an AnimationGroup, with the design's four-point star, two crossed 6-unit streaks one unit thick in the glow's colour (the accent, so it matches the rest of the theme), centred 3 units in from the frame's right edge and 2.5 below its top, and an additive inner glow (`core`) over the frame at 35%, 1.2 times the frame's size. `alpha` scales only the outer halo; the star and the inner glow keep their strength. Reduced motion shows it steadily, and switching reduced motion on or off stops or restarts the pulse of a glow that is already running.
- A selection glow is steady at `alpha`. With `core`, its inner wash (1.2 times the frame, on a `top` frame inside the holder) follows `SetIntensity` with the halo.

| Method | Behaviour |
| --- | --- |
| `Start()`, `Stop()` | Fade in over `fade`, and fade out then stop the animations. |
| `IsPlaying() -> boolean` | |
| `SetIntensity(t)` | For a stopped glow: show it at `t` of full strength, or hide it at 0. Icon buttons drive their hover glow with it. |
| `SetColor(name)`, `Restyle()` | |
| `SetColorRGB(r, g, b)` | Colours the glow with plain numbers instead of a token, kept through restyles. No arguments return to the token. |

Fields: `holder`, `slice`, for proc glows `pulse`, `sparkPulse`, `top`, `spark`, `sparkCross` and `core`, and for a selection glow with a wash `top` and `core`.

## Tooltip

`Tooltip() -> Frame`: one shared glass tooltip for KstyleUI's own controls, in the `TOOLTIP` strata, clamped to the screen and scaled by the `tooltipScale` setting. Blizzard's `GameTooltip` is left to the Tooltips module.

| Method | Behaviour |
| --- | --- |
| `SetOwner(owner, anchor, x, y)` | Clears the lines and anchors to `owner`: `"ANCHOR_RIGHT"` (default), `"ANCHOR_LEFT"`, `"ANCHOR_TOP"` or `"ANCHOR_BOTTOM"`, 6 units away, plus `x` and `y`. |
| `IsOwned(frame) -> boolean` | |
| `SetIcon(texture, color)` | The design's item icon: a 50-unit rounded `buttonFill` tile 9.5 units inside the top left corner, the icon cropped and masked by `iconMask`; the lines move into a column 11 units right of it. With a `color`, the tile's hairline takes it and a `selection` glow lights in it, as a rarity-lit item; without one the hairline stays `edgeInner` and nothing glows. |
| `AddTitle(text, color)` | The design's title: `body` text in capitals, tracked with a thin space between the letters, `textEmphasis` by default. |
| `AddCaption(text, color)` | Upper-case tracked caption text, `text` by default |
| `AddLine(text, color, wrap)` | Body text that wraps unless `wrap` is `false` |
| `AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)` | Body text left, `textEmphasis` text right |
| `AddRule()` | The design's 56-unit rule under an item's base lines: one border thick, from the accent to transparent, 4 units of air above and below |
| `AddDivider()` | The `divider` line that fades at both ends, `edgeFaint`, from the panel's padding on the left to its padding on the right, 6.5 units of air above and below |
| `ClearLines()` | Returns every line to a pool, so lines are made once. |
| `Show()`, `Hide()` | Lay out, anchor and fade in, or fade out, hide and drop the owner, over `hover`. |

`color` is a token name, or `r, g, b` as three numbers. The tooltip is 160 to 300 units wide. Lines start 9.5 units below the top and are pitched half a unit apart (the design's 13.5 units for 11-unit text), with 2 more units after a title and 4 after a caption; the string height falls back to 1.2 times the font size where the game gives none.

The panel is as wide as its widest line (a double line counts both halves and a `gapLarge` between them) plus its insets, between the minimum and maximum widths, snapped to the pixel grid; the lines' width is never under the widest line's measured text, so snapping cannot wrap that line's last word onto a line the height did not count.

`AttachTooltip(frame, content)` shows the tooltip on `OnEnter` and hides it on `OnLeave`. `content` is a string, or `function(tooltip, frame)` that adds the lines. `Button` and `IconButton` call it for `opts.tooltip`.

## Skin helpers

`KstyleUI.Skin`, in `Core/Skin.lua`, restyles Blizzard frames in place for `KstyleUI_Skins` and any reskin module. The helpers follow the spec's reskin rules:

- No `SetScript`, `Hide` or `SetParent` on a Blizzard frame or region. They hook with `HookScript` and `hooksecurefunc`.
- No field written onto a Blizzard frame. Per-frame state lives in `KstyleUI.Safe.Side(frame).skin`. The only change to a Blizzard object's table is the wrapper `hooksecurefunc` installs on the method it hooks.
- KstyleUI's art sits on KstyleUI's own child frames.
- A `nil` frame is logged and skipped, so callers can pass `_G.SomeFrame` unchecked. A forbidden frame is skipped too.
- On a protected frame in combat, the call waits for `Combat.Queue` and returns `nil`. Out of combat it runs at once.
- Every helper is safe to call twice: the second call returns what the first made.

`test-skin.lua` builds stand-in Blizzard frames and fails on any `SetScript`, `Hide` or `SetParent` call on them, or any new field other than a hooked method.

| Function | Behaviour |
| --- | --- |
| `Strip(frame, opts) -> count` | Sets every texture region of `frame` to alpha 0 and hooks its `SetAlpha`, so Blizzard code cannot bring it back. Font strings stay. `opts.keep` is a set of regions to leave; `opts.children` lists child keys, dotted paths such as `"Inset.NineSlice"`, frames or textures to strip as well. A hooked `OnShow` strips textures the frame adds later, unless `opts.watch` is `false`. Returns the number of textures stripped. |
| `Backdrop(frame, opts) -> Frame` | A KstyleUI [chrome](#chrome) on a child frame one level behind `frame`. `opts`: `shape`, `fill`, `shadow`, `icon` (`true`: the chrome is an [`IconChrome`](#icon-chrome), the dark button body with `SetRim` and `SetRimAccent`, and `shape`, `fill` and `shadow` are ignored), `inset` (a number, or `{ left, right, top, bottom }`), snapped in the frame's own scale and snapped again on `ScaleChanged`, `target`: a KstyleUI frame the panel surrounds instead of `frame`, such as one anchored to the content a Blizzard frame shows, and `gilt` (`false` leaves a window's gilt tips off, as on the story card). |
| `CloseButton(button) -> Texture` | Strips the button and draws the `glyphClose` cross on a child frame: `text` at rest, `textHover` under the mouse, `textDisabled` when disabled. |
| `Tab(tab) -> parts` | Strips the tab and draws an `accent` underline on a child frame while the tab is selected. The selected text is `textEmphasis`, others `text`, a disabled tab `textDisabled`. Selection comes from a hook on the tab's `SetTabSelected` (the tab system), or from global hooks on `PanelTemplates_SelectTab`, `PanelTemplates_DeselectTab` and `PanelTemplates_SetDisabledTabState`. A tab whose `isDisabled` is set (Blizzard uses `1`) counts as disabled. |
| `Tabs(frame) -> count` | `Tab` for each of `frame.Tabs`, or `<name>Tab1` to `<name>Tab<numTabs>`. |
| `ScrollBar(bar) -> parts` | For `MinimalScrollBar`, `WowTrimScrollBar` and the older `UIPanelScrollBarTemplate` slider: strips the track, thumb, steppers and the trim bar's `Background`, then draws a 2-unit `track` line, a 6-unit pill thumb (a bar between two half-`dot` caps, `text` at 45%, `accent` under the mouse) that follows Blizzard's thumb, and chevrons on the back and forward steppers. The line and the thumb sit on child frames of Blizzard's track and thumb, so they hide when Blizzard hides those. |
| `EditBox(box, opts) -> Frame` | Strips the box, keeping a search box's `searchIcon`, and puts a `buttonFill` tile behind it whose hairline is `accent` while the box has focus. `opts.inset` as for `Backdrop`. |
| `CheckBox(check) -> parts` | Strips the check button and draws a 16-unit `buttonFill` tile with a rounded `accent` mark (`iconMask`) while checked. It follows `SetChecked`, clicks and `OnShow`. |
| `Button(button, opts) -> Frame` | Strips the button and puts a `buttonFill` tile behind it, the design kit's dark control. The hairline and the text light under the mouse, and a disabled button's text is `textDisabled`. `opts.font` restyles the text in a font role. |
| `Text(fontString, role, colorName)` | The role's font and shadow, and a token colour. |
| `Window(frame, opts) -> Frame` | For `PortraitFrameTemplate` and `ButtonFrameTemplate` windows: strips `NineSlice`, `Bg`, `TopTileStreaks`, `PortraitContainer`, `TitleContainer`, `Inset` and the inset's art, puts a shadowed window-grade panel (`shape = "window"`) behind, skins `CloseButton`, sets the title in the `heading` font (unless `opts.title` is `false`) and skins the tabs (unless `opts.tabs` is `false`). `Tabs(frame)` also puts one `buttonFill` strip, the design kit's tab bar, behind the window's bottom tabs, from the first to the last, in `Parts(frame).strip`. |
| `IsSkinned(frame, kind) -> boolean` | `kind` is `"Backdrop"`, `"CloseButton"`, `"Tab"`, `"Tabs"`, `"ScrollBar"`, `"EditBox"`, `"CheckBox"`, `"Button"` or `"Window"`. |
| `Parts(frame) -> table` | The KstyleUI parts made for the frame: `backdrop`, `glyph`, `underline`, `track`, `thumb`, `back`, `forward`, `box`, `mark` and `text`, as the helper made them. |

The parts restyle with the kit on `ThemeChanged` and `ScaleChanged`. Blizzard's button font objects can recolour a button's text on a state change the hooks do not see; `Button` repaints on enter, leave, enable, disable and show.
