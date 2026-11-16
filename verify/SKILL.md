---
name: verify-kstyleui
description: Verify KstyleUI, the World of Warcraft addon suite for the Forever client, by rendering its real Lua UI to a screenshot and by running its regression harness; reach for this whenever a task must prove HUD or module behaviour without a game client.
---

# Verify KstyleUI

KstyleUI has no server and no game client in the loop. Two harnesses drive the real addon Lua in stub environments. The render harness (`Tools/render/shoot.sh`) puts a module into a state and screenshots it with headless Chrome. The regression harness (`Tools/regression/test-*.lua`) fires events and asserts on the frames.

[The feature map](../docs/feature-map.md) is the canonical list of player-facing features. It names, for each feature, its settings place, its code path, its regression files and its render scene with `RENDER_*` variables. The files in `features/` next to this file seed the top journeys from that map. They point back to it rather than copying it. A proof that covers one convenient entry point is incomplete when the map lists others for the same feature.

Run everything from the repository root. The scene and test files load Lua by root-relative path.

## Launch

Launch means environment setup. There is no process to keep alive. Each drive below is one short-lived command.

On macOS or Linux, a plain shell with `luajit`, `lua5.1` and Chrome works as [AGENTS.md](../AGENTS.md) describes. Windows needs the setup in the rest of this section. Use Git Bash (`C:\Program Files\Git\bin\bash.exe`). `bash` is not on the PowerShell `PATH` on this machine.

Prepend any toolchain directory your shell lacks:

- `~/.local/bin` for `lua5.1` (5.1.5) and `luacheck.exe`.
- `%LOCALAPPDATA%\Programs\LuaJIT\bin` for `luajit`.
- `%APPDATA%\Python\Python313\Scripts` for `pre-commit`.
- The real Python 3.13 directory for `python`. Set `KSTYLEUI_PYTHON=python`. The `python3` on the PowerShell `PATH` is the Microsoft Store stub.

Two Windows harness failures are known. Record them, do not patch the harness. Both workarounds live outside the repository.

**Failure 1: the Lua harnesses list no files.** `Tools/regression/toc_files.lua` runs `ls -1d <glob> 2>/dev/null` through `io.popen`. The native Windows Lua builds run that through `cmd.exe`, which cannot create `\dev\null` while `C:\dev` is missing. A regression run then prints `The system cannot find the path specified.`, loads no addon files, and fails with a nil global, for example `test-hud-style-gate.lua:13: attempt to index local 'K0' (a nil value)`, exit 1. The workaround is one directory on the repository's drive, so `cmd.exe` can create its `null` file inside it, plus Git Bash on the `PATH` it hands to Lua, so `cmd.exe` finds the `ls.exe` in `C:\Program Files\Git\usr\bin`:

```bash
mkdir -p /c/dev
```

**Failure 2: the render page step never finishes.** `shoot.sh` defaults `CHROME` to a macOS path, then looks for `google-chrome`, `chromium` or `chromium-browser` on the `PATH`. Windows Chrome is at `C:\Program Files\Google\Chrome\Application\chrome.exe`. Even with `CHROME` set to it, the run fails: `guard: the page did not finish drawing, so the texts it truncated are unknown`, then `guard: hud_warlock_mac fails the render guard: the page step did not complete`, exit 3, and no PNG at the `--out` path despite a `wrote ...` line. Headless Chrome reports `Page load failed: net::ERR_FILE_NOT_FOUND`. The cause is URL shape. Git Bash prints the repository root as `/c/Users/...`, so the harness builds `file:///c/...` URLs for the page, its scripts and its asset base. Windows Chrome cannot resolve that shape. It needs `file:///C:/...`.

The workaround uses the `CHROME` override the harness already offers. A small shim outside the repository rewrites the drive letter in the page URL and the `--screenshot` path, and in the generated page under `Tools/render/out/` (ignored output), then execs the real Chrome. It changes no repository source. Create it once per machine:

```bash
mkdir -p ~/.cache/kstyleui-verify
cat > ~/.cache/kstyleui-verify/chrome-shim.sh <<'EOF'
#!/usr/bin/env bash
real="/c/Program Files/Google/Chrome/Application/chrome.exe"
args=()
for a in "$@"; do
  if [[ "$a" =~ ^file:///([a-z])/(.*)$ ]]; then
    drive=$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')
    rest="${BASH_REMATCH[2]}"
    page="/${BASH_REMATCH[1]}/$rest"
    if [ -f "$page" ]; then
      sed -i -E 's|file:///([a-z])/|file:///\U\1:/|g' "$page"
    fi
    args+=("file:///$drive:/$rest")
  elif [[ "$a" =~ ^(--screenshot=)/([a-z])/(.*)$ ]]; then
    drive=$(printf '%s' "${BASH_REMATCH[2]}" | tr '[:lower:]' '[:upper:]')
    args+=("${BASH_REMATCH[1]}$drive:/${BASH_REMATCH[3]}")
  else
    args+=("$a")
  fi
done
exec "$real" "${args[@]}"
EOF
chmod +x ~/.cache/kstyleui-verify/chrome-shim.sh
export CHROME="$HOME/.cache/kstyleui-verify/chrome-shim.sh"
```

The shim must stay executable. When the `CHROME` path is not executable, `shoot.sh` silently falls back to a `PATH` search, finds nothing on Windows, and exits 1 with `no Chrome found; set CHROME`.

Readiness means the Lua side of the render completes:

```bash
mkdir -p /c/dev
bash Tools/render/shoot.sh smoke --json-only
echo "exit=$?"
```

Exit 0 is ready. The scene JSON and guard file land in `Tools/render/out/`, which git ignores.

## Doctor

Run this read-only check first whenever anything looks off. It answers whether this machine is worth driving:

```bash
lua5.1 -v
luajit -v
python --version
python3 --version
command -v lua5.1 luajit python python3 luacheck pre-commit
[ -x "/c/Program Files/Google/Chrome/Application/chrome.exe" ] && echo "chrome: present"
[ -x "$HOME/.cache/kstyleui-verify/chrome-shim.sh" ] && echo "shim: executable"
[ -d /c/dev ] && echo "dev dir: present"
git status --porcelain
```

`shoot.sh` and `run-all.sh` call `python3` by that literal name. Check what it resolves to inside Git Bash. On this machine it resolves to the real Python 3.13 (`Python 3.13.15`). A `python3` that prints nothing, opens the Microsoft Store, or exits nonzero breaks both harnesses before any Lua runs. Fix the `PATH` order, then run Doctor again.

If Doctor is green but a regression file fails with a nil global, Failure 1 is back. If Doctor is green but a render exits 3 on the page step, Failure 2 is back.

## Drive

Pick the scene and variables from the feature's row in [the feature map](../docs/feature-map.md), then read the matching file in `features/`. `--ppu` is pixels per unit. Set it to the screen height over 1080, so the PNG carries the screen's own pixels: `--ppu 1` at 1920x1080, `--ppu 1.3333333333` at 5120x1440. Always pass `--strict` for evidence. It fails the run, exit 3 after the PNG is written, on truncated text, content spilled past its card, or a stale `Tools/render/guard_allow.tsv` line for the scene.

The owner's case comes first: the 5120x1440 screen, the Medallions HUD style, a warlock. The scene `hud_warlock_mac` pins the warlock class. `RENDER_HUD_STYLE=Medallions` selects the style. Send the PNG outside the repository:

```bash
mkdir -p /c/dev ~/.cache/kstyleui-verify
export CHROME="$HOME/.cache/kstyleui-verify/chrome-shim.sh"
RENDER_SCREEN=5120x1440 RENDER_SIZE=auto RENDER_HUD_STYLE=Medallions RENDER_LAYOUT=DPS \
  bash Tools/render/shoot.sh hud_warlock_mac --ppu 1.3333333333 --strict \
  --out "$HOME/.cache/kstyleui-verify/hud_warlock_medallions_5120x1440.png"
echo "exit=$?"
```

One regression file proves behaviour without pixels. It boots a stub environment, fires events, and prints one line on success:

```bash
lua5.1 Tools/regression/test-hud-style-gate.lua
echo "exit=$?"
```

`test-hud-style-gate.lua` prints `hud style gate ok` and exits 0. Swap in the regression files the feature map row names for the change under test. Run them one file at a time under `lua5.1` for a focused proof. `bash Tools/regression/run-all.sh` with no argument is the full suite, and `bash scripts/gate.sh` with `KSTYLEUI_PYTHON=python` is the repository gate.

One gate caveat is specific to Windows. The gate's lint group passes here: `Tools/dev/crlf.py --check`, `pre-commit run --all-files`, `luacheck` (0 warnings, 0 errors), `Tools/hooks/check_toc.py`, `Tools/locale/strings.py check` and `scripts/check-suppressions.sh`. The other two groups fail on platform assumptions before any change of yours is involved. The Lua group dies at import: `Tools/regression/run_all.py`, line 9, `import fcntl`, then `ModuleNotFoundError: No module named 'fcntl'`, and the runner also uses `os.killpg`, which Windows Python has not got. The Python suite fails POSIX-shaped tests, 27 failures and errors in the run recorded when this skill was written, for example `test_written_file_follows_umask` with `AssertionError: 438 != 420`, and the suite process then dies with no summary at `test_ctrl_c_cancels_the_queued_icons_and_keeps_the_running_one`, exit 2. The gate ends `gate FAILED: run-all.sh --affected origin/staging python suite`, exit 1. No workaround leaves `Tools/` untouched, and inventing a fake `fcntl` module would fake the runner's own locks, so there is none. On Windows, proof is the focused drives above plus the lint group, `KSTYLEUI_PYTHON=python bash scripts/gate.sh lint`. The full gate belongs to a POSIX machine or CI. Never report a Windows gate run as green, and never patch `Tools/` to make it look green.

Renders of the same scene share `Tools/render/out/<scene>.json`, `.html` and `.guard.tsv`. Run one render of a scene at a time per worktree. Parallel renders of the same scene overwrite each other's page and proof. Use a second worktree, or run them in sequence.

## Evidence

For each drive, record the exact command, its full output, and its exit code. Read the exit code, never a pipe's. Do not pipe a harness run into `tail` or `head`.

Render exit codes, as `Tools/render/shoot.sh` sets them: 0 passes with a PNG written. 3 means the render guard failed after the PNG, or the page step did not complete. 1 means the scene wrote no JSON, no Chrome was found, or Chrome wrote no screenshot. 2 means bad usage or no such scene.

Read the render log before trusting the picture. The log names every flat stand-in, grey box and unresolved anchor. On a machine with no handoff mockup and no Blizzard texture cache, portraits and the minimap terrain draw as flat colours, and the log says so. That is expected scaffolding, not a defect. A missing texture drawn as a grey box is not acceptable before/after art evidence.

Open the PNG and describe what it actually shows: the HUD style, the layout, the class, the element under test, and anything spilled, clipped or missing. A proof exercises the real user path through scene state and events. Do not swap in internal setters or weaken a journey to make it pass. If a scene or test lacks a precondition a journey needs, the journey reports a failure and the reason goes in that feature's `Gotchas`.

Evidence lives in `~/.cache/kstyleui-verify/`: the PNG, and any log you redirect there. Never commit rendered images. Report the PNG path, the render log's `drawables` and `wrote` lines, the regression file's output line, and both exit codes.

## Cleanup

Headless Chrome exits by itself. There is no server to stop. Kill only a process you started, by its own handle, never by process name.

Cleanup removes scratch state, never the evidence:

- Keep the PNG and logs in `~/.cache/kstyleui-verify/`.
- Remove probe leftovers you created, such as dumped DOM files in `~/.cache/kstyleui-verify/`.
- `Tools/render/out/` is regenerated harness output and git ignores it. Leave it, or delete the scene files you generated.
- `/c/dev` and the `null` file the Lua workaround creates in it are machine scaffolding. Every Windows run recreates the directory with `mkdir -p /c/dev`, so it is safe to remove `C:\dev\null` and the empty `C:\dev` directory at the end of a session. The next run's Launch step puts it back.
- The Chrome shim is machine scaffolding too. Leave `~/.cache/kstyleui-verify/chrome-shim.sh` in place for the next run, or remove it and recreate it from Launch.

After cleanup, confirm the evidence still exists:

```bash
ls -l ~/.cache/kstyleui-verify/
```

## Helpers

This skill ships no script in the repository. Its two helpers are machine scaffolding shown in full above: `mkdir -p /c/dev` and `~/.cache/kstyleui-verify/chrome-shim.sh`, selected through the harness's own `CHROME` variable and invoked by the Drive commands as written.
