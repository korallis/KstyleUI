# KstyleUI_Chat

Chat panels, tabs with an accent underline, an edit box that shows while typing, copy chat, clickable links and class-coloured names.

| Field | Value |
| --- | --- |
| Module name | `Chat`: its switch in `Core/Features.lua` and the `name` it registers with `KstyleUI.Modules.Register` |
| Approach | Reskin |
| Loads | With the core addon, switched off until the player turns it on |
| Files | `KstyleUI_Chat.toc` lists `Chat.xml`, which loads every Lua file in order, so adding a file never edits the TOC |

## Rules

These come from the [design spec](../docs/superpowers/specs/2026-11-07-kstyleui-design.md). The roadmap's Global Constraints and [AGENTS.md](../AGENTS.md) apply too.

- Reskins hook with `hooksecurefunc` or `HookScript`, never `SetScript` on a Blizzard frame. They never write fields onto Blizzard frames, and never call Blizzard functions that open or refresh Blizzard windows. Per-frame state goes in `KstyleUI.Safe.Side(frame)`.
- Blizzard frames keep a reskin after `Disable`, so turning the module off asks the player to reload.
- At load the module only registers itself with `KstyleUI.Modules.Register`. It creates no frames, registers no events and installs no hooks until `Enable` runs. `test-modules-load.lua` checks the frames.
- Every element it shows registers with `KstyleUI.Layout.Register`, and every setting is declared through `KstyleUI.Options.Register`, so the player can resize and customise everything from the settings window.
- UI comes from `KstyleUI.Widgets`, colours from `KstyleUI.Tokens` and strings from `KstyleUI.L`. Translations go in `Locale.lua` in this folder, loaded by `Chat.xml`.
- Build mode: check that an API exists before calling it, check `issecretvalue` before any comparison, fall back to a safer path when the preferred one is unavailable, and log the path taken with `KstyleUI.DevTest.Log`.

## Files

`Chat.xml` loads the files in this order:

| File | What it holds |
| --- | --- |
| `Init.lua` | The addon table the files share |
| `Format.lua` | Pure text helpers: timestamps, short channel names, URL links, plain text and class-coloured names. No frames, no game state. |
| `Settings.lua` | The defaults, the module accent and the settings page's rows |
| `Windows.lua` | Finds Blizzard's chat windows, including whisper windows the game opens later, and hands each to the parts once |
| `Stamps.lua` | Chat timestamps through the game's `showTimestamps` setting, and the player's own value back when the module turns off |
| `Messages.lua` | The message pipeline and the dialog that copies a clicked link |
| `Panel.lua` | The glass panel: the `chat.main` Layout element that holds Blizzard's main chat window |
| `Frames.lua` | Restyles every chat window in place: art, tabs, edit box, scroll bar, fonts and buttons |
| `Copy.lua` | The copy-chat window, its Copy button action and the tab menu's Copy chat entry |
| `Preview.lua` | The live preview on the settings window's Chat page |
| `Module.lua` | Registers the module and its settings page, and starts and stops the parts |

Tests: `Tools/regression/test-chat-format.lua` (the text helpers), `test-chat-messages.lua` (the pipeline), `test-chat-stamps.lua` (timestamps through the game's setting), `test-cvars.lua` (the core's restore at login) and `test-chat-panel.lua` (the panel and the window skins) and `test-chat-copy.lua` (the copy window, its button and menu entry, and the preview), against stand-ins for Blizzard's chat in `Tools/regression/chat_env.lua`.

## Settings

| Key | Default | Row |
| --- | --- | --- |
| `panelOpacity` | the `surface` token's alpha, 0.88 | The glass behind the chat, 0 to 1. The text stays fully visible. |
| `shadow` | `true` | The panel's soft shadow |
| `copyButton` | `true` | The copy glyph beside the plus at the right end of the tab row |
| `editBox` | `typing` | `typing` shows the edit box only while the player types; `always` keeps the game's resting box under the messages at Blizzard's alpha and leaves it room. In the game's Classic chat style Blizzard hides the resting box itself, so `always` only keeps the room. |
| `buttons` | `false` | Shows Blizzard's chat menu and channel buttons beside the chat |
| `font` | Source Sans 3 Regular | Messages, tabs and the edit box; the regular face matches the mockup's lighter chat text. A font the game cannot load falls back to the body font and logs once. |
| `fontSize` | 14 | 8 to 24, messages and the edit box, the mockup's size. A size picked from the game's tab menu becomes this setting. |
| `lineSpacing` | 4 | 0 to 10 units between lines; 4 gives the mockup's pitch at size 14 |
| `fontOutline` | `none` | `none` (the soft text shadow), `OUTLINE` or `THICKOUTLINE` |
| `fade`, `fadeTime` | `true`, 120 | Old lines fade after this many seconds, 10 to 600 |
| `tabStyle` | `underline` | `underline` (the accent underline), `filled` (a raised tile behind the selected tab) or `minimal` (bright text only) |
| `tabCase` | `upper` | Tab names in capitals or as typed |
| `tabFontSize` | 13 | 8 to 16; the mockup's tab labels measure 13 at 1.348 px per unit |
| `accentSource`, `accentColor` | `class`, the default accent | Links and the chat's highlights follow the class colour or a custom colour |
| `timestamp` | `%H:%M` | `none`, `%H:%M`, `%H:%M:%S`, `%I:%M %p`, `%I:%M:%S %p`, `%I:%M` or `%I:%M:%S`: the game's six formats. The game draws it, so system and loot lines have none. |
| `timestampColor` | the `text` token | The colour of the time |
| `channels` | `short` | `short` or `full` (as the game shows them) |
| `numbers` | `name` | Numbered channels as `[1. General]` (`name`) or `[1]` (`number`) |
| `abbr.guild` to `abbr.instanceLeader` | `G`, `O`, `P`, `PL`, `R`, `RL`, `RW`, `I`, `IL` | Up to 6 letters each; empty hides the channel |
| `classNames` | `true` | Class-coloured sender names |
| `urls` | `true` | Clickable web addresses |

## Message pipeline

| Feature | How |
| --- | --- |
| Web addresses | A filter on each player chat event through `ChatFrameUtil.AddMessageEventFilter` rewrites the message text. `Format.Linkify` wraps `http`, `https`, `ftp` and `www.` addresses, bare domains with a known top-level domain, and IPv4 addresses in an `addon:KstyleUI:url:<address>` link in the accent colour. Text inside item links, textures and other escape sequences is never touched. |
| Clicking a link | Blizzard routes `addon:` links to `EventRegistry`'s `SetItemRef` event. The module opens the kit's `Popup` with the address selected, ready for Ctrl+C. |
| Class-coloured names | A sender-name filter through `ChatFrameUtil.AddSenderNameFilter` colours the name from `GetPlayerInfoByGUID` with `Theme.ClassColor`, brightened by `Theme.Brighten`. A name the game already coloured is left alone. |
| Timestamps | `Stamps.lua` writes the `timestamp` and `timestampColor` settings into the game's `showTimestamps` CVar as `\|cffRRGGBB[%H:%M]\|r `. Blizzard's chat puts that in front of each chat message as it builds the line (`TimeUtil.BetterDate`), so the module rewrites no line for its timestamp. See [Timestamps](#timestamps). |
| Short channel names | A `hooksecurefunc` post-hook on each chat window's `AddMessage` computes the decorated line and swaps it in through the window's own `TransformMessages`, only when the line changes. The combat log is skipped. |

## Timestamps

| Case | What happens |
| --- | --- |
| The module turns on | It writes its value into `showTimestamps`, out of combat (`Combat.Queue`). An unchanged value is not written again. |
| A setting changes | The value is written again. `none` or a format not on the list writes `none`. |
| Turned off | The player's own value comes back. The module keeps it in `KstyleUIDB.account.chatTimestamps[<character key>]` as `{ original, written }`, because the CVar is saved per character. A value that differs from `written` when the module starts is the player's own. |
| Off at login on this character | The module was turned off in a shared profile while you played another character, so this character's `showTimestamps` still holds KstyleUI's value. The core's [`CVars` service](../docs/core-services.md#cvars) puts the player's value back at login, out of combat, and clears the memory. A refused value keeps the memory for the next login. |
| `VARIABLES_LOADED` after the module started | The client loaded the character's saved CVars late. The module takes that value as the player's and writes its own again. |
| A change in Blizzard's options (`SettingsPanel` shown) | One of the game's six formats, or `none`, becomes the `timestamp` setting, and the module writes it back in its own style. Any other value is not taken. |
| Any other change (`/console`, another addon) | The module writes its own value back on the next frame. |
| The client drops the colour codes | The module writes the plain `[%H:%M] ` and logs it once. |
| The client refuses the value, or has no `C_CVar.SetCVar` | The player's value stays. The module puts its own timestamp on each line through `TransformMessages`, only while the game's setting is `none`, so a line never gets two. |

`Stamps.GameDraws()` tells `Messages.lua` whether the game is drawing timestamps. It reads the CVar once after each `CVAR_UPDATE` that names it, not on every line. The module's own writes set a flag around `SetCVar`, because `CVAR_UPDATE` fires inside the call.

## The panel

`Panel.lua` builds a plain holder frame and registers it with Layout as `chat.main` (label from `Setup.Layouts`, module `Chat`), resizable from 260 by 120 to 1000 by 800 units, at the setup's position: 424 by 164 units at the bottom left in every layout. The owner's mockup draws the chat 430 by 164 at 1.348 px per unit; 424 keeps it clear of the tracked buff bars on the owner's screen, which sit 4 units above the panel's top. Layout gives it the element settings: position, size, shown rule, opacity in and out of combat, and strata.

The glass is a `Widgets.Panel` child of the holder that fills it, in the `BACKGROUND` strata with `SetFixedFrameStrata(true)`, so a strata the player picks for the element never lifts the glass over Blizzard's chat, whose windows and dock stay in their own strata.

Blizzard's `ChatFrame1` is anchored inside the holder by two points, so it follows every move and resize:

| Part | Where, in root units at the 1080 reference |
| --- | --- |
| Tabs | The tabs sit inside the glass, in a 32-unit row as the mockup draws them. A faint divider closes the row where Blizzard's dock meets the window, and the selected tab's underline lies on it: one unit in the accent (the class colour), across the tab's full width, with a 5-unit accent glow fading upward from it. Blizzard centres the tab text 14 units above its window, so the labels sit 21 units below the panel's top. |
| Glyphs | At the row's right end, level with the tab labels: a plus, the close glyph turned an eighth of a turn, centred 22 units in from the right edge, which opens the chat's settings page; and a copy glyph, two outlined squares drawn from the kit's white texture, one button and a tiny gap to its left, which opens the copy window. Both are 8 units across in the accent (white on hover) with 20-unit hit areas. |
| Messages | 16 units in from the left and up from the bottom, as the mockup, below the tab row, and in from the right by whichever is wider: 16 plus the scroll bar's column, or the glyphs' room. Blizzard's dock ends 2 chat units past the window and its 16-unit overflow button sits at that end, so the window stops where the button clears the last glyph's hit area: 56 units with the copy glyph, 352 units of room for the mockup's lines. |
| Edit box | Blizzard keeps it under the window. With `editBox` at `typing` the panel keeps no room for it, so the box hangs under the panel while the player types; when the chat window's units are larger than the root's or the panel sits low, the bottom inset grows until the box's tile clears the screen's edge by `gapTiny`, and a `LayoutChanged` callback places the window again when the panel moves. With `always` the panel keeps the room: the tile is 22 units tall and 6 units above the panel's bottom. |

The offsets come from Blizzard's own geometry in the chat window's units (`FloatingChatFrame.xml` and `ChatFrameEditBox.xml`: the tab text 14 units above the window, the dock 3 units above it, the edit box 2 units below it and 32 tall, starting 5 units left of the window and ending 8 past the scroll bar), converted through the ratio of the chat window's effective scale to the panel's and snapped to whole physical pixels. They are worked out again on `ScaleChanged`. The line pitch is the font's own line height plus the `lineSpacing` setting, which goes through the window's `SetSpacing` (`ScrollingMessageFrameSecureMixin` in Forever's `ScrollingMessageFrame.lua`; its lines anchor one spacing apart).

The panel's visibility and opacity carry over to Blizzard's chat: hooks on the holder's `Show`, `Hide`, `SetShown` and `SetAlpha` set the same alpha on `GENERAL_CHAT_DOCK` (the tabs) and every docked window. An edit box, which Blizzard parents to `UIParent` and fades itself, is at alpha 0 with its mouse off until the player types in it, when it shows at Blizzard's own alpha and takes the mouse again; with `editBox` at `always` a docked window's box keeps Blizzard's alpha times the panel's instead. A window that leaves the dock gets full alpha back, a window opened into the dock takes the panel's at once, and turning the module off puts everything back.

## The windows

`Frames.lua` restyles every chat window `Windows.lua` finds, including whisper windows opened later:

| Part | How |
| --- | --- |
| Art | `Skin.Strip` on the window and its button column; Blizzard's border textures stay at alpha 0 |
| Tabs | `Skin.Tab`, keeping the new-message glow. A hook on `FCFTab_UpdateColors` tells each tab whether it is selected. The underline and the filled tile take the module accent. |
| Tab names | Upper-cased with the tab's own `SetText`; the typed name is kept in `Safe.Side(tab)` so the normal case can come back. A secret name, such as a whisper window's, is left alone. A hook on `FCF_SetWindowName` handles renames. |
| Edit box | `Skin.EditBox`: a raised tile whose hairline lights in the module accent while it has focus |
| Scroll bar | `Skin.ScrollBar`, and a chevron on the jump-to-bottom button, which keeps its flash |
| Fonts | `SetFont`, `SetShadowColor`, `SetShadowOffset` and `SetSpacing` on each window, its edit box and the edit box's header texts, and on each tab's text. They are set again after `UPDATE_CHAT_WINDOWS`, which resets each window's size. |
| Fading | `SetFading` and `SetTimeVisible` |
| Buttons | Blizzard's button column next to `ChatFrame1` (chat menu, channels) is hidden with `Safe.HideBlizzard` unless `buttons` is on |
| Undocked windows | A glass backdrop from `Skin.Backdrop` that reaches out to cover the tab and the edit box. Hooks on `FCF_DockFrame` and `FCF_UnDockFrame` show and hide it. |

`/kstyle test` reports whether `ChatFrame1` sits in the panel.

## Copy chat

The copy window is a `Widgets.Panel` titled "Copy chat - <tab>" in the `DIALOG` strata, with a read-only `Widgets.TextArea`, a **Select all** button and a hint. It registers with Layout as `chat.copy` (module `Chat`), resizable from 320 by 200 to 1400 by 1000 units, 560 by 380 by default, 40 units above the centre. Dragging its title bar saves a `CENTER` position through `Layout.Update`. Escape closes it.

| Way in | Window it copies |
| --- | --- |
| The copy glyph beside the plus at the right end of the panel's tab row | The selected docked window. The glyphs fade with `ChatFrame1Tab`, as Blizzard fades the tabs. |
| **Copy chat** in a chat tab's right-click menu, added with `Menu.ModifyMenu("MENU_FCF_TAB", ...)` | That tab's window |

It shows every line in the window's history, oldest first, as plain text: `Format.Strip` drops colours, textures and atlases and keeps link text. A secret line becomes "(a line the game keeps hidden)". The text scrolls to the end and is selected, ready for Ctrl+C.

## Preview

The schema's `preview` builds a small glass panel with three sample tabs and four sample lines (guild, a numbered channel with a zone, party with a web address, and a loot line). `Refresh` redraws it from the current settings: glass opacity and shadow, font, sizes and outline, tab style, case and accent, timestamps, channel names, class colours and links.

## Why

- Secret values: under chat restriction the game hands addons secret message text and names. Every filter and hook checks `issecretvalue` first and passes a secret on untouched: the filter returns `false` with no replacement, the name filter returns `nil`, and the `AddMessage` hook does nothing. Blizzard's own filter registry also skips addon filters when an argument is secret; the module does not rely on that.
- No protected chat function is replaced or hooked. The send path (`ChatEdit_SendText`, the edit box's `OnEnterPressed`, slash commands) is never touched, so `/cast` and other secure commands typed in chat stay secure.
- No field is written onto a chat window. `AddMessage` is hooked with `hooksecurefunc`, the one change the spec allows. Rewriting a line goes through `TransformMessages`, which `ScrollingMessageFrameSecureMixin` exposes for addons as a secure elevation barrier, instead of replacing `AddMessage` or the `CHAT_*_GET` strings.
- The channel shown in a numbered channel line cannot be shortened in the event filter: Blizzard matches the channel argument's length against the window's channel list after the filters run, so a shorter name would drop the line. The module rewrites the finished line instead.
- `TransformMessages` walks the window's history in its buffer's slot order, not by age, once per new line. The predicate matches only the newest slot, which the window's `historyBuffer:CalculateElementIndex(1)` names, so an older identical line is never rewritten in its place. A client without that function falls back to the first line with the same text, and the devlog says so. A line costs one pass over at most a few hundred entries; the combat log, the busiest window in combat, is skipped.
- A clicked link replaces any link dialog still open or queued behind another dialog, and its address is selected whenever its dialog takes focus, so Ctrl+C copies it even when it had to wait.
- Links use the `addon:` link type because it is the one Blizzard routes to addons (`LinkUtil` hands it to `EventRegistry`); any other unknown type falls through to the item tooltip.
- Build mode: each missing API (`ChatFrameUtil`'s filter registries, `TransformMessages`, `EventRegistry`) is logged once to the devlog and its feature switches off; the rest keeps working.
- Placing Blizzard's chat: the chat is a reskin, so the messages, tabs and edit box stay Blizzard's own frames and every secure chat path keeps working. To let Layout move and resize it, the module anchors `ChatFrame1` to its panel. Edit Mode replaces `ChatFrame1`'s `SetPoint` and `ClearAllPoints` with overrides that update the Edit Mode manager, so calling them from addon code would run Edit Mode in a tainted call. The module calls `SetPointBase` and `ClearAllPointsBase`, the widget methods Edit Mode keeps, and falls back to `SetPoint` only on a client without them. Layout itself never moves the Blizzard frame.
- When Blizzard anchors `ChatFrame1` again (Edit Mode applying a layout), a `hooksecurefunc` on its `SetPoint` puts it back in the panel on the next frame. While Edit Mode is open the module waits, and `EventRegistry`'s `EditMode.Exit` brings it back.
- `ChatFrame1` is not protected, so it can be placed in combat. If a client ever makes it protected, placement waits for `Combat.Queue`.
- Blizzard's chat functions that select tabs, resize the dock or change windows (`FCFDock_UpdateTabs`, `FCF_Tab_OnClick`, `PanelTemplates_TabResize`) are never called: running them from addon code would taint the dock and the edit box behind it, the failure other suites hit as chat tabs dying on a protected table. The module only hooks them after the fact.
- Upper-case tab names are set with the tab's `SetText`. The game sizes each tab from its text the next time the dock lays out its tabs, which anchoring the window into the panel triggers at once.
- The button column is reparented through `Safe.HideBlizzard`, not hidden, because Blizzard lays it out and fades it.
- Copying: secret lines cannot be concatenated into the copy text without making the whole text secret, so each one is replaced by a placeholder line. Messages are read with the window's own `GetNumMessages` and `GetMessageInfo`.
- The tab menu entry uses `Menu.ModifyMenu`, the hook Blizzard's menu system offers addons, so Blizzard's menu builder is never replaced. Its handle is unregistered when the module turns off. A client without it logs that the entry is missing; the Copy button still works.
- The glyphs' room is taken from the messages' width so the dock's tabs and its overflow button never run under them.
- The plus opens the module's settings page because the module cannot do what a plus on a chat strip usually does: `FCF_NewChatWindow` and the chat menu are Blizzard functions that open Blizzard windows, and running them from addon code would taint the dock.
- The invisible resting box also has `EnableMouse(false)`, so a click under the messages reaches the world instead of waking the box; the mouse comes back with focus, with the `always` mode and when the module turns off. The edit box is never hidden or shown by the module: Blizzard's own `Deactivate` hides it only in the `classic` chat style, and writing the `chatStyle` CVar would run Blizzard's chat-style handlers from addon code; in that style `always` cannot bring the resting box back and keeps only its room. The module sets the box's alpha instead, the one call it already makes to mirror the panel's opacity, and the game's activate path (`ChatFrameUtil.ActivateChat` sets alpha 1, then focuses the box) brings it back through the focus hooks.
