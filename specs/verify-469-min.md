# Minimal-code review: #469 at 1c394c61

Work only in your own worktree; never change `C:\Projects\KstyleUI` or another worktree. Check out `1c394c61f5ed704ab187334fa5e53b84eb3754c6` (draft PR https://github.com/korallis/KstyleUI/pull/469), base `1d7b635948b81675583e29c31e9f92b62b6703d3`. Edit nothing, push nothing, comment nothing.

**Goal**: the owner's rule is minimal code: if it can be done in a few lines, do it in a few lines; no file, helper, abstraction, dependency, option plumbing, dead branch or comment the change does not need; prefer deleting to adding. This PR was already reviewed for correctness; review only size and simplicity. Read every addon-code hunk (`git diff 1d7b635948b81675583e29c31e9f92b62b6703d3..1c394c61f5ed704ab187334fa5e53b84eb3754c6 -- . ':!Tools' ':!docs' ':!**/Locales/**'`), then the tests only where they are oversized.

**Report**: start with "minimal 1c394c61"; PASS (nothing material to cut) or ISSUES: each cut with file:line, why it is not needed, the smaller version (a short code sketch) and lines saved. Behaviour, defaults, settings the owner asked for (every change toggleable, ON by default) and tests stay; only flag cuts that keep behaviour identical. Run `bash scripts/gate.sh lint` only if you need to prove a claim. Total the lines saved.
