# Task: release notes for v0.3.2

Write the notes PR for v0.3.2 from `staging`, covering `git log v0.3.1..origin/staging`: #761 gamepad: controller button icons on action bar keybinds while a gamepad is active (Action Bars > Controller button icons, on), a Controls choice (Keyboard or Gamepad) in setup and on the General page (General > Keyboard or gamepad bars, on); #762 the shaman totem choice fan gets its forged backing (dark band with an element-colour rim, element edges and tabs on every totem; the Frames row sits on a forged plate); #763 the consumables bar defaults to button size 26 with no gap (players who set their own keep it); #764 fixed: the setup window's pages (Welcome and the rest) and Options pages could open blank in game. CI-only and docs PRs (#758, #759, #760) skip.

Use each PR's `## Changelog`, verify every line against the code on staging, and give the Options path for each setting. Owner's voice (`C:/Users/leeba/.cache/kstyleui-evidence/voice/lee-discord-voice.txt`), no AI tells, no em dashes. Branded style of the v0.3.1 section in `CHANGELOG.md` and `docs/RELEASE_NOTES.md`, highlights of 120 characters or fewer, Notes.lua entry with translations (`strings.py sync`, `crlf.py`). Checks: lint, python, `test-options-notes`, both `test-options-preview-content-locales*`, `Tools.tests.test_release_changelog`, embed under 6000. PR `docs(release): v0.3.2 notes`, label `no changelog`. Do not merge, tag or post.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
