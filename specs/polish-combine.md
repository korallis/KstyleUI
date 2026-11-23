# Task: combine the 16 polish audits into one ranked plan to massively surpass CaithUI (read-only report)

**The owner's words**: "a massive polish audit checking how everything could be improved to achieve massive polish that beats CaithUI and all other popular UI packs by quite a margin". The most recent CaithUI is the gold standard that inspired KstyleUI; we want to massively surpass it. This work ships in the release **after v0.2.9**.

**Inputs**: 16 independent reports in `C:/Users/leeba/.cache/kstyleui-evidence/polish-audit/`, four lenses by four model families:
- **A**, visual craft: `A-muse.md`, `A-codex.md` (Sol), `A-fable.md`, `A-astra.md`;
- **B**, motion and interaction: `B-muse.md`, `B-codex.md`, `B-fable.md`, `B-astra.md`;
- **C**, competitor teardown: `C-muse.md`, `C-grok.md`, `C-fable.md`, `C-astra.md`;
- **D**, systems polish: `D-muse.md`, `D-codex.md`, `D-fable.md`, `D-astra.md`.

Their renders, crops and mockups are in the same folder (subfolders per report), and the CaithUI clips are in `caith-clips/`.

**Do**:
1. **De-duplicate and reconcile.** Merge findings that agree, and weight a finding higher when several families found it independently. Settle disagreements by checking the code (file:line) and the renders yourself. Mark anything you couldn't verify.
2. **Separate the kinds of finding.**
   - **Bugs:** real defects players hit today. These go to v0.2.9 if small. Note the ones already being fixed: the welcome text fold, the French Options footer, the data bar clamp at 1080p, colour-vision health, the raid preview "Orrin" overlap, the `gallery_groupframes` strict failure, and the stale `guard_allow` line.
   - **Polish:** what lifts the premium feel.
   - **Strategic:** bigger product moves, such as Medallions as the default HUD style, Looks/preset cards, or a clean screen at rest.
3. **One ranked plan** for the release after v0.2.9:
   - each item gets its impact against CaithUI's latest, its effort (S/M/L), the modules and files it touches, the owner rules it must respect, and the evidence (render or mockup path);
   - group the items into PR-sized batches in a sensible order, shared foundations first (one type voice, one lit bar fill, motion system fixes, search/Options UX);
   - list "already best-in-class, must not regress".
4. **Owner rules every item must respect**:
   - one consistent style;
   - everything toggleable and ON by default, where the default changes the look only if it's a clear improvement; say which items change the default look, so the owner can approve them;
   - the four screen sizes;
   - real scenery only;
   - performance work is pixel-identical;
   - minimal code.
5. **Owner decisions:** list the decisions that only the owner can make, for example a new type voice, changing the default HUD to Medallions, or default-on behaviour changes. Give your recommendation for each.

**Output**:
- `C:/Users/leeba/.cache/kstyleui-evidence/polish-audit/PLAN.md`, short and scannable: an executive summary of the five moves that beat CaithUI by a margin, then the batches, the decisions and the must-not-regress list;
- a one-page visual summary: an HTML page with the top 10 before/after pairs, using existing renders and mockups only, saved as `PLAN.html` beside it.

No code changes, commits or PRs.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report both paths and the top five moves.
