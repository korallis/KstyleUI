# Task: fix korallis/orca-jev-router PR #4 (evidence-based catalog) after review

PR https://github.com/korallis/orca-jev-router/pull/4 at `1c767a401b14ee8d1132f828c05960edc6a08c4e`. Read:
- the review, `C:/Users/leeba/.cache/kstyleui-evidence/model-catalog/verify-router-4.md`, whose scratch and audit scripts are in `verify-scratch/` beside it;
- your own report, `final.md`;
- the spec, `C:/Projects/KstyleUI/specs/model-catalog-combine.md`.

Work in a fresh temp clone of the PR branch, and never in the live checkout `C:/Users/leeba/orca-jev-router`. Push to the same PR branch.

**The owner's further decisions (binding)**: keep the xhigh effort ladder as written; keep Composer and zcode; keep `jev-latest`.

**Fix**:
1. **Comma-list `--avoid`** (P1): `orca-route.mjs:18` compares `e.agent !== opts.avoid`, so `--avoid claude,codex` excludes nothing. Split on commas, as `String(opts.avoid ?? '').split(',').includes(e.agent)`, and make the tier-S fallback with `--avoid` use the filtered pool. Add a tiny offline check, or extend an existing one: `--avoid claude,grok` with no key must pick Astra, and `--avoid claude,codex` must exclude both. (The live checkout has an uncommitted edit with this split and an `--on` change. Implement the split yourself in the PR; don't copy or touch the live file.)
2. **Criteria accuracy** (P2):
   - **Fable's not_for:** state Opus as the owner's default *policy*. Remove the unsupported "scores the same there at lower cost" claim, since at the cited settings Fable high is the cheaper of the equal scores.
   - **Sol's local numbers:** use the correct counts (35 PASS of 115 Sol-authored PRs, not 28). Describe them as an observed first-review proxy, not a true first-pass rate. Apply the same honesty to the reviewer labels and to the Composer and zcode receipts.
   - **Speed and cost claims:** state the setting that makes each true, or drop it. This covers GLM "slowest", Grok "costs as much as Fable" (that matches Fable xhigh, not high), Astra "half the Claude models' time", and Sol "fastest".
   - **Benchmark scope:** name the benchmark for each design or UI ranking, so a cross-benchmark preference doesn't read as a universal one.
   - **not_for:** every entry names the option that should win instead, per the format; Composer, zcode, Haiku, Luna and Astra's trivial case are missing it.
3. **Keep everything else:** the order, the owner's decisions, the effortBy ladder and minimal code.

**Re-run**: `node --check orca-route.mjs`, `node check-paths.mjs skill/orca-jev-routing/SKILL.md`, the offline avoid checks, and a 10-spec live replay subset (no workers) to confirm the choices are unchanged apart from the avoid fix. Update the PR body and `final.md`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the new SHA and what changed.
