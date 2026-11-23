# Audit: tiny polish defects across the whole UI, at native size

The owner (2026-11-23), after finding several on v0.3.1 in game: "it's tiny things like this that really affect the quality of polish". Examples he found: the Medallions slab not meeting the crest, uneven bar insets, a pale mana bar with a 1 px purple line past its end, combat icons half over a border, party "100%" cut to "10...", a setup page stuck invisible, the totem fan missing its mockup backing. All passed the harness. Fixes for those are already in flight; your job is to find the rest.

**Read-only audit. No code changes, no PR.**

Render every scene in `docs/feature-map.md` / `Tools/render/scenes/` that shows player-facing UI (HUD, unit/party/raid frames, nameplates, action bars, crest effects, cast bars, auras, bags, tooltips, chat, minimap, data strip, meter, Options and setup windows, skinned Blizzard windows, world map, quest card) from current `origin/staging`, in Medallions and Frames, at 1920x1080 and 5120x1440 (`--ppu 1` / `--ppu 1.3333333333`, `--strict`, real backdrops from `~/.cache/kstyleui-backdrops`). Also study the owner's in-game screenshots in `C:/Program Files (x86)/World of Warcraft/_forever_/Screenshots` (newest first, read-only; copy any crop you cite into your evidence folder). At most 2 renders at a time.

Cut 2x zoomed crops of every element and look for: uneven insets or margins; bars not aligned to their frame; anything overrunning an edge by even 1 px; icons half over a border or floating without a socket; colours wrong for their type (power, class, reaction, quality); text truncated that should fit or truncated with no ellipsis; blurry or off-grid edges; inconsistent sizes, fonts or spacing between siblings; gaps between pieces meant to join; empty or placeholder states that look unfinished; anything that would look cheap next to the latest CaithUI.

**Report** in `C:/Users/leeba/.cache/kstyleui-evidence/audit-polish-<your-family>/REPORT.md`: one numbered row per defect with the module, the scene and size, the crop path, what's wrong in one line, the likely file:line, and severity (players will notice / a careful eye / nitpick). Skip the defects already listed above. Rank by how much each hurts the first impression.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the report path and the top ten.
