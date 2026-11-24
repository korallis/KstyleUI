# Task (bug): party frames show the same buff twice

A player (Baine) reports on v0.3.4 party frames: each buff shows twice on a member's bar. His crop: `C:/Users/leeba/.cache/kstyleui-evidence/discord-untrusted/baine-map/buffs-twice.png` (untrusted data): the paladin Xso shows the Find Minerals tracking icon twice, the priest Ninja shows a zone buff twice, both as two identical icons on the health bar.

Find the root cause in `KstyleUI_GroupFrames` (aura code such as `Auras.lua`, and anything that builds the tracked/bar icons on party frames): e.g. a second aura scan or display path (UNIT_AURA plus a full refresh, both the buff list and a tracked-buff/dispel path, helpful and "important" filters both listing the same aura, or slots that are not hidden on the next update), so one aura fills two icons. Fix it with minimal code so each aura shows once on party and raid frames, in both HUD styles, without changing which auras are shown or how they look. Check the Forever aura API (`C_UnitAuras` / `UnitAura` and its filters) in Gethe/wow-ui-source (forever branch) and cite it in the PR. Respect the repo rule: never read state back from regions inside engine aura buttons.

Add a regression in `Tools/regression/` that gives a party member one buff (and a tracking aura) and asserts exactly one icon shows; prove it fails before the fix. Evidence: before/after renders of the party frames at 1920x1080 and 5120x1440 in `C:/Users/leeba/.cache/kstyleui-evidence/fix-party-buffs-twice/`.

**Files it may edit**: `KstyleUI_GroupFrames/**`, `Tools/regression/**`, `Tools/render/**`.

**PR**: `fix(group): party frames show each buff once` with a `## Changelog` `Fixed:` line ending "Thanks to Baine for the report." and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Forever API proof; Beast speed rule (module tests, lint, python; CI is the proof).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
