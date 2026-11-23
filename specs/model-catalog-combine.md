# Task: combine the two model-research reports into the final Jev routing catalog (global change, PR to the router repo)

**The owner's words**: Jev "isn't receiving anything to make a good call". The routing catalog should be built from researched, current evidence of what each model is best at: speed, accuracy, design, implementation and so on. This is a global change that affects every repo, now and in future. You (Fable 5.2) combine the two independent reports and write the final catalog.

**Inputs**:
- `C:/Users/leeba/.cache/kstyleui-evidence/model-catalog/claude.md` (Fable 5.2's research; its scripts are in `claude-scripts/` and `claude-scratch/`);
- `C:/Users/leeba/.cache/kstyleui-evidence/model-catalog/codex.md` (Astra's research);
- the router: `C:/Users/leeba/orca-jev-router` (`README.md`, `orca-route.mjs`, `catalog.json`). **Don't edit the live checkout**; it has unrelated uncommitted edits.

**The owner's decisions (binding)**:
1. Keep Muse's contributor mode.
2. **Pay for first-pass quality.** Route most implementation to the models with the highest measured first-pass quality: Opus, Astra and Fable class. Sol is not the default implementer. Reserve the cheaper and faster models for genuinely routine or trivial work, and for verification or review where they measure well.
3. No Gemini 4 for now.

**Do**:
1. **Reconcile the reports.** Where they disagree, check the cited source yourself and use the number you can verify. Mark anything unverified as unverified; never invent a number. Both reports found that `gpt-6.2-astra` and `gpt-6.2-sol` (2026-11-17) superseded the 6 / 6.1 versions, but that the local Codex proxy catalog may not list them. Check what the installed Codex CLI actually accepts on this machine (`codex --help`, its model list, or a dry `codex exec` probe that sends nothing private), and use only ids that work. Note any upgrade path.
2. **Design the catalog format for Jev.** TypeSafe's docs (per the research) say Jev knows only what the criteria say, favours earlier options, and is unreliable at numeric comparison. So:
   - for each option give Jev a short **what it's best at / not for / evidence (2-3 key numbers in words) / speed / cost tier** text;
   - keep the full numeric evidence in `catalog.json` as structured fields, for people and code;
   - order the options to reflect the owner's quality-first decision.

   If the research recommends having Jev rate the task (type, difficulty, design-heavy, speed-sensitive) and a small table pick the model, implement that **only if** it is small (about 40 lines in `orca-route.mjs`) and clearly better. Otherwise keep the single choice question with the better criteria. Keep the `--avoid`, fallback, confidence and playbook behaviour unchanged.
3. **Write the new `catalog.json`** and the minimal `orca-route.mjs` change needed to send the new criteria. Update the router `README.md` "Editing the catalog" section with how to refresh the evidence, including the date and sources.
4. **Validate offline:** replay the last ~50 KstyleUI dispatch specs from `C:/Users/leeba/orca-jev-router/logs/specs/` through the new route function against the live Jev API (`node orca-route.mjs route --spec-file <f> --json` from your temp clone), and report the before/after distribution of choices and complexity. **Don't start any workers.** Check that hard work now goes to the quality models, trivial work to tier B, reviews to a different family when avoided, and design/UI work to the measured design leaders.

**Deliver**:
- Clone `https://github.com/korallis/orca-jev-router` into a fresh temp directory, branch `catalog-evidence-2026-11`, commit, and open a PR against its default branch titled `catalog: evidence-based model criteria (2026-11-20)`.
- The PR body holds the per-model evidence table with sources and dates, the owner's decisions, the format rationale and the replay before/after table.
- Run the router's own checks (`node check-paths.mjs skill/orca-jev-routing/SKILL.md`, and the plugin tests if touched). Do not merge.

**Report**: `C:/Users/leeba/.cache/kstyleui-evidence/model-catalog/final.md`. Include:
- the final catalog in readable form;
- the replay table;
- the open questions.

**Constraints**:
- Minimal code; no new dependencies.
- Never print or commit the TypeSafe key or any token.
- Don't touch `~/.claude` or installed copies; the coordinator installs after merge.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the PR URL, SHA and report path.
