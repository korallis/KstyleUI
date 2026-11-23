# Task: post a branded roadmap to Discord, using the release embed's style

**Goal**: the owner wants a roadmap post in #announcements, in the same branding and tone as the release embeds from PR #575: logo author, gold accent, banner, footer, short readable highlights.

**Change** (minimal; reuse `Tools/release/discord_post.py` and its embed helpers):
1. **`docs/ROADMAP.md`**, the source of truth. Copy the content from `C:/Users/leeba/.cache/kstyleui-roadmap-draft.md`, whose structure is: title, intro line, then one `## vX.Y.Z — name` section per planned release, each with an "Estimated:" line, a one-line summary and a "Highlights:" list, then `## Later` and a closing line. Keep the text exactly as given; the coordinator edits the wording.
2. **A `--roadmap` mode in `discord_post.py`.** It builds **one message with one embed per section** (Discord allows up to 10 embeds and 6000 characters per message; check this):
   - **each release embed:** the title "KstyleUI vX.Y.Z — name", the gold accent, the logo as the author icon, the "Estimated:" line as the first line, then the summary and the highlights as bullets;
   - **the first embed:** carries the intro;
   - **the last embed:** carries "Later" and the closing line, plus the banner image and the footer "KstyleUI for WoW Forever · Roadmap · <date>".

   Every highlight must be 120 characters or fewer, with no ellipsis, enforced by a test as the changelog is. Support `--dry-run` (print the payload) and `--edit <message_id>`, so the roadmap can be updated in place later.
3. **The release workflow's dispatch** gets a `roadmap` boolean input (with `message_id` optional) that runs only the Discord step in roadmap mode. It must stay impossible to package or upload from it, and the existing test should prove that.
4. **Tests:** payload limits, section parsing, highlight length, the edit path (with the fake opener) and the workflow guard.

**Evidence**: a dry-run payload and a rendered preview of the embeds in Discord's look (an HTML mock screenshotted with headless Chrome) in `C:/Users/leeba/.cache/kstyleui-evidence/discord-roadmap/`.

**PR**: open a PR (not a draft) against `staging` titled `docs(roadmap): a branded roadmap post for Discord`, with the `no changelog` label. Do not merge.

**Files it may edit**: `docs/ROADMAP.md` (new), `Tools/release/discord_post.py`, `Tools/tests/test_discord_post.py`, `.github/workflows/release.yml`, `Tools/tests/test_workflows.py`, `Tools/hooks/ci_scope.py` (READ_BY_TESTS, if needed).

**Gate**: lint and python, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the preview path.
