# Verify: #475 at 26e53389

Work only in your own worktree; never change `C:\Projects\KstyleUI` or another worktree. Check out `26e53389cea9702b67c608bbeadad5a8bd07c231` (draft PR https://github.com/korallis/KstyleUI/pull/475), base `1d7b635948b81675583e29c31e9f92b62b6703d3`. Edit nothing, push nothing, comment nothing. This PR ships in v0.2.7.

**Spec**: `C:\Projects\KstyleUI\specs\feat-role-spec-customisation.md`. Author evidence: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_d482bd9ae996\evidence.txt`. Owner rules: every change toggleable and ON by default; meter bars keep full class colours.

**Local checks**: `bash scripts/gate.sh lint`; with PUC `lua5.1` the tests the PR touches plus `test-comments.lua` and `test-syntax.lua`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start. At most 2 renders at a time.

**Checks**: the tank sees threat and not damage, healer/DPS see damage, per-role choice editable with those defaults; off keeps today's behaviour exactly; a role or spec change in combat applies at combat end; the per-spec profile switch goes through ProfileChanged, defaults to the current profile for every spec (turning it on changes nothing), and handles classes with no specs via the role row; the spec/role APIs and events are proven against the `forever` branch of Gethe/wow-ui-source at `9dc84f0` (clone `C:\Users\leeba\.cache\wow-ui-source`), with `issecretvalue` before comparisons; one event handler per owner; strings localised. **Minimal code**: report every cut that keeps behaviour identical (file:line, the smaller version, lines saved); over-engineering is an issue. CI run 44343580668 green.

**Report**: start with "verified 26e53389"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".
