# Task: build the melee crest trackers (Warrior, Paladin, Rogue)

The owner approved all three recommended concepts and every piece in them ("yeah add all", 2026-11-23). The design study is `C:/Users/leeba/.cache/kstyleui-evidence/crest-trackers/melee/REPORT.md` with the concept sheets and moment GIFs beside it: read it fully, including "The routes every piece uses", "Fit on the crest" and "In-game checks before any build".

Build, Medallions first plus the Frames form the study gives:
- **Warrior, War Drums**: Sunder Armor banners stay (today's crown); Battle Shout timer on the left shoulder (anyone's shout counts, `HELPFUL`, as that is what the buff does); "the opening" on the right shoulder (Overpower, Revenge or Execute usable); Enrage burning round the inner rim for every warrior.
- **Paladin, Seal and Gavel**: the active Seal and its timer in a reliquary above the crest; Judgement cooldown on the left shoulder; your Judgement on the target on the right shoulder; the five ring jewels fed by Vengeance, falling back to Holy Shield charges.
- **Rogue, Cutthroat's Kit**: combo-point blades stay; Slice and Dice timer on the left shoulder; Rupture on the target on the right shoulder; a poison vial per weapon on the lower ring, draining with the poison's time.

Build one shared shoulder-medal / ring-socket helper first (reuse what the shaman's Ghost Wolf and Call medals, hawk perches and storm orbs already do in `KstyleUI_ActionBars/Totems.lua`, `Slab.lua` and the crest effects; extend, don't duplicate) so the ranged and healer classes can use it next. Every piece is engine-driven (duration objects, aura slots, weapon-enchant frames, never-secret values); Lua never compares a secret. Each piece gets its own Options switch (beside Hawk perches and Lightning Shield on the crest), on by default; off restores today's crest exactly. Low-level characters see only what they have. Calm crest at rest (#743) still calms these.

**Evidence** in `C:/Users/leeba/.cache/kstyleui-evidence/crest-trackers/melee/build/`: per class, a GIF of each moment and renders at all four sizes in both styles over real backdrops, `--strict`; 2x crops of every piece checked against the "Polish details" list in `specs/_verify-audit.tmpl`; a concept-vs-build side by side per class; zero-pixel diffs with every switch off and for the other classes.

**Files it may edit**: `KstyleUI_ActionBars/**` (crest code; new per-class files are fine), `Core/Medallions*.lua`, `Core/Effects*.lua`, `Core/Tokens.lua` (art tokens only; say why), new art under `Media/` with provenance and its generator under `Tools/media/`, `KstyleUI_Options/**` (rows only), locales, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, `docs/medallions-effects.md`.

**PR**: `feat(crest): warrior, paladin and rogue trackers on the crest` with `## Changelog`, `## Options`, `## In-game checks`, `## Forever API`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; no per-frame work, nothing loaded for other classes; `test-perf-fights` and `test-perf-path-budgets` with no new ceiling; Beast speed rule (module tests locally, hosted CI as proof); other workers are polishing the unit frames and the totem fan, so rebase before opening.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and evidence paths.
