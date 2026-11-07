# Widget kit

`KstyleUI.Widgets` is the component kit every KstyleUI window and module builds its UI from. Each component matches [`docs/design/mockups/05_kit_hunter.jpg`](../../docs/design/mockups/05_kit_hunter.jpg). `Core/Widgets/Widgets.xml` loads the files in order: `Base.lua` first, then one file per component.

The roadmap's [Core public API](../../docs/superpowers/plans/2026-11-07-kstyleui-roadmap.md#core-public-api) names stay binding. This page lists every function, its options and its behaviour. Tests: `Tools/regression/test-widgets-*.lua`, which load the core through `Tools/regression/widget_env.lua`.

## Rules every component follows

- Colours, sizes, durations, easings, fonts and textures come from `KstyleUI.Tokens` only.
- Sizes and offsets are snapped to whole physical pixels in each frame's own scale, with `Widgets.Snap`. Lines are one `Widgets.Border(frame)` thick. A frame whose scale changes outside `ScaleChanged`, such as a Layout Mode element, calls `Widgets.RestyleAll()` or its own `Restyle()` to redraw.
- Every component registers with `Widgets.Track`, so it restyles on `ThemeChanged`, `ScaleChanged`, `ProfileChanged`, a change to a setting on the `Widgets` page, and a change to the Appearance page's `reducedMotion` switch.
- Hover and press run through `KstyleUI.Motion`: hover is `Tokens.Duration("hover")` with `outQuart`, and press moves the content down `Tokens.Size("pressOffset")`.
- Components hook scripts with `HookScript`. A component built on a secure template keeps the template's own `OnClick`.
- A protected frame is never moved in combat. Content offsets and chrome anchors wait, and chrome re-anchors through `Combat.Queue` once combat ends.
- Secret values are never compared. A secret string reaches `SetText` untouched.
- Components never call `SetScript`, `Hide` or `SetParent` on a Blizzard frame, and never write fields onto one.

## Settings

The kit registers the `Widgets` settings page with `Store.RegisterDefaults` and `Options.Register` at load.

| Key | Default | Row | Effect |
| --- | --- | --- | --- |
| `panelOpacity` | the `surface` token's alpha, 0.88 | slider, 0.5 to 1 in steps of 0.01 | The alpha of every `surface` fill |
| `shadows` | `true` | toggle | Shows the shadow of panels, windows and tooltips |
| `sounds` | `true` | toggle | Plays the kit's click and open sounds |
| `tooltipScale` | `1` | slider, 0.75 to 1.5 in steps of 0.05 | The scale of `Widgets.Tooltip()` |

`Widgets.Setting(key) -> value` returns the active profile's value, or the default before the saved data loads or when the saved value is not allowed. An unknown key raises an error. `Widgets.defaults` and `Widgets.schema` hold the registered tables.

## Shared helpers (`Base.lua`)

| Function | Behaviour |
| --- | --- |
| `Track(widget) -> widget` | Adds `widget` to the restyle registry. `widget:Restyle()` runs on every restyle event. A failing `Restyle` is reported through `KstyleUI.Call` and the rest still run. |
| `RestyleAll()` | Runs every tracked `Restyle`. |
| `Text(parent, role, colorName, layer) -> FontString` | A font string in the role's font (`Tokens.Font`), with the soft `textShadow` shadow offset by `textShadowOffset`, coloured `colorName` (default `text`), in `layer` (default `OVERLAY`). A face change restyles every text made here. |
| `StyleText(text, role)` | Applies a role's font and shadow to any font string and adds it to the face-change list. A font the game cannot load falls back to `GameFontHighlight` and logs once. A role with font flags, such as `world`, gets no shadow. |
| `SetText(text, value)` | Sets the text. A role whose `Tokens.TextStyle` is upper case, such as `caption`, upper-cases it. `nil` clears it. A secret passes through untouched. |
| `TextColor(text, name, alphaScale)` | Sets a token colour on a font string. |
| `TextWidth(text, fallback)`, `TextHeight(text, fallback)` | The string's size, or `fallback` when the game gives no plain number. |
| `Rgba(name, alphaScale) -> r, g, b, a` | A token colour with its alpha scaled. |
| `Tint(region, name, alphaScale)` | `SetVertexColor` with a token colour. |
| `Mix(r1, g1, b1, a1, r2, g2, b2, a2, t)`, `MixTokens(nameA, alphaA, nameB, alphaB, t)` | Linear mix of two colours. |
| `ScaleFactor(frame) -> number` | The frame's effective scale over `KstyleUI_Root`'s: 1 for a frame at the root's scale, 1.25 for a tooltip at a size of 1.25. A secret or missing scale gives 1. |
| `Snap(frame, units) -> units`, `Border(frame) -> units` | `Scale.Snap` and `Scale.Border` in the frame's own units, so a frame with its own scale still draws whole pixels. Every component snaps through these. |
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

`Chrome(owner, opts) -> chrome` draws a component's shape on `owner`'s own layers:

| Part | Layer | What it is |
| --- | --- | --- |
| `chrome.shadow` | `BACKGROUND` -8 | The nine-sliced `shadow` texture, corner pieces `Snap(24)` centred on the owner's corners, tinted `shadow` |
| `chrome.fill` | `BACKGROUND` -6 | The nine-sliced `chamferPanel` or `chamferTile` texture |
| `chrome.noise` | `BACKGROUND` -5 | Panels only: the `noise` grain, tiled at 3.5% white, inset by the chamfer |
| `chrome.outer`, `chrome.inner` | `BORDER` | Each line: four corner pieces of the bevel texture, then the top, bottom, left and right lines as solid textures one `Scale.Border()` thick. The inner line sits one border inside the outer. |

`opts`: `shape` (`"panel"`, 6-unit chamfers, or `"tile"`, 3-unit chamfers), `fill` (a colour token, default `surface`), `edge` (the inner line's token, default `edgeInner`), `shadow` (default on for panels and off for tiles), `grain` (`false` removes the grain).

A `surface` fill takes its alpha from the `panelOpacity` setting. The shadow shows only while `shadows` is on.

| Method | Behaviour |
| --- | --- |
| `SetFill(name, alphaScale)`, `SetFillRGBA(r, g, b, a)` | Recolours the fill. |
| `SetEdge(name, alphaScale)`, `SetEdgeRGBA(r, g, b, a)` | Recolours the inner line, the hairline that hover and selection light up. |
| `SetShadow(on)`, `SetShown(shown)` | |
| `Restyle()` | Re-anchors every piece in whole pixels and repaints. |

`NineSlice(owner, textureName, layer, sublevel) -> list`, `LayoutSlice(slice, owner, cornerUnits, outsetUnits)`, `ColorSlice(slice, r, g, b, a)` and `ShowSlice(slice, shown)` build and place any sliced texture. `TEXTURE_TEXELS` holds each sliced texture's size in texels; `test-widgets-kit.lua` checks it against the PNG files.

## Panel

`Panel(parent, opts) -> Frame`. The default parent is `KstyleUI_Root`.

| Option | Effect |
| --- | --- |
| `width`, `height` | Snapped size |
| `title` | Adds the title bar: an upper-case heading, an accent divider, and a drag area when `movable` is set |
| `close` | Adds a close button that calls `panel:Close()` |
| `onClose(panel)` | Runs when the panel closes |
| `escape` | Escape closes the panel |
| `movable`, `onMoved(panel)` | Drag by the title bar, clamped to the screen |
| `shape`, `fill`, `shadow` | Passed to `Chrome` |
| `strata`, `name`, `hidden` | |
| `layout = { key, position, options }` | Calls `Widgets.Place` with them |

Fields: `chrome`, `content` (a frame one `panelPadding` inside, below the title bar), `titleBar`, `titleText`, `divider`, `closeButton`, `rise` and `riseParts` (the open animation).

| Method | Behaviour |
| --- | --- |
| `Open()` | Fades in over `panelOpen` and plays the rise: down `panelRise`, up past rest by `panelOvershoot`, then back. The three translations add up to 0, so nothing jumps when the group ends. Reduced motion skips the rise. |
| `Close()` | Fades out over `panelClose`, hides, and runs `onClose`. |
| `Toggle()`, `SetTitle(text)`, `Restyle()` | |

## Button

`Button(parent, opts) -> Button`: a raised tile with a centred label.

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

`IconButton(parent, opts) -> Button`: a chamfered square for action, cooldown and aura icons.

Options: `size` (default `actionButton`, 34), `icon`, `template` (such as `SecureActionButtonTemplate`), `name`, `onClick`, `tooltip`, `crop` (`false` keeps the full texture; Blizzard icons are cropped 7% each side), `hideNumbers` (hides the cooldown countdown).

The icon sits two borders inside the edge, masked to the chamfer by `iconMask`. The cooldown swipe uses the same mask.

| State | Hairline | Icon |
| --- | --- | --- |
| Rest | `accent` at 50% | Full colour |
| Hover | `accent`, and a soft selection glow | |
| Pressed | Mixes toward `text` at 60% | Dims by 25% and moves down `pressOffset` |
| Cooldown running | `text` at 35% | Swipe in `black` at 65%, countdown in the `number` font |
| Proc (`SetProc(true)`) | `accent` | Proc glow pulses |
| Selected (`SetSelected(true)`) | `accent` | |
| Unusable (`SetUsable(false)` or `Disable()`) | `textDisabled` at 50% | Desaturated at 55% brightness |

| Method | Behaviour |
| --- | --- |
| `SetIcon(texture)` | `SetTexture` on the icon. To use KstyleUI's custom icons, call `KstyleUI.Icons.Apply(button.icon, fileID)` instead. |
| `SetCooldown(start, duration) -> ok` | Plain numbers only. `Cooldown:SetCooldown` refuses secret arguments from addon code, so a secret is refused, logged once, and returns `false`. |
| `SetCooldownFromDuration(durationObject) -> ok` | `Cooldown:SetCooldownFromDurationObject`, for secret cooldowns. Returns `false` and logs once when the method is missing. |
| `ClearCooldown()` | |
| `SetProc(on)`, `SetUsable(on)`, `SetSelected(on)` | |
| `SetHotkey(text)`, `SetCount(text)` | Caption text at the top right (upper case) and `number` text at the bottom right, above the swipe |

Fields: `icon`, `mask`, `cooldown`, `overlay`, `hotkey`, `count`, `chrome`, `hoverGlow`, `procGlow` (made on the first `SetProc(true)`).

## Tabs

`Tabs(parent, opts) -> Frame`: a raised strip of upper-case tabs. The selected tab's text is `textEmphasis`, and an accent underline, the `divider` texture, slides to it over `fade` (0.2 s).

Options: `tabs = { { value, label, disabled }, ... }`, `value` (the selected tab, default the first), `onSelect(value, tabs)`, `width` (equal tab widths that fill it; without it each tab fits its label, at least 64 units), `height` (default 32), `name`.

| Method | Behaviour |
| --- | --- |
| `Select(value, silent) -> ok` | Selects a tab and runs `onSelect` unless `silent`. Returns `false` for an unknown or disabled tab. Selecting the selected tab does nothing. |
| `GetValue()` | |
| `SetTabs(tabs, value)` | Replaces the tabs, reusing buttons and hiding the extras. |
| `SetTabEnabled(value, enabled)` | A disabled tab shows `textDisabled` and cannot be clicked. |

Fields: `buttons` (each with `value`, `label`, `x`, `w` and `inset`), `underline`, `chrome`.

## Glow

`Glow(frame, opts) -> handle`: a glow drawn from the `shadow` falloff with additive blending, on a frame one level behind `frame`, so the frame's own fill hides the inside.

Options: `kind` (`"proc"`, the default, or `"selection"`), `color` (a token, default `accent`), `spread` (units the glow reaches out, default `gapMedium`).

- A proc glow fades in, then pulses from 45% to 100% alpha and back over `procPulse` (1.2 s) on an AnimationGroup, with a spark that pulses at the frame's top right corner. Reduced motion shows it steadily, and switching reduced motion on or off stops or restarts the pulse of a glow that is already running.
- A selection glow is steady at 60%.

| Method | Behaviour |
| --- | --- |
| `Start()`, `Stop()` | Fade in over `fade`, and fade out then stop the animations. |
| `IsPlaying() -> boolean` | |
| `SetIntensity(t)` | For a stopped glow: show it at `t` of full strength, or hide it at 0. Icon buttons drive their hover glow with it. |
| `SetColor(name)`, `Restyle()` | |

Fields: `holder`, `slice`, and for proc glows `pulse`, `sparkPulse`, `top` and `spark`.

## Tooltip

`Tooltip() -> Frame`: one shared glass tooltip for KstyleUI's own controls, in the `TOOLTIP` strata, clamped to the screen and scaled by the `tooltipScale` setting. Blizzard's `GameTooltip` is left to the Tooltips module.

| Method | Behaviour |
| --- | --- |
| `SetOwner(owner, anchor, x, y)` | Clears the lines and anchors to `owner`: `"ANCHOR_RIGHT"` (default), `"ANCHOR_LEFT"`, `"ANCHOR_TOP"` or `"ANCHOR_BOTTOM"`, 6 units away, plus `x` and `y`. |
| `IsOwned(frame) -> boolean` | |
| `SetIcon(texture)` | A chamfered 34-unit icon at the top left; the lines move right of it. |
| `AddTitle(text, color)` | Heading text, `textEmphasis` by default |
| `AddCaption(text, color)` | Upper-case caption text, `text` by default |
| `AddLine(text, color, wrap)` | Body text that wraps unless `wrap` is `false` |
| `AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)` | Body text left, `textEmphasis` text right |
| `AddDivider()` | An `edgeInner` divider |
| `ClearLines()` | Returns every line to a pool, so lines are made once. |
| `Show()`, `Hide()` | Lay out, anchor and fade in, or fade out, hide and drop the owner, over `hover`. |

`color` is a token name, or `r, g, b` as three numbers. The tooltip is 160 to 300 units wide.

`AttachTooltip(frame, content)` shows the tooltip on `OnEnter` and hides it on `OnLeave`. `content` is a string, or `function(tooltip, frame)` that adds the lines. `Button` and `IconButton` call it for `opts.tooltip`.
