# KstyleUI_Chat

Chat panels, tabs with an accent underline, edit box, copy chat, clickable links and class-coloured names.

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
| `Messages.lua` | The message pipeline and the dialog that copies a clicked link |
| `Module.lua` | Registers the module and its settings page, and starts and stops the parts |

Tests: `Tools/regression/test-chat-format.lua` (the text helpers) and `test-chat-messages.lua` (the pipeline against stand-ins for Blizzard's chat in `Tools/regression/chat_env.lua`).

## Settings

| Key | Default | Row |
| --- | --- | --- |
| `accentSource`, `accentColor` | `class`, the default accent | Links and the chat's highlights follow the class colour or a custom colour |
| `timestamp` | `%H:%M` | `none`, `%H:%M`, `%H:%M:%S`, `%I:%M %p` or `%I:%M:%S %p` |
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
| Timestamps and short channel names | A `hooksecurefunc` post-hook on each chat window's `AddMessage` computes the decorated line and swaps it in through the window's own `TransformMessages`. The combat log is skipped. When the game's own timestamp setting (`showTimestamps`) is on, the module adds none. |

## Why

- Secret values: under chat restriction the game hands addons secret message text and names. Every filter and hook checks `issecretvalue` first and passes a secret on untouched: the filter returns `false` with no replacement, the name filter returns `nil`, and the `AddMessage` hook does nothing. Blizzard's own filter registry also skips addon filters when an argument is secret; the module does not rely on that.
- No protected chat function is replaced or hooked. The send path (`ChatEdit_SendText`, the edit box's `OnEnterPressed`, slash commands) is never touched, so `/cast` and other secure commands typed in chat stay secure.
- No field is written onto a chat window. `AddMessage` is hooked with `hooksecurefunc`, the one change the spec allows. Rewriting a line goes through `TransformMessages`, which `ScrollingMessageFrameSecureMixin` exposes for addons as a secure elevation barrier, instead of replacing `AddMessage` or the `CHAT_*_GET` strings.
- The channel shown in a numbered channel line cannot be shortened in the event filter: Blizzard matches the channel argument's length against the window's channel list after the filters run, so a shorter name would drop the line. The module rewrites the finished line instead.
- `TransformMessages` walks the window's history in its buffer's slot order, not by age, once per new line. The predicate matches only the newest slot, which the window's `historyBuffer:CalculateElementIndex(1)` names, so an older identical line is never rewritten in its place. A client without that function falls back to the first line with the same text, and the devlog says so. A line costs one pass over at most a few hundred entries; the combat log, the busiest window in combat, is skipped.
- A clicked link replaces any link dialog still open or queued behind another dialog, and its address is selected whenever its dialog takes focus, so Ctrl+C copies it even when it had to wait.
- Links use the `addon:` link type because it is the one Blizzard routes to addons (`LinkUtil` hands it to `EventRegistry`); any other unknown type falls through to the item tooltip.
- Build mode: each missing API (`ChatFrameUtil`'s filter registries, `TransformMessages`, `EventRegistry`) is logged once to the devlog and its feature switches off; the rest keeps working.
