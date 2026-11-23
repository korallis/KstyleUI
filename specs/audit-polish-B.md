# Task: polish audit, B. motion and interaction (read-only report with renders)

**The owner's words**: "Do a massive polish audit checking how everything could be improved to achieve massive polish that beats CaithUI and all other popular UI packs by quite a margin."

Several auditors from different model families each take one lens; you have **B. motion and interaction**. Don't coordinate with the others. Read the project rules first: `AGENTS.md`, the design spec and the roadmap it links. Keep the binding owner rules:
- one consistent style, everything forged as one piece;
- everything toggleable and ON by default;
- minimal code;
- the four screen sizes (1920x1080, 2560x1440, 5120x1440, 3840x2160);
- real game scenery only;
- performance changes are pixel-identical.

**Context**:
- KstyleUI is a WoW Forever UI suite with three HUD styles (Frames, Orbs, Medallions) plus skins, options, Layout Mode and a world map. The latest release is v0.2.8.1; work on `origin/staging`.
- The render harness (`Tools/render/shoot.sh`, `docs/feature-map.md`, `Tools/render/README.md`) renders every scene. The owner's real game screenshots are in `~/.cache/kstyleui-backdrops`. At most 2 renders at a time.
- Competitors to beat: CaithUI (https://youtu.be/8WPBCQLa4BA is the owner's reference video), ElvUI, EllesmereUI, NaowhUI, SUI, LUI, Tukui, KkthnxUI. Use public pages, videos and screenshots only, and copy nothing.

**Lenses** (yours is B):
- **A. Visual craft:**
  - typography (sizes, weights, tracking, hierarchy), spacing rhythm, alignment and pixel snapping, edges and borders, shadows and glass, colour and contrast;
  - icon treatment, art cohesion between modules, density, and how it reads at a glance in combat;
  - every HUD style, role and screen size, plus the skins.
- **B. Motion and interaction:**
  - animation timing and easing, hover and press states, transitions, feedback;
  - Layout Mode feel, Options window UX (navigation, search, previews, defaults), first-run setup;
  - error states, empty states and discoverability.
- **C. Competitor teardown:** for each competitor, the 5-10 details that make players say "wow" (screenshots and videos with timestamps), what they do better than KstyleUI today, and what KstyleUI already does better. Finish with a ranked "beat them by a margin" list.
- **D. Systems polish:**
  - perceived performance (load, hitches, combat), reliability (Lua errors, taint, combat lockdown), edge cases (vehicles, pet battles, cinematics, resizing, UI scale, very long names, empty bags or quest logs);
  - the world map, chat, bags, tooltips, minimap and data bars;
  - accessibility (colour vision, readability options) and localisation fit (German and French string lengths).

**Do**:
- Render what your lens needs, with `--strict`, over real backdrops.
- Inspect closely: crop and zoom. Cite file:line in the code for each finding.

**Output**: `C:/Users/leeba/.cache/kstyleui-evidence/polish-audit/B-<family>.md`, with `B` being A, B, C or D. Include:
- a ranked table (impact on how premium it feels, effort in S/M/L, which module, file:line, render or crop path);
- the **top 10** changes that would most lift KstyleUI above CaithUI and the others, each with a before render and, where it helps, a quick Pillow mockup of the after using real repo art only;
- anything that's already best-in-class and must not regress.

No code changes, commits or PRs. Evidence goes in `C:/Users/leeba/.cache/kstyleui-evidence/polish-audit/` and is never committed.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the report path and your top 5.
