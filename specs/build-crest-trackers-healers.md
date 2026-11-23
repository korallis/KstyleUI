# Task: build the healers crest trackers (Priest, Druid and the Shaman extension)

The owner approved every recommended concept ("yes build them all", 2026-11-23). The design study is `C:/Users/leeba/.cache/kstyleui-evidence/crest-trackers/healers/REPORT.md` with the sheets and moment GIFs beside it: read it fully, including the routes, fit and in-game checks.

**Shared helper**: worker ctx_84afd76f826f is building the melee trackers and a shared shoulder-medal / ring-socket helper first; it will push that helper early on its branch (the coordinator forwards the branch and commit). Start with the research, art and class logic; build on that helper (rebase onto its commit) rather than writing your own, and if you need it extended, ask the coordinator (`orca orchestration ask`) instead of changing its API. Open your PR against `staging` once the melee PR is merged, or stacked on its branch if it isn't yet (say which in the body).

Build, Medallions first plus the Frames form the study gives:
- **Priest, A Vigil**: Inner Fire charges (halo and four flames on the inner rim); Penance or Mind Blast ready (left shoulder medal); Shadowfiend ready or Shadowform (right shoulder medal); your Shadow Word: Pain on the target (gem at the top of the ring).
- **Druid, A Grove**: your two effects on the target (two seed medals on the shoulders, form-aware); Clearcasting (leaves bloom on the inner rim); Swiftmend, Nature's Swiftness or Innervate ready (gem at the top of the ring).
- **Shaman, A Stormforged** (adds to Spirit Poles, storm orbs and the two medals): weapon imbues (two stones set into the ring, main hand and off hand); shock cooldown (the emblem sweeps and sparks).

Every piece is engine-driven (duration objects, aura slots, weapon-enchant frames, never-secret values); Lua never compares a secret. Each piece gets its own Options switch (beside Hawk perches and Lightning Shield on the crest), on by default; off restores today's crest exactly. Low-level characters see only what they have. Calm crest at rest (#743) still calms these.

**Evidence** in `C:/Users/leeba/.cache/kstyleui-evidence/crest-trackers/healers/build/`: per class, a GIF of each moment and renders at all four sizes in both styles over real backdrops, `--strict`; 2x crops of every piece checked against the "Polish details" list in `specs/_verify-audit.tmpl`; a concept-vs-build side by side per class; zero-pixel diffs with every switch off and for the other classes.

**Files it may edit**: `KstyleUI_ActionBars/**` (crest code; new per-class files are fine), `Core/Medallions*.lua`, `Core/Effects*.lua`, `Core/Tokens.lua` (art tokens only; say why), new art under `Media/` with provenance and its generator under `Tools/media/`, `KstyleUI_Options/**` (rows only), locales, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, `docs/medallions-effects.md`.

**PR**: `feat(crest): priest, druid and the shaman extension trackers on the crest` with `## Changelog`, `## Options`, `## In-game checks`, `## Forever API`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; no per-frame work, nothing loaded for other classes; `test-perf-fights` and `test-perf-path-budgets` with no new ceiling; Beast speed rule (module tests locally, hosted CI as proof); other workers are polishing the unit frames and the totem fan, so rebase before opening.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and evidence paths.
