# Task: polish the Medallions crest resource jewels to the owner's mockup standard

The owner says the crest jewels (v0.2.9, `KstyleUI_ActionBars/SlabJewels.lua`, PR #614) "don't look as polished as I think they can be". In his original mockups, e.g. the rogue one, **when you were at max combo points the entire ring glowed**. Current renders: `C:/Users/leeba/.cache/kstyleui-evidence/showcase-jewels/` (crest-rogue/paladin/warlock GIFs and frames). The owner may send the original mockup images; the coordinator will forward them, and then match them closely.

**Build (one forged look; read docs/medallions.md and docs/medallions-effects.md first and reuse the existing Medallions effects and tokens, never new colour literals outside `Core/Tokens.lua`):**
1. **Full ring at max**: when the resource is at its maximum, the whole crest rune ring lights in the resource's colour (embers for combo points, gold for holy power, violet for soul shards): the runes glow and a soft halo breathes around the ring. It fades in over ~0.2 s on reaching max and out when a point is spent.
2. **Point gained**: a new jewel ignites with a brief flash/bloom (gem core flares, then settles), not just switching on.
3. **Points spent**: lit jewels drain with a short fade, not an instant cut.
4. **Jewel finish**: richer gems: a lit gem has depth (darker rim, bright core, specular glint), sockets read as cut settings when empty, and the five sit evenly with consistent spacing at every size.
5. **Motion setting**: every animation follows Appearance > Motion (Full / Calm / Off); Off shows the end states with no animation. No OnUpdate while nothing animates.
6. **Secret-safe**: values stay engine-fed (status bars / SetAlphaFromBoolean / curves); Lua never compares a secret power value. The max-ring state must also come from the engine side (e.g. a status bar or curve driven by power/max), never a Lua comparison of secret numbers; prove the approach against the Forever API docs at 9dc84f0.
7. Keep the switch (Action Bars > Slab and cooldowns > Crest resource jewels) and add **Glow at max** under it, on by default; off keeps today's ring.

**Evidence**: animated GIFs (0→max→spend, like the showcase set) for rogue, paladin and warlock at 1920x1080 and 5120x1440 over real game backdrops, `--strict`; default renders with jewels off pixel-identical to staging; Motion Off stills. Regressions (stub) for: max state lights the ring and turns off on spend, gain/spend transitions, Motion Off has no animation, no OnUpdate while idle, secret values never compared. Lint, python, ActionBars tests, `test-taint-scan`, `test-perf-path-budgets`, `test-secrets` under PUC Lua 5.1; hosted CI green. One PR to `staging`, `feat(actionbars): ...`, `Changed:` changelog line. Do not merge; the coordinator shows the owner the GIFs before merge.

**Files it may edit**: `KstyleUI_ActionBars/**`, `Core/Tokens.lua` (new jewel/glow tokens only), `Media/**` (new textures with provenance), `Core/Locales/*`, `Tools/locale/*`, `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and the GIF paths.
