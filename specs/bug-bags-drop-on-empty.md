# Task: a held item can be put into the bags when they are collapsed by category

**Goal**: the owner, from his game: "edge case: if I split a stack in half and the bags are minimalistic like this, I can't put it in the bag." In the category view the bag and bank windows show each category's items, and EMPTY as one summary tile ("47 3" counts) instead of individual free slots, so a split stack or any item on the cursor has nowhere to drop. Screenshot: `C:\Users\leeba\.cache\lee-shots\bags-split-stack.png` (bank at left, bags at right).

**Target**: KstyleUI on the latest `origin/staging`. `KstyleUI_Bags/**` (`Window.lua`, `Slot.lua`, `Inventory.lua`, `Bank.lua`, `Data.lua`). Blizzard APIs for placing the cursor item: grep the Forever UI source (`forever` branch of Gethe/wow-ui-source at `9dc84f0`, clone `C:\Users\leeba\.cache\wow-ui-source`; for example `C_Container.PickupContainerItem`, `CursorHasItem`, `PutItemInBag`, `C_Container.ContainerIDToInventoryID`), and name the files.

**Change**:
1. Clicking or dropping onto the EMPTY tile (and onto any category's free area) with an item on the cursor puts it into the first free slot that can hold it (respecting bag type: a reagent or profession bag only for matching items; the keyring for keys), in the bags window for bags and in the bank window for the bank. A right-click with nothing on the cursor does nothing new.
2. While the cursor holds an item, show a clear drop affordance: the EMPTY tile highlights (and, if simplest, expands to show real free slots until the item is placed).
3. Works for split stacks, items dragged from the bank to the bags and back, and items dragged from the character pane; never in a way that taints or calls protected functions in combat (bags are not protected, but check).
4. Tests: with an item on the cursor, a click on EMPTY places it in the first suitable free slot (bags and bank), a bag-type mismatch skips that bag, and nothing happens with an empty cursor (red on staging, green after).

**Options**: per the owner rule, the drop target is a fix to existing behaviour; if you add the expand-on-drag view, give it a Bags option (default on).

**Constraints**: AGENTS.md rules (CRLF/ASCII, one comment per TOC-loaded file, Forever API grep, strings through `python Tools/locale/strings.py sync`). Another worker is changing bag slot figures and the bag header (G7, G10) in `KstyleUI_Bags/**`: keep to the drop and placement code and rebase before the PR. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Open a **draft** PR against `staging`: title `fix(bags): drop a held item onto the empty slots`, `## Summary`, `## Changelog` (`Fixed: With the bags grouped by category, you can drop a held or split item onto the empty slots to put it away.`), `## In-game checks`. Do not merge.

**Files it may edit**: `KstyleUI_Bags/**`, `Core/Locales/**` and `Tools/locale/*.json` via strings.py, `Tools/regression/**`, `Tools/render/scenes/**`, `docs/feature-map.md`.

**Gate**: `bash scripts/gate.sh` (natively green on Windows; Known failing: none).

**Evidence of done**: the behaviour tests red then green; a render of the bags with an item on the cursor; the draft PR's green `checks` run.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id and Gate output.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
