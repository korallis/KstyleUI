# Task: review korallis/orca-jev-router PR #4 (evidence-based routing catalog), read-only

PR https://github.com/korallis/orca-jev-router/pull/4 at `1c767a401b14ee8d1132f828c05960edc6a08c4e` (base `main` `13e037867f5ca580d8e7fa27e8c8bfde142f3fcc`). It rewrites `catalog.json` from researched evidence and changes `orca-route.mjs` (3 lines) and `README.md`.

Read:
- the author's report, `C:/Users/leeba/.cache/kstyleui-evidence/model-catalog/final.md`, with its replay in `final-replay/`;
- the two research reports, `claude.md` and `codex.md`, in the same folder;
- the spec, `C:/Projects/KstyleUI/specs/model-catalog-combine.md`, which holds the owner's binding decisions: keep Muse contributor mode, pay for first-pass quality, no Gemini.

**Check**:
- **Evidence:** every number in `catalog.json` matches its cited source and date. Spot-check at least 10 numbers against the source URLs yourself, and flag any you can't verify.
- **The Jev criteria text:**
  - it is accurate to the evidence;
  - the not_for lines point to the right alternative;
  - the order and wording are consistent with quality-first;
  - nothing is misleading, for example claiming a measurement that doesn't exist.
- **The router change:** `orca-route.mjs` still handles `--avoid` (comma lists), the fallback, the confidence threshold, the playbooks and effort clamping. Use `node --check`, plus an offline route run with no key, which must fall back cleanly.
- **The new model ids:** `gpt-6.2-astra` and `gpt-6.2-sol` actually run in the installed Codex CLI. Check with a harmless `codex exec` probe that sends no private content. Note the `~/.codex/cpa-gui-model-catalog.json` fallback-metadata warning.
- **Minimal code:** nothing added that isn't needed.

**Output**: `C:/Users/leeba/.cache/kstyleui-evidence/model-catalog/verify-router-4.md`, starting with "verified 1c767a40: PASS" or "ISSUES". Don't edit, push or comment on the PR.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
