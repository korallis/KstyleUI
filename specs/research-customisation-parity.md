# Task: gap analysis: KstyleUI customisation against EllesmereUI (read-only)

**Goal**: the owner wants KstyleUI to offer the same level of customisation as EllesmereUI: everything fully customisable by the player, while keeping KstyleUI's one consistent style and quick setup (every new option on by default unless it changes the look). Find out exactly what EllesmereUI lets players customise, compare it with what KstyleUI offers today, and propose the work in PR-sized batches. Do not build anything yet.

**Research**:
1. **EllesmereUI's customisation surface**, from public sources only: its CurseForge and Wago pages, its website or docs, videos and screenshots, and its public source if it has any. Read behaviour only and copy no code. Cover, per module, what a player can change:
   - unit frames, party and raid frames, nameplates, action bars, cooldowns, auras, cast bars, the minimap, chat, bags, tooltips, data texts, resources and anything else it has;
   - size, position, anchoring and attaching to other frames, growth, spacing;
   - fonts per element, textures, colours (class, reaction, custom), borders and backgrounds;
   - text tags and formats, visibility rules (combat, mouseover, group size, fade), aura filters, sorting;
   - profiles, import and export, per-spec settings, and any layout editor with snapping and grids.

   Note anything retail-only that Forever cannot have.
2. **KstyleUI today** (latest `origin/staging`, cite file:line): each module's settings schema (`*/Settings.lua`), `Core/Options.lua`, Layout Mode (`Core/Layout/**`) and profiles. Include the action bar options from #499 and the in-flight work: the data bar module list (#507), crest presets and the consumables bar.
3. **Gap table**, per module: what EllesmereUI has, what KstyleUI has, and the gap. For each gap, say whether it fits KstyleUI's design rules (one consistent style, so per-element fonts and colours may be "global with optional overrides" rather than free-for-all; the Forever API; combat lockdown) and how to do it with the least code. Prefer generic building blocks shared by every module, such as one "text element" option set (font, size, outline, colour, format) and one "bar element" option set (texture, colour mode, height), reused everywhere.
4. **Layout Mode**: compare EllesmereUI's mover or editor with ours: snapping, grid, nudging, anchor-to-frame, numeric X and Y entry, per-element reset. List the gaps.

**Report**: write `C:/Users/leeba/.cache/kstyleui-evidence/customisation-parity/report.md`. Keep it short:
- the gap table, ranked by how much players will notice;
- the shared building blocks to add first;
- PR-sized batches with line estimates, ordered for the biggest player impact per line;
- risks, such as Options page size, reload cost (keep reload work near zero by building option schemas lazily) and defaults that must not change anyone's look.

Add 2–3 mockups of key Options pages, made by rendering the existing Options pages and editing them with Pillow, saved in the same folder.

**Constraints**: read-only, no PR. Use the Forever UI source (`C:/Users/leeba/.cache/wow-ui-source`, `forever` at `9dc84f0`) for API feasibility. No AI scenery in the mockups.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
