# Task: research what each available model is best at today, with real benchmark numbers, for the Jev routing catalog (read-only research)

**The owner's words**: "Where are we getting these descriptions from? This seems a very bad way to route, as Jev isn't receiving anything to make a good call. Ideally we should research what each model we have access to is best at as of today's date, record those benchmark numbers for speed, accuracy, design, implementation and so on, and then record this in the catalogue that Jev gets. Deep research is required, and this would be a global change that affects every repo, both now and future ones."

**Context**:
- The router is `C:/Users/leeba/orca-jev-router` (repo `korallis/orca-jev-router`); read `README.md`, `orca-route.mjs` and `catalog.json`. Don't edit anything there.
- Jev (TypeSafe `jev-latest` via `https://api.typesafe.ai/v1/systemone`) receives only:
  - the task spec;
  - for each catalog entry, its `use` sentence plus `(tier X)`, as the criteria of a `choice` question with the instruction "Quality first: pick the strongest option whose strengths fit this task. Pick a tier-B option only if the task is clearly trivial."
- Those `use` sentences were hand-written with no evidence. Today's date is **2026-11-20**.
- The models in the catalog, which are what we have access to:
  - **Claude:** `claude-fable-5-2`, `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`;
  - **OpenAI (Codex CLI):** `gpt-6-astra`, `gpt-6.1-sol`, `gpt-6-luna`;
  - **Grok:** `grok-4.7`, `grok-4.7-build-fast`;
  - **Muse:** `muse-wonder-full-1.0-contributor`, `muse-spark-1.3`;
  - **Cursor:** `composer-2.5`, `composer-2.5-fast`;
  - **Z.ai:** `zcode` (`glm-5.3`).

  Confirm each model id is current. Note any newer model each provider now offers that we should add, and any that are retired.
- Routing history: 731 decisions in `C:/Users/leeba/orca-jev-router/logs/dispatch.jsonl` (model, playbook, probability, complexity). Outcomes are in the Orca worker reports, and in the KstyleUI review verdicts in `C:/Users/leeba/.cache/kstyleui-evidence/` (files named `verify-*`, with PASS or ISSUES per author model). Mine these for our own measured evidence of which models' work passed review first time, and how often each needed fix rounds.

**Research, citing every number with source URL and date**:
1. **Per model, the current public benchmarks**:
   - agentic coding: SWE-bench Verified / Pro, Terminal-Bench, Aider Polyglot, LiveCodeBench, SWE-Lancer or similar;
   - reasoning: GPQA, HLE, ARC-AGI and similar;
   - long-horizon agentic: METR time horizon, tau-bench and similar;
   - design and frontend: WebDev Arena, Design Arena, UI benchmarks;
   - writing quality, where measured;
   - tool-use reliability;
   - context window;
   - **speed** (output tokens/s, time to first token, from Artificial Analysis, OpenRouter and similar);
   - **cost** per million tokens;
   - provider-stated strengths.

   Use the most recent leaderboard snapshot and say its date. Mark a missing number "not published", and never guess.
2. **How other developers write routing catalogs:** how Jev / TypeSafe users, model routers (Martian, NotDiamond, OpenRouter auto) and agent-orchestration setups describe models for a router. Find TypeSafe's own docs on `systemone` choice criteria if public. What format gets the best routing: a short evidence line with numbers, task-type fit, speed and cost tiers, or "avoid for X"?
3. **Our evidence:** from the logs and review verdicts above, give each model's first-pass PASS rate and average fix rounds, by playbook (feature, bug, perf, review, investigation).

**Output**: `C:/Users/leeba/.cache/kstyleui-evidence/model-catalog/<family>.md` (`claude.md` or `codex.md`), containing:
- a table per model with every number and its source and date;
- a short verdict per model: best at, weak at, speed, cost;
- recommended criteria lines;
- your view on format.

Be thorough; this is deep research. Don't coordinate with the other researcher.

**Constraints**:
- Read-only: no edits to the router or any repo.
- Web research is allowed. Never put credentials or private details in any request.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the report path and the five most important findings.
