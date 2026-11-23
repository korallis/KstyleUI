# Verify: #417 render harness (auto size honours the game's fit; gallery fixes) at 4c011921

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `4c0119215f073f7fae42466f04c7fb5a4684e096` (draft PR https://github.com/korallis/KstyleUI/pull/417). Base is `8326aab1f465e22300355d93434506a15e4e7832`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\harness-autosize-gallery.md`. Approved exception: regenerated `hud_reference` rows in `Tools/regression/pixel_allow.tsv` (by its generator, never by hand) with a `Baseline-Growth: LEE-5826` trailer; LEE-5826 tracks fixing those regions. Author report: `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\harness\report.txt`.

**Allowed files**: `Tools/render/**`, `Tools/tests/test_render*.py`, `docs/feature-map.md`, and the `hud_reference` rows of `Tools/regression/pixel_allow.tsv`.

**Gate**: `bash scripts/gate.sh` (on Windows the `lua` group now runs natively; failures from Lua shell calls fixed by #413 and Windows wall-clock overruns are known). Windows bar: `gate.sh lint` exit 0 and the new tests. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. `verify/SKILL.md` documents rendering on this machine.

**Checks**:
- Auto size calls the addon's real fit code (no copied numbers): at 3456x2234 it gives the game's value (about 0.8158); at 5120x1440 and 1920x1080 it equals the addon's own fit result. Run the new tests at base (red) and SHA (green).
- `gallery_options` and `gallery_unitframes` pass `--strict`; open the PNGs and describe them; any grey boxes, truncation or spill?
- The baseline: regenerate `pixel_allow.tsv` yourself with its generator at the SHA and diff it against the committed file (must match); every changed row is a `hud_reference` row; the counts rose only because of the true size (show one region at old vs new size); no row outside `hud_reference` changed; `scripts/check-suppressions.sh` passes with the trailer.
- Nothing else that used `RENDER_SIZE=auto` (README pictures via `Tools/render/readme.py`, gallery scripts, `verify/SKILL.md`) silently changes meaning without a doc update.
- Rebase cleanliness onto current `origin/staging` (scratch branch); CI run 43927880771 green for the SHA; `git diff --stat` within allowed files; suppressions grep.
- Comments: `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY; blast radius: `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified 4c011921"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
