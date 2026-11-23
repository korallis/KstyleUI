# Task: release announcements on Discord that look good, not a wall of text

**The owner's words**: "Make sure the discord announcement isn't just a wall of text and it looks good."

**Today**: `Tools/release/discord_post.py` pastes the whole CHANGELOG section as plain text, split into up to six 2000-character messages (v0.2.8 in #announcements was six walls of bullets). The release workflow runs it at `.github/workflows/release.yml:120-124` with the `DISCORD_RELEASE_WEBHOOK` secret.

**Change** (minimal; stdlib only):
1. **One message with one Discord embed per release:**
   - **title** `KstyleUI vX.Y.Z — <release name>`. The name comes from `docs/RELEASE_NOTES.md`'s heading (for example "the map and bars release"); fall back to the version alone;
   - **url**: the GitHub release page;
   - **colour**: KstyleUI's gold accent from `Core/Tokens.lua`;
   - **description**: the one-paragraph summary at the top of the CHANGELOG section, then a **Highlights** list. Use the section's `Highlights:` bullets when present, at most 6, each shortened to one line (cut at the first sentence or about 120 characters, without breaking words or markdown). With no Highlights, use the first 5 Added and Fixed lines;
   - **a counts line**: for example `14 added · 2 changed · 12 fixed`;
   - **fields**:
     - `Download` with CurseForge, Wago and GitHub as markdown links on one line;
     - `Full notes` linking to the GitHub release;
     - when the section has an `Upgrading` list, an `Upgrading` field with its bullets shortened;
   - **image**: the README's hero picture for the release, if `docs/` has a stable one (raw.githubusercontent URL pinned to the tag), else none;
   - **footer**: `KstyleUI for WoW Forever` with the date.

   Respect Discord's embed limits: title 256, description 4096, field value 1024, total 6000. Keep `allowed_mentions` empty and the suppress flags, but don't suppress embeds.
2. **Small releases** (like v0.2.8.1 with two Fixed lines) get the same embed, with the fixed lines as the highlights.
3. **`--dry-run`** prints the JSON payload and its character totals.
4. **Repost a past release:** a `workflow_dispatch` on `release.yml` with a `tag` input that runs **only** the Discord post step for that tag (no packaging, no uploads). It must be impossible to trigger an upload from it. A separate tiny workflow file may be smaller; choose the smaller option and say why. This lets the coordinator repost v0.2.8 after the old messages are deleted.
5. **Tests**: update `Tools/tests/test_discord_post.py`:
   - the v0.2.8 and v0.2.8.1 sections produce valid payloads within the limits;
   - the highlights shortening never breaks markdown;
   - the counts are correct;
   - the links are correct.

**Evidence**: post the v0.2.8 and v0.2.8.1 dry-run payloads in the PR body, plus a rendered preview. A simple HTML mock of the embed screenshotted with the render harness's Chrome is fine, never committed, in `C:/Users/leeba/.cache/kstyleui-evidence/discord-embed/`.

**PR**: open a PR (not a draft) against `staging` titled `build(release): Discord announcements as one tidy embed`, with the `no changelog` label. Say why `.github/workflows/` changed. Do not merge.

**Files it may edit**: `Tools/release/discord_post.py`, `Tools/tests/test_discord_post.py`, `.github/workflows/release.yml` (or one new small workflow), `docs/RELEASE_NOTES.md` (only if a heading needs the name format).

**Constraints**: minimal code; LF for tools. Run gate lint and python, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the preview path.
