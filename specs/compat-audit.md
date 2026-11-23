# Task: audit KstyleUI for conflicts with other addons, and propose guards (read-only)

**Goal**: the owner rule is that KstyleUI must not cause conflicts with other addons wherever that can be avoided. Players run it alongside addons such as:
- questing and guides: Questie (and QuestieTrace), RestedXP, HandyNotes;
- professions and trade: Mastercraft, Gatherpedia, Auctionator, TSM;
- combat: Details, DBM, BigWigs, WeakAuras, GTFO, KickAlert;
- bars and UI: Bartender, Dominos, Leatrix Plus;
- social and utility: BetterFriendlist, SimplePoisons, Polite, LayerSwap, Questynator;
- error capture: BugSack and BugGrabber.

Find every way KstyleUI could break, slow down or taint another addon or Blizzard's UI, rank the findings, and propose the smallest fix for each. Most important, propose **automatic checks** (source-scan tests whose failure message names the fix) that stop each kind of conflict from coming back. Change no code.

**Look for** (latest `origin/staging`, cite file:line):
1. **Taint**: replacing Blizzard functions or methods instead of `hooksecurefunc`; `SetScript` on Blizzard or other addons' frames instead of `HookScript`; writing fields on Blizzard secure frames or mixins; anything that can taint action bars, unit frames, nameplates, the world map, the quest log, Edit Mode or the chat edit box.
2. **Globals**: globals KstyleUI creates outside its `.luacheckrc` line; generic names another addon could also use, such as frame names, `SLASH_*` and `BINDING_*` strings.
3. **Shared Blizzard frames**: re-parenting, hiding, moving or re-skinning frames other addons also hook or move, such as `ObjectiveTrackerFrame`, `Minimap` children, `ChatFrame*`, `GameTooltip`, `UIParent` panels and `WorldMapFrame`. Check whether KstyleUI yields when another addon owns the frame.
4. **Settings others rely on**: CVars KstyleUI changes, especially without restoring them; key bindings it overrides; the UI scale.
5. **Events and cost**: `OnUpdate` scripts, broad event registrations, and `GameTooltip` hooks that run on every tooltip and are not cheap.
6. **Same-job addons**: action bars, meters, the quest tracker, the minimap, chat, bags, tooltips and nameplates. For each, say whether KstyleUI detects the other addon with `C_AddOns.IsAddOnLoaded` and yields, for example by turning its own module off or skipping the skin with a one-line notice. Point to the existing pattern, such as the Questie and RestedXP coexistence work (#502, #498, #487).
7. **Errors**: code paths that can throw when another addon has changed a Blizzard frame, such as a missing region or a nil `GetPoint`.

**Report**: write `C:/Users/leeba/.cache/kstyleui-evidence/compat-audit/report.md`. Keep it short:
- the findings, ranked by player impact, each with file:line and the smallest fix;
- a list of proposed guard tests. Each names what it scans, the exact failure message (which names the fix), and proof that it would have caught a real past mistake in this repo's history (cite the commit), or "no past case";
- a proposed "yield to" table: for each other addon, the KstyleUI module, and whether it is on, skinned or off;
- PR-sized fix batches with line estimates.

**Constraints**: read-only, no PR. Use the Forever UI source (`C:/Users/leeba/.cache/wow-ui-source`, `forever` at `9dc84f0`) for Blizzard frames and APIs. Use public pages only for other addons' behaviour, and copy no code.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
