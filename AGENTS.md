# AGENTS.md

Rules for any agent working in this repository. Read the [design spec](docs/superpowers/specs/2026-11-07-kstyleui-design.md) and the [roadmap](docs/superpowers/plans/2026-11-07-kstyleui-roadmap.md) before you change code. The roadmap's Global Constraints and Core public API are binding.

## Branch flow

- Every change merges into `staging`. `main` moves only after the owner confirms the in-game tests on `staging`.
- Never edit the owner's checkout at `~/KstyleUI`. Create a worktree per pull request:

```bash
git -C ~/KstyleUI fetch origin
git -C ~/KstyleUI worktree add -b <type>/<scope>-<slug> ~/KstyleUI.worktrees/<type>-<scope>-<slug> origin/staging
```

- Open the pull request with `gh pr create --base staging`. Squash-merge it.
- A pull request changes at most 400 lines, not counting generated data, images, fonts, and lockfiles. Split bigger work.
- The title is `type(scope): summary` (Conventional Commits).
- The body has a `## Changelog` section whose line starts with `Added:`, `Changed:`, or `Fixed:`. A pull request that changes only tooling or docs gets the `no changelog` label instead.
- The body has an `## In-game checks` list.

## Commands

Run these from the repository root before every push. All of them must pass.

```bash
python3 Tools/dev/crlf.py
pre-commit run --all-files
LUA=luajit bash Tools/regression/run-all.sh
python3 -m unittest discover -s Tools/tests
```

Phase 0 adds these tools one task at a time. Until a task adds a command's file, skip that command.

`python3 Tools/hooks/check_toc.py` reports each file a TOC or an XML include lists that is missing, or whose letter case differs from the file on disk. Linux CI cannot find a file whose case differs, even when macOS can.

After the checks pass, run `cr review --agent` and fix the critical and major findings, at most two rounds. Then get one cross-family review with `codex review`.

## Line endings and encoding

- Every `.lua`, `.toc`, and `.xml` file outside `Tools/` and `docs/` is an addon file. Addon files are ASCII only and use CRLF line endings.
- `.gitattributes` sets `* -text`, so git never rewrites line endings.
- Agents write LF. `python3 Tools/dev/crlf.py` converts every changed or untracked addon file to CRLF. Pass paths to convert only those files.
- `python3 Tools/dev/crlf.py --check` changes nothing. It lists each addon file with LF endings and exits 1 if it finds any.
- Files in `Tools/` and `docs/` use LF and may contain non-ASCII text.

## Sensitive paths

Change these only when your task needs it, and say why in the pull request:

- `.github/workflows/`
- `.pkgmeta`
- `Core/Tokens.lua`

## Forever API

- Blizzard's UI source for the live build (1.60.1.70840) is the `forever` branch of [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source/tree/forever). On the owner's Mac a read-only checkout lives at `~/.local/share/wow-dev/wow-ui-source`.
- Grep that source before you use any API, event, template, mixin, CVar, or Blizzard frame name. `Blizzard_APIDocumentationGenerated/` lists every C API with its `SecretReturns` and `SecretArguments` flags.
- Forever does not load the `Blizzard_Deprecated*` folders. Forever overrides live in `Camelot/` subfolders.
- Code defensively, as the spec's "Build mode" section says: check that an API exists before you call it, check `issecretvalue` before any comparison, and fall back to a safer path when the preferred one is unavailable.

## Learned mistakes

Add one line for each mistake that happened twice: what went wrong and the rule that prevents it.
