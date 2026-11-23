# Task: ship the BM hunter hawk perches on the Medallions crest (concept B)

The owner approved concept B (perched hawks) on 2026-11-21: "let's build it and ship it". Turn your prototype into the real feature in one PR to `staging`, `feat(medallions): hawk perches for Summon Hawk`, with an `Added:` changelog line crediting Baine for the idea.

- Engine-fed and secret-safe as you described: `GetTotemDuration(slot)` drives each ring's cooldown swipe, `SetAlphaFromBoolean(haveTotem)` gates the sigil, `PLAYER_TOTEM_UPDATE` only (one owner in `Core/Events.lua`), no Lua timing, no comparisons of secret values. Cite the proving files at 9dc84f0 in the PR.
- Shown only for hunters who know Summon Hawk (1293241); nothing is created or registered for other classes.
- Animations (summon flare, drain, expiry fade, oldest replaced) follow Appearance > Motion (Full/Calm/Off). No OnUpdate when idle; hidden, not alpha 0, when empty (`test-perf-idle-draw` ceiling unchanged for non-hunters).
- Toggle **Hawk perches** in the Medallions options, ON by default. One forged look with the approved crest jewels (#671); tokens from `Core/Tokens.lua` (new tokens only), any new art in `Media/` with provenance; no AI credit lines.
- Docs: `docs/medallions-effects.md`, `docs/feature-map.md` row, locales via `strings.py sync`.
- Tests: hawk count 0/1/2, expiry, third summon replaces the oldest, non-hunter creates nothing, Motion Off end states, toggle off restores today's crest pixel-for-pixel, secret values never compared.
- Evidence: GIFs (0 -> 1 -> 2 draining -> expiry -> resummon) at 1920x1080 and 5120x1440 over real backdrops, `--strict`, plus 2560x1440 and 3840x2160 stills, in `C:/Users/leeba/.cache/kstyleui-evidence/hawk-crest/`. Never commit them.

Lint, python, ActionBars tests, `test-perf*`, `test-taint-scan`, `test-perf-path-budgets`, `test-secrets` under PUC Lua 5.1; hosted CI green. Do not merge.

**Files it may edit**: `KstyleUI_ActionBars/**`, `Core/Events.lua` (only if needed), `Core/Tokens.lua` (new tokens only), `Media/**` with provenance, `Core/Locales/*`, `Tools/locale/*`, `docs/feature-map.md`, `docs/medallions-effects.md`, `docs/medallions.md`, `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and GIF paths.
