# Verify: PR #418 (quest card retention in combat, RestedXP Items alignment) at 066bdead

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `066bdead0b6535ed6eccea263a271f478e1a3f36` (draft PR https://github.com/korallis/KstyleUI/pull/418). Base is `d70a3f5e76ba7f1bd57ec07a8f6be37086c7fc75`. Edit nothing, push nothing, comment nothing.

**Spec the author worked from**: `C:\Projects\KstyleUI\specs\bug-quest-card-combat.md`. Author's report and renders: `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\quest-card\REPORT.txt` and the PNGs beside it.

**Allowed files**: `KstyleUI_Skins/**`, `Core/Layout/Calm.lua`, `Core/Setup/Layouts.lua` (no new top-level locals), `Tools/regression/**` (tests and stubs for this bug only), `Tools/render/scenes/**`, `CHANGELOG.md`, `docs/feature-map.md`.

**Gate**: `bash scripts/gate.sh`; known failing on Windows: `lua` and `python` groups. Windows bar: `gate.sh lint` exit 0 plus every touched or new `Tools/regression/test-*.lua` run with `lua5.1`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. `verify/SKILL.md` documents rendering on this machine.

**Checks**:
- The claimed mechanism: with `GetTitleForQuestID` returning nil (prove from the Forever UI source that nil is a documented/possible return, and in which states), staging clears every quest row and the head keeps the last complete list; a genuinely empty watch list still clears; the combat-deferred retry fires after `PLAYER_REGEN_ENABLED` without another quest event. Run the new tests at base (red) and head (green); paste both. Apply `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\principle-test-behavior-not-implementation\SKILL.md`.
- Stale data risk: can retention show a quest the player abandoned or completed (watch removed while titles are nil)? Show what the code does.
- Forever rules from AGENTS.md: `issecretvalue` before comparisons on watch IDs/counts, no measurement of restricted regions, API names proven in the source (grep the `forever` branch of Gethe/wow-ui-source at `9dc84f0`; clone to `C:\Users\leeba\.cache\wow-ui-source` if missing), CRLF/ASCII addon files, one comment per file, `K.Widgets.FontString`.
- Items box: render the RestedXP scene yourself at 5120x1440 and 3456x2234, measure the Items and Targets tops, and confirm alignment; open the PNGs.
- CI run 43919101868 green for the SHA; `git diff --stat` against the allowed files; suppressions grep; the PR body has `## Changelog` with a `Fixed:` line and `## In-game checks`.
- Comments: `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY; blast radius: `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified 066bdead"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
