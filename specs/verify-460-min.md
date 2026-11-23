# Minimal-code review: #460 at 7faa5593

Work only in your own worktree; never change `C:\Projects\KstyleUI` or another worktree. Check out `7faa55936b0851eba9b4057f7e745e04e2b9cc6e` (draft PR https://github.com/korallis/KstyleUI/pull/460), base `1d7b635948b81675583e29c31e9f92b62b6703d3`. Edit nothing, push nothing, comment nothing.

**Goal**: the owner's rule is minimal code: if it can be done in a few lines, do it in a few lines; no file, helper, abstraction, dependency, option plumbing, dead branch or comment the change does not need; prefer deleting to adding. This PR was already reviewed for correctness; review only size and simplicity. Read every addon-code hunk (`git diff 1d7b635948b81675583e29c31e9f92b62b6703d3..7faa55936b0851eba9b4057f7e745e04e2b9cc6e -- . ':!Tools' ':!docs' ':!**/Locales/**'`), then the tests only where they are oversized.

**Report**: start with "minimal 7faa5593"; PASS (nothing material to cut) or ISSUES: each cut with file:line, why it is not needed, the smaller version (a short code sketch) and lines saved. Behaviour, defaults, settings the owner asked for (every change toggleable, ON by default) and tests stay; only flag cuts that keep behaviour identical. Run `bash scripts/gate.sh lint` only if you need to prove a claim. Total the lines saved.
