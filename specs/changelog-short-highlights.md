# Task: every changelog highlight and upgrading line fits in one short line (no "…" in Discord)

**Why**: the owner wants every changelog and announcement to look good, be fully branded, and be easy to read. `Tools/release/discord_post.py` shortens each **Highlights** and **Upgrading** bullet to 120 characters with "…". 51 bullets across 17 releases in `CHANGELOG.md` are longer, so the Discord embeds show sentences cut mid-word (v0.2.7: "…with your choice of readouts and…").

**Change**:
1. **Rewrite every Highlights and Upgrading bullet in `CHANGELOG.md`** to at most **120 characters**, keeping the facts and the player-friendly tone:
   - lead with the benefit;
   - drop detail that belongs in Added, Changed and Fixed;
   - no truncation, and no "…".

   Leave the Added, Changed and Fixed bullets alone unless they break the existing readability limit.
2. **Enforce it:** extend `Tools/tests/test_release_changelog.py` so every release's Highlights and Upgrading bullets must be at most 120 characters. The failure message names the fix ("shorten this highlight to 120 characters or fewer; move the detail to Added/Changed/Fixed").
3. **Check the result:** dry-run `discord_post.py` for v0.2.7, v0.2.8 and v0.2.8.1, and confirm no "…" appears in any embed.

**PR**: open a PR (not a draft) against `staging` titled `docs(release): short highlights that fit every announcement`, with the `no changelog` label. Do not merge.

**Files it may edit**: `CHANGELOG.md`, `Tools/tests/test_release_changelog.py`.

**Gate**: lint and python, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the three dry-run descriptions.
