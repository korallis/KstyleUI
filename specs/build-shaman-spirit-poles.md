# Task: build the shaman package — Concept B "Spirit Poles" (totem bar + Ghost Wolf + shaman crown)

The owner picked Concept B from the design study: read `C:/Users/leeba/.cache/kstyleui-evidence/shaman-totem-bar/REPORT.md` and its images (`B-poles-*.png`, `B-poles-choose-drop-expire.gif`) first. The goal is "true love" for shamans: ultra-polished, one forged look with the crest, the approved crowns (`Core/Widgets/ClassPip.lua`, `KstyleUI_ActionBars/SlabCrown.lua`, merged in #678) and the jewels.

**What to build** (as in the B mockup, done properly with real art and animation):
- KstyleUI takes over Blizzard's `MultiCastActionBarFrame` for shamans with its own secure buttons (the report's stance/pet precedent: action, multispell, destroytotem), hiding Blizzard's bar; nothing taints, nothing moves in combat lockdown.
- Medallions: four element sockets set into the crest ring (order earth, fire, water, air, as in the mockup; earth moss green, fire, water and air in their colours from tokens), each holding the chosen totem; each socket's flyout fans out as a forged fan to choose a totem; the shaman crown's four spires rise from their sockets (owner accepts the smaller, socket-seated spires) and show active totems with time left from `GetTotemInfo`/duration objects, engine-fed and secret-safe; Ghost Wolf and Call of the Elements as medals on the ring's shoulders; right-click on Call = Recall (say so in its tooltip). Check against the crest debuff fan (`KstyleUI_UnitFrames/Fan.lua`) so nothing overlaps.
- Frames and Orbs: the same pieces as a forged row in each style's layout (report section on Frames), with the crown on that row.
- States: empty slot, chosen, active with time, cooldown; Motion Full/Calm/Off; no idle OnUpdate; hidden-not-alpha-0.
- Keybinds: the source declares no MULTICASTACTIONBUTTON bindings on Forever (report); expose bindings for the four slots, Call and Recall through KstyleUI's existing binding approach if it has one, else skip and note it.
- Setting **Shaman totem bar** (Action Bars), ON by default; off gives Blizzard's bar back exactly as today. Layout Mode: movable in Frames/Orbs; saved positions respected.
- Use Higgsfield (higgsfield-generate) for the element socket and spire art if it lifts quality; art in `Media/` with provenance; no AI credit lines.

**Evidence**: GIFs (choose from a flyout, drop, active timer, expire; Ghost Wolf; Call) in Medallions and Frames at 1920x1080 and 5120x1440, stills at 2560x1440 and 3840x2160, all over real backdrops, `--strict`, in `C:/Users/leeba/.cache/kstyleui-evidence/shaman-totem-bar/build/`. Off-state and non-shaman renders pixel-identical to staging. Tests: take-over and give-back, combat lockdown, flyout choose, totem active/expire via the secret path, Recall, toggle, non-shaman creates nothing, Motion Off, `test-taint-scan`, `test-perf-path-budgets`, `test-perf*`, `test-secrets` under PUC Lua 5.1; hosted CI green. Cite proving files at 9dc84f0 in the PR.

PR to `staging`: `feat(actionbars): shaman Spirit Poles — totem bar and Ghost Wolf on the crest`, `Added:` line, in-game checks list. Do not merge. Note: the class-crowns PR (ctx_daa2c781239a) is told to leave the shaman crown to this PR.

**Files it may edit**: `KstyleUI_ActionBars/**`, `KstyleUI_UnitFrames/**` (only for the Frames/Orbs row and fan clearance), `Core/Widgets/ClassPip.lua`, `Core/Events.lua` (only if needed), `Core/Tokens.lua` (new tokens only), `Media/**` with provenance, `Core/Locales/*`, `Tools/locale/*`, `docs/feature-map.md`, `docs/medallions-effects.md`, `docs/statecharts/**`, `.luacheckrc` (only your module's line for new globals), `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id and GIF paths.
