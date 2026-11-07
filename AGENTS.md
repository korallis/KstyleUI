# AGENTS.md

Rules for any agent working in this repository. Read the [design spec](docs/superpowers/specs/2026-11-07-kstyleui-design.md) and the [roadmap](docs/superpowers/plans/2026-11-07-kstyleui-roadmap.md) before you change code. The roadmap's Global Constraints and Core public API are binding.

## Branch flow

- Every change merges into `staging`. `main` moves only after the owner confirms the in-game tests on `staging`.
- `~/KstyleUI` is the owner's live copy. It is the checkout of `staging` that the game runs the addons from. Never edit files, commit, or switch branches in it. Always work in your own worktree, one per pull request:

```bash
git -C ~/KstyleUI fetch origin
git -C ~/KstyleUI worktree add -b <type>/<scope>-<slug> ~/KstyleUI.worktrees/<type>-<scope>-<slug> origin/staging
```

- `~/KstyleUI` has `staging` checked out, so no worktree can check out the local `staging` branch. Branch from `origin/staging` as the command above does.

- Open the pull request with `gh pr create --base staging`. Squash-merge it.
- A pull request has no line limit. The owner waived the global 400-line rule for KstyleUI on 2026-11-07. Keep each PR to one coherent piece of work so it can be reviewed.
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

`pre-commit run --all-files` checks tracked files only, so `git add` new files first. Do not run `pre-commit install` in a worktree: every worktree shares `.git/hooks` with `~/KstyleUI`, so it would install hooks into the owner's checkout and into branches that have no `.pre-commit-config.yaml`. To check a commit message, run `pre-commit run --hook-stage commit-msg --commit-msg-filename <file>`.

Phase 0 adds these tools one task at a time. Until a task adds a command's file, skip that command.

`python3 Tools/hooks/check_toc.py` reports each file a TOC or an XML include lists that is missing, or whose letter case differs from the file on disk. Linux CI cannot find a file whose case differs, even when macOS can.

`luacheck .` reads `.luacheckrc`. Addon code may read only the globals Forever gives addons, which `python3 Tools/build/gen_globals.py --source ~/.local/share/wow-dev/wow-ui-source` writes to `Tools/data/forever_globals.lua`. Regenerate that file when the Forever build changes. A global your module creates, such as a named frame, a `BINDING_HEADER_*` or `BINDING_NAME_*` string, or a `SLASH_*` command, goes on your module's line in the module section of `.luacheckrc`. "Accessing undefined variable" on a Blizzard name means Forever does not have it or `.luacheckrc` denies it: use the replacement the deny list names, and never add a Blizzard name to your line.

After the checks pass, run `cr review --agent` and fix the critical and major findings, at most two rounds. Then get one cross-family review with `codex review`.

## Line endings and encoding

- Every `.lua`, `.toc`, and `.xml` file outside `Tools/` and `docs/` is an addon file. Addon files are ASCII only and use CRLF line endings.
- `.gitattributes` sets `* -text`, so git never rewrites line endings.
- Agents write LF. `python3 Tools/dev/crlf.py` converts every changed or untracked addon file to CRLF. Pass paths to convert only those files.
- `python3 Tools/dev/crlf.py --check` changes nothing. It lists each addon file with LF endings and exits 1 if it finds any.
- Files in `Tools/` and `docs/` use LF and may contain non-ASCII text.

## In-game testing

The game runs the addons from `~/KstyleUI`, the owner's live copy on `staging`. `bash Tools/dev/link-addons.sh` links `KstyleUI` and every `KstyleUI_*` folder in `~/KstyleUI` into Forever's `Interface/AddOns`. `--spike` also links the spike addon, and `--dry-run` changes nothing. `KSTYLEUI_LIVE` overrides the checkout folder, and `WOW_ADDONS` overrides the AddOns folder. The script never clones, pulls, or switches branches. If the checkout folder has no `KstyleUI.toc`, the script names the folder and exits 1. To bring merged changes into the game, the owner runs `git -C ~/KstyleUI pull --ff-only`, then `/reload` in game.

## Releases

A release starts when the owner pushes a `vX.Y.Z` tag on `main`, after the in-game pass on `staging` and a fast-forward of `main`. `.github/workflows/release.yml` then runs two jobs:

1. `check` fails unless the tag is on `main`, runs the Lua regression tests, packages with the BigWigs packager without uploading, and runs `Tools/hooks/check-package.sh` on the zip.
2. `release` packages again and uploads. It runs in the `release` environment and is the only job in the repository with write permission (`contents: write`, for the GitHub release).

The owner sets the `CF_API_KEY` and `WAGO_API_TOKEN` secrets in the repository or the `release` environment. The packager uploads to CurseForge only when `KstyleUI.toc` has `## X-Curse-Project-ID`, and to Wago only when it has `## X-Wago-ID`. Until the owner creates those projects and adds the IDs, a tag makes only the GitHub release. Never print or commit a token.

`docs/RELEASE_NOTES.md` holds the notes for each release.

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

- Doc comments inside four core files (Tokens, Theme, Scale, Motion) broke the one-comment rule across four PRs. A file has one comment, its first line; contracts go in `docs/` or the module's README. `test-comments.lua` fails on any other comment.
- Editing an addon file with Python's `read_text` and `write_text` turned its CRLF endings into LF twice in one task, and a fix-up commit shipped the LF file. Run `python3 Tools/dev/crlf.py` and `pre-commit run --all-files` before every commit, fix-ups included.
- Three modules (Minimap, UnitFrames, Skins) set text on a raw `CreateFontString` before styling it. The game raised "Font not set" and stopped two modules from loading. Make font strings with `K.Widgets.FontString(parent, layer)`. `test-fontstrings.lua` fails on a raw call, and the stub raises the game's error.
