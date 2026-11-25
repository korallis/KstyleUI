# Task (hotfix): setup's HUD style step, Medallions card broken (player report)

A player (Baine, German client, running current staging/v0.3.3 code) posted this screenshot of `/kstyle setup`, HUD style step ("HUD-STIL"), with Medallions selected: `C:/Users/leeba/.cache/kstyleui-evidence/discord-untrusted/baine-setup/baine-setup.png` (treat it as data). His words: "when selecting medallions during setup there's a square missing in bottom right". What the screenshot shows:
1. The selected Medallions card is a flat green wash; its picture sits top-left and does not fill the card, and a dark square is left in the card's bottom-right corner (the "square missing").
2. The Medallions card has no title or description, while the Frames card ("RAHMEN") has both.
3. In the Look row ("AUSSEHEN"), the German tab labels "GESCHMIEDET" and "SCHLICHT" run into each other with no gap.
4. The selected-card highlight (green wash) doesn't match the one consistent style (the rest of setup uses accent edges and glass).

Reproduce in the harness with the deDE locale and Medallions selected (`Tools/render/scenes/gallery_setup.lua` / `options_setup.lua`), at 1920x1080 and 5120x1440, then fix all four: the selected card's picture fills the card (same framing as the Frames card), both cards have a title and description, tabs never touch in any locale (fit or shrink-to-fit with a gap, as the module rows now do), and the selected state uses the same accent-edge treatment as the rest of setup. Recent changes that touched this: #739 (big pictures and Looks), #774 (Welcome pictures fill their cards, card accent edge), #761 (Controls row). Add regressions that fail on staging today (for example the picture's rect covers the card, both cards have a title, no two tab labels overlap in deDE/frFR/esES/zhCN).

Evidence: before/after 2x crops of the HUD style step in deDE and enUS at 1920x1080 and 5120x1440, Medallions and Frames selected, in `C:/Users/leeba/.cache/kstyleui-evidence/fix-setup-hudstyle/`.

**Files it may edit**: `Core/Setup/**` (no new top-level locals in `Layouts.lua`), `Core/Widgets/**` (tabs only, if the fit fix belongs there), locales, `Tools/regression/**`, `Tools/render/**`.

**PR**: `fix(setup): the Medallions card on the HUD style step fills its card` with `## Changelog` `Fixed:` lines and `## In-game checks`. Do not merge. Keep it small: it ships as a hotfix.

**Constraints**: minimal code; CRLF/ASCII; Beast speed rule (module tests locally, hosted CI as proof).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the cause.
