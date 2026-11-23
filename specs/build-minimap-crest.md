# Task: dress the minimap as a crest medallion in Medallions (mockup B)

**Goal**: the owner approved mockup B. It is in `C:/Users/leeba/.cache/kstyleui-evidence/minimap-medallions/`: read `B-crest-medallion.png` and `B-in-place-1920x1080.png`, and see `today.png` for comparison. In the Medallions HUD style, the round minimap wears the central crest hub's three ring layers:
- the gunmetal bevel ring (`Ring256`);
- `Enamel256` at 0.35;
- the engraved rune ring (`RuneGlyphs`), additive at 0.25 in the class colour.

These are exactly the layers `KstyleUI_ActionBars/Slab.lua` BuildRing uses, plus the same class-colour edge line. North becomes the crest's level-plaque gem (`LevelPlaque`), set in the band. The coordinates and clock bar is shortened and seated on the bottom rim like the level plaque under the crest. The zone plaque stays as it is.

**Owner decisions**:
- **Size.** The wider band would shrink the visible map from 195 to 167 px at 1080p. Instead, **grow the minimap element** so the visible map keeps today's size (about 18 units per side). The layout overlap guard must pass at 1920x1080, 2560x1440, 5120x1440 and 3840x2160 in Medallions, including players' saved positions. If growing collides with the buff rows or quest cards at a size, move the default of the smallest affected neighbour by the least amount. If that is not clean, grow only as much as fits and say so in the PR.
- **Option.** Following the owner rule, add an Options setting "Crest minimap frame", ON by default. Off gives today's ring. It only affects the Medallions style; Frames and Orbs keep today's minimap.
- **Art resolution.** `Ring256` is 256 px, which blurs at 4K. Find the source the repository's ring textures were made from (`Media/` provenance, `Tools/` scripts) and export the layers the minimap needs at 512 px the same way. Do not upscale or invent art. If no source exists, say so and use the 256 px art.

**Target**: latest `origin/staging`. `KstyleUI_Minimap/**`, the ring builder in `Slab.lua` (reuse it if you can share it in a few lines rather than copying it), `Core/Setup/Layouts.lua` (footprint only, no new top-level local), and the minimap render scenes.

**Tests**: the crest frame is on in Medallions by default and off in the other styles; the setting off restores today's ring; the class colour follows the player's class; the overlap guard passes at the four sizes. Renders before and after at the four sizes in Medallions (`--strict`), over real game backdrops.

**Constraints**: minimal code; AGENTS.md rules (CRLF/ASCII, `K.Widgets.FontString`, one event handler per owner); evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/minimap-crest-build/`). Open a **draft** PR against `staging` titled `feat(minimap): the Medallions minimap wears the crest` with `## Changelog` (`Added: In Medallions, the minimap is framed like the central crest, with a rune ring in your class colour. Turn it off with Crest minimap frame in Options.`), `## Options`, `## In-game checks` and `## Before and after`. Do not merge.

**Files it may edit**: `KstyleUI_Minimap/**`, `KstyleUI_ActionBars/Slab.lua` (sharing the ring builder only), `KstyleUI_Options/**`, `Media/Textures/**` (new 512 px exports with provenance), `Core/Setup/Layouts.lua`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, the module README.

**Gate**: lint, python and the touched modules' tests locally; green Mac CI is the full proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id and render paths.
