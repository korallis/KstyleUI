# Task: the shaman totem choice fan has no background in game

The owner (2026-11-23), in game on the released build: "the shaman totems when they expand to select one, they don't look like this. there's no background etc. so it didn't complete all the way." His reference picture is `C:/Users/leeba/.cache/kstyleui-evidence/fix-totem-fan/owner-reference.gif` (the marketing render of the Spirit Poles: forged sockets with coloured frames, dark backing and spires). In game, when a socket's fan opens (right click a socket, `KstyleUI_ActionBars/Totems.lua` `Choice()`, `Unfold`, `Place()`), the fan buttons draw as bare icons: no slab dressing, no dark shade disc, no frame.

The render harness shows the backgrounds, so this is a harness-vs-client gap: something the harness draws that the client doesn't. Rule: believe the game over the harness. Check, at least:
- `f.shade` (`Art(f, "BACKGROUND", "glow", "black")`, sized in `Place()` with `Widgets.Size(f.shade, FAN * 2.6, ...)`): does the client draw a BACKGROUND texture bigger than its frame, and is the size applied before the first show?
- `ns.Slab.Dress(f)` and `f:Restyle()` on fan buttons: do they run for every fan button (including ones created by `Fill()` after a later `SPELLS_CHANGED`), and under Medallions and Frames? Does Dress put its art on a child frame whose frame level ends up below the crest hub or the fan's parent?
- The fan's alpha animation (`Fade(f, 0, 1, UNFOLD, 2)`, Translation animations): with `Effects.Allows("flare")` off or at Calm, does anything stay at alpha 0? Memory note: in the client SetAlpha on a texture is its vertex alpha (last write wins), unlike the harness's old model.
- Secure templates: `SecureActionButtonTemplate` buttons parented to a secure fan; is any art created in combat or hidden by a state driver?

Fix the cause so the opened fan in game matches the reference look (dark backing and forged frame behind each choice, both HUD styles). Make the stubs raise or model what the client does, so a regression test fails on today's code (see `Tools/regression/test-stub-refusals.lua` for how the stubs copy client refusals). Evidence: harness renders of the opened fan at 1920x1080 and 3840x2160 in both styles, in `C:/Users/leeba/.cache/kstyleui-evidence/fix-totem-fan/`, plus a short note in the PR of what the client did differently.

**Files it may edit**: `KstyleUI_ActionBars/Totems.lua`, `KstyleUI_ActionBars/Slab.lua` and `Socket.lua` (only if Dress is the cause), `Tools/regression/**` (stubs included), `Tools/render/**`.

**PR**: `fix(actionbars): the totem choice fan gets its forged backing in game` with a `## Changelog` `Fixed:` line and an `## In-game checks` list. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Beast speed rule (module tests locally, hosted CI as proof).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the cause.
