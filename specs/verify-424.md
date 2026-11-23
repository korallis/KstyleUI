# Verify: #424 engraved rune rim at 5ae453a6

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `5ae453a609b4f294e780357cf9cdca51c6fc293b` (draft PR https://github.com/korallis/KstyleUI/pull/424). Base is `f6144445fcd16f9e922607e5ed7cc4c65e737414`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\ui-rune-rim.md`. Author evidence and sheets: `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\rune-rim\evidence.txt`, `compare-5120x1440.png`, `compare-3456x2234.png`, `compare-1920x1080.png`.

**Allowed files**: `Core/Widgets/Medallion.lua`, `Core/Tokens.lua` (new entries only), `Tools/media/**`, `Media/Textures/Medallions/**`, `Media/PROVENANCE.md`, `Tools/regression/**` (tests for this), `docs/medallions.md`.

**Gate**: `bash scripts/gate.sh` (the `lua` group runs natively; Windows wall-clock overruns and four known files are PR 7's). Windows bar: `gate.sh lint` exit 0 plus the new and touched tests under `lua5.1`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`; `verify/SKILL.md` documents rendering.

**Checks**:
- Original art: regenerate the rim texture with the repo's generator at the SHA and compare it byte for byte (or pixel for pixel) with the committed PNG; confirm no external image is an input (`Media/PROVENANCE.md`).
- Look: render the warlock's player, target, pet and party medallions in Medallions at 5120x1440, 3456x2234 (0.8158) and 1920x1080 with `--strict`; open them; check the engraving is crisp at 5120x1440, has no moire or blur at 1920x1080, sits inside the rim (no spill onto the portrait or past the ring), and keeps the level badge readable. Frames and Orbs pixel-identical to base.
- Texture registration: the new registry/load test fails when the texture is unregistered (no silent fallback in `Medallion.lua`); the texture's size and format are valid for the client (power-of-two, format the other medallion textures use).
- The author says the shared `medRing` registration was reused without `Core/Tokens.lua` edits: confirm nothing else that uses `medRing` (grep) changes appearance unintentionally.
- CI run 43944912284 green for the SHA; `git diff --stat` within the allowed files; zip size change; suppressions grep; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY; blast radius via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified 5ae453a6"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
