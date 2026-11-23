# Arena cross-judge: score three KstyleUI audit pages (read-only)

**Goal**: independently score three candidate artifacts built from the same brief, criterion by criterion, and recommend a base. Do not build anything.

**Brief the candidates had**: `C:\Projects\KstyleUI\specs\arena-audit.md` (read it fully; its "Rubric the picker will use" is your rubric).

**Candidates** (label them only by folder): `C:\Users\leeba\.cache\kstyleui-audit\arena\candidate-claude\`, `candidate-codex\`, `candidate-grok\`. Each has `scorecard.md`, `plan.md`, `rationale.md`, `index.html` and `img/`. Source reports: `C:\Users\leeba\.cache\kstyleui-audit\*.md` (twelve).

**Do**:
1. Read every candidate end to end (all four documents) and open `index.html` in headless Chrome at 1440 px and 390 px (light and dark via `prefers-color-scheme`), screenshot full pages and look at every screen.
2. Spot-check traceability: for each candidate pick 8 claims or scores at random and find them in the source reports (or not); pick 5 before/after pairs and check same crop, honest labels (render / capture / mock) and that the "after" shows the stated change.
3. Score each candidate 1-10 on each of the six rubric criteria with one line of evidence per score; total them.
4. Recommend a base (the one a maintainer could extend most easily without breaking its accuracy), and list for each other candidate the one to three things worth grafting into the base.
5. Flag anything wrong in any candidate: overclaims, scores that disagree with the sources, owner rulings broken, broken images, layout faults at 390 px, items that re-propose work already in flight.

**Output**: `C:\Users\leeba\.cache\kstyleui-audit\arena\judge.md` and screenshots under `arena\judge\`.

**Constraints**: read-only; edit nothing in the candidates or the repository. Windows machine (Beast); never stop processes you did not start.

**Files it may edit**: only `C:\Users\leeba\.cache\kstyleui-audit\arena\judge.md` and `arena\judge\**`.

**Gate**: none (read-only).

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report the totals per candidate, the recommended base and the grafts.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
