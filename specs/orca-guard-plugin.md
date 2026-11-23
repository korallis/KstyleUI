# Task: an Orca plugin that enforces the Orca + Jev workflow and the minimal-code rule on every agent

**Goal**: the owner's rules must be enforced by Orca itself, for every agent CLI Orca runs (Claude, Codex, Grok, Cursor, Muse, Zcode and the rest), not left to each CLI's instructions file. The rules: (1) minimal code: if it can be done in a few lines, do it in a few lines; no dependency, framework, abstraction, helper or settings plumbing the task does not need; (2) Orca + Jev workflow: substantive work is dispatched with `node "C:/Users/leeba/orca-jev-router/orca-route.mjs" dispatch`; no in-session subagents or Workflow tool; no direct `orca orchestration worker-start` unless the user named the agent or model.

**Target**: a new Orca plugin in the router repo `C:\Users\leeba\orca-jev-router` (folder `orca-plugin/`), installed and enabled on this Orca (1.4.262). Read the guide first: `orca skills get orca-plugin-authoring --full`, especially `references/recipes.md` (hooks) and `references/host-api.md` (Hooks: `agent.prompt.before`, `agent.tool.before`, `agent.launch.before`). Start from `orca plugin create <dir> --template hook`. An existing PreToolUse script already holds the rules and messages: `C:\Users\leeba\orca-jev-router\hooks\guard.mjs` (installed as a CLI hook for Claude, Codex and Cursor); reuse its logic and messages, do not duplicate them by hand (import it or move the shared rules into one module both use).

**Change**:
1. `agent.prompt.before`: for every prompt Orca submits to an agent (launch, orchestration dispatch, task prompt), append one short rules block (the two rules above, in a few lines) unless it is already present. This makes every worker of every CLI receive the rules.
2. `agent.tool.before`: deny the Workflow and Agent/Task tools, deny a shell command that runs `orchestration worker-start` without `JEV_USER_NAMED=1`, and apply the once-per-commit minimal-code gate on `git push` / `gh pr create` and once per PR head on `gh pr merge` (same rules as guard.mjs). Orca only blocks for Claude Code; for other agents it only reports, so keep the CLI hooks as the blocking layer there and say so in the README.
3. Fail closed where it matters (`"onError": "deny"` for `agent.tool.before`), and decide before any awaited call.
4. Codex check: the guard hook is in `~/.codex/hooks.json` (PreToolUse group 1) with a trust entry in `~/.codex/config.toml` (`pre_tool_use:1:0`, hash computed with Codex's `version_for_toml` formula), yet a `codex exec` test that runs `orca orchestration worker-start --help` was not blocked. Find out why (hook not loaded, wrong trust key, Codex tool input shape, exit-code handling) and fix it, proving a block with one `codex exec` run. Never print tokens.

**Constraints**: minimal code. Do not touch other plugins or Orca's own agent-hooks files in `~/.orca/agent-hooks/`. Do not break running agents: test with `orca plugin dev hook` and unit tests (`mountWorker`) before enabling; enabling needs `--approve`. Commit in the router repo (local, no remote, no PR). Write a short `orca-plugin/README.md` (what is enforced where, how to disable: `orca plugin disable <id>`).

**Files it may edit**: `C:\Users\leeba\orca-jev-router\orca-plugin\**`, `C:\Users\leeba\orca-jev-router\hooks\guard.mjs`, `~/.codex/hooks.json` and `~/.codex/config.toml` (the guard entries only).

**Gate**: `npx tsc -p .` in the plugin if TypeScript, the plugin's unit tests, `orca plugin validate`, and `orca plugin dev hook` decisions for: a dispatch prompt (rules appended once), a Workflow tool call (deny), `orchestration worker-start` (deny), the same with `JEV_USER_NAMED=1` (pass), a first and second `git push` (deny then pass).

**Evidence of done**: the gate output; `orca plugin list` showing it enabled; one real worker prompt (from `orca orchestration worker-read` of any worker started after enabling) showing the rules block; the Codex block proof. Report the commit SHA.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`.
