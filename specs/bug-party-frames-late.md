# Task: party frames appear late after joining a group

**Goal**: a tester (0xDAB, druid, levelling): "overall I see a bit of lag of state update, e.g. joined the party and the overlay showed later." When a player joins a party (or raid, or someone joins theirs), KstyleUI's group frames must appear at once, and every state update (health, power, auras, role, ready check, offline, dead, range) must show promptly.

**Target**: KstyleUI on the latest `origin/staging` (it now includes the performance work #456, #462: P5c skips widgets whose inputs did not change, P3 builds chrome on first show; and #464, #468). `KstyleUI_GroupFrames/**` (`AutoLayout.lua`, `Unit.lua`, `Frames.lua`, header/visibility code), `Core/Events.lua`, `Core/Combat.lua` (deferred work in combat), `Core/Widgets/Base.lua` (first-show build).

**Change**:
1. Reproduce in the stubs: fire the events in the order the client sends them when joining a party (`GROUP_JOINED`, `GROUP_ROSTER_UPDATE`, `PLAYER_ROLES_ASSIGNED`, `UNIT_NAME_UPDATE`, unit events; check the Forever UI source, `forever` branch of Gethe/wow-ui-source at `9dc84f0`, clone `C:\Users\leeba\.cache\wow-ui-source`, for the real order and for how secure group headers show children) and measure how many timer ticks and frames pass before each new member's frame is shown, named and painted. Do the same out of combat and in combat (secure headers can only change outside combat; anything queued must apply at once when combat ends).
2. Find the cause of any delay beyond the client's own (candidates: a throttle or `C_Timer` in AutoLayout or the bracket change, the P5c input-skip missing a roster input, P3 chrome waiting for a second show, a combat queue, a restyle that waits for an event that does not come). Compare against the base before #456/#462 to tell old from new.
3. Fix it so frames show and paint on the same frame the client makes the unit available (or the first frame after combat ends), and add a regression test with a frame-count budget for join, leave, swap and role change.

**Options**: this is a fix, no setting needed.

**Constraints**: AGENTS.md rules (CRLF/ASCII, one comment per TOC-loaded file, Forever API grep naming the file, secret values, combat lockdown, one event handler per owner). Another worker is adding group status icons and presets in `KstyleUI_GroupFrames` (#460): keep to the update path and rebase before the PR. Local checks per the speed rule below. Open a **draft** PR against `staging`: title `fix(groupframes): party frames show the moment you join`, `## Summary`, `## Changelog` (`Fixed: Party and raid frames appear as soon as you join a group.`), `## In-game checks`. Do not merge.

**Files it may edit**: `KstyleUI_GroupFrames/**`, `Core/Events.lua`, `Core/Combat.lua`, `Core/Widgets/Base.lua` (first-show path only), `Tools/regression/**`.

**Gate**: lint, python and the affected tests locally (speed rule); green Mac CI is the full proof.

**Evidence of done**: the measured delay before and after, by event; the regression test red then green; the draft PR's green `checks` run.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id, the cause and the measurements.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Local checks (speed rule, coordinator decision)**: do NOT run the full native Lua suite on Beast (no `bash scripts/gate.sh` or `gate.sh lua`); it starves the shared machine and CI runs the full suite in about 5 minutes. Before pushing run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`, and with PUC `lua5.1` directly the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; green Mac CI (`checks`) is the full proof. Render at most 2 pictures at a time, and only at the screen sizes your items need.
