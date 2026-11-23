# Task: can the KstyleUI icon pack be an optional download on CurseForge and Wago? (research, then a recommendation)

**Goal**: the owner: "can we also add the icon pack as an optional download on Wago / CurseForge and mention it in the README / marketing material if it isn't already". Find out what each store allows and recommend the best compliant way, so the coordinator can do it.

**Facts to start from**: the pack is `KstyleUI-Icons-<version>.zip`, a loose-file texture pack that installs into `World of Warcraft/_forever_/Interface/Icons/` (not `AddOns`), uploaded to GitHub releases by `.github/workflows/release.yml` (`docs/icons.md`). The icons are AI-generated with Higgsfield `gpt_image_2_5`, some as repaints using Blizzard's own icon as a subject reference (`Tools/icons/setB/PROVENANCE.md`). The README already mentions it as "Optional, GitHub only" (README.md:183). Earlier research (`docs/store/RESEARCH.md:60`, `docs/store/curseforge.md:28`) kept it off the stores because they install into `AddOns` and CurseForge's description rules forbid external download links. Projects: CurseForge 1812141, Wago EGPabeN1.

**Research** (cite every source URL and quote the rule):
1. CurseForge: the moderation policies (https://support.curseforge.com/support/solutions/articles/9000197279-moderation-policies) and file rules for World of Warcraft addons: are "additional files" allowed on a project, may an additional file be a non-addon (a texture pack installed outside `AddOns`), how the CurseForge app treats additional files (install or manual download only), the AI-generated content disclosure rules, and the rules on redistributing or deriving from game art (Blizzard icons used as a subject reference). Is there a separate project type that fits (for example a separate "KstyleUI Icons" project), and would it be allowed?
2. Wago Addons: the same questions (additional or optional files, non-addon content, AI art, game-art derivatives) from docs.wago.io, the terms and the developer UI.
3. Blizzard's UI add-on development policy on distributing modified game assets.
4. If a store allows it, how to upload: does the BigWigs packager or the store API support additional files (so `release.yml` can do it), or is it a manual upload per release?

**Recommendation**: for each store, one of: allowed as an additional file (how), allowed as a separate project (how), or not allowed (why, quoting the rule). Then the exact README and store-description wording that mentions the pack within each store's rules (no external link on CurseForge if that rule still applies; for example "an optional icon pack is available from the project's GitHub page"). Note the AI-art disclosure wording if required.

**Constraints**: read-only for the repository; change nothing, no uploads, no PR. Write `C:\Users\leeba\.cache\icon-pack-stores\REPORT.md`.

**Files it may edit**: none in the repository; only `C:\Users\leeba\.cache\icon-pack-stores\**`.

**Gate**: none (read-only).

**Evidence of done**: the report with a quoted, linked source for every rule.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report the recommendation per store in two lines each.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
