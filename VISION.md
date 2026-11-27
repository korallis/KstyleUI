# Vision

`KstyleUI` exists so that a World of Warcraft: Forever player can replace the whole default interface with one finished, dark forged style whose crest comes alive with their class's spells, without it ever costing them a Lua error or a taint.
It serves Forever players who install it from CurseForge, Wago or GitHub, and it turns one setup window into a complete HUD and a matching set of restyled windows.
It owns exactly one thing: how the Forever interface looks and behaves, built from its own code and its own art.

This file says what the project is for and how to weigh one good thing against another.
The rules a change must follow are in [AGENTS.md](AGENTS.md), and the design it must match is the [design spec](docs/superpowers/specs/2026-11-07-kstyleui-design.md).
Where this file and those two disagree on a rule, they win and this file is corrected.

## Reliability comes before everything it adds

A feature that can throw a Lua error or taint Blizzard's UI is not merged, however good it looks.
Secret values pass unchanged only to the APIs documented to accept them; nothing compares, branches on, indexes by, measures or does arithmetic on a secret.
Aura data goes secret during a boss pull before combat lockdown begins, so aura reads are guarded with `C_Secrets.ShouldAurasBeSecret()`, addon aura updates freeze while it is true, and they resume only from a restriction-change event after checking again.
State is never read back from regions inside engine aura buttons.
Blizzard frames are observed, hooked with `hooksecurefunc` or `HookScript`, or faded with `SetAlpha`; they are never driven, re-scripted with `SetScript`, written to, or hidden while Blizzard lays them out.
A hook goes only where the client allows one: an engine aura slot's visibility is secret, so no `OnShow` or `OnHide` handler is ever attached to one, by `HookScript` or by `SetScript`, and what the addon needs to know about a slot comes from objects the addon owns.
Protected work in combat waits in `KstyleUI.Combat.Queue`.
When safety is uncertain, the operation is skipped and the safer path is taken.
A failure stays small: a piece that errors takes only itself down, never the module around it.
A fix goes at the root of a failure, and the regression stubs learn the client rule that caused it, so the suite fails if it returns.
A test render proves layout, not freedom from taint; only the game settles that, in the owner's in-game pass, and a release candidate is also run with the forced-restriction CVars and the taint log on.

## Forever only, checked against its real source

KstyleUI targets the Forever client and nothing else: TOC `16001`, game type `camelot`, classic-era spell IDs.
No change adds another client's branches or prepares for one.
Every API, event, template, mixin, CVar or Blizzard frame name is found in the Forever UI source revision the repo records, or in build-matched client proof, and the pull request cites it.
Retail branches, retail spell IDs, deprecated shims and the combat log are refused.
An unknown Blizzard global is a finding to resolve, never something to silence in `.luacheckrc`.

## The living crest is the point

Animated effects are a core goal of KstyleUI, not decoration on top of it.
The crest, and everything else a player needs to track, is shown as animated, polished spell effects that are easy to identify and read and that match the one look: animated spell-effect auras, not static icons and not rows of spell icons.
A class's buffs, procs, debuffs, cooldowns and resources live on the crest itself under Medallions, and the same pieces stand free above the stance bar under Frames.
Every class already has a crest; the project grows by finishing each class's crest and cooldown work in turn, with more of its spells shown and richer effects.
A still mark that remains is a stand-in on the way to an animated aura, not the destination.
When an effect and its frame cost pull against each other, the effect stays and the work goes into making it cheaper; an effect is not cut for cost before that work is done.
Cheap means: art is baked small and loaded only when it is needed, nothing is drawn that is not seen, effects run as animation groups, flipbooks or engine curves rather than Lua every frame, nothing runs while the effect or its module is switched off, `OnUpdate` runs only while something animates or counts down, hot paths reuse frames and buffers, and every effect follows the player's Full, Calm or Off motion choice.
Every piece has its own switch in `/kstyle`, and a player who turns a module off pays nothing for it.
A performance change is welcome when the only thing players notice is a lighter cost.

## One art direction, set by the owner

The look is one forged style across bars, frames, bags and windows, with the current character's class colour as the accent by default.
The design spec, the mockups and the owner's recorded rulings are binding; layout geometry, materials and defaults change only by a new owner ruling.
Colours come only from `Core/Tokens.lua`; text, overlays and cards come from the shared widget kit, pixel snapping from the core's scale service, and modules use the core public API rather than each other's internals.
Borders land on whole physical pixels on every supported screen, and pixel-perfect sizing stays the default even where other sizing is offered.
Crest, aura and animation artwork is made in Blender from the project's own models, then baked small and loaded only when needed.
All art is KstyleUI's own: each generated or rendered asset has a row in `Media/PROVENANCE.md` saying how it was made, and nothing is extracted or traced from the game or lifted from another addon.
Art made another way before this rule keeps its provenance row; whether a piece is remade is the owner's call.
Matching another addon's behaviour is fine; copying its source, or adding a library for something the kit already does, is not.

## Shipped through staging, confirmed in game

Every change is one coherent pull request into `staging`, titled `type(scope): summary`, with the in-game checks the owner will run and a changelog line a player can read; a change to docs or tooling alone carries the `no changelog` label instead.
Before it merges, the project's gate passes on the exact commit and the latest GPT Sol model has independently reviewed the diff.
`main` and every release tag move only after the owner's in-game pass.
One release is cut from `main` each time a class's crest and cooldown work is complete; a fix that cannot wait goes out in between as a hotfix built from `main`, carrying only that fix.
The changelog, README and roadmap speak to players in plain language and never describe tooling.
Player-facing strings go through the locale tables, so translations follow every new string.
Bug reports and ideas arrive on Discord; a change that answers one says what the player will notice, and the changelog thanks the player who found or tested it.

## What an agent may do alone, and what waits for the owner

An agent builds what the owner asked for or approved as a plan, and merges it into `staging` itself once the gate and the independent review pass.
An agent may start and merge on its own: fixes that bring a reproducible Lua error, taint or broken behaviour back to what the docs or changelog already promise; new or repaired tests and stubs; doc fixes; encoding, line-ending and locale-sync repairs; and performance changes players cannot see.
An agent proposes to the owner before building: anything new or different that players can see; any change to geometry, materials, fonts, defaults or the art direction; a new module, setting or slash command, or removing one; new art; and new dependencies.
A change to `.github/workflows/`, `.pkgmeta` or `Core/Tokens.lua` is explained in its pull request, and a TOC version or `CODE_BUILD` changes only in a release.
`main`, tags and releases move only on the owner's word after their in-game pass; an agent prepares and cuts a release when the owner asks for one.
An outside pull request gets a full review against this vision and the gate run on its commit; the agent recommends merging it, asking for changes or reworking it, and the owner chooses.

## Scope

KstyleUI is entirely its own code: it is not built on oUF or Ace3, and LibSharedMedia is optional interop only.
It does not read the combat log; boss timelines and anything else that needs the combat log are out.
Its own frames move in its own Layout Mode, not Blizzard's Edit Mode; setup writes an Edit Mode layout only to place the Blizzard frames it keeps.
A dedicated gamepad layout is planned; today setup offers Gamepad controls (bars 1 and 2 as two groups of eight), keybinds show the active controller's glyphs, and the bars stand aside cleanly in the game's gamepad mode.
Click casting is the game's own: the group frames offer a panel on the game's Click Casting bindings and a reminder on the frames, and KstyleUI builds no second click-cast system.
The accent is the class colour or one custom colour, and the Forged, Clean and Readable Looks and the card materials are the only presets; extra accent themes wait for an owner ruling.
The optional icon pack is not part of the addon and ships only on GitHub.

A change aligns when it brings the crest more alive, turns a still mark into an animated aura, removes a Lua error, a taint or wasted work, makes an effect or module cheaper without taking it away, brings a surface closer to the owner's picture, completes a class's crest and cooldown work, moves the gamepad layout forward inside these rules, or fixes a real player report at its root, with a test.
A change should be resisted when it can throw or taint in combat, attaches a script to a frame whose state is secret, relies on an API it cannot cite from the Forever source, adds another client's branches, does work while disabled, loads or draws art nobody sees, ignores the motion choice, adds a static icon where an animated aura belongs, cuts a crest effect to save frame cost before making it cheaper, adds colour literals outside the tokens, copied code or a redundant library, changes geometry or the art direction without an owner ruling, or reaches `main` before the owner's in-game pass.
