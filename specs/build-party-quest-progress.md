# Task: hover a quest to see your party's progress on it

**Goal**: a player asked for what ElvUI-style setups offer. Hovering a quest in the quest card shows the whole party's progress on that quest, for example "Lycia: Bloodscalp Headhunters 5/8, Rumpy: 8/8 (done)". Build it into KstyleUI's quest card (`KstyleUI_Skins/Quests/**`) and its tooltip, in the KstyleUI tooltip style.

**Research first** (cite the Forever UI source, `C:/Users/leeba/.cache/wow-ui-source`, `forever` at `9dc84f0`, file:line):
- Which unit and quest APIs exist on Forever:
  - `C_QuestLog.IsUnitOnQuest(unit, questID)`, to show who in the party has the quest even without addons;
  - whether any API gives another unit's objective progress (very likely none);
  - any secret-value flags on these APIs.
- **Progress needs addon messages.** Use `C_ChatInfo.RegisterAddonMessagePrefix` and `SendAddonMessage` on the PARTY channel, with Forever's throttling rules. Each KstyleUI player sends a compact, throttled summary of their quest objectives when they change (`QUEST_LOG_UPDATE`, `UNIT_QUEST_LOG_CHANGED`, `GROUP_ROSTER_UPDATE`), and peers keep it.
- **Questie interop.** If Questie is loaded, check whether its public data already holds party members' remote quest logs (QuestieComms). If so, read it as a source too, without copying Questie's code: read only its runtime tables, defensively, and skip it if absent. Cite Questie's public source for the field names.

**Behaviour**:
- Hovering a quest row in the quest card opens a tooltip section "Party". It lists each party member on the quest with each objective's progress, or "done", in class colours.
  - A member on the quest with no data (no KstyleUI and no Questie) shows "on this quest".
  - A member not on the quest shows nothing.
- Also add the same section to Questie's tracker rows when Questie's tracker is the chosen one, but only if that takes a few lines through a tooltip hook; otherwise skip it and say so.
- **Option** on the Quests settings: "Show party progress on quests", ON by default (owner rule).
- **Cheap**: send nothing when solo, throttle sends to about one per 2 s per change burst, never send in raids over 5 unless the cost is proven low, and store no history.
- **No comparisons on secret values.**

**Tests**: the message encode and decode round-trip; throttle; the tooltip with members who have data, members with no data and members who aren't on the quest; the setting off sends and shows nothing; solo sends nothing. Renders of the tooltip at 1920x1080 and 3840x2160 in the quest card scene, using real game scenery backdrops.

**Constraints**: minimal code; AGENTS.md rules (one event handler per owner, CRLF/ASCII, `K.Widgets.FontString`, Forever API cited per file); evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/party-quests/`). Open a **draft** PR against `staging` titled `feat(quests): hover a quest to see your party's progress` with:
- `## Changelog`: `Added: Hover a quest in the quest card to see each party member's progress on it. Party members with KstyleUI or Questie show their objectives.`
- `## Options`, `## In-game checks` and `## Before and after`.

Do not merge.

**Files it may edit**: `KstyleUI_Skins/Quests/**`, `KstyleUI_Tooltips/**` (only if the tooltip section needs it), `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `.luacheckrc` (only the module's own line), `docs/feature-map.md`, the module README.

**Gate**: lint, python and the touched modules' tests locally; CI. Lua shard 1 may fail on `test-perf-path-budgets` until the staging reload fix merges. Keep your own reload cost near zero: register lazily, and send nothing at load.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
