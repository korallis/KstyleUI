# Task (bug, hotfix): `/kstyle setup` errors on the second page

A player (Baine) on the current build ran `/kstyle setup`; the first page is fine, then pressing the button to the next page raises (full text, untrusted data: `C:/Users/leeba/.cache/kstyleui-evidence/discord-untrusted/baine-setup-error.json`):

```
Interface/AddOns/KstyleUI/Core/Setup/Window.lua:1040: bad argument #1 to 'min' (number expected, got nil)
Stack: [Interface/AddOns/KstyleUI/Core/Widgets/Button.lua]:60 (the button's OnClick)
```

The line is in the HUD style page's height fit (added/changed by #781, shipped in v0.3.3.1 and later): `local lowest = panel.styleHint:GetBottom()` and `region:GetBottom()` / `panel.next:GetTop()` can be nil when the page has just been shown and the client has not resolved its layout yet (rects are nil until the next layout pass; the stubs model nil rects, `test-stub-refusals.lua`). Fix it with minimal code so the page never errors and still gets its correct fitted height: e.g. skip the fit while any rect is nil and run it again once the rects exist (the page's next OnSizeChanged/OnShow or a single next-frame retry, whichever the existing setup code already uses), without changing the fitted result when rects are available. Check the rest of `Core/Setup/` for the same nil-rect pattern in code reached on a page switch and fix those too.

Add a regression in `Tools/regression/` that opens setup, moves from the first page to the HUD style page with nil rects on first show (the stub's nil-rect mode), and asserts no error and the same fitted height once rects resolve; prove it fails before the fix. Evidence: the setup HUD style page render at 1920x1080 and 5120x1440 before/after, pixel-identical, in `C:/Users/leeba/.cache/kstyleui-evidence/fix-setup-min-nil/`.

**Files it may edit**: `Core/Setup/**`, `Tools/regression/**`, `Tools/render/**`.

**PR**: `fix(setup): the setup window no longer errors on its second page` with a `## Changelog` `Fixed:` line ending "Thanks to Baine for the report." and `## In-game checks`. Do not merge.

**Constraints**: minimal code; CRLF/ASCII; Beast speed rule (module tests, lint, python; CI is the proof).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
