# Verify: PR #410 (Medallions WP-C unit cluster) at dd616851

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `dd616851` (branch `capy/medallions-unit-cluster`, PR https://github.com/korallis/KstyleUI/pull/410). Base is `d70a3f5e` (origin/staging). Edit nothing, push nothing, comment nothing.

**What it claims**: read the PR body in full ("Decisions for the Captain" items 1-8, "Pictures") and the rebase worker's evidence at `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\renders\KSTY-113\evidence.txt`. Compare sheets: `compare-5120x1440.png`, `compare-3456x2234.png`, `compare-1920x1080.png` in the same folder.

**Gate**: `bash scripts/gate.sh`; known failing on Windows: `lua` and `python` groups (AGENTS.md). Windows bar: `gate.sh lint` exit 0 plus the PR's touched and new `Tools/regression/test-*.lua` files run directly with `lua5.1` (all must pass). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. `verify/SKILL.md` documents rendering on this machine.

**Checks**:
- Project rules from AGENTS.md: addon files ASCII/CRLF (`python3 Tools/dev/crlf.py --check`), one comment per TOC-loaded file, Forever API names proven in the source (grep), `K.Widgets.FontString`/`K.Widgets.Cover`, no secret-value comparisons (decision 4 claims the bar finish never computes on the fill colour: prove it from the code), no reads back from engine aura buttons.
- Product rules: one row of action buttons on every screen; action buttons always above the hub; no textures around bars. Prove from tests (`test-actionbars-medallions-slab`, `test-layout-medallions-hub`, `test-layout-medallions`) and by rendering yourself the owner's case (undead male warlock with an imp, Medallions) at 5120x1440, 3456x2234 (RENDER_SIZE 0.8158) and 1920x1080 with `--strict`. Open each PNG and describe it.
- Frames and Orbs unchanged versus base at those three screens (pixel diff, no bounding box).
- Tests: apply `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\principle-test-behavior-not-implementation\SKILL.md`; run the one-row tests at base (must fail at 16:9, since base stacks two rows below 21:9) and at the SHA (pass). Paste both.
- CI: `gh pr checks 410` and the checks run for dd616851, all green.
- `git diff --stat d70a3f5e..dd616851`; grep the diff for suppressions (`luacheck: *ignore`, workaround markers without a ticket id).
- Comments: `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY on the diff; skip its greeting.
- Blast radius: `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5 (other HUD styles, other classes without a pet or with stances, screens in docs/feature-map.md).

**Report**: start with "verified dd616851"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".
